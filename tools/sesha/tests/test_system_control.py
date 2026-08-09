"""Offline tests for the system-control MCP server.

Subprocess calls are monkeypatched; nothing touches real hardware/power/GPU.
The @mcp.tool decorator leaves the underlying Python function callable directly.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "mcp_servers"))

import system_control as sc  # noqa: E402


@pytest.fixture(autouse=True)
def _no_hyprctl(monkeypatch):
    """Pretend hyprctl is absent so tests don't touch the compositor."""
    monkeypatch.setattr(sc.shutil, "which", lambda _: None)


def test_set_power_profile_rejects_unknown():
    assert "Unknown mode" in sc.set_power_profile("turbo")


@pytest.mark.parametrize("mode,profile", [
    ("gaming", "performance"),
    ("performance", "performance"),
    ("balanced", "balanced"),
    ("battery", "power-saver"),
])
def test_set_power_profile_valid(monkeypatch, mode, profile):
    calls: list[list[str]] = []

    def fake_run(cmd, **_kw):
        calls.append(list(cmd))
        return ""

    monkeypatch.setattr(sc, "_run", fake_run)
    result = sc.set_power_profile(mode)
    assert profile in result
    assert ["powerprofilesctl", "set", profile] in calls


def test_get_system_status_structure(monkeypatch):
    # No GPU, no battery, no thermal zones in the sandbox -> still returns a dict.
    monkeypatch.setattr(sc.Path, "glob", lambda self, pat: iter([]))
    status = sc.get_system_status()
    assert "gpu" in status
    assert "error" in status["gpu"]  # no nvidia-smi in sandbox
    assert "ram" in status


def test_switch_gpu_mode_rejects_unknown():
    assert "Unknown" in sc.switch_gpu_mode("turbo")


def test_mux_status_without_binary(monkeypatch):
    monkeypatch.setattr(sc.shutil, "which", lambda _: None)
    assert "not installed" in sc.mux_status()
