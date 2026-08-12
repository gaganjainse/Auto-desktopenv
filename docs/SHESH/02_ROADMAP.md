# 02 — Roadmap & Execution Plan

> A dependency-ordered plan to take the fork from "partially-fixed, partially-broken" to a
> production-grade Shesh ecosystem. Each phase ends in a **shippable, tested state** so you can stop
> after any phase and have a working system. Effort estimates assume you + an AI pair-programmer.

Legend: 🛑 blocker · ⚙️ mechanical · 🧠 design · 🧪 needs testing on real hardware

---

## Phase 0 — Pre-install: stop the bleeding (🛑 do this BEFORE installing CachyOS)

**Goal:** a clean `./setup install` that completes on a fresh CachyOS 260628 system.
**Effort:** 1–2 sessions · **Risk:** none (all in-repo)

| # | Task | IDs | Done |
|---|------|-----|------|
| 0.1 | Add `get_aur_helper()` to `sdata/lib/functions.sh`; set/export `AUR_HELPER`; prefer `paru` for scripting (`pacman -S --needed paru`) since `shelly` CLI flags differ | N-01 | ☐ |
| 0.2 | Replace `bc -l` version compare with pure bash; remove `bc` assumption | N-02 | ☐ |
| 0.3 | Fix MSI DMI detection to test *content* with OR; tighten to `Sword 16 HX` for device features | BUG-05, N- | ☐ |
| 0.4 | Rewrite `setup_power_management`: detect RAM (`/proc/meminfo`), write `/etc/systemd/zram-generator.conf` (RAM/2, zstd, cap 16G), enable service; install `power-profiles-daemon` only on Arch | HIGH-05 | ☐ |
| 0.5 | Run `bash -n` on every script in `sdata/` and `tools/`; fix syntax (esp. NVIDIA heredoc/case) | N-09 | ☐ |
| 0.6 | MCP install: iterate `tools/shesh/mcp_servers/*.py` that actually exist; don't enable units for missing files; **or** add the 2 missing servers now | N-04 | ☐ |
| 0.7 | Idempotent mkinitcpio MODULES edit (read list, dedupe, prepend nvidia+i915) | BUG-06 | ☐ |
| 0.8 | Fix NVIDIA tail message `msi-mux-switcher` | N-07 | ☐ |
| 0.9 | License: README → GPL-3.0 badge/text; fill `licenses/MIT.txt` (2024–2026, gaganjainse) or delete it | MED-16 | ☐ |
| 0.10 | Create `tools/lib/common.sh` (colors `STY_*`, `log_*`, `die`, `command_exists`); source from all `tools/*.sh`; delete local redefs | HIGH-01/02, MED-01/02 | ☐ |
| 0.11 | Fix `--fisrtrun` typo; fix `2>&1>/dev/null`; quote `$t`/`$s`; subshell the font `cd` | MED-03/10/17/18 | ☐ |
| 0.12 | Replace `($(ls -A))` with `mapfile` in `functions.sh` | MED-19 | ☐ |
| 0.13 | Dedupe `*credentials*`/`*backup*` in `safety.sh` | MED-07 | ☐ |
| 0.14 | Delete `ci-test-trigger.txt`; use `workflow_dispatch`; remove stale `exp-update-tester` comment | LOW-04/05 | ☐ |
| 0.15 | `bootstrap.sh`: generic title, `--skip-ai/--skip-nvidia/--skip-zram/--dry-run/--device`, idempotent | HIGH-08 | ☐ |
| 0.16 | Create `profiles/msi-sword-cachyos/` with correct 1920×1200@144 / RTX 4050 6GB / 16GB DDR5 values | NEW-A | ☐ |

**Exit criteria:** `bash -n` clean; `shellcheck` (new scope) clean at `severity=warning`; README license correct.

---

## Phase 1 — CI & quality gates (so it never regresses)

**Goal:** every push is linted and dry-run tested in an Arch/CachyOS-like container.
**Effort:** ½ session · **Risk:** low

- 1.1 Expand `.github/workflows/shellcheck.yml` to lint **all** `.sh` plus `setup`, `diagnose`,
  `test.sh` (exclude `dots/`, `.git/`); use `shellcheck -x -s bash -S warning`.
- 1.2 Add `.github/workflows/arch-test.yml`: `container: archlinux:latest`, `pacman -Syu --noconfirm
  git bash shellcheck`, run `bash -n`, `shellcheck`, then `./setup --help` and `./diagnose` (dry).
- 1.3 Extend `python-check.yml` to `py_compile` and `ruff`/`flake8` everything under
  `tools/sesha` and `tools/smart-organizer/**/*.py`.
- 1.4 Add a `cargo check` step for `watcher-rs` once created (Phase 3).
- 1.5 Add a `Makefile` / `justfile` with `make lint`, `make test`, `make dry-install` so you and AI
  have one command to validate.
- 1.6 Branch protection on `main`: require lint + arch-test to pass.

**Exit criteria:** CI is green; introducing any of the N-01…N-09 class bugs fails a check.

---

## Phase 2 — Structural refactor (no behavior change, de-duplicate)

**Goal:** one definition of everything; setup reads cleanly top-to-bottom.
**Effort:** 1–2 sessions · **Risk:** medium (installer changes) — covered by CI dry-run

- 2.1 Reorganize `sdata/subcmd-install/2.setups.sh`: **all functions first**, then a single execution
  block at the bottom with distro/hardware guards.
- 2.2 Move all systemd units to canonical `tools/<tool>/units/*.{service,timer}` and `install -Dm644`
  them; delete every here-doc unit generator in `2.setups.sh` and `subcmd-smart-organizer/0.run.sh`.
- 2.3 Shrink `subcmd-smart-organizer/0.run.sh` to a thin delegator that calls `tools/smart-organizer/`.
- 2.4 Implement `subcmd-uninstall/2.undo-setups.sh` for real:
  - undo mkinitcpio MODULES (remove nvidia/i915 added by us — behind a marker comment),
  - remove `/etc/udev/rules.d/{igpu,dgpu}-device-path.rules`, `/usr/local/bin/nvidia-run`,
  - disable+remove `smart-organizer.*`, `backup.*`, `maintenance.*`, `shesh-*-mcp.*` units,
  - disable `ollama.service` (do **not** `pacman -R` without asking),
  - remove zram-generator.conf only if we created it (marker),
  - print bold warnings about bootloader params that need manual removal.
- 2.5 Consolidate `.updateignore` to one XDG path with a one-time migration; remove the TODO.
- 2.6 Add `CONTRIBUTING.md` at root pointing to `docs/SHESH/` + checklist.
- 2.7 Prune (behind a flag, don't delete upstream sync ability): keep `dist-arch`; for your personal
  install set `--device msi-sword-cachyos` which skips fedora/gentoo/nix branches. **Do not** delete
  them from the repo (they aid upstream merges) — just don't execute them.

**Exit criteria:** setup is a straight-line read; one source of truth per unit; uninstall actually cleans up.

---

## Phase 3 — Device profile & CachyOS performance tuning

**Goal:** the machine is correctly configured for the exact hardware, faster/better-looking than stock.
**Effort:** 1 session + 🧪 on-device · **Risk:** medium (boot/nvidia)

Documented fully in `04_DEVICE_PROFILE.md`. Highlights:
- 3.1 `env.lua` / `general.lua`: `monitor=eDP-1,1920x1200@144,0x0,1`; enable VRR if supported;
  `highrr`; tearing for games via windowrule.
- 3.2 NVIDIA hybrid env block (`GBM_BACKEND=nvidia-drm`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`,
  `NVD_BACKEND=direct`, `WLR_NO_HARDWARE_CURSORS=1`); boot param `nvidia_drm.modeset=1` +
  `nvidia.NVreg_PreserveVideoMemoryAllocations=1`.
- 3.3 iGPU primary for compositing (`AQ_DRM_DEVICES=/dev/dri/igpu:/dev/dri/dgpu` after udev stable
  paths); `prime-run`/`nvidia-run` for offload; MUX via `msi-mux-switcher` for dGPU-direct.
- 3.4 ZRAM 8 GB zstd (16 GB RAM); `vm.swappiness=10`; `vm.dirty_ratio=5`.
- 3.5 CachyOS tuning: verify BORE scheduler, NVMe `kyber` I/O sched via udev,
  `net.core.default_qdisc=cake` + BBR, PipeWire low-latency (quantum 256 @48k — not 64, causes
  underruns on laptop audio; verify on hardware), `makepkg.conf` `-march=native` (install
  `x86_64-v3`/v4 Cachy repos if compatible with 14700HX).
- 3.6 Wi-Fi AX211: `iwlwifi` power-save off on AC, enable 6E regdomain if needed.
- 3.7 144 Hz animation curves in Quickshell/Hyprland (use Caelestia/end-4 easings; don't over-blur
  on battery — blur costs GPU).

**Exit criteria:** boots to Hyprland at 1920×1200@144; `glxinfo | grep renderer` shows iGPU on
desktop; `nvidia-run <app>` uses dGPU; MUX switch works with reboot; power profile auto-switches on AC.

---

## Phase 4 — Smart-Organizer v2 (your clutter problem)

**Goal:** files organize themselves, safely, with undo and AI-assisted classification.
**Effort:** 2–3 sessions · **Risk:** medium (touches your files) — start in `--dry-run`

Spec in `05_SMART_ORGANIZER_V2.md`. Build order:
- 4.1 `watcher-rs` (Rust `notify`): non-recursive watch on Downloads/Desktop/Documents/Pictures;
  debounce 30s; emit JSON lines to stdout. Tiny (~3 MB), no Python startup cost.
- 4.2 `classifier.py`: deterministic extension/name rules first (no LLM, instant, private); optional
  Ollama (`phi4-mini`) for ambiguous cases; vision via `moondream2` for screenshots/images.
- 4.3 `rules.toml` user rules; SQLite history + undo log at
  `~/.local/share/smart-organizer/{history.db,undo/}`.
- 4.4 Safety: centralized protected patterns (deduped), trash-not-rm (`gio trash`), always
  `--dry-run`-capable, low-confidence → `notify-send` with action buttons.
- 4.5 Wire into MCP so Shesh can say "organize downloads" / "undo last move".
- 4.6 Quickshell indicator widget (last N moves, pause/resume, open undo).

**Exit criteria:** drop 20 mixed files into Downloads → they land in the right folders within a minute;
one command undoes it; nothing in protected paths ever moves.

---

## Phase 5 — Automations (set-and-forget)

**Goal:** you stop doing repetitive system tasks.
**Effort:** 1–2 sessions · **Risk:** low

Catalog in `07_AUTOMATIONS.md`. Implement as canonical units:
- AC/battery → power profile + (optionally) GPU hint via udev/systemd.
- Nightly: smart-organizer deep scan, backup (with verification), maintenance (cache/journal vacuum).
- Weekly: `pacman -Syu` **notification-only** (never auto-update without your approval), mirrorlist refresh.
- Disk-usage alert at 80%; SMART/battery-health monthly report; inotify-based wallpaper/theme refresh.
- Font cache / mkinitcpio via pacman hooks (CachyOS provides most).
- Session restore + window rules per activity.

**Exit criteria:** a single `systemctl --user list-timers` shows the whole automation surface; every job
logs to the journal and to the Shesh audit log.

---

## Phase 6 — Shesh agent (Shesh/Shesh)

**Goal:** voice-first, local, private, auditable desktop agent.
**Effort:** 3–5 sessions · **Risk:** medium (voice/MCP integration)

Architecture in `06_SHESH_AGENT.md`. Build order:
- 6.1 Install Newelle **1.4.5 native** (AUR, not Flatpak) + Ollama ≥0.32; pull the 6 GB-safe models.
- 6.2 Provide the 3 MCP servers (system-control, smart-organizer, hyprland-control) over **stdio**.
- 6.3 Configure Newelle: Ollama `phi4-mini`, STT faster-whisper `base.en`, TTS Piper, wake "Hey Shesh".
- 6.4 Quickshell overlay (listening/thinking/speaking states) driven by Newelle's
  interface/API (1.4.0+ OpenAI-compatible endpoint) or a small bridge.
- 6.5 `shesh-audit`: append every tool call/result to a local SQLite/JSONL event log
  (SheshAOS-style), with a `shesh undo` and a policy file that requires confirmation for destructive
  actions (`rm`, `pacman -R`, writes outside allowed dirs).
- 6.6 Daily 08:00 briefing skill: weather, calendar, battery health, updates, last night's backups.
- 6.7 (Optional, later) Android phone harness over ADB for your Realme Narzo 90x (see
  `08_ECOSYSTEM_TOOLS.md`).

**Exit criteria:** "Hey Shesh, organize my downloads and switch to performance mode" → done by voice,
visible in the overlay, recorded in the audit log, undoable.

---

## Phase 7 — SheshAOS / SheshaOS convergence (the long game)

**Effort:** ongoing · No deadlines. This is your research vision.
- 7.1 Expose the Shesh audit log through the same append-only event-store API SheshAOS uses.
- 7.2 Run your RAG service locally over `~/Documents`, `~/Projects`, and the dotfiles for memory.
- 7.3 eBPF observability: feed scheduler/power/GPU telemetry to Shesh for hints (start with
  `bcc`/`bpftrace` scripts; do **not** fork the kernel yet).
- 7.4 Treat the AI-first kernel as a multi-year research track; the practical near-term win is
  AI-assisted tuning of an already-excellent CachyOS kernel, not a from-scratch microkernel.

---

## Effort summary

| Phase | Sessions | Shippable after |
|-------|----------|-----------------|
| 0 Pre-install fixes | 1–2 | ✅ clean install |
| 1 CI gates | ½ | ✅ no regressions |
| 2 Refactor | 1–2 | ✅ maintainable |
| 3 Device tuning | 1 + on-device | ✅ fast/pretty |
| 4 Organizer v2 | 2–3 | ✅ clutter gone |
| 5 Automations | 1–2 | ✅ hands-off |
| 6 Shesh agent | 3–5 | ✅ voice AI |
| 7 OS convergence | ongoing | 🔭 research |

Realistically: **Phases 0–3 in the first week**, **4–5 in week two**, **6 across weeks 3–4**, with 7
as a persistent backlog. Use `09_AI_PROMPTS.md` to drive each session and `checklist.md` to track.
