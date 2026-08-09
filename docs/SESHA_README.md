# Sesha Documentation

This directory is the single source of truth for the **Sesha** ecosystem — the production-grade,
local-first, AI-assisted desktop built on this fork of `end-4/dots-hyprland` for the MSI Sword
16 HX B14VEKG on CachyOS 260628.

**Start with [`SESHA/00_INDEX.md`](SESHA/00_INDEX.md).** It contains the verified hardware/software
facts (correcting errors in earlier AI audits) and the map of every document.

| Document | Purpose |
|---|---|
| [00_INDEX](SESHA/00_INDEX.md) | Master index, verified facts, philosophy, vision |
| [01_AUDIT](SESHA/01_AUDIT.md) | Independent audit of the live repo — every issue with exact fixes |
| [02_ROADMAP](SESHA/02_ROADMAP.md) | Phased execution plan (effort, dependencies, exit criteria) |
| [03_DISK_STRUCTURE](SESHA/03_DISK_STRUCTURE.md) | On-disk layout: job vs personal vs projects, backup policy |
| [04_DEVICE_PROFILE](SESHA/04_DEVICE_PROFILE.md) | MSI Sword + CachyOS tuning: GPU/MUX, 144 Hz, power, kernel |
| [05_SMART_ORGANIZER_V2](SESHA/05_SMART_ORGANIZER_V2.md) | Real-time AI file organizer (Rust watcher + Python classifier) |
| [06_SESHA_AGENT](SESHA/06_SESHA_AGENT.md) | The voice agent: Newelle + Ollama + MCP + audit log |
| [07_AUTOMATIONS](SESHA/07_AUTOMATIONS.md) | Every autonomous job, unit, and udev rule |
| [08_ECOSYSTEM_TOOLS](SESHA/08_ECOSYSTEM_TOOLS.md) | More tools to build + what to steal from other repos + phone harness |
| [09_AI_PROMPTS](SESHA/09_AI_PROMPTS.md) | Copy-paste prompts for AI pair-programming per phase/situation |
| [10_LICENSES_AND_SOURCES](SESHA/10_LICENSES_AND_SOURCES.md) | License manifest, pinned versions, all links audited |
| [checklist](SESHA/checklist.md) | Tick these as you implement |

The audit and roadmap supersede the two earlier AI documents you provided (`Auto-desktopenv-audit.md`
and the 63-page master-plan PDF). Both contained errors — most notably the wrong display resolution
and GPU, plus new bugs introduced while "fixing" the repo — all catalogued in `01_AUDIT.md`.
