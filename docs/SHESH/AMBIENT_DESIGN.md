# Ambient Shesh — scheduling without a 24/7 assumption

The first automation draft used fixed wall-clock timers (`Sun 03:00`, `08:00`).
That's wrong for a laptop: it's asleep/off much of the day, `Persistent=true`
fires *every* missed job the instant you unlock (a thundering herd), and the
agent was either passive or interrupting. `shesh-ambient` replaces that model.

## 1. Catch-up, not cron

- A JSON state file records each job's last successful run.
- A `tick` runs shortly after session start and every few hours (`OnStartupSec=3min`,
  `OnUnitActiveSec=4h`, `Persistent=true`, `RandomizedDelaySec=3min`) — **not** at a fixed hour.
- Due jobs are selected and run **one at a time with jitter**, heavy jobs only on
  AC + 2 min idle, all within a catch-up budget (default 30 min). A laptop offline
  for a week doesn't try to run a week of backups at once.
- Network jobs **skip** when offline; busy-condition jobs **defer** to the next tick.

## 2. Courtesy policy (when not to run)

`Context.busy` is true when any of:
- fullscreen window focused (movie/game/presentation)
- screenshare/DND/presentation flag
- microphone/camera in use (active call)
- CPU > 70%, or recently active with CPU > 35%

Heavy jobs additionally require AC and 2+ minutes idle; all jobs pause on
low battery (<40%) and outside work/quiet hours. The same policy gates offers.

## 3. Warmth — proactive but optional

At a **natural pause** (`Context.natural_pause`: idle 45s–15m, not busy, work
hours, battery OK), the engine picks **one** short, optional offer:

- "Take a 2-minute break?" (after long focus)
- "Organize Downloads?" (files in Inbox)
- "Commit your work?" (dirty git repo)
- "Summarize today's notes?"
- "Run a backup?"
- "Clear the air for focus mode?"

Throttling: at most one offer per 30 min, max 3/day, snooze-able, quiet-hours
aware. Offers are surfaced in the Quickshell overlay as a dismissible pill with
**yes / later / no** — never a modal interruption, never mid-keystroke. A "later"
defers with a snooze; a "no" records a soft negative signal.

## 4. How to add behavior

- New scheduled job: add a `Job` to `JOBS` in `cli.py` (interval, command,
  needs_network, heavy). The scheduler and policy handle the rest.
- New offer: add an `Offer` to `DEFAULT_OFFERS` (or generate one from live state,
  e.g. uncommitted changes count, Inbox file count). Higher priority surfaces first.
- Tune thresholds: edit `Context` defaults rather than scattering timers.

## 5. What this is not

- Not a daemon that watches every keystroke — it only checks coarse idle/CPU at tick time.
- Not autonomous — every state-changing action is still policy-gated and logged;
  offers are suggestions the user accepts/dismisses.
- Not cloud-dependent — the core works fully offline.
