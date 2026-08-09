# Shesha Ecosystem — Master Index

> **Owner:** Gagan Jain (`gaganjainse`) · Jaipur, IN (Asia/Kolkata)
> **Device:** MSI Sword 16 HX **B14VEKG-210IN**
> **OS:** CachyOS **260628** (Arch-based, Linux 6.18 live / 7.1 installed, BORE scheduler)
> **Desktop:** Hyprland ≥0.55 (Lua config era) + Quickshell (`ii`), on top of `end-4/dots-hyprland`
> **Last reconciled:** 2026-08-09

This folder is the single source of truth for the **Shesha** ecosystem — the production-grade,
AI-first, hands-off desktop built on top of your `shesha-desktop` fork. Every document here was
independently verified against the live repo on 2026-08-09; it supersedes the two prior AI audits
(`uploads/shesha-desktop-audit.md` and the 63-page `shesha-desktop_Master_Plan_90p.pdf`), both of
which contained factual errors catalogued in `01_AUDIT.md`.

---

## 0. How to use these documents

You said you will be driving the build **with AI assistants**. The docs are therefore written in a
specific order so you can paste them into an AI one at a time, check the result, and move on:

| # | Document | What it gives you | When to open it |
|---|----------|-------------------|-----------------|
| 00 | `00_INDEX.md` (this) | Map of everything, verified facts, status legend | Always start here |
| 01 | `01_AUDIT.md` | Independent audit of the **current** repo + every issue, with exact fixes | Before touching code |
| 02 | `02_ROADMAP.md` | Phased, dependency-ordered execution plan with effort/risks | Planning each session |
| 03 | `03_DISK_STRUCTURE.md` | Full on-disk layout (work vs personal vs job) + bootstrap script | When you install CachyOS |
| 04 | `04_DEVICE_PROFILE.md` | MSI Sword + CachyOS tuning: GPU/MUX, 144 Hz, power, kernel | Hardware setup |
| 05 | `05_SMART_ORGANIZER_V2.md` | Real-time, AI-assisted file organizer spec + code | Beating clutter |
| 06 | `06_SHESHA_AGENT.md` | The Shesha agent: Newelle + Ollama + MCP, local-first | Building the assistant |
| 07 | `07_AUTOMATIONS.md` | Catalog of every autonomous job + units + udev rules | Set-and-forget |
| 08 | `08_ECOSYSTEM_TOOLS.md` | The broader tool ecosystem (incl. Android phone harness) | Expanding the system |
| 09 | `09_AI_PROMPTS.md` | **Copy-paste prompts for AI assistants**, per phase/situation | Every work session |
| 10 | `10_LICENSES_AND_SOURCES.md` | License manifest + every link, version-pinned | Legal / upgrades |

A parallel set of **machine-actionable files** lives in this repo:

- `docs/SHESHA/checklist.md` — one-line-per-task checklist you tick off.
- `tools/lib/common.sh`, `profiles/msi-sword-cachyos/`, etc. — actual code referenced by the docs.

---

## 1. Verified hardware & software baseline (do not trust anything else)

These were verified against the manufacturer product page and CachyOS release notes on 2026-08-09.
**Two prior AI reports got the display resolution and GPU wrong.** Use these numbers everywhere.

| Component | Correct value | Notes |
|-----------|---------------|-------|
| CPU | Intel Core **i7-14700HX** (20C/28T, Raptor Lake-HX) | `-march=native` target |
| iGPU | Intel **Arc / UHD** (integrated in 14700HX) | Primary Wayland renderer to save power |
| dGPU | NVIDIA **RTX 4050 Laptop, 6 GB GDDR6**, 96-bit bus | **NOT 4070 / 8 GB** |
| Display | 16" **FHD+ 1920×1200 (16:10), 144 Hz, IPS** | **NOT 2560×1600**; connector `eDP-1` |
| RAM | **16 GB DDR5-5600** (1×16 GB, one SODIMM free; max 96 GB) | Upgrade to 32/64 GB strongly advised for local LLM |
| Storage | 1 TB NVMe Gen4; **1× Gen4 + 1× Gen5 M.2 slot** | Second slot free |
| Network | Wi-Fi 6E (likely **AX211**), 2.5G Ethernet | |
| Ports | 1× TB/USB-C (DP/PD), 3× USB-A, **HDMI 2.1 (8K60/4K120)**, RJ45, audio | |
| OS | **CachyOS 260628** — Linux 6.18 live / 7.1 installed, GCC 14.1, Python 3.13 | BORE scheduler; `chwd` for drivers |
| AUR helper | **Shelly** is default (paru removed). You can still install `paru`/`yay`. | Your installer must auto-detect |
| Hyprland | ≥ **0.55** (Lua config). 0.56 is git; rolling will pull it | Dotfiles already use Lua ✅ |
| Display mgr | SDDM recommended for Hyprland on CachyOS | greetd optional |

### AI model budget (RTX 4050, 6 GB) — hard ceiling

Rule of thumb: a Q4_K_M model needs ≈ (file size) + 1–1.5 GB KV cache headroom at 4k context.
**Run one GPU model at a time.** Use the iGPU/CPU for vision offload where supported.

| Role | Model | VRAM | Why |
|------|-------|------|-----|
| Primary brain / chat | **phi4-mini** (3.8B Q4) | ~3.2 GB | Best quality/size for 6 GB |
| Code | **qwen2.5-coder:3b** Q4 | ~2.8 GB | Fast, strong at code |
| Embeddings / RAG | **nomic-embed-text** | <0.5 GB | Runs alongside main model |
| Vision (screenshots) | **moondream2** Q4 | ~2.5 GB | Smallest usable vision model |
| Heavy (occasional) | qwen2.5:7b Q4 | ~4.6 GB | Partial CPU offload, slower |
| ❌ Do NOT pull | qwen3:14b, llava:13b, mistral:7b@8k | 6–9 GB | Overflows 6 GB → thrash/OOM |

> With 16 GB system RAM you can offload 7B layers to CPU, but expect 5–15 tok/s. A 32 GB RAM upgrade
> is the single biggest quality upgrade for local AI (enables 7–9B models comfortably).

---

## 2. Status legend

- 🔴 **BROKEN** — fails on a clean CachyOS 260628 install today
- 🟠 **BUG/RISK** — works sometimes but wrong or fragile
- 🟡 **INCOMPLETE** — scaffolded by a prior AI but not finished
- 🟢 **DONE** — verified present and correct in the live repo
- ⚪ **NEW** — proposed, not yet started

The authoritative issue list with current status is in `01_AUDIT.md`.

---

## 3. Your philosophy (read this before changing anything)

From your chats, GitHub profile (`AI/LLM Engineer, VIT Vellore 2025, author of SheshaAOS`), and
repos (SheshaAOS — governance-first, event-sourced, append-only audit trail; SheshaOS — local-first
specialist models; Vyākṛti — a Sanskrit programming language; RAG service; LLM eval harness), the
design principles for this ecosystem are:

1. **Local-first & private.** Voice, files, memory, and models run on-device. Cloud is an
   opt-in fallback (OmniRoute-style), never the default.
2. **Governance & auditability.** Borrow SheshaAOS's append-only event log: every autonomous action
   Shesha takes is recorded, replayable, and reversible. Policy gates destructive actions.
3. **Performance without compromise.** Looks (end-4 Material You + Quickshell polish) and speed
   (144 Hz, CachyOS BORE, NVMe kyber) are first-class; bloat from other distros/devices is pruned.
4. **Hands-off.** If it can be automated safely, it is automated. You speak; the system acts.
5. **Composable over monolithic.** Small tools (smart-organizer, mux-switcher, backup) exposed over
   MCP/IPC; one agent orchestrates them — not one giant binary.
6. **Rust where it matters (systems, watchers, kernel-adjacent); Python for AI glue; Lua/QML for
   the shell; Bash for the installer.** Matches your existing skill set (Rust + Python + TS).
7. **Indian-rooted identity.** The names (Shesha, Vyākṛti, Nexus) and the Sanskrit/Indic framing are
   intentional — keep them consistent across the system.

Keep every future decision aligned to these seven principles. If a proposal violates one, it needs
an explicit exception in this file.

---

## 4. The one-paragraph vision

**Shesha** is the local AI layer that sits between you and your CachyOS/Hyprland machine: it watches
your folders and organizes them, switches GPU/power profiles based on what you're doing, backs up
and maintains the system in the background, and answers you by voice through a Quickshell overlay —
all while writing every action to a SheshaAOS-style audit log so nothing it does is invisible or
irreversible. Over time it becomes the desktop manifestation of your SheshaAOS/SheshaOS thesis:
an AI-first operating environment built on a fast, beautiful, trustworthy open base.
