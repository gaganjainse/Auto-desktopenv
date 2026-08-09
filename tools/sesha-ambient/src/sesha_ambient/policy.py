"""Do-not-disturb / courtesy policy.

`Context` describes what the user is doing right now; `decide` returns one of:
- "run":      conditions are good, go ahead
- "defer":    user is busy; retry later (don't nag)
- "skip":     conditions make the job pointless now (e.g. offline for a network job)

The thresholds are intentionally conservative. The goal is to be present without
being pushy. This module is pure logic so it is fully unit-tested.
"""
from __future__ import annotations

from dataclasses import dataclass


@dataclass
class Context:
    # User activity
    idle_seconds: int = 0            # seconds since last input
    fullscreen: bool = False         # a fullscreen window is focused
    presentation: bool = False       # screenshare / DND explicitly on
    on_battery: bool = False
    battery_percent: int = 100
    cpu_percent: float = 0.0         # 0..100 over the last few seconds
    # System
    network_online: bool = True
    on_ac: bool = True
    uptime_minutes: int = 0          # since boot
    active_call: bool = False        # mic/camera in use
    work_hours: bool = True          # within user's quiet hours window

    @property
    def busy(self) -> bool:
        """User is actively doing something that should not be interrupted."""
        if self.presentation or self.active_call:
            return True
        if self.fullscreen:
            return True
        if self.cpu_percent > 70:
            return True
        return self.idle_seconds < 30 and self.cpu_percent > 35

    @property
    def natural_pause(self) -> bool:
        """A good moment for a brief, optional offer."""
        if self.busy:
            return False
        if not self.work_hours:
            return False
        if self.on_battery and self.battery_percent < 30:
            return False
        # idle for a bit but not AFK for ages, OR just settled after high CPU
        return 45 <= self.idle_seconds <= 900


def decide(job_needs_network: bool, ctx: Context) -> str:
    if job_needs_network and not ctx.network_online:
        return "skip"
    if not ctx.work_hours:
        return "defer"
    if ctx.presentation or ctx.active_call:
        return "defer"
    if ctx.fullscreen:
        return "defer"
    if ctx.cpu_percent > 85:
        return "defer"
    # Heavy jobs want AC and some idleness; light jobs only avoid the truly busy.
    if ctx.on_battery and ctx.battery_percent < 40:
        return "defer"
    return "run"
