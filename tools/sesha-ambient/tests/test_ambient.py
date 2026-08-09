"""Offline tests for the scheduler, policy, and proactivity engine."""
from __future__ import annotations

import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from sesha_ambient.policy import Context, decide  # noqa: E402
from sesha_ambient.proactivity import (  # noqa: E402
    DEFAULT_OFFERS,
    ProactivityState,
    mark_offered,
    pick_offer,
    should_offer,
    snooze,
)
from sesha_ambient.scheduler import Job, SchedulerState, jittered_delays, plan  # noqa: E402


# ── policy ────────────────────────────────────────────────────────────────
def test_runs_when_idle_on_ac():
    ctx = Context(idle_seconds=200, on_ac=True, network_online=True)
    assert decide(False, ctx) == "run"


def test_defers_fullscreen():
    ctx = Context(fullscreen=True, on_ac=True, idle_seconds=200)
    assert decide(False, ctx) == "defer"


def test_defers_presentation_and_call():
    assert decide(False, Context(presentation=True, on_ac=True)) == "defer"
    assert decide(False, Context(active_call=True, on_ac=True)) == "defer"


def test_skips_network_job_when_offline():
    assert decide(True, Context(network_online=False, on_ac=True)) == "skip"


def test_defers_on_low_battery():
    ctx = Context(on_battery=True, battery_percent=20, on_ac=False)
    assert decide(False, ctx) == "defer"


# ── scheduler catch-up ────────────────────────────────────────────────────
def test_due_jobs_run_on_wake():
    jobs = [Job("health", 3600, ["true"])]
    state = SchedulerState(last_run={"health": 0})
    ctx = Context(idle_seconds=300, on_ac=True)
    plan_ = plan(jobs, state, now=7200, ctx=ctx)
    assert [j.name for j in plan_.to_run] == ["health"]
    assert plan_.deferred == [] and plan_.skipped == []


def test_heavy_job_defers_unless_ac_and_idle():
    jobs = [Job("backup", 86400, ["true"], heavy=True)]
    state = SchedulerState(last_run={"backup": 0})
    # battery -> defer
    ctx_bat = Context(on_battery=True, on_ac=False, idle_seconds=300)
    assert plan(jobs, state, now=200_000, ctx=ctx_bat).deferred == ["backup"]
    # AC but just started using the machine -> defer
    ctx_busy = Context(on_ac=True, idle_seconds=10)
    assert plan(jobs, state, now=200_000, ctx=ctx_busy).deferred == ["backup"]
    # AC + idle -> run
    ctx_ok = Context(on_ac=True, idle_seconds=200)
    run = plan(jobs, state, now=200_000, ctx=ctx_ok)
    assert [j.name for j in run.to_run] == ["backup"]


def test_no_duplicate_run_before_interval():
    jobs = [Job("health", 3600, ["true"])]
    state = SchedulerState(last_run={"health": 3500})
    ctx = Context(idle_seconds=300, on_ac=True)
    assert plan(jobs, state, now=3600, ctx=ctx).to_run == []


def test_jitter_spreads_jobs():
    jobs = [Job("a", 60, ["x"]), Job("b", 60, ["x"]), Job("c", 60, ["x"])]
    delays = jittered_delays(jobs, rng=random.Random(1))
    assert delays == sorted(delays)       # monotonic
    assert len(set(delays)) == len(jobs)  # distinct


# ── proactivity / warmth ──────────────────────────────────────────────────
def test_does_not_offer_when_busy():
    state = ProactivityState()
    ctx = Context(fullscreen=True, on_ac=True)
    assert not should_offer(ctx, state, now=1000)


def test_offers_at_natural_pause():
    state = ProactivityState(last_offer_ts=0)
    ctx = Context(idle_seconds=120, on_ac=True, work_hours=True)
    assert should_offer(ctx, state, now=10_000)


def test_respects_cooldown():
    state = ProactivityState(last_offer_ts=9000)
    ctx = Context(idle_seconds=120, on_ac=True)
    assert not should_offer(ctx, state, now=10_000)  # only 1000s later


def test_snooze_blocks_offers():
    state = ProactivityState()
    snooze(state, 3600, now=1000)
    ctx = Context(idle_seconds=120, on_ac=True)
    assert not should_offer(ctx, state, now=2000)
    assert should_offer(ctx, state, now=6000)


def test_pick_offer_returns_one_and_records():
    state = ProactivityState()
    offer = pick_offer(Context(idle_seconds=120, on_ac=True), state,
                       rng=random.Random(0))
    assert offer is not None and offer.title
    mark_offered(state, offer, now=1000)
    # daily cap works
    for _ in range(10):
        o = pick_offer(Context(idle_seconds=120, on_ac=True), state, rng=random.Random(1))
        if o:
            mark_offered(state, o, now=1000)
    assert len(state.offered_today) <= len(DEFAULT_OFFERS)


def test_quiet_hours_no_offer():
    state = ProactivityState()
    ctx = Context(idle_seconds=300, on_ac=True, work_hours=False)
    assert not should_offer(ctx, state, now=1000)
