"""Bridge ambient observations into memory/habit learning.

This module has no hard dependency on shesh-memory; it imports it lazily so
shesh-ambient remains usable standalone. Observations are coarse signals (offer
accepted/declined, focus-mode entry, repeated workspace/app patterns) — not
keystroke surveillance.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Protocol


class HabitPort(Protocol):
    def observe(self, signature: str, description: str, *, success: bool = True) -> Any: ...


@dataclass
class LearningConfig:
    enabled: bool = True
    # Only learn after N corroborations to avoid one-off noise.
    min_observations: int = 3


def record_offer_outcome(port: HabitPort | None, offer_title: str, accepted: bool) -> None:
    """Learn whether the user accepts a class of offer (informs future warmth)."""
    if port is None:
        return
    sig = f"offer:{offer_title.lower().replace(' ', '_')}:{'accepted' if accepted else 'declined'}"
    port.observe(sig, f"User {'accepted' if accepted else 'declined'} '{offer_title}'",
                 success=accepted)


def record_focus(port: HabitPort | None, hour: int, dow: int) -> None:
    if port is None:
        return
    port.observe(f"focus:dow{dow}:hour{hour}", "Enters focus mode at this time", success=True)


def default_memory_port():
    """Lazily construct a HabitLearner backed by shesh-memory, or None if unavailable."""
    try:
        from shesh_memory.habits import HabitLearner
        from shesh_memory.store import MemoryStore

        return HabitLearner(MemoryStore())
    except Exception:  # noqa: BLE001 - optional integration
        return None
