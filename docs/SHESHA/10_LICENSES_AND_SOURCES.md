# 10 — Licenses, Versions & Source Manifest

> License compliance + a version-pinned manifest of every external dependency and link you gave me,
> with what to use and what to skip. Verify versions at install time (rolling releases move fast),
> but this is the reconciled baseline as of **2026-08-09**.

---

## 1. License manifest

Your repo root is **GPL-3.0** (matches upstream `end-4/dots-hyprland`). The README must say GPL-3.0
(the current "MIT" claim is wrong — see MED-16). All the components below are GPL-3-compatible:

| Component | License | GPL-3 compatible? | Use in Shesha |
|---|---|---|---|
| end-4/dots-hyprland (base) | GPL-3.0 | ✅ same | core dotfiles |
| Newelle 1.4.5 | GPL-3.0 | ✅ same | agent frontend |
| Ollama | MIT | ✅ | local LLM runtime |
| faster-whisper | MIT | ✅ | STT |
| Piper TTS | MIT | ✅ | TTS |
| ChromaDB | Apache-2.0 | ✅ | vector memory |
| MCP SDK / FastMCP | MIT/Apache-2.0 | ✅ | tool protocol |
| hyprland-rs | MIT | ✅ | future Rust Hyprland IPC |
| Rust `notify` crate | MIT/Apache-2.0 (dual) | ✅ | file watcher |
| OmniRoute | MIT | ✅ | opt-in cloud fallback only |
| Hermes Agent | MIT | ✅ | reference/skills ideas |
| pi (earendil-works) | MIT | ✅ | agent-loop reference |
| Prime Agent / pi harness | MIT | ✅ | Continual Harness idea |
| phone-harness | MIT | ✅ | ADB port concept |
| computer-use-linux | Apache-2.0 | ✅ | future desktop control |
| build-your-own-x | MIT | ✅ | learning track |
| Hyprland | BSD-3-Clause | ✅ | compositor |
| Quickshell | LGPL-3/GPL | ✅ | shell (dynamic linking OK) |
| NVIDIA driver/userspace | NVIDIA proprietary | ⚠️ system pkg, not linked into your code | use distro packages |
| CachyOS packages | mixed (GPL/MIT/Apache) | ✅ | distro |
| HermesOffice | Apache-2.0 | ✅ | **concept only** (Electron, mac/win) |

**Actions:**
1. Set `README.md` license to GPL-3.0; fix the badge.
2. `licenses/MIT.txt`: either fill `2024–2026 / gaganjainse` for MIT-licensed *snippets you author*,
   or delete it if your contributions are GPL-3 (the root `LICENSE` already covers the repo).
3. Keep `licenses/LGPL-3.0.txt` (Quickshell) and add a `NOTICE` crediting end-4, Newelle, and any
   vendored assets.
4. If you ever vendor code, add its license to `licenses/` and this table.

---

## 2. Pinned versions (install-time manifest)

### System / OS
| Thing | Target | Notes |
|---|---|---|
| CachyOS ISO | **260628** | Linux 6.18 live / 7.1 installed; GCC 14.1; Python 3.13 |
| Kernel | `linux-cachyos` (BORE) | keep `-lts` as fallback |
| Hyprland | ≥ **0.55** (Lua config); 0.56 in git | rolling will update; your config is Lua ✅ |
| Quickshell | latest (end-4 pinned via PKGBUILD) | don't override the end-4 version casually |
| Display manager | **SDDM** | recommended for Hyprland on CachyOS |
| AUR helper | **paru** (for scripting) on top of Shelly | ISO ships Shelly; `pacman -S paru` |

### AI stack
| Component | Version | Notes |
|---|---|---|
| Newelle | **1.4.5** (2026-06-19) | native/AUR, not Flatpak; MCP+wake word+subagents |
| Ollama | ≥ **0.32.6** | agent mode in 0.32.0; flash-attention; OpenAI-compat API |
| phi4-mini | latest Q4 | ~3.2 GB, primary brain |
| qwen2.5-coder | **:3b** Q4 | ~2.8 GB, code/tool calls |
| nomic-embed-text | latest | <0.5 GB, embeddings |
| moondream2 | latest Q4 | ~2.5 GB, vision |
| faster-whisper | ≥ **1.2.0** | needs CUDA 12 + cuDNN 9 |
| Piper TTS | latest | `en_US-ryan-high` or preferred |
| ChromaDB | ≥ **1.5.9** | vector memory |
| mcp[cli] | ≥ 1.0 | MCP SDK (2026-07-28 spec) |
| FastMCP | ≥ 0.1 | decorator framework |

> Version reality-check performed 2026-08-09: the earlier "Newelle 1.2" and "qwen3:14b / llava:13b"
> recommendations were wrong (outdated and over the 6 GB VRAM limit). Use the table above.

### Rust (`watcher-rs`)
```toml
notify = "6"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
crossbeam-channel = "0.5"
# future: hyprland = "0.3" (verify latest on crates.io)
```

### Python (Shesha MCP servers / memory)
```
mcp[cli]>=1.0
fastmcp>=0.1
chromadb>=1.5.9
httpx>=0.27
pydantic>=2
tomli-w>=1.0
watchfiles>=0.24   # only if not using the Rust watcher
```

---

## 3. Every link you provided — audited

| Link | What it is | Verdict / use |
|---|---|---|
| github.com/gaganjainse | your profile | AI/LLM engineer; SheshaAOS, SheshaOS, Vyākṛti, RAG, eval harness |
| github.com/gaganjainse/shesha-desktop | this repo | fork of end-4; subject of this work |
| youtube.com/shorts/emfFxq_yXvA | Jarvis-like voice demo | inspiration = wake word + STT + TTS + desktop control (Newelle + MCP) |
| youtube.com/shorts/WSBwga31gE0 | voice assistant demo | same pattern |
| youtube.com/shorts/kwpEDhGQ3sU | voice assistant demo | same pattern |
| youtube.com/shorts/62TwxgOnniw + newelle URL | (malformed concat) | treat as a Newelle pointer; the short shows AI desktop control |
| github.com/qwersyk/newelle | Newelle | **core frontend** — use 1.4.5 native |
| github.com/criptogus/HermesOffice | AI office suite (Electron, mac/win) | concept only (shared OpenAI endpoint); don't install |
| github.com/diegosouza.../OmniRoute | 40k★ multi-provider AI gateway | opt-in cloud fallback; never default |
| github.com/earendil-works/pi | agent harness (85k★) | reference for agent loop/hardening; don't add runtime |
| github.com/nousresearch/hermes-agent | 227k★ self-improving agent | reference skills/cron/gateway; Newelle already covers most |
| avifenesh/computer-use-linux | Linux desktop-control MCP | future: AT-SPI + Wayland control (evaluate maturity) |
| github.com/PrimeIntellect-ai/prime-agent | RLM harness | steal "Continual Harness" prompt-refinement idea |
| github.com/ShawnPana/phone-harness | macOS iPhone harness | port concept to Android ADB (your Realme) |
| github.com/codecrafters-io/build-your-own-x | 537k★ tutorials | learning track for shesha-kernel/shell/DB |
| star-history.com | star-growth charts | used to size projects; no action |
| trendshift.io | trending repos | monitoring; no action |

Note: one URL in your message was concatenated incorrectly
(`.../shorts/62TwxgOnniwhttps://github.com/qwersyk/newelle`); treat as two separate references.

---

## 4. Your own repos to connect (from your profile)

| Repo | Role in the Shesha vision |
|---|---|
| **SheshaAOS** | Governance/event-sourcing layer → Shesha audit log & policy (the bridge) |
| **SheshaOS** | Local-first specialist-model OS concept → informs model routing |
| **shesha-kernel** | Alpha microkernel track → long-term research, not daily driver |
| **rag-service** | Run locally as `shesha-memory` (RAG over notes/docs/projects) |
| **llm-eval-harness** | Use to evaluate phi4-mini/qwen2.5-coder on your own tool-use tasks |
| **Vyākṛti** | Personal project; keep under `Projects/personal`, exclude from AI scope |
| AIM/FWRS/portfolio/etc. | Job/personal; keep the work/personal boundary in `03_DISK_STRUCTURE.md` |

The single highest-leverage connection is **SheshaAOS ↔ Shesha audit log**: it makes your desktop agent
the first client of the governance system you already built, and gives you a real, daily testbed for
the event-sourced AI-kernel thesis.

---

## 5. Upgrade checklist (run monthly on rolling release)

```bash
# 1. Review what changed (NEVER blind -Syu with NVIDIA)
checkupdates                          # repo packages
paru -Qua                             # AUR
# 2. Check Arch/CachyOS news for NVIDIA/hyprland/kernel holds
# 3. Snapshot root/home (btrfs) first
sudo snapper -c root create -d pre-update
# 4. Update
sudo pacman -Syu
paru -Sua
# 5. Rebuild kernels/modules if needed
sudo mkinitcpio -P
# 6. Verify
hyprctl version ; ollama --version ; newelle --version
systemctl --user --failed ; systemctl --failed
```
If `linux-cachyos`, `nvidia`, or `hyprland` updated, reboot and re-run the Phase-3 verification
commands in `04_DEVICE_PROFILE.md` §7.
