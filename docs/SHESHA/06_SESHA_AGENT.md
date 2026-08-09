# 06 — Shesha: the local, voice-first desktop agent

> **Shesha** (शेष) is the name of the agent layer — your Shesha/Friday/Ultron. It is deliberately
> **not** a from-scratch agent framework. As of 2026-08, the fastest path to a working,
> production-grade voice assistant on CachyOS/Hyprland is **Newelle 1.4.5 (frontend/voice/MCP host)
> + Ollama ≥0.32 (local models) + your own MCP servers (device skills) + a SheshaAOS-style audit log
> (governance).** This doc specifies exactly that, corrected for RTX 4050 6 GB and the FHD+ panel.

---

## 1. Why this stack (and not the alternatives)

| Component | Choice | Why |
|-----------|--------|-----|
| Frontend / voice / chat | **Newelle 1.4.5** (native, not Flatpak) | Already has wake word, STT (faster-whisper), TTS (Piper/Kokoro/Edge), MCP client (stdio+http as of 1.4.5), subagents, skills, file permissions, scheduled tasks, OpenAI-compatible API. Building this yourself is months of work. |
| LLM runtime | **Ollama ≥0.32** | v0.32 has an interactive agent CLI, OpenAI-compatible endpoint, flash attention, model library; one `systemctl` unit. |
| Primary model | **phi4-mini** (3.8B Q4, ~3.2 GB) | Best quality that fits 6 GB with KV headroom. |
| Code model | **qwen2.5-coder:3b** Q4 | Strong at shell/code for tool calls. |
| Vision | **moondream2** Q4 (~2.5 GB) | Screenshots/OCR. |
| Embeddings | **nomic-embed-text** (<0.5 GB) | Memory/RAG, runs alongside primary. |
| Tool protocol | **MCP 2026-07-28** (Model Context Protocol) | Open standard Newelle speaks; your servers are reusable in any MCP client. |
| Governance | **Shesha audit log** (your SheshaAOS pattern) | Append-only JSONL/SQLite of every tool call + result; policy gates destructive actions. |
| Overlay | **Quickshell QML** (the shell you already run) | Mic/thinking/speaking indicator; no new dependency. |

**Do not build** a custom wake-word daemon, STT pipeline, chat UI, or agent loop — Newelle ships all of
them. **Do build** the MCP servers that know *your* machine (GPU, organizer, Hyprland, backups) and the
audit/policy layer that makes autonomy safe. That is where your unique value is.

---

## 2. Process topology

```
                       ┌──────────────────────────────┐
                       │   Newelle 1.4.5 (GTK4)       │
                       │  - wake word "Hey Shesha"     │
                       │  - STT faster-whisper        │
                       │  - TTS piper/kokoro           │
                       │  - MCP client (stdio)        │
                       │  - OpenAI-compatible API :xxxx│
                       └───────┬───────────┬───────────┘
                  stdio MCP    │           │   HTTP API
            ┌──────────────────┘           └──────────────────┐
            ▼                                                   ▼
   ┌────────────────────┐                          ┌───────────────────────┐
   │ system_control     │                          │  Quickshell overlay    │
   │ smart_organizer    │                          │  (SheshaOverlay.qml)    │
   │ hyprland_control   │                          │  listens on Newelle    │
   │ (FastMCP servers)  │                          │  API / DBus            │
   └─────────┬──────────┘                          └───────────────────────┘
             │ every tool call + result
             ▼
   ┌──────────────────────────────────────────────────────┐
   │ shesha-audit  (append-only JSONL + SQLite)            │
   │ ~/.local/share/shesha/audit/events.db                 │
   │ policy.toml: which tools need confirmation / are denied│
   └──────────────────────────────────────────────────────┘
             │
             ▼
   ┌────────────────────┐
   │ Ollama :11434      │  phi4-mini / qwen2.5-coder:3b / moondream2 / nomic
   └────────────────────┘
```

Newelle runs as a user service. The MCP servers are launched by Newelle over stdio (no open ports,
no auth surface). The audit log is written by a thin wrapper the MCP servers call.

---

## 3. Installation (correct for CachyOS 260628 / RTX 4050)

```bash
# 1. Ollama
sudo pacman -S --needed ollama
systemctl --user enable --now ollama.service   # or system service; prefer user for per-user models

# 2. Newelle 1.4.5 NATIVE (AUR). Do NOT use Flatpak for Shesha — sandbox blocks stdio MCP + mic.
paru -S --needed newelle        # or: yay -S newelle ; shelly if its CLI supports -S

# 3. Python venv for the MCP servers and memory
uv venv ~/.local/state/shesha/.venv
uv pip install --python ~/.local/state/shesha/.venv/bin/python \
  "mcp[cli]>=1.0" "fastmcp>=0.1" "chromadb>=1.5.9" "httpx>=0.27" "pydantic>=2"

# 4. 6 GB-safe models (one at a time on GPU; nomic-embed can co-reside)
ollama pull phi4-mini
ollama pull qwen2.5-coder:3b
ollama pull nomic-embed-text
ollama pull moondream2
# DO NOT pull qwen3:14b / llava:13b / mistral:7b@8k — they overflow 6 GB.
```

> `paru` is not on the 260628 ISO (Shelly is). For scripting reliability, install `paru`
> (`sudo pacman -S --needed paru`) or adapt commands to `shelly`. The installer must auto-detect.

---

## 4. Newelle configuration

`~/.config/newelle/config.toml` (the repo ships a corrected template at
`dots/.config/newelle/config.toml`):
```toml
[model]
provider = "ollama"
model = "phi4-mini"
ollama_url = "http://localhost:11434"

[voice]
enabled = true
wake_word = "hey sesha"
stt_backend = "faster_whisper"
stt_model = "base.en"          # ~145 MB, fast, English. Use "small.en" if CPU allows.
tts_backend = "piper"
tts_voice = "en_US-ryan-high"  # swap to a preferred voice; keep it local

[memory]
enabled = true
embedding_model = "nomic-embed-text"

[permissions]
# Newelle 1.3.5+ file permission system
allow_read  = ["~/Documents/Personal", "~/Downloads", "~/Notes", "~/Projects/personal"]
allow_write = ["~/Downloads", "~/Documents/Inbox", "~/.local/share/sesha"]
ask_before  = ["~/"]           # anything else prompts
deny        = ["~/Documents/Job", "~/Projects/job", "~/Vaults", "~/.ssh", "~/.gnupg"]
```

MCP servers are registered in Newelle's settings as **stdio commands** (not the bogus HTTP URLs from
the prior config):
```toml
[mcp.shesha_system]
command = "~/.local/state/shesha/.venv/bin/python"
args = ["~/.local/bin/shesha-system-control-mcp"]

[mcp.shesha_organizer]
command = "~/.local/state/shesha/.venv/bin/python"
args = ["~/.local/bin/shesha-smart-organizer-mcp"]

[mcp.shesha_hyprland]
command = "~/.local/state/shesha/.venv/bin/python"
args = ["~/.local/bin/shesha-hyprland-control-mcp"]
```

---

## 5. MCP server: `hyprland_control.py` (NEW — fixes N-04)

```python
#!/usr/bin/env python3
"""MCP server: control Hyprland via hyprctl. License: GPL-3.0"""
import json, subprocess
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("hyprland-control")

def _hypr(*args):
    r = subprocess.run(["hyprctl", "-j", *args], capture_output=True, text=True)
    return r.stdout or r.stderr

@mcp.tool()
def switch_workspace(number: int) -> str:
    """Switch to Hyprland workspace N (1-10)."""
    return _hypr("dispatch", "workspace", str(number))

@mcp.tool()
def get_active_window() -> dict:
    """Return JSON info about the focused window."""
    return json.loads(_hypr("activewindow"))

@mcp.tool()
def move_window_to_workspace(number: int) -> str:
    """Move the focused window to workspace N."""
    return _hypr("dispatch", "movetoworkspace", str(number))

@mcp.tool()
def set_opacity(active: float = 1.0, inactive: float = 0.92) -> str:
    """Adjust window opacity (0.0-1.0)."""
    subprocess.run(["hyprctl", "--keyword", f"decoration:active_opacity={active}"])
    subprocess.run(["hyprctl", "--keyword", f"decoration:inactive_opacity={inactive}"])
    return f"opacity {active}/{inactive}"

@mcp.tool()
def toggle_effects(battery: bool) -> str:
    """Reduce blur/shadows on battery for power saving; restore on AC."""
    if battery:
        subprocess.run(["hyprctl", "--keyword", "decoration:blur:passes=1"])
        subprocess.run(["hyprctl", "--keyword", "decoration:shadow:enabled=0"])
        return "power-saver visuals"
    subprocess.run(["hyprctl", "--keyword", "decoration:blur:passes=3"])
    subprocess.run(["hyprctl", "--keyword", "decoration:shadow:enabled=1"])
    return "full visuals"

if __name__ == "__main__":
    mcp.run(transport="stdio")
```

`smart_organizer.py` exposes `organize`, `last_moves`, `undo_last`, `pause`, `resume` per
`05_SMART_ORGANIZER_V2.md` §7. `system_control.py` already exists (fix the `hyprland` typo
`decoration` and add battery/GPU/backup/status tools).

---

## 6. Governance: the Shesha audit log + policy

Every MCP tool call is wrapped to append an event:
```jsonl
{"ts":"2026-08-09T18:11:02+05:30","server":"system_control","tool":"switch_gpu_mode",
 "args":{"mode":"gaming"},"result":"ok","session":"newelle-...","hash":"sha256:..."}
```
Stored in `~/.local/share/shesha/audit/events.db` (SQLite) + a hash-chained JSONL (each line includes
the previous line's hash, à la SheshaAOS append-only log — tamper-evident).

`~/.config/shesha/policy.toml`:
```toml
[confirm]
# these tools require an in-chat "yes" before running
tools = ["switch_gpu_mode", "undo_last", "organize"]

[deny]
# never runnable by the agent at all
tools = ["*_rm", "shell_exec_root"]
paths = ["~/Documents/Job", "~/Projects/job", "~/Vaults", "~/.ssh", "~/.gnupg"]

[auto]
# safe to run without asking
tools = ["get_system_status", "last_moves", "switch_workspace", "get_active_window"]
```
A `sesha` CLI wraps queries:
```bash
shesha log --since 1h          # what did Shesha do
shesha undo                    # undo the last reversible action
shesha replay --from <hash>    # replay the event log (SheshaAOS-style)
```

This is the bridge to your **SheshaAOS** thesis: the desktop agent becomes the first *client* of the
governance/event-sourcing layer you already built in Rust. Later, replace the SQLite/JSONL shim with a
real SheshaAOS event-store connection.

---

## 7. Quickshell overlay

`dots/.config/quickshell/ii/shesha/SheshaOverlay.qml` — a small floating pill, bottom-right above the
bar, showing idle / listening / thinking / speaking with a pulsing arc. It subscribes to Newelle's
OpenAI-compatible/interface API (1.4.0+) or watches the audit log via a QML `FolderListView`/timer.
Bind:
- mic active → cyan + waveform scale
- LLM thinking → amber spinner
- TTS speaking → green equalizer bars
- error/needs-confirmation → red pulse + raises Newelle window

Reuse end-4's existing color tokens (`matugen`) so it matches Material You. Do **not** add a heavy
separate UI; the overlay is status only, interaction is by voice or Newelle.

---

## 8. Persona ("SOUL")

`~/.config/shesha/SOUL.md` (fed as Newelle's system prompt):
```
You are Shesha, Gagan's local AI desktop agent on CachyOS Linux + Hyprland.
- You are private-first: all models run locally; never send personal data to the cloud.
- You are brief and precise. Prefer acting over explaining. One short sentence + the action.
- You control the system through MCP tools (GPU, power, files, Hyprland, organizer).
- Every action is logged; destructive actions require Gagan's confirmation per policy.toml.
- Gagan is an AI/LLM engineer who builds SheshaAOS, SheshaOS, and Vyākṛti. Be technical when asked.
- Speak English by default; respond in the language Gagan uses.
- If unsure, ask one short question rather than guessing.
```

---

## 9. What you explicitly do NOT need (cut the bloat)

- ❌ Custom agent framework / `pi` / `prime-agent` integration — Newelle is the agent host.
- ❌ `openWakeWord` as a separate daemon — Newelle 1.3.0+ has wake word built in.
- ❌ ChromaDB-heavy memory on day one — start with Newelle's semantic memory; add your RAG service later.
- ❌ OmniRoute/cloud routing by default — local-first; add cloud only as an explicit, labeled fallback.
- ❌ Newelle Flatpak — use native AUR for stdio MCP + mic + filesystem.
- ❌ 14B/13B models on the 4050 — they thrash.

---

## 10. Acceptance test (voice)

1. Boot → Newelle starts, Ollama running, overlay idle.
2. Say **"Hey Shesha"** → overlay pulses, STT activates.
3. "Organize my downloads." → confirmation prompt → organizer runs → "Moved 12 files" spoken.
4. "Switch to performance mode." → `powerprofilesctl set performance` + notification.
5. "What was my GPU temp an hour ago?" → audit log / `nvidia-smi` query answered.
6. "Undo the last move." → files restored from undo log.
7. Pull the network → all of the above still works (proves local-first).
