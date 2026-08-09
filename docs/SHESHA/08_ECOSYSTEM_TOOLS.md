# 08 — The Broader Tool Ecosystem

> Beyond the installer, organizer, and agent, you asked for a *complete ecosystem of tools* — more
> things automated, a phone harness, and a map of which open-source projects to learn from or steal
> patterns from. This doc is the backlog and source map. Everything here is licensed compatibly with
> your GPL-3 root (verified in `10_LICENSES_AND_SOURCES.md`).

---

## 1. New tools to build (priority-ordered)

Each tool is a small, composable component exposed to Shesha over MCP/IPC — not a monolith.

### 1.1 `sesha` CLI — the one command
A Python/CLI entrypoint (`~/.local/bin/sesha`) that unifies control:
```
shesha status            # GPU/power/battery/services/last audit events
shesha organize [path]   # trigger smart-organizer
shesha power ac|battery  # set profile + visuals
shesha gpu hybrid|dgpu|igpu
shesha backup [verify]
shesha log [--since]     # read audit log
shesha undo              # undo last Shesha action
shesha ask "..."         # pipe to local LLM (phi4-mini) from terminal
```
This is the non-voice fallback and the scripting surface. Implement with `typer`; reuse the MCP
server functions as a library so there's one implementation.

### 1.2 `shesha-memory` (RAG over your life)
Run your existing **rag-service** locally, indexing `~/Notes`, `~/Documents/Personal`, and
`~/Projects/personal/**/README.md`. Use `nomic-embed-text` through Ollama and ChromaDB. Newelle's
document chat points at it. This gives "when did I last work on SheshaAOS's event store?" answers.
Keep it opt-in and local.

### 1.3 `shesha-health` (system health & telemetry)
Collects CPU/GPU temps, battery wear, NVMe SMART, RAM, failed systemd units, zram pressure, and
produces a daily/weekly report. Exposes a `health_report()` MCP tool so Shesha can answer "how's my
laptop holding up?" Backed by a tiny SQLite time-series (or `btm`/`sysstat` parsing).

### 1.4 `shesha-focus` (context/work-mode switching)
A "focus mode" that: closes/mutes distractions (Discord, browsers), sets a Hyprland workspace layout,
toggles Do-Not-Notify (`mako`/Quickshell DND), starts a focus timer, and switches to performance.
Triggered by voice ("Shesha, focus") or a keybind. The inverse ("Shesha, I'm done") restores state.

### 1.5 `shesha-sync` (personal dotfiles & notes sync)
A safe, restic/git-based sync for `~/.config` (selected), `~/Notes`, and `~/Projects/personal` to a
private remote (GitHub for notes/config; restic to external/NAS for data). Never sync job folders.

### 1.6 `shesha-scratchpad` / quick capture
A global keybind that opens a tiny Quickshell input; text is appended to `~/Notes/Inbox.md` and
(optionally) categorized by the LLM. Captures ideas the way your YouTube references show (instant,
no app-switching).

### 1.7 `shesha-window` (Hyprland layout manager)
Higher-level than `hyprctl`: "move Slack to workspace 3 and tile it right", "tile two browsers
side by side". Builds on `hyprland_control.py`; useful for voice.

### 1.8 `shesha-clipboard` (semantic clipboard)
Beyond cliphist: embed clipboard text, let you search "that URL I copied yesterday about eBPF" via
embeddings. Keep history local, encrypted at rest optionally.

### 1.9 `shesha-updater` (intelligent update gating)
Wraps `pacman -Syu`: checks the Arch/CachyOS RSS/forum for breakage reports (e.g., NVIDIA/hyprland
hold), runs the update in a snapshot, and offers rollback via btrfs snapshot if boot fails. This is
the safe way to automate updates on rolling release (we never auto-`-Syu`; see `07_AUTOMATIONS.md`).

---

## 2. Phone harness (Realme Narzo 90x, Android)

The Mac-only `phone-harness` concept maps directly to Android over **ADB**. Build `tools/phone-harness/`:

```python
# phone_harness.py — ADB-based eyes/hands for an Android phone
import subprocess, io
from PIL import Image

def screenshot():
    raw = subprocess.check_output(["adb", "exec-out", "screencap", "-p"])
    return Image.open(io.BytesIO(raw))

def tap(x, y):
    subprocess.run(["adb", "shell", "input", "tap", str(x), str(y)])

def type_text(text):
    subprocess.run(["adb", "shell", "input", "text", text.replace(" ", "%s")])

def swipe(x1,y1,x2,y2,dur=300):
    subprocess.run(["adb", "shell", "input", "swipe", str(x1),str(y1),str(x2),str(y2),str(dur)])

def launch(app):  # monkey launcher
    subprocess.run(["adb","shell","monkey","-p",app,"-c","android.intent.category.LAUNCHER","1"])
```
- **Eyes:** `screencap` + `moondream2` (vision) to locate UI elements without brittle OCR.
- **Hands:** `input tap/swipe/text`.
- **Connect:** `adb pair` over Wi-Fi (Android 11+ wireless debugging) so no cable is needed.
- **Use cases:** send yourself the 2FA code from the phone screen to the desktop clipboard;
  read/notify notifications (via `adb shell dumpsys notification`); start/stop music; share the photo
  you just took straight into `~/Media/Camera`.
- **Safety:** always show a confirmation on desktop before any action that sends a message or makes a
  call; log everything to the same audit log.
- License: your own GPL-3 code; ADB is Apache-2.0 (CLI use is fine).

---

## 3. What to study / steal from each repo you linked

| Repo | Take | Don't take |
|---|---|---|
| **qwersyk/Newelle** (GPL-3) | Use as the agent host: MCP, wake word, STT/TTS, subagents, skills, scheduled tasks, file perms. | Don't fork the GTK UI; run it native on Hyprland as a floating app. Avoid Flatpak (sandbox limits). |
| **criptogus/HermesOffice** (Apache-2.0) | The *idea* of an OpenAI-compatible local endpoint every app can share (same pattern as Ollama/OmniRoute). | It's Electron, mac/win-first — not relevant as a codebase for you. |
| **diegosoupw/OmniRoute** (MIT) | Multi-provider routing + fallback + token compression for a *cloud* tier. Add as an **opt-in** fallback when local can't answer. | Don't make cloud the default (violates local-first). |
| **earendil-works/pi** (MIT) | Agent-loop design and supply-chain hardening (lockfile ground truth, lifecycle allowlist) for your Rust/Python services. | Don't add another agent runtime — Newelle is the host. |
| **NousResearch/hermes-agent** (MIT) | Skills format, cron automations, multi-platform gateway (Telegram→talk to Shesha from your phone), self-improvement patterns. | Don't duplicate Newelle; consider Hermes only if you outgrow Newelle. |
| **avifenesh/computer-use-linux** (Apache-2.0) | AT-SPI accessibility + Wayland input injection for "see and control the desktop" — reference for deeper Hyprland control beyond hyprctl. | Verify maintenance/Wayland support before depending on it. |
| **PrimeIntellect-ai/prime-agent** (MIT) | The "Continual Harness" idea: a refinement store for prompts/skills without touching the base system prompt — excellent for Shesha learning safely. | The RLM abstraction is overkill at your scale. |
| **ShawnPana/phone-harness** (MIT) | The OCR→coordinates→tap loop concept; port to ADB (§2). | macOS-only, unusable directly. |
| **codecrafters-io/build-your-own-x** (MIT) | Learning path for the kernel/OS vision: build-a-shell, build-a-database, build-an-interpreter. Use the test-driven, increment-by-increment format for `shesha-kernel` learning. | Not a library. |
| **end-4/dots-hyprland** (GPL-3) | Keep rebasing/merging upstream for Quickshell/Lua/Hyprland improvements; your value is the system+AI layer, not forking the shell itself. | Don't diverge the `dots/` more than necessary (use `custom/` overrides) so merges stay clean. |
| **JaKooLit/Hyprland-Dots** | Robust multi-distro install guards, per-monitor refresh scripts, SDDM theme, reliable BT menu patterns. | Less visual polish — only borrow logic. |
| **prasanthrangan/hyprdots (HyDE)** | `themepatcher`/Wallbash one-key theming, `hyde-cli` modularity. | 70+ themes are bloat for you. |
| **ML4W 2.14.1** | Single-file `statusbar.json` Quickshell bar config pattern; welcome app concept. | You're technical; skip the GUI config tool. |
| **CachyOS Noctalia** | Now a Hyprland option on the ISO; compare its Quickshell shell for animation/performance ideas. | Don't switch shells — end-4 is your base. |

---

## 4. Optional cloud tier (explicit opt-in only)

To honor local-first, the cloud is a **labeled fallback**, never the default:
- **OmniRoute** gives free/cheap multi-provider access for heavy queries the 6 GB GPU can't run.
- Gate it behind a policy flag `[cloud] enabled = false` and a per-session voice confirmation ("This
  would use the cloud, continue?").
- Route through a **local LiteLLM/OpenAI-compatible proxy** so apps never see provider keys directly.
- Never send `~/Documents/Job`, `~/Vaults`, or keys to any cloud.

---

## 5. Development & quality tooling ecosystem

Standardize the repo on:
- **Shell:** `shellcheck`, `shfmt`, `bats` (replace `exp-update-tester.sh`), `bash -n` in CI.
- **Python:** `ruff`, `mypy`, `py_compile`, `pytest`; one venv per tool under `~/.local/state/<tool>`.
- **Rust:** `cargo fmt`, `cargo clippy -D warnings`, `cargo test`; release builds with LTO.
- **Lua/QML:** `stylua` for Lua; `qmlformat` for QML (end-4 ships a `.qmlformat.ini`).
- **Docs:** this folder is the spec; keep one `CHANGELOG.md`; use Conventional Commits.
- **Secrets:** `gopass`/KeePassXC in `~/Vaults`; pre-commit hook to block secrets (`gitleaks`).
- **One command:** a `justfile`/`Makefile` with `lint`, `test`, `dry-install`, `build-watcher`.

---

## 6. The kernel/AI-OS vision — realistic track

Your long-term thesis (AI-first OS, SheshaAOS/SheshaOS/shesha-kernel) is valid but years-scale. The
practical near-term contributions that build toward it without a from-scratch kernel:

1. **eBPF observability:** write BCC/libbpf tools that collect scheduler, GPU, and I/O telemetry and
   feed `shesha-health`. Learn the kernel you already run.
2. **AI-assisted tuning:** a userspace daemon that uses telemetry + a local model to suggest/apply
   sysctl/scheduler/power hints (with approval). This is "AI-first" without risky kernel patches.
3. **Contribute upstream:** CachyOS, Hyprland, Quickshell, and Ollama are all moving fast and accept
   patches; your MUX/NVIDIA/hybrid-GPU work is genuinely useful upstream.
4. **SheshaAOS as the governance brain:** connect Shesha's audit log to SheshaAOS's event store so the
   *policy/governance* layer you already wrote in Rust starts controlling the desktop agent. This is
   the cleanest bridge between your two bodies of work.
5. Only after (1–4) consider `shesha-kernel` modules — and use build-your-own-x's incremental
   test-driven approach so it's a learning/research project, not a blocker for your daily driver.
