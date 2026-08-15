#!/usr/bin/env python3
"""shesh-ambient CLI.

Commands:
  tick       run one catch-up pass (called by the timer)
  offer      check whether to make a proactive offer now (hotkey/overlay)
  status     print current context + what would run/offer (dry-run)

System probing is via subprocess; every probe fails open to safe defaults so
a tick can never crash the session.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys
import time
from pathlib import Path

from .policy import Context
from .proactivity import ProactivityState, mark_offered, pick_offer, should_offer
from .scheduler import Job, SchedulerState, jittered_delays, plan

STATE_DIR = Path.home() / ".local/state/shesh/ambient"
JOBS: list[Job] = [
    Job("smart-organizer", 24 * 3600, ["shesh-files", "--once"], heavy=True, jitter_s=120),
    Job("backup", 24 * 3600, ["shesh-backup"], needs_network=True, heavy=True),
    Job("maintenance", 7 * 24 * 3600, ["shesh-maintenance"], heavy=True),
    Job("update-check", 12 * 3600, ["shesh-update-check"]),
    Job("health", 6 * 3600, ["shesh-health"]),
]


def _sh(cmd: list[str], timeout: int = 5) -> str:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except Exception:  # noqa: BLE001 - probing must not crash
        return ""


def _nproc() -> int:
    try:
        return max(1, Path("/proc/cpuinfo").read_text().count("processor\t:"))
    except OSError:
        return 4


def _uptime_s() -> float:
    try:
        return float(Path("/proc/uptime").read_text().split()[0])
    except (OSError, ValueError):
        return 0.0


def probe_context() -> Context:
    ctx = Context()

    # idle seconds (Hyprland reports ms; xprintidle reports ms too)
    for cmd, divisor in ((["hyprctl", "inactivity"], 1000), (["xprintidle"], 1000)):
        out = _sh(cmd).strip()
        if out.isdigit():
            ctx.idle_seconds = int(out) // divisor
            break

    # fullscreen
    fs = _sh(
        [
            "bash",
            "-c",
            "hyprctl activewindow -j 2>/dev/null | grep -o '\"fullscreen\":[0-9]*' "
            "| cut -d: -f2 | head -1",
        ]
    ).strip()
    ctx.fullscreen = fs == "1"

    # AC / battery
    ac = Path("/sys/class/power_supply/AC/online")
    if ac.exists():
        ctx.on_ac = ac.read_text().strip() == "1"
    ctx.on_battery = not ctx.on_ac
    cap = Path("/sys/class/power_supply/BAT0/capacity")
    if cap.exists() and cap.read_text().strip().isdigit():
        ctx.battery_percent = int(cap.read_text().strip())

    # CPU pressure from 1-min load average (rough %)
    try:
        load = float(Path("/proc/loadavg").read_text().split()[0])
        ctx.cpu_percent = min(100.0, load * 100 / _nproc())
    except (OSError, ValueError):
        # Non-Linux host or an unreadable /proc/loadavg: cpu_percent keeps its
        # 0.0 default, which the scheduler treats as "no pressure signal".
        pass

    ctx.network_online = bool(_sh(["bash", "-c", "getent hosts github.com"]).strip())
    ctx.uptime_minutes = int(_uptime_s() // 60)
    return ctx


def tick(args: argparse.Namespace) -> int:
    ctx = probe_context()
    state = SchedulerState.load(STATE_DIR / "jobs.json")
    runplan = plan(JOBS, state, now=time.time(), ctx=ctx)
    delays = jittered_delays(runplan.to_run)
    for job, delay in zip(runplan.to_run, delays, strict=False):
        if not args.dry_run:
            time.sleep(delay)
            subprocess.run(job.command, check=False)
            state.last_run[job.name] = time.time()
    if not args.dry_run:
        state.save(STATE_DIR / "jobs.json")
    print(
        json.dumps(
            {
                "ran": [j.name for j in runplan.to_run],
                "deferred": runplan.deferred,
                "skipped": runplan.skipped,
                "busy": ctx.busy,
                "on_ac": ctx.on_ac,
                "idle_s": ctx.idle_seconds,
            },
            indent=2,
        )
    )
    return 0


def offer(_args: argparse.Namespace) -> int:
    ctx = probe_context()
    pstate = ProactivityState()
    pf = STATE_DIR / "proactivity.json"
    if pf.exists():
        data = json.loads(pf.read_text())
        pstate.last_offer_ts = data.get("last_offer_ts", 0)
        pstate.offered_today = set(data.get("offered_today", []))
        pstate.snoozed_until = data.get("snoozed_until", 0)

    if should_offer(ctx, pstate, now=time.time()):
        # Data-aware proactivity: gather real facts (git, backup, downloads,
        # disk) so the offer line is concrete, never a static guess. Each fact
        # is optional — unavailable sources fall back to the default detail.
        from .sources import gather_facts

        home = pathlib.Path.home()
        repo_candidate = home / "src" / "shesh-ecosystem"
        facts = gather_facts(
            repo=str(repo_candidate) if repo_candidate.is_dir() else None,
            state_dir=str(home / ".local" / "share" / "shesh"),
            downloads_dir=str(home / "Downloads"),
        )
        chosen = pick_offer(ctx, pstate, facts=facts)
        if chosen:
            mark_offered(pstate, chosen, now=time.time())
            pf.parent.mkdir(parents=True, exist_ok=True)
            pf.write_text(
                json.dumps(
                    {
                        "last_offer_ts": pstate.last_offer_ts,
                        "offered_today": list(pstate.offered_today),
                        "snoozed_until": pstate.snoozed_until,
                    },
                    indent=2,
                )
            )
            print(
                json.dumps(
                    {
                        "offer": chosen.title,
                        "detail": chosen.detail,
                        "action": chosen.action,
                    }
                )
            )
            return 0
    print(json.dumps({"offer": None, "busy": ctx.busy, "pause": not ctx.natural_pause}))
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Shesh ambient scheduler/proactivity")
    ap.add_argument("--dry-run", action="store_true")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("tick")
    sub.add_parser("offer")
    args = ap.parse_args(argv)
    return {"tick": tick, "offer": offer}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
