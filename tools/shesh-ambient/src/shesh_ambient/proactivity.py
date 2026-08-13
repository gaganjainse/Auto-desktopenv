"""Proactivity with warmth — offer help at natural pauses, never mid-task.

The engine watches coarse signals (idle, recent task completion, workspace
switch) and, when `Context.natural_pause` is true, picks *one* short, optional
offer from a prioritized list. Offers are throttled so the agent never nags
(max one per cooldown; quiet hours respected; user can snooze).

This is intentionally small and local-first. It does not call the LLM on every
keystroke — it only fires at genuine pauses.
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field

from .policy import Context
from .sources import Facts  # noqa: F401  (type only, avoids cycle)


@dataclass
class Offer:
    title: str  # one line shown in the overlay
    detail: str  # optional second line
    action: str  # a shesh command / MCP tool call
    priority: int = 50  # higher = more eager to show


@dataclass
class ProactivityState:
    last_offer_ts: float = 0.0
    offered_today: set = field(default_factory=set)
    snoozed_until: float = 0.0
    min_interval_s: int = 1800  # at most one offer every 30 min
    offers_per_day: int = 3


DEFAULT_OFFERS = [
    Offer("Take a 2-minute break?", "You've been heads-down a while.", "break", priority=70),
    Offer("Organize Downloads?", "Files are waiting in Inbox.", "organize-downloads", priority=60),
    Offer("Commit your work?", "You have uncommitted changes.", "git-status", priority=55),
    Offer("Summarize today's notes?", "I can draft a daily note.", "daily-summary", priority=40),
    Offer("Run a backup?", "Last backup was a while ago.", "backup", priority=30),
    Offer("Clear the air?", "Close distracting apps for focus mode.", "focus-mode", priority=25),
]


def should_offer(ctx: Context, state: ProactivityState, now: float) -> bool:
    if now < state.snoozed_until:
        return False
    if not ctx.natural_pause:
        return False
    if now - state.last_offer_ts < state.min_interval_s:
        return False
    return len(state.offered_today) < state.offers_per_day


def pick_offer(
    ctx: Context,
    state: ProactivityState,
    candidates: list[Offer] | None = None,
    rng: random.Random | None = None,
    facts: Facts | None = None,
) -> Offer | None:
    """Return one offer appropriate to the moment, or None to stay quiet.

    When real facts are provided, the chosen offer's detail line is replaced
    with a concrete one (real counts/ages) instead of the static default.
    """
    candidates = candidates or DEFAULT_OFFERS
    rng = rng or random.Random()

    # Weight by priority; occasionally vary so it doesn't feel robotic.
    pool = [c for c in candidates if c.title not in state.offered_today]
    if not pool:
        return None
    pool.sort(key=lambda o: o.priority, reverse=True)
    # Usually pick from the top 3, sometimes a lower one for variety.
    top = pool[:3]
    offer = rng.choice(top)
    if facts is not None:
        from .sources import detail_for

        detail = detail_for(offer.action, facts)
        if detail:
            return Offer(offer.title, detail, offer.action, offer.priority)
    return offer


def mark_offered(state: ProactivityState, offer: Offer, now: float) -> None:
    state.last_offer_ts = now
    state.offered_today.add(offer.title)


def snooze(state: ProactivityState, seconds: int, now: float) -> None:
    state.snoozed_until = now + seconds


def reset_day(state: ProactivityState) -> None:
    state.offered_today.clear()


def offer_from_signal(sig) -> Offer:
    """Convert a signals.Signal into an Offer."""
    return Offer(title=sig.title, detail=sig.detail, action=sig.action, priority=sig.priority)


def candidates_with_signals(candidates, live_signals) -> list:
    """Boost/insert live signals, dropping static offers whose action matches
    a live one (so 'Commit your work?' uses real repo names, not a template)."""
    by_action = {o.action: o for o in candidates}
    for sig in live_signals:
        by_action[sig.action] = offer_from_signal(sig)
    return list(by_action.values())


def offer_for_moment(
    ctx,
    state,
    live_signals,
    candidates=None,
    rng=None,
):
    """High-level entry: merge live signals, then pick one offer.

    This is what the ambient loop should call instead of pick_offer()
    directly so data-aware signals (git/backup/inbox) take priority over
    static templates.
    """
    merged = candidates_with_signals(candidates or DEFAULT_OFFERS, live_signals)
    return pick_offer(ctx, state, candidates=merged, rng=rng)
