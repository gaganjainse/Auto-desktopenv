#!/usr/bin/env python3
"""Shesha MCP server — Smart Organizer control.

Lets Newelle/Shesha trigger organization, inspect recent moves, undo the last
batch, and pause/resume the watcher — all by voice.
License: GPL-3.0   See docs/SHESHA/05_SMART_ORGANIZER_V2.md
"""
from __future__ import annotations

import json
import os
import sqlite3
import subprocess
from datetime import UTC, datetime, timedelta
from pathlib import Path

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("smart-organizer")

HOME = Path.home()
STATE = HOME / ".local" / "share" / "smart-organizer"
DB = STATE / "history.db"
UNDO_LOG = STATE / "undo.jsonl"


def _bin(name: str) -> str:
    return str(HOME / ".local" / "bin" / name)


@mcp.tool()
def organize(path: str = "~/Downloads", dry_run: bool = False) -> str:
    """Run smart-organizer on a path (default ~/Downloads). Set dry_run=true to preview."""
    target = os.path.expanduser(path)
    cmd = [_bin("smart-organizer"), "--once", "--dir", target]
    if dry_run:
        cmd.append("--dry-run")
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    return (r.stdout + r.stderr).strip()[-4000:] or "done"


@mcp.tool()
def last_moves(n: int = 10) -> list[dict]:
    """Return the last n file moves performed by the organizer."""
    n = max(1, min(n, 100))
    if not DB.exists():
        return []
    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    rows = con.execute(
        "SELECT original_path, destination_path, method, confidence, timestamp "
        "FROM moves ORDER BY id DESC LIMIT ?",
        (n,),
    ).fetchall()
    con.close()
    return [dict(r) for r in rows]


@mcp.tool()
def undo_last() -> str:
    """Reverse the most recent batch of moves recorded in the undo log."""
    if not UNDO_LOG.exists():
        return "Nothing to undo."
    lines = UNDO_LOG.read_text().splitlines()
    if not lines:
        return "Nothing to undo."
    # A "batch" = lines sharing the same minute timestamp (one organize run).
    last = json.loads(lines[-1])
    batch_ts = last.get("batch")
    moved_back = 0
    remaining = []
    for line in reversed(lines):
        ev = json.loads(line)
        if ev.get("batch") == batch_ts and Path(ev["to"]).exists():
            dst = Path(ev["to"])
            src = Path(ev["from"])
            src.parent.mkdir(parents=True, exist_ok=True)
            dst.rename(src)
            moved_back += 1
        else:
            remaining.append(line)
    UNDO_LOG.write_text("\n".join(reversed(remaining)) + ("\n" if remaining else ""))
    return f"Restored {moved_back} file(s) from batch {batch_ts}."


@mcp.tool()
def pause(minutes: int = 60) -> str:
    """Pause the real-time file watcher for N minutes (e.g. during a big download)."""
    subprocess.run(["systemctl", "--user", "stop", "smart-organizer-watch.service"])
    # schedule resume via a transient timer
    when = (datetime.now(UTC) + timedelta(minutes=minutes)).strftime("%H:%M")
    subprocess.run(
        ["systemd-run", "--user", "--on-calendar", when,
         "--unit=shesha-org-resume", "systemctl", "--user", "start",
         "smart-organizer-watch.service"],
        capture_output=True, text=True,
    )
    return f"Watcher paused for {minutes} min (resumes ~{when})."


@mcp.tool()
def resume() -> str:
    """Resume the real-time file watcher."""
    r = subprocess.run(
        ["systemctl", "--user", "restart", "smart-organizer-watch.service"],
        capture_output=True, text=True,
    )
    return r.stdout.strip() or "watcher resumed"


if __name__ == "__main__":
    mcp.run(transport="stdio")
