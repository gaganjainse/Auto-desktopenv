"""Catch-up scheduler for a laptop that sleeps/shuts down.

Unlike `OnCalendar=... Persistent=true` (which fires *every* missed job the
instant you unlock — all at once), this scheduler:

- records the last successful run per job in a small JSON state file,
- on wake/boot/network, finds due jobs and runs them **one at a time with jitter**,
- checks the courtesy policy first and defers if you're busy,
- separates heavy jobs (backup, organizer) from light ones (update check, health),
- never runs more than N minutes per catch-up so it can't hog the machine.

This is pure logic; the actual system probing (idle, fullscreen, CPU) and
command execution are injected, making it testable offline.
"""
from __future__ import annotations

import json
import random
from dataclasses import dataclass, field
from pathlib import Path

from .policy import Context, decide


@dataclass
class Job:
    name: str
    interval_s: int            # how often it should run
    command: list[str]
    needs_network: bool = False
    heavy: bool = False        # AC + idle preferred
    jitter_s: int = 60        # max random delay before run


@dataclass
class SchedulerState:
    last_run: dict[str, float] = field(default_factory=dict)

    @classmethod
    def load(cls, path: Path) -> SchedulerState:
        if path.exists():
            return cls(**json.loads(path.read_text()))
        return cls()

    def save(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"last_run": self.last_run}, indent=2))


@dataclass
class RunPlan:
    to_run: list[Job]
    deferred: list[str]
    skipped: list[str]


def plan(jobs: list[Job], state: SchedulerState, now: float, ctx: Context,
         max_catch_up_s: int = 1800) -> RunPlan:
    """Decide which due jobs should run now vs defer/skip."""
    due = [j for j in jobs if now - state.last_run.get(j.name, 0) >= j.interval_s]
    to_run: list[Job] = []
    deferred: list[str] = []
    skipped: list[str] = []
    budget = max_catch_up_s
    for j in due:
        verdict = decide(j.needs_network, ctx)
        if verdict == "skip":
            skipped.append(j.name)
            continue
        if verdict == "defer":
            deferred.append(j.name)
            continue
        # Heavy jobs only run on AC and with some idle budget.
        if j.heavy and not (ctx.on_ac and ctx.idle_seconds >= 120):
            deferred.append(j.name)
            continue
        if budget < 60:    # don't start a job if we'd exceed the catch-up window
            deferred.append(j.name)
            continue
        to_run.append(j)
        budget -= min(j.interval_s, 300)   # rough cost estimate
    return RunPlan(to_run, deferred, skipped)


def jittered_delays(jobs: list[Job], rng: random.Random | None = None) -> list[float]:
    """Return per-run startup delays (seconds), spread so jobs don't pile up."""
    rng = rng or random
    delays: list[float] = []
    acc = 0.0
    for j in jobs:
        acc += rng.uniform(0, j.jitter_s)
        delays.append(acc)
    return delays
