# 09 — AI Prompts & Session Playbook

> You said you'll build this **with AI assistants**. This doc is copy-paste-ready prompts organized
> by phase and by situation. The pattern: always (1) point the AI at the exact files, (2) quote the
> governing rule from `00_INDEX.md`/the relevant doc, (3) demand a diff + tests + checklist update,
> and (4) require it to verify against the **real hardware facts** (not the wrong numbers).

---

## 0. The "system prompt" that starts every work session

Paste this at the top of every AI session. It anchors the model to reality:

```
You are working on the "Shesh" ecosystem — Gagan's local-first, AI-first CachyOS/Hyprland desktop
fork of end-4/dots-hyprland. Repo: /home/user/shesh-desktop (a git repo).

HARDWARE (verified 2026-08-09 — do NOT use other numbers):
- MSI Sword 16 HX B14VEKG-210IN; i7-14700HX; Intel iGPU + NVIDIA RTX 4050 6GB GDDR6
- 16" FHD+ 1920x1200 (16:10), 144Hz, IPS — NOT 2560x1600
- 16GB DDR5-5600; 1TB NVMe Gen4 + free Gen5 slot
- OS: CachyOS 260628 (Arch), Hyprland >=0.55 Lua config, Quickshell, linux-cachyos (BORE)
- AUR: Shelly default; install paru for scripting. Newelle 1.4.5, Ollama >=0.32.

PHILOSOPHY: local-first/private; audit/append-only log; performance + looks never compromised;
hands-off/automated; composable MCP tools; Rust for systems, Python for AI glue, Lua/QML for shell,
Bash for installer. Separate JOB vs PERSONAL strictly.

RULES:
1. Read the actual files before changing them; never assume.
2. Give minimal, reviewable diffs (unified). Explain each change.
3. Run/fix `bash -n`, shellcheck, py_compile, ruff, cargo check as applicable.
4. One logical change per turn. Update docs/SHESH/checklist.md.
5. If a task is hardware-dependent, write the code AND a verification command; don't claim success
   without it.
6. Never hardcode the wrong resolution/VRAM. Source them from profiles/msi-sword-cachyos/.
7. Destructive operations must be guarded, dry-run capable, and logged.
```

---

## 1. Phase 0 — bug-fixing prompts

### 1.1 Fix the `$AUR_HELPER` crash (N-01)
```
Read sdata/subcmd-install/2.setups.sh and sdata/lib/functions.sh.
The line `v "$AUR_HELPER" -S --noconfirm --needed newelle` crashes because AUR_HELPER is never set.
Implement get_aur_helper() in functions.sh (prefer paru, then shelly, then yay; if none, install
paru via pacman). Export AUR_HELPER early in 2.setups.sh. Note shelly's CLI may not accept
--noconfirm like paru; detect and adapt, or standardize on installing paru for the installer.
Show the diff, and add a shellcheck-clean guard. Do not change unrelated lines.
```

### 1.2 Replace `bc` version compare (N-02)
```
In sdata/subcmd-install/2.setups.sh, find the `ollama_ver >= 0.32 | bc -l` check. Replace it with
pure bash (IFS=. read; arithmetic compare). Remove the bc dependency assumption. Ensure it handles
output like "ollama version is 0.32.6". Show the diff and a quick test with sample strings.
```

### 1.3 Fix MSI DMI detection (BUG-05)
```
In setup_mux_switcher, the condition `[[ -f /sys/class/dmi/id/product_name ]] || grep -qi MSI
sys_vendor` is true on almost every laptop (the file always exists). Change it to actually test
CONTENT: grep -qi MSI sys_vendor OR grep -qi MSI product_name. Then, for device-specific features,
narrow to product_name matching "Sword 16 HX". Provide the exact diff and a one-line command to test
the detection logic on the target.
```

### 1.4 Power management + ZRAM (HIGH-05)
```
Rewrite setup_power_management to: detect total RAM from /proc/meminfo; write
/etc/systemd/zram-generator.conf with zram-size = ram/2 and zstd (cap 16G); enable
systemd-zram-setup@zram0; install/enable power-profiles-daemon only on Arch; set balanced; all
idempotent and guarded by OS_GROUP_ID. Use install -Dm644 or tee with a marker so uninstall can
revert. Show the full function.
```

### 1.5 License, typos, quoting (batch)
```
Make these small fixes as separate commits:
- README.md: change "MIT - Same as upstream" to "GPL-3.0" and fix the license badge.
- licenses/MIT.txt: fill <YEAR> = 2024-2026, <COPYRIGHT HOLDER> = gaganjainse (or delete it and note
  the project is GPL-3 only).
- options.sh: fix --fisrtrun -> --firstrun in help.
- 1.deps-router.sh: fix `2>&1>/dev/null` to `>/dev/null 2>&1`.
- functions.sh backup_clashing_targets: replace `($(ls -A))` with mapfile.
- 3.files.sh: quote all $t/$s/$src_dir; wrap the font cd in a subshell.
Run shellcheck after each and report.
```

---

## 2. Phase 1 — CI prompts

### 2.1 Expand ShellCheck to all scripts
```
Update .github/workflows/shellcheck.yml to find ALL shell scripts in the repo (setup, diagnose,
test.sh, sdata/**/*.sh, tools/**/*.sh) excluding dots/ and .git/, and run shellcheck -x -s bash
-S warning with SC1091/SC2034 excluded where needed. Also add a `bash -n` syntax check step. Then
run it locally equivalent and show any new findings. Do not weaken checks to make it pass; fix code.
```

### 2.2 Arch container CI
```
Add .github/workflows/arch-test.yml using container archlinux:latest, install git bash shellcheck,
pacman -Syu, run bash -n on scripts, shellcheck, ./setup --help, and bash diagnose. It must NOT do
a real install. Keep it fast (<3 min). Provide the YAML.
```

---

## 3. Phase 2 — refactor prompts

### 3.1 Canonical systemd units
```
There are 3 sources of truth for systemd units: here-docs in 2.setups.sh, here-docs in
subcmd-smart-organizer/0.run.sh, and static files in tools/*/. Audit them, produce ONE canonical
copy per unit under tools/<tool>/units/, and change setup to `install -Dm644` them. Delete the
here-docs. Units must include TimeoutStartSec=15/TimeoutStopSec=10 and PartOf=graphical-session.
List every file changed.
```

### 3.2 Real uninstall (HIGH-06 / N-06)
```
Implement sdata/subcmd-uninstall/2.undo-setups.sh for real: revert mkinitcpio MODULES (only the
modules we added, identified by a marker), remove our udev rules and /usr/local/bin/nvidia-run,
disable/remove smart-organizer/backup/maintenance/jarvis MCP user units, disable (not remove) ollama,
remove our zram-generator.conf if we created it. Never pacman -R without prompting. Print clear
warnings that bootloader cmdline needs manual editing. Mirror the structure of 2.setups.sh.
```

---

## 4. Phase 3 — device tuning prompts

```
Create profiles/msi-sword-cachyos/ containing profile.conf (the canonical hardware values from
04_DEVICE_PROFILE.md), mkinitcpio.fragment, kernel-cmdline.txt, sysctl/99-shesh.conf,
udev/60-ioschedulers.rules, and a hypr/custom snippet that sets monitor eDP-1,1920x1200@144 and
battery/AC visual presets. Then wire setup to apply this profile when product_name matches "Sword 16
HX". Every file must have a comment pointing back to docs/SHESH/04_DEVICE_PROFILE.md. Provide
verification commands for display, GPU renderer, zram, scheduler.
```

---

## 5. Phase 4 — organizer prompts

```
Implement smart-organizer v2 per docs/SHESH/05_SMART_ORGANIZER_V2.md:
1. tools/smart-organizer/watcher-rs/ (Cargo.toml + src/main.rs) as specified, with debounce and
   JSON-lines output. It must build with cargo build --release.
2. classifier.py reading JSON from stdin, deterministic EXT_MAP/NAME_PATTERNS first, optional phi4-mini
   LLM for unknowns, 10s timeout, routes failures to Documents/Inbox.
3. Wire the existing smart-organizer.sh `apply` path to read decisions, dedupe safety.sh patterns,
   use gio trash for deletes, write undo JSONL + SQLite, and notify on low confidence.
4. Add the two canonical units (watch + daily timer) under units/.
5. Add pytest unit tests for classifier destinations + safety refusals.
Show each file and the test output. Do not call the LLM in tests (mock it).
```

---

## 6. Phase 6 — Shesh agent prompts

### 6.1 MCP servers
```
Fix tools/sesha: (a) correct system_control.py (fix the `decoration` typo, add get_system_status,
trigger_backup, set_power_profile); (b) create hyprland_control.py from
docs/SHESH/06_SHESH_AGENT.md section 5; (c) create smart_organizer.py with organize/last_moves/
undo_last/pause/resume; (d) change setup_ai_stack to iterate actual *.py files and create stdio units
only for those (fix N-04); (e) replace the bogus http://localhost:87xx MCP URLs in
dots/.config/newelle/config.toml with stdio command entries. Use fastmcp, stdio transport, and a
shared audit-log helper. Provide py_compile + a manual MCP smoke test.
```

### 6.2 Audit log + policy
```
Create tools/shesh/shesh_audit.py: an append-only JSONL + SQLite writer with a chained SHA-256 hash
(prev_hash field) like an event log, and policy.toml loading (confirm/deny/auto tool lists + denied
paths). Wrap every @mcp.tool with it (decorator) so calls/args/results are logged and denied tools
refused. Add `shesh log` and `shesh undo` CLI subcommands. Include tests that tampering breaks the
chain.
```

### 6.3 Quickshell overlay
```
Create dots/.config/quickshell/ii/shesh/SheshaOverlay.qml: a small Material-You-colored pill (reuse
end-4's color variables) bottom-right showing idle/listening/thinking/speaking states. It should read
state from a small file/socket the Newelle bridge updates (do not assume an API that doesn't exist;
propose the minimal bridge). Keep it <150 lines, no heavy dependencies. Note it must not regress
performance at 144Hz.
```

---

## 7. Situational prompts ("what to do when…")

### 7.1 An AI gives you code you're unsure about
```
You are a skeptical reviewer. Here is a patch <paste>. Verify: (1) does it match the verified
hardware/OS facts in docs/SHESH/00_INDEX.md? (2) does it introduce undefined vars, missing quoting,
or unguarded rm? (3) is it idempotent? (4) does it duplicate something already present? (5) what's
the exact command to test it on CachyOS? List problems by severity and give corrected diffs.
```

### 7.2 After a failed install
```
Read the error below <paste>. Determine which phase/script failed, find the root cause in the repo
(not just the symptom), propose a minimal fix, and a command to resume from where it stopped without
re-running completed steps. If it's a known issue from docs/SHESH/01_AUDIT.md, cite its ID.
```

### 7.3 Before rebasing on upstream end-4
```
I want to merge upstream end-4/dots-hyprland main into my fork. List the files/areas I've diverged
in (sdata installer additions, tools/, dots/.config/newelle, dots/.config/sesha, profiles/) and give
a safe rebase strategy: commit my changes, fetch upstream, merge with strategy-option, and resolve
conflicts preferring upstream for dots/ shell/Quickshell but keeping my sdata/tools/profiles. Provide
exact git commands and a checklist to test after merge.
```

### 7.4 A performance or battery regression
```
Diagnose a <battery/performance/lag> regression on this MSI + CachyOS + Hyprland + NVIDIA hybrid
setup. Give ordered diagnostic commands (powerprofilesctl, nvidia-smi, hyprctl systeminfo,
sensors, `systemd-analyze blame`, `top`/`btm`, journal errors for nvidia/hyprland), identify likely
causes (blur on iGPU, dGPU not powering down, compositing on dGPU, swappiness), and a fix for each.
Apply only the safest first; verify with <command> before/after.
```

### 7.5 "Make it look even better" without losing speed
```
Propose visual polish for end-4 Quickshell on a 1920x1200@144, Intel iGPU + RTX 4050 setup:
animation curves, blur passes, shadows, rounding, font (Google Sans Flex is present), and wallpaper
theming via matugen — with explicit AC vs battery presets. Every suggestion must include its
performance cost and a hyprctl/Quickshell setting; never suggest anything that drops below 144fps on
the iGPU or hurts battery. Give the exact custom/*.lua / QML snippets.
```

### 7.6 Adding a new automation
```
I want to automate: <describe>. Following docs/SHESH/07_AUTOMATIONS.md conventions, produce a
canonical .service + .timer under tools/<name>/units/, the script under tools/<name>/, an install
snippet for setup, an uninstall reversal, an audit-log append, and a dry-run flag. It must not run
destructive actions without asking for the first 7 days. Show the file tree and diffs.
```

### 7.7 Writing a weekly progress / resume prompt
```
Read docs/SHESH/checklist.md and git log since last week. Summarize what's done, what's next from
02_ROADMAP.md, any blockers, and produce the next 5 ordered tasks as copy-paste prompts in the style
of this file. Keep me moving one phase at a time and don't let scope creep.
```

---

## 8. Prompt hygiene rules for you (the human)

- One task per prompt; batch only the trivially-related (e.g., typo fixes).
- Always paste the exact error and the relevant file path(s).
- After each AI change: read the diff before applying; run the verification command; tick the
  checklist; commit with a Conventional Commit (`fix:`, `feat:`, `docs:`, `chore(ci):`).
- If an AI contradicts `00_INDEX.md` hardware facts, it's wrong — correct it.
- Prefer asking it to *show* the plan first for anything touching bootloader/NVIDIA/partitioning.
- Keep `docs/SHESH/` as the spec of record; if reality changes, update the doc in the same commit.
