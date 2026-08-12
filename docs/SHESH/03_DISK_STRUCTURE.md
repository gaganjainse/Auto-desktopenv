# 03 — Disk Structure: Work vs Personal vs Job

> A clean, XDG-compliant, backup-friendly layout that separates your **job** (employed work),
> **personal projects** (SheshAOS, SHESH, Vyākṛti, shesh-desktop), and **personal life**, while
> giving the smart-organizer and Shesh predictable roots to operate on.

---

## 1. Top-level partition strategy

Your laptop has **1 TB NVMe (Gen4)** and a free **Gen5 M.2 slot**. Recommended partitioning on the
Gen4 drive; use the Gen5 slot later for a second disk (projects/VMs) or a larger replacement.

| Mount | Size | FS | Purpose |
|-------|------|----|---------|
| `/boot` (or `/efi`) | 1 GiB | FAT32 | EFI system partition |
| `/boot` (XBOOTLDR if needed) | — | ext4 | CachyOS kernels |
| `/` | 80–120 GiB | **btrfs** (zstd, snapshots) | System; use `@` subvols |
| `swap` | 8 GiB (≈½ RAM) | swap | Hibernate support with 16 GB RAM (zram handles the rest) |
| `/home` | remaining | **btrfs** (zstd, snapshots) | User data; split into subvolumes below |
| *(future Gen5)* | 1–2 TB | btrfs/ext4 | `~/Projects` + VMs/datasets (heavy I/O) |

> Use **btrfs snapshots** (snapper/timeshift) for `/` and `/home` but **exclude** the large,
> regenerable, or private subvolumes below from snapshots to save space. ZRAM handles swap; the
> 8 GiB swap partition is for hibernate (s2idle/s2disk) only.

### Btrfs subvolume layout (under `/home/gagan`)

```
@home/.snapshots         (snapper-managed, EXCLUDED from backup of large data)
└── gagan/
    ├── .local/share/    ← XDG_DATA (apps state)
    ├── .config/         ← XDG_CONFIG (your dotfiles live here via stow/git)
    ├── .cache/          ← XDG_CACHE (NO backup, NO snapshot)
```

---

## 2. The `$HOME` directory tree

```
~/
├── Desk/                      ← keep the literal Desktop EMPTY (only in-progress, auto-cleaned)
├── Documents/
│   ├── Personal/              ← life: IDs, scans, travel, finance, medical
│   │   ├── Finance/
│   │   ├── Government-ID/
│   │   ├── Medical/
│   │   └── Travel/
│   ├── Job/                   ← EMPLOYER work (separate, access-controlled, separate backup)
│   │   ├── <employer>/        ← one folder per employer/client, NDA data stays here
│   │   └── _onboarding/
│   ├── Reference/             ← manuals, papers, books notes
│   └── Inbox/                 ← landing zone; smart-organizer sorts from here
│
├── Downloads/                 ← TRANSIENT. Auto-organized nightly, auto-delete after 30d
│   ├── Archives/  Installers/  Torrents/  Unsorted/
│
├── Media/                     ← NOT ~/Pictures/Music/Videos soup; one media root
│   ├── Images/  Screenshots/  Wallpapers/  Music/  Videos/  Camera/  Design/
│
├── Projects/                  ← ALL code, clearly split
│   ├── job/                   ← work repos (cloned with work git identity)
│   ├── personal/              ← your own repos
│   │   ├── shesh-desktop/
│   │   ├── SheshAOS/
│   │   ├── SHESH/
│   │   ├── shesh-kernel/
│   │   ├── Vyakrti/
│   │   ├── rag-service/
│   │   ├── llm-eval-harness/
│   │   └── portfolio/
│   ├── labs/                  ← experiments, spikes, AI scratch (git not required)
│   ├── forks/                 ← upstream forks you're studying/PRing
│   └── _archive/              ← completed/abandoned (cold, excluded from recent-projects)
│
├── AI/                        ← local AI assets (excluded from snapshots — large)
│   ├── Models/                ← safetensors, GGUF, LoRAs
│   ├── Datasets/
│   ├── Vectors/               ← Chroma/SQLite-vss stores
│   ├── Weights-Cache/         ← huggingface, ollama blobs (symlink ~/.cache/huggingface here)
│   └── Sessions/              ← agent transcripts / audit logs
│
├── Notes/                     ← knowledge base (Obsidian/logseq vault, git-backed)
│   ├── Daily/  Tech/  Ideas/  Meetings/  Shesh/
│
├── Vaults/                    ← encrypted at rest
│   ├── Passwords/             ← KeePassXC / gopass database (NOT synced to cloud)
│   └── Keys/                  ← exported GPG/SSH backups (LUKS container only)
│
├── Backups/                   ← LOCAL backup targets (external drive mounts here)
│   ├── external/  nas/  restic-repo/
│
└── .local/  .config/  .cache/ (XDG)
```

### Why this shape

- **`Desk/` stays empty.** It's a staging area, not storage. Smart-organizer sweeps anything older than
  a threshold into `Documents/Inbox` → sorted.
- **Job vs personal is a hard boundary** at `Projects/job` and `Documents/Job`. Separate:
  - git identity (`includeIf "gitdir:~/Projects/job/"` → work `user.email`),
  - cloud-sync (job accounts never touch personal sync),
  - backup encryption keys (job data encrypted with employer-approved tooling, not your personal key),
  - Shesh permissions (the agent is **denied** write to `~/Documents/Job` and `~/Projects/job` by default).
- **One `Media/` root** instead of XDG's Pictures/Music/Videos split — easier for the organizer and
  for queries like "find that screenshot". Set XDG dirs to point here (or symlink).
- **`AI/` is one big, snapshot-excluded tree.** Models and datasets are regenerable and huge; never
  let them bloat btrfs snapshots or restic backups.
- **`Notes/` is a git-backed vault** — versioned, diffable, queryable by Shesh RAG.

---

## 3. XDG + environment variables

Put this in `dots/.config/environment.d/99-shesh.conf` (systemd environment generator, works across
Hyprland/Quickshell/SSH):

```ini
# XDG base
XDG_CONFIG_HOME=%h/.config
XDG_DATA_HOME=%h/.local/share
XDG_CACHE_HOME=%h/.cache
XDG_STATE_HOME=%h/.local/state

# Project roots (consumed by smart-organizer, Shesh, shell aliases)
PROJECTS_HOME=%h/Projects
JOB_HOME=%h/Projects/job
PERSONAL_HOME=%h/Projects/personal
LABS_HOME=%h/Projects/labs
AI_HOME=%h/AI
VAULT_HOME=%h/Vaults

# AI caches redirected out of snapshot/backup paths
HF_HOME=%h/AI/Weights-Cache/huggingface
OLLAMA_MODELS=%h/AI/Models/ollama
TRANSFORMERS_CACHE=%h/AI/Weights-Cache/huggingface/hub

# Prefer the Gen5 disk later:
# PROJECTS_HOME=/mnt/gen5/Projects
```

Then `systemctl --user import-environment` or relog.

### Git identity separation

`~/.gitconfig`:
```ini
[user]
    name = Gagan Jain
    email = gagan.jain.se@gmail.com
[init]
    defaultBranch = main
[includeIf "gitdir:~/Projects/job/"]
    path = ~/.config/git/job.gitconfig
[url "git@github.com-work:"]
    insteadOf = https://github.com/<work-org>/
```
`~/.config/git/job.gitconfig` holds the work email + work SSH host alias. This guarantees you never
commit personal identity to job repos (and vice versa) — a real risk when juggling both.

---

## 4. The directory bootstrap script

Save as `tools/setup-dirs.sh` in the repo and run once after first boot. It is **idempotent** (safe to
re-run) and sets permissions. (A copy is also written to the repo by the doc build.)

```bash
#!/usr/bin/env bash
# tools/setup-dirs.sh — create the Shesh home layout. Idempotent.
set -euo pipefail

home="${HOME}"
mkdir -p "$home"/{Desk,Downloads/{Archives,Installers,Torrents,Unsorted},Notes/{Daily,Tech,Ideas,Meetings,Shesh}}

# Documents
mkdir -p "$home"/Documents/{Personal/{Finance,Government-ID,Medical,Travel},Job,Reference,Inbox}

# Media
mkdir -p "$home"/Media/{Images,Screenshots,Wallpapers,Music,Videos,Camera,Design}

# Projects
mkdir -p "$home"/Projects/{job,personal,labs,forks,_archive}

# AI (large — mark nocow for btrfs to avoid CoW overhead on model files)
mkdir -p "$home"/AI/{Models,Datasets,Vectors,Weights-Cache,Sessions}
command -v chattr >/dev/null && chattr +C "$home/AI/Models" "$home/AI/Datasets" 2>/dev/null || true

# Vaults & backups
mkdir -p "$home"/Vaults/{Passwords,Keys} "$home"/Backups/{external,nas,restic-repo}

# XDG state
mkdir -p "$home"/.local/share "$home"/.config "$home"/.cache "$home"/.local/state

# Permissions for secrets
chmod 700 "$home/Vaults" "$home/Vaults/Keys"

echo "✅ Shesh directory structure created under $home"
```

> **btrfs + CoW:** `chattr +C` on `AI/Models` and `AI/Datasets` disables copy-on-write for those
> huge files (better write performance, no fragmentation); snapshot them anyway only if you want, but
> they're regenerable.

---

## 5. Backup & snapshot policy

| Data | Snapshot (btrfs) | Local backup (restic) | Offsite/cloud | Encryption |
|------|------------------|-----------------------|---------------|------------|
| `Documents/Personal` | hourly/daily | ✅ external | ✅ rclone→cloud | restic repo key |
| `Documents/Job` | ❌ (per employer policy) | ✅ employer tool only | employer-approved only | employer key |
| `Projects/personal` | hourly | ✅ | ✅ (GitHub + restic) | restic |
| `Projects/job` | ❌ | employer tool only | employer only | employer |
| `Notes` | hourly | ✅ | ✅ git remote | git + restic |
| `AI/Models`, `Datasets` | ❌ | ❌ | ❌ (regenerable) | — |
| `Vaults/Keys` | ❌ never snapshot | ❌ never auto | manual LUKS offline copy only | LUKS |
| `.config`, `.local/share` | daily | ✅ | ✅ | restic |
| `Downloads`, `.cache` | ❌ | ❌ | ❌ | — |

Restic excludes file should skip: `AI/`, `.cache/`, `Downloads/`, `node_modules/`, `target/`,
`__pycache__/`, `.venv/`, `*.gguf`, `*.safetensors`.

---

## 6. Dotfiles management

The repo already uses the `dots/` tree + `setup` (rsync/cp with auto-backup). Recommended hardening:

- Adopt a **bare git repo / GNU stow** approach for anything you want to version precisely:
  `git init --bare $HOME/.cfg` (the "bare dotfiles" pattern) so `~` is never itself a git repo.
- Keep machine-specific overrides in `~/.config/hypr/custom/*.lua` (already provided) and in
  `profiles/msi-sword-cachyos/` for system-level files.
- Never commit `Vaults/`, `.ssh/`, `*.kdbx`, cloud tokens, or Newelle/LLM API keys. Add to a global
  `.gitignore` (the repo `.gitignore` should include `.env`, `*.secret`, `config.toml` with keys).
- Symlink `~/.config` into the repo's `dots/.config` via the installer; keep an `INSTALLED_LISTFILE`
  so uninstall can revert (this is the feature `3.files.sh` already attempts — make it robust).

---

## 7. Integration points for the other docs

- **Smart-organizer** watches `Desk`, `Downloads`, `Documents/Inbox`, `Media/Screenshots` and sorts
  into the folders above using `rules.toml`. It is **forbidden** (via `safety.sh`) to touch
  `Projects/`, `Vaults/`, `Documents/Job`, `.ssh`, `.gnupg`, `.config`.
- **Shesh** gets a permission profile (in Newelle's per-file permissions + your MCP policy):
  read-only for `Documents/Personal`, `Notes`, `Projects/personal`; write only to `Downloads`,
  `Documents/Inbox`, `AI/Sessions`; **deny** on `Documents/Job`, `Projects/job`, `Vaults`.
- **Backup tool** reads the policy table in §5 to decide what to snapshot/back up.
