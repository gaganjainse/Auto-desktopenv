# 🌤️ shesha-ambient

Polite, catch-up scheduler and proactivity engine for a **laptop that sleeps/shuts down**.

- License: GPL-3.0
- Solves: fixed `OnCalendar` timers assume a 24/7 server and pile up on unlock;
  agents that are either passive or interrupt mid-work.
- Part of: [Shesha](https://github.com/gaganjainse/shesha-desktop)

## Three guarantees

1. **Catch-up without the thundering herd.** On wake/boot, jobs whose last successful
   run is older than their interval are considered. They run one at a time with
   jitter, heavy jobs only on AC + idle, and there's a catch-up time budget so a
   long-offline laptop doesn't try to do everything at once.
2. **Do-not-disturb.** Jobs and offers defer when you're fullscreen, on a call,
   presenting, under high CPU, or in quiet hours. Low battery pauses heavy work.
3. **Warmth, not nagging.** At a natural pause (idle 45s–15m, not busy, work
   hours), Shesha makes **one** small optional offer (break, organize downloads,
   commit, summary…), at most every 30 min, capped per day, snooze-able.

## Layout

```
src/shesha_ambient/
  policy.py       # Context + decide() (run/defer/skip), busy/natural_pause
  scheduler.py    # due detection, jitter, catch-up budget
  proactivity.py  # offer selection, cooldown, daily cap, snooze
  cli.py          # `shesha-ambient tick|offer` (real system probing)
units/            # user timer + service (OnStartupSec, not fixed wall-clock)
tests/            # 15 offline tests
```

## Run

```bash
uv sync --extra dev
uv run pytest -q
uv run ruff check .
# Dry-run what a tick would do now:
uv run shesha-ambient --dry-run tick
# Check whether an offer is appropriate (for an overlay/hotkey):
uv run shesha-ambient offer
```

## How it integrates

- The **timer** fires 3 min after the graphical session starts and every 4 h, with
  catch-up + jitter; it calls `shesha-ambient tick`.
- The **Quickshell overlay** calls `shesha-ambient offer` opportunistically (e.g. on
  workspace switch to an empty workspace) and shows the returned offer as a
  dismissible pill with "yes / later / no".
- Nothing runs while busy; deferred jobs retry on the next tick.
- Heavy jobs (backup, organizer, maintenance) require AC + 2 min idle.

See `docs/SHESHA/AMBIENT_DESIGN.md` for the full rationale and the proactivity model.
