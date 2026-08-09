"""Offline tests for the ambient→learning bridge."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from shesha_ambient.learning import (  # noqa: E402
    LearningConfig,
    record_focus,
    record_offer_outcome,
)


class FakePort:
    def __init__(self) -> None:
        self.obs: list[tuple[str, str, bool]] = []

    def observe(self, signature, description, *, success=True):
        self.obs.append((signature, description, success))


def test_record_offer_accepted():
    p = FakePort()
    record_offer_outcome(p, "Organize Downloads?", accepted=True)
    assert p.obs[0][0].endswith(":accepted")
    assert p.obs[0][2] is True


def test_record_offer_declined():
    p = FakePort()
    record_offer_outcome(p, "Commit your work?", accepted=False)
    assert "declined" in p.obs[0][0]
    assert p.obs[0][2] is False


def test_none_port_is_safe():
    record_offer_outcome(None, "x", accepted=True)
    record_focus(None, 10, 1)


def test_record_focus_signature():
    p = FakePort()
    record_focus(p, hour=10, dow=1)
    assert "focus:dow1:hour10" in p.obs[0][0]


def test_learning_config_defaults():
    cfg = LearningConfig()
    assert cfg.enabled and cfg.min_observations == 3
