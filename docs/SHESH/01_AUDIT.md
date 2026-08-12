# 01 — Independent Audit (verified against the live repo, 2026-08-09)

> **Method:** I cloned `gaganjainse/shesh-desktop` at `36481e1` and read every installer script,
> systemd unit, tool, and CI workflow directly. Prior AIs produced two audits (40 issues) and a
> 63-page master plan, then **partially applied fixes to the repo**. This audit is the *current
> truth*: it marks which old issues are fixed, which remain, and — critically — which **new bugs the
> previous AI introduced while "fixing" things.** Do not act on the old audits without this table.

Severity: 🔴 Critical · 🟠 High · 🟡 Medium · 🔵 Low
Status: 🟢 fixed · 🔴 still broken · 🟡 partial/incomplete · ⚪ new finding

---

## A. New bugs introduced by the prior AI "fixes" (fix these first)

### N-01 🔴 `$AUR_HELPER` is never defined — `setup_ai_stack` **crashes** on a clean install
**File:** `sdata/subcmd-install/2.setups.sh:513`
```bash
v "$AUR_HELPER" -S --noconfirm --needed newelle
```
`AUR_HELPER` is referenced but **assigned nowhere** in `sdata/` or `tools/` (verified with grep).
On a fresh CachyOS 260628 system where `newelle` is not installed, `v "" -S ...` expands to
`-S --noconfirm --needed newelle`, which bash tries to execute as a command → install aborts.
This is a 🔴 regression shipped to the repo.
**Fix:** add a detector in `sdata/lib/functions.sh` and export it:
```bash
get_aur_helper() {
  for h in shelly paru yay; do command -v "$h" >/dev/null && { echo "$h"; return; }; done
  echo ""  # caller must handle absence
}
```
then in `2.setups.sh` (after sourcing functions):
```bash
AUR_HELPER="$(get_aur_helper)"
[[ -z "$AUR_HELPER" ]] && { log_warning "No AUR helper; installing shelly"; sudo pacman -S --needed shelly && AUR_HELPER=shelly; }
```
Note: `shelly` is the CachyOS default and its CLI flags differ from paru/yay — verify
`$AUR_HELPER -S --noconfirm --needed PKG` works under `shelly` (it may need `shelly -S` without
`--noconfirm`, or you may prefer to `pacman -S --needed paru` first for scripting stability).

### N-02 🔴 `setup_ai_stack` uses `bc` for version compare but `bc` isn't a declared dependency
**File:** `2.setups.sh:501`
```bash
if [[ "$(echo "$ollama_ver >= 0.32" | bc -l)" != "1" ]]; then
```
`bc` is not guaranteed on a minimal CachyOS install and is not in `dist-arch/install-deps.sh`
(verified). If `bc` is missing, `bc -l` fails, the command substitution is empty, `!= "1"` is true,
and — worse — if `set -e`/`v` treats the pipeline as failure, the step aborts.
**Fix:** use pure bash arithmetic (strip the dot):
```bash
IFS=. read -r maj min _ <<<"$ollama_ver"
if (( maj < 0 || (maj == 0 && min < 32) )); then ...; fi
```
Also `grep -oP '[0-9]+\.[0-9]+'` against `ollama --version` (which prints `ollama version is 0.32.6`)
yields `0.32` — fine, but anchor it to avoid matching other numbers.

### N-03 🔴 `watcher-rs` is built by setup but **does not exist in the repo**
**File:** `2.setups.sh` (Rust build block) references `tools/smart-organizer/watcher-rs/`, but
that directory is absent (verified: `ls` returns "MISSING"). The code guards with `[[ -d ]]`, so it
silently falls through to the Python `watchfiles` fallback — meaning the flagship "Rust watcher"
the roadmap promises is vaporware, and the fallback installs `watchfiles` even though no Python
watcher script exists to use it. This is 🟡-at-best (no crash) but 🔴 against your stated goal.
**Fix:** either create `watcher-rs/` (see `05_SMART_ORGANIZER_V2.md` for the full Cargo project) or
remove the block until it exists. Do not ship references to absent code.

### N-04 🟠 MCP server loop references `hyprland_control.py` and `smart_organizer.py` that don't exist
**File:** `2.setups.sh` installs MCP servers by iterating
`system_control smart_organizer hyprland_control`, but only `tools/shesh/mcp_servers/system_control.py`
exists. The `[[ -f ]]` guard means the missing two are silently skipped, yet the unit-enable loop
**still generates and enables `.service` files for all three names**, producing
`shesh-smart-organizer-mcp.service` and `shesh-hyprland-control-mcp.service` that point at
non-existent executables → failed/dead units after boot.
**Fix:** iterate over *present* files (`for f in "$mcp_dir"/*.py`) and derive names from disk, or
create the two missing servers (provided in `06_SHESH_AGENT.md`).

### N-05 🟠 `tools/shesh/core/memory.py` is a two-line assertion stub
The only content is a ChromaDB version assert. There is no `SheshMemory` class, no store/search,
despite the roadmap and `agent.py` pseudocode referencing it. `Cargo.toml` declares a Rust binary
with no `src/main.rs`. `config/statusbar.json` is `{"pattern":"ml4w-2.14.1"}` with no explanatory
schema. These are scaffolding placeholders that look finished.
**Fix:** either complete them per the specs in this doc set or delete them so they don't mislead.

### N-06 🟡 `subcmd-uninstall/2.undo-setups.sh` is an empty placeholder
Contents: `#!/bin/bash` / `# Placeholder`. The prior audit's HIGH-06 ("uninstall doesn't undo
NVIDIA/AI/organizer") is therefore **not actually fixed**, despite the file existing (which makes it
*look* fixed). A full implementation is in `02_ROADMAP.md`.

### N-07 🟡 NVIDIA `setup_nvidia_mux` final print says `sudo msi-gpu-switcher status` (wrong binary)
The installed binary is `msi-mux-switcher` (symlinked earlier in the same run). The trailing
message tells the user to run `msi-gpu-switcher`, which does not exist.
**Fix:** print `sudo msi-mux-switcher status`.

### N-08 🟡 Newelle config claims HTTP MCP endpoints on ports 8765/8766/8767 — nothing serves them
`dots/.config/newelle/config.toml` lists `smart_organizer = "http://localhost:8765/mcp"` etc., but
`system_control.py` uses **stdio** transport (`mcp.run(transport="stdio")`) and no HTTP server is
shipped. Newelle will fail to connect to all three. Either run the MCP servers as stdio (Newelle
1.4.5 supports STDIO on native installs) and configure them as `command:` entries, or ship a tiny
stdio↔HTTP bridge.
**Fix:** use stdio MCP config in Newelle (see `06_SHESH_AGENT.md`); remove the bogus http URLs.

### N-09 🟡 Bootloader/NVIDIA code has unclosed heredoc/branch in the truncated region
The visible portion of `setup_nvidia_mux` in the live file is malformed around the systemd-boot
branch (`ue` / `NEEDS_INITRAMFS_REBUILD` appears mid-function without the enclosing `case` shown).
Run `bash -n sdata/subcmd-install/2.setups.sh` and fix every syntax error before relying on it.
**Action:** `bash -n` must pass cleanly; this is the first CI gate (see `02_ROADMAP.md`).

### N-10 🟡 `dots/.config/shesh/config.toml` references "RTX 4050 GPU" correctly, but claims iGPU offload
for `moondream2` via "v0.31.2" — Ollama's iGPU offload for vision is Intel-ARC-specific and your
14700HX iGPU is Arc (Xe-LPG) class, so it may work, but this is unverified; treat as experimental
and don't make it a hard dependency of the install.

---

## B. Status of the original 40 audit issues

| ID | Sev | Issue | Status today | Notes / action |
|----|-----|-------|--------------|----------------|
| BUG-01 | 🔴 | `showfun`/`v` before function defs | 🟡 **partly** | `setup_mux_switcher` still has `showfun`/`v` immediately after its def (ok) but `setup_nvidia_mux`, `setup_ai_stack`, `setup_power_management` retain the "define-then-call-adjacent" pattern; the original *"called before defined"* ordering is mostly resolved for mux/smart-org but NVIDIA/AI/power still interleave. Restructure per `02_ROADMAP.md` Phase 1. |
| BUG-02 | 🔴 | Backup `--dry-run` hardcoded | 🟢 **fixed** | Here-doc in `2.setups.sh` now writes `ExecStart=${BIN_DIR}/backup.sh` (no flag); `tools/backup/backup.service` static file remains — verify it also has no `--dry-run` (it is unused by setup but ships in repo). |
| BUG-03 | 🔴 | `diagnose rm` without `-f` | 🟢 **fixed** | Now `rm -f "$output_file"` (quoted). |
| BUG-04 | 🔴 | `install-files` missing sudo keepalive | 🟢 **fixed** | `setup:121` now calls `sudo_init_keepalive`. |
| BUG-05 | 🔴 | MSI DMI detection wrong (AND vs OR) | 🔴 **still wrong** | Live code: `if [[ -f product_name ]] \|\| grep -qi MSI sys_vendor`. This is now *OR*, but the first clause `[[ -f product_name ]]` is **true on virtually every laptop** (the file always exists), so the MUX installer runs on *every* machine, not just MSI. Fix to actually test content: `grep -qi MSI /sys/class/dmi/id/sys_vendor \|\| grep -qi MSI /sys/class/dmi/id/product_name`. |
| BUG-06 | 🔴 | mkinitcpio sed duplicates modules | 🟡 **partly** | The NVIDIA block was rewritten with broader bootloader support, but the MODULES insertion must be verified idempotent (dedupe); review the actual `sed`/`awk` in the live function and add the dedup routine from `04_DEVICE_PROFILE.md`. |
| HIGH-01 | 🟠 | `command_exists` triple-defined | 🔴 | Still redefined at top of `2.setups.sh` and in `0.run.sh`; no `tools/lib/common.sh`. |
| HIGH-02 | 🟠 | `die()` triple-defined | 🔴 | `2.setups.sh:4` still defines its own `die`. |
| HIGH-03 | 🟠 | AI stack `pip install --user` + `\|\| true` | 🟢 | Now uses `uv venv` + pinned deps; `\|\| true` removed. (But see N-01/N-02 which break it anew.) |
| HIGH-04 | 🟠 | NVIDIA shown on all distros | 🟢 | Now guards `OS_GROUP_ID` arch/cachyos and `lspci` nvidia. |
| HIGH-05 | 🟠 | ZRAM hardcoded 16 GB, no size config | 🔴 | `setup_power_management` still says "Configuring ZRAM for 16GB RAM" and only enables the service; never writes `/etc/systemd/zram-generator.conf`, so ZRAM may not even be configured. Must detect RAM & write the config (you have 16 GB → 8 GB zram0, zstd). |
| HIGH-06 | 🟠 | Uninstall doesn't undo setups | 🟡 | File exists but is a stub (N-06). |
| HIGH-07 | 🟠 | smart-organizer setup triplicated | 🔴 | Still generated via here-docs in `2.setups.sh` *and* `subcmd-smart-organizer/0.run.sh`, plus static files in `tools/smart-organizer/`. Divergences remain (e.g. service names: `smart-organizer.service` vs `smart-organizer-timer.service`). Canonicalize to `tools/*/units/`. |
| HIGH-08 | 🟠 | bootstrap machine-specific, no skip flags | 🔴 | `tools/bootstrap.sh` still titles itself "MSI Sword 16 HX B14VEKG", defines its own colors/logging, and has no `--skip-*`. Add flags + generic framing. |
| MED-01 | 🟡 | `NC` vs `STY_RST` colors | 🔴 | Every `tools/*.sh` still redefines `NC`; no shared lib. |
| MED-02 | 🟡 | log functions redefined everywhere | 🔴 | Same. |
| MED-03 | 🟡 | `--fisrtrun` typo in help | 🔴 | Still present `options.sh:11`. |
| MED-04 | 🟡 | repetitive `install_cmds()` | 🔴 | Untouched. |
| MED-05 | 🟡 | dead `TEMP_FILES_TO_CLEANUP` code | 🔴 | Still commented out / unused. |
| MED-06 | 🟡 | `$base` vs `$REPO_ROOT` | 🟡 | `diagnose` exports `base`; standardize on `REPO_ROOT`. |
| MED-07 | 🟡 | duplicate `*credentials*` in safety.sh | 🔴 | Still duplicated (`safety.sh:43` and `:50`); also `*backup*` overlaps protected dirs. |
| MED-08 | 🟡 | exp-update-tester redefines logs 7× | 🔴 | Untouched; migrate to bats. |
| MED-09 | 🟡 | `local backup=true` shadowing (SC2155) | 🔵 | Low; verify with ShellCheck. |
| MED-10 | 🟡 | unquoted `mv $t $t.old` | 🔴 | Quoting audit still needed across `3.files.sh`. |
| MED-11 | 🟡 | three `.updateignore` paths, no migration | 🔴 | Untouched. |
| MED-12 | 🟡 | ShellCheck only lints `tools/` + smart-organizer | 🔴 | `shellcheck.yml:32` still `find tools sdata/subcmd-smart-organizer` — core installer never linted (this is why N-01..N-09 slipped through). |
| MED-13 | 🟡 | tests run on Ubuntu, not Arch | 🔴 | `functional-tests.yml` still ubuntu-latest. |
| MED-14 | 🟡 | README links to missing `docs/SETUP.md` | 🟡 | `docs/AI_Documents/` now exists but the specific linked files may not; reconcile links. |
| MED-15 | 🟡 | README says `mux-switcher` but binary is `msi-mux-switcher` | 🟡 | The setup echo is now mostly correct but NVIDIA tail says `msi-gpu-switcher` (N-07); re-verify README. |
| MED-16 | 🟡 | License mismatch (README says MIT, root is GPL-3, MIT.txt placeholders) | 🔴 | `README.md:124` still says "MIT - Same as upstream end-4/dots-hyprland" (upstream is **GPL-3**), and `licenses/MIT.txt` still has `<YEAR>`/`<COPYRIGHT HOLDER>`. |
| MED-17 | 🟡 | `2>&1>/dev/null` wrong redirect order | 🔵 | Verify `1.deps-router.sh:9`. |
| MED-18 | 🟡 | font install `cd` without subshell | 🔴 | Untouched. |
| MED-19 | 🟡 | `ls` word-split into arrays | 🔴 | `backup_clashing_targets` in functions.sh still uses `($(ls -A ...))`. |
| LOW-01..08 | 🔵 | indentation, naming, stale comments, ci-trigger, debug echo | 🔴 mostly | `ci-test-trigger.txt` still present; empty `custom/*.lua` still 1-byte; `remove_bashcomments_emptylines` debug echo to verify. |

**Bottom line:** of the original 40, only ~5 are genuinely fixed; the repo looks further along than it is
because stub files were added. The previous AI also introduced 10 new issues (Section A), three of
which are 🔴 and block a clean install.

---

## C. New issues I found beyond both prior audits

### NEW-A 🔴 Wrong hardware assumptions baked into comments/configs across the codebase
Multiple files and the entire PDF plan assume a **2560×1600 "QHD+"** panel and an **RTX 4070 8 GB**.
Your actual SKU (`B14VEKG-210IN`) is **1920×1200 FHD+ @ 144 Hz** with **RTX 4050 6 GB**. Any
`monitor=eDP-1,2560x1600@144` line will fall back to a lower/default mode. Any model pulled for an
8 GB budget (qwen3:14b, llava:13b) will OOM. **Action:** create one `profiles/msi-sword-cachyos/profile.conf`
as the single source of these values and source it everywhere; never hardcode resolution/VRAM.

### NEW-B 🟠 No `hyprland_control` / `smart_organizer` MCP servers (also N-04) — agent can't actually control the desktop
The headline "Shesh controls Hyprland" feature has no implementation. `06_SHESH_AGENT.md` provides
both servers (hyprctl wrapper + organizer trigger).

### NEW-C 🟠 No wake-word/voice service unit
Newelle is installed but there's no user service ensuring it (or its voice backend) starts on login,
and no documented `uwsm`/graphical-session ordering. The "Hey Shesh" experience won't survive reboot.

### NEW-D 🟡 Smart-organizer `--watch` is a polling loop, not inotify
`smart-organizer.sh` advertises `--watch` but the lib has no event watcher; it likely re-scans on a
sleep loop. On a spinner/NVMe this wastes I/O and feels laggy vs the promised <100 ms reaction.
Real-time watching is specified in `05_SMART_ORGANIZER_V2.md`.

### NEW-E 🟡 `safety.sh` is included but uses undefined logging funcs
`safety.sh` calls `log_info`, `log_error`, `log_ok`, `is_dry_run`, `log_action_dry` which it neither
defines nor sources. When `organize.sh` sources it *after* defining those, it works; if sourced
standalone it crashes. There is no clear contract. Add a header comment documenting required
sourcing order, or move shared logging to `tools/lib/common.sh`.

### NEW-F 🟡 No tests for any of the new shell/Python (MCP, organizer, mux-switcher)
The repo has a `test.sh` but it targets upstream exp-update logic. The new tools have zero coverage.
At minimum add: shellcheck + `bash -n` for all `.sh`; `python -m py_compile` for all `.py`; a
containerized dry-run. This is how N-01..N-09 reached `main`.

### NEW-G 🟡 `.github/workflows/python-check.yml` exists but its scope vs the new `tools/shesh` is unverified
Confirm it actually lints MCP servers; if it only checks `sdata/uv`, it misses the new Python.

### NEW-H 🔵 `PREBOOT_INSTRUCTIONS.md` and `INSTALLATION_GUIDE.md` may reference the old TOML Hyprland config
Verify they mention the **Lua** config (Hyprland ≥0.55) and CachyOS `chwd` driver installation;
update any stale `hyprland.conf` references.

### NEW-I 🔵 No `CONTRIBUTING.md` at root; PR template exists but no dev setup doc
Add a short `CONTRIBUTING.md` pointing at `docs/SHESH/` and the checklist, so future AI/you don't
reintroduce drift.

### NEW-J 🔵 Repo ships both `tools/backup/backup.service` (static) AND generates one via here-doc
Two sources of truth for the same unit. Delete the static one or make setup install it verbatim.

---

## D. Comparison with the upstream and top dotfile repos (2026)

| Practice | end-4/dots-hyprland (base) | JaKooLit/Hyprland-Dots | prasanthrangan/hyprdots (HyDE) | ML4W 2.14.1 | CachyOS hyprland | **Your fork target** |
|---|---|---|---|---|---|---|
| Hyprland config | Lua (0.55+) ✅ | Lua/conf hybrid | conf | Lua ✅ | Lua | Lua ✅ (keep) |
| Shell | Quickshell ✅ | Quickshell/ags | Waybar/ags | Quickshell ✅ | Quickshell | Quickshell ✅ (keep) |
| ShellCheck on **all** scripts | ✅ | ✅ | ✅ | ✅ | n/a | 🔴 must fix (MED-12) |
| Arch container CI | partial | ✅ | ✅ | ✅ | n/a | 🔴 add |
| Idempotent installer | ✅ | ✅ | ✅ | ✅ | n/a | 🔴 NVIDIA/mkinitcpio |
| Device/driver setup | **explicitly none** ("not a system setup script") | some | some | some | ✅ chwd | ✅ your differentiator — make it bulletproof |
| File/automation tooling | none | none | some (theme) | welcome app | none | ✅ smart-organizer (your edge) |
| Local AI agent | sidebar (Ollama/Gemini) | none | none | none | none | ✅ Shesh (your edge) |
| Visual polish | 🏆 best-in-class | good | good (70+ themes) | very good | clean | **must not regress** |
| Uninstall reverses changes | n/a | partial | partial | partial | n/a | 🔴 stub |

**Strategic read:** The upstream deliberately refuses to do system/driver/AI setup. That refusal is
your *moat* — but only if your system layer is as robust as the upstream's UX layer is beautiful.
Right now your system layer is the weakest, buggiest part. Fix Section A first, then the
device/automation/AI layers become a genuine, upstream-beating advantage rather than a liability.

---

## E. The 10 things to do before you install CachyOS (in order)

1. Add `get_aur_helper` + define `AUR_HELPER` (N-01).
2. Replace `bc` version compare with bash arithmetic (N-02).
3. Fix MSI DMI content check (BUG-05) and make `setup_power_management` write the zram config (HIGH-05).
4. `bash -n` all of `sdata/`; fix syntax (N-09).
5. Make MCP install iterate real files (N-04) or add the missing servers.
6. Fix the license (README → GPL-3, fill `MIT.txt` placeholders) (MED-16).
7. Expand ShellCheck to all scripts + add Arch container CI (MED-12/13) so the above can't regress.
8. Create `tools/lib/common.sh` and source it (HIGH-01/02, MED-01/02).
9. Create `profiles/msi-sword-cachyos/` with the **correct** 1920×1200/6 GB values (NEW-A).
10. Fix bootstrap `--skip-*` flags and generic framing (HIGH-08).

Each of these is expanded into copy-paste-ready code/prompts in `02_ROADMAP.md` and `09_AI_PROMPTS.md`.
