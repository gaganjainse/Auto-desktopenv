# Shesha — Implementation Checklist

Tick these as you go. IDs match `01_AUDIT.md` and `02_ROADMAP.md`.

## Phase 0 — Stop the bleeding (before first install)
- [ ] N-01 `get_aur_helper()` defined; `AUR_HELPER` never empty (✅ code added)
- [ ] N-02 `bc` removed; pure-bash version compare (✅ code added)
- [ ] BUG-05 MSI DMI tests content with OR (✅ code added)
- [ ] HIGH-05 ZRAM detects RAM, writes config (✅ code added)
- [ ] N-09 `bash -n` clean across `sdata/` (✅ verified for changed files)
- [ ] N-04 MCP install iterates real `*.py` (✅ code added)
- [ ] BUG-06 mkinitcpio MODULES idempotent (review sed; use dedupe routine from 04)
- [ ] N-07 NVIDIA tail message fixed (✅ code added)
- [ ] MED-16 README license → GPL-3 (✅ code added)
- [ ] MED-03 `--fisrtrun` typo (✅ code added)
- [ ] MED-17 redirect order fixed (✅ code added)
- [ ] MED-07 safety.sh patterns deduped (✅ code added)
- [ ] HIGH-01/02 create `tools/lib/common.sh` + source (✅ common.sh added; still wire tools)
- [ ] MED-10/18 quote vars + subshell font `cd`
- [ ] MED-19 replace `ls` arrays with mapfile
- [ ] HIGH-08 bootstrap `--skip-*` flags + generic framing
- [ ] NEW-A `profiles/msi-sword-cachyos/` with correct 1920×1200/6GB values (✅ added)

## Phase 1 — CI gates
- [ ] ShellCheck lints ALL scripts (not just tools/)
- [ ] Arch container CI (`archlinux:latest`)
- [ ] Python `py_compile` + ruff for tools/shesha
- [ ] `cargo check` for watcher-rs
- [ ] `justfile`/Makefile: lint/test/dry-install
- [ ] Branch protection on main

## Phase 2 — Structural
- [ ] Functions defined before calls in 2.setups.sh
- [ ] Canonical units under tools/*/units/; delete here-docs (✅ units added; migrate setup)
- [ ] subcmd-smart-organizer delegates to tools/
- [ ] 2.undo-setups.sh implemented (✅ added; test on hardware)
- [ ] consolidate .updateignore
- [ ] CONTRIBUTING.md
- [ ] keep dist-fedora/gentoo/nix but skip via --device

## Phase 3 — Device tuning
- [ ] eDP-1 1920x1200@144 in custom/general.lua
- [ ] NVIDIA modeset + suspend services
- [ ] iGPU compositor verified; nvidia-run works
- [ ] sysctl + kyber + BBR applied
- [ ] PipeWire quantum 256
- [ ] msi-mux-switcher improved (envycontrol, JSON status, no false MUX claim)
- [ ] on-device verification commands in 04 §7 all pass

## Phase 4 — Smart-organizer v2
- [ ] watcher-rs builds and emits JSON (✅ code added; cargo build on device)
- [ ] classifier.py rules+LLM (✅ added; test with fixtures)
- [ ] apply path reads decisions, gio trash, undo log, SQLite
- [ ] rules.toml + low-confidence notifications
- [ ] units installed (✅ added)
- [ ] MCP organize/last_moves/undo/pause/resume (✅ added)
- [ ] tests (classifier fixtures, safety refusals, undo round-trip)

## Phase 5 — Automations
- [ ] udev power script + rules (✅ added)
- [ ] real restic backup + verify (no --dry-run)
- [ ] maintenance timer
- [ ] update-notify (never auto -Syu)
- [ ] disk/SMART/battery health report
- [ ] wallpaper/swww + matugen (optional)

## Phase 6 — Shesha agent
- [ ] Newelle 1.4.5 native + Ollama models
- [ ] 3 MCP servers (✅ system/smart-organizer/hyprland added; test in Newelle)
- [ ] config.toml uses stdio (✅ fixed)
- [ ] shesha audit log + policy.toml + `sesha` CLI
- [ ] Quickshell overlay
- [ ] Newelle starts on login (user service)
- [ ] voice acceptance test in 06 §10 passes offline

## Phase 7 — Convergence
- [ ] shesha-memory = local rag-service over Notes/Docs/Projects
- [ ] SheshaAOS event-store bridge for audit log
- [ ] eBPF telemetry into shesha-health
- [ ] Android ADB phone harness for Realme Narzo 90x
