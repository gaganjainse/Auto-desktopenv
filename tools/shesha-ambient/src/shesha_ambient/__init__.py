"""shesha-ambient: polite, catch-up scheduler and proactivity engine.

This solves three problems with fixed timers on a laptop that sleeps/shuts down:

1. **Missed jobs catch up** — when the machine wakes/boots, any job whose last
   successful run is older than its interval runs, with jitter so they don't all
   fire at once and only when conditions (AC, idle, network) allow.
2. **Do-not-disturb** — jobs and proactive offers are deferred while you're busy
   (fullscreen app, high CPU, presentation mode, on battery saver, active call).
3. **Warmth / proactivity** — at natural pauses (idle for a few minutes, after a
   long task completes, switching to an empty workspace), Shesha makes one small,
   optional, helpful offer rather than staying passive or interrupting mid-flow.

Everything is local, time-bounded, and testable (no real system calls in core logic).
"""
from __future__ import annotations

__version__ = "0.1.0"
