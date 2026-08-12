# Shesh Documentation

This directory is the single source of truth for the **Shesh** ecosystem — the production-grade,
local-first, AI-assisted desktop built on this fork of `end-4/dots-hyprland` for the MSI Sword
16 HX B14VEKG on CachyOS 260628.

**Start with [`SHESH/00_INDEX.md`](SHESH/00_INDEX.md).** It contains the verified hardware/software
facts (correcting errors in earlier AI audits) and the map of every document.

| Document | Purpose |
|---|---|
| [00_INDEX](SHESH/00_INDEX.md) | Master index, verified facts, philosophy, vision |
| [01_AUDIT](SHESH/01_AUDIT.md) | Independent audit of the live repo — every issue with exact fixes |
| [02_ROADMAP](SHESH/02_ROADMAP.md) | Phased execution plan (effort, dependencies, exit criteria) |
| [03_DISK_STRUCTURE](SHESH/03_DISK_STRUCTURE.md) | On-disk layout: job vs personal vs projects, backup policy |
| [04_DEVICE_PROFILE](SHESH/04_DEVICE_PROFILE.md) | MSI Sword + CachyOS tuning: GPU/MUX, 144 Hz, power, kernel |
| [05_SMART_ORGANIZER_V2](SHESH/05_SMART_ORGANIZER_V2.md) | Real-time AI file organizer (Rust watcher + Python classifier) |
| [06_SHESH_AGENT](SHESH/06_SHESH_AGENT.md) | The voice agent: Newelle + Ollama + MCP + audit log |
| [07_AUTOMATIONS](SHESH/07_AUTOMATIONS.md) | Every autonomous job, unit, and udev rule |
| [08_ECOSYSTEM_TOOLS](SHESH/08_ECOSYSTEM_TOOLS.md) | More tools to build + what to steal from other repos + phone harness |
| [09_AI_PROMPTS](SHESH/09_AI_PROMPTS.md) | Copy-paste prompts for AI pair-programming per phase/situation |
| [10_LICENSES_AND_SOURCES](SHESH/10_LICENSES_AND_SOURCES.md) | License manifest, pinned versions, all links audited |
| [checklist](SHESH/checklist.md) | Tick these as you implement |

The audit and roadmap supersede the two earlier AI documents you provided (`shesh-desktop-audit.md`
and the 63-page master-plan PDF). Both contained errors — most notably the wrong display resolution
and GPU, plus new bugs introduced while "fixing" the repo — all catalogued in `01_AUDIT.md`.
