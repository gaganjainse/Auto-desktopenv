# Smart Organizer

Intelligent systemwide file organization and cleanup tool.

## Features

- **File Classification**: Automatic categorization by extension, path, and content
- **Cleanup**: Cache, trash, bloat, old installers, browser caches
- **Media Organization**: Pictures, videos, music, documents sorting
- **Folder Operations**: Create, merge, split, dedupe
- **Heuristics**: Age, size, type, and path-based scoring
- **Safety**: Protected paths, dry-run mode, backups
- **Systemd Integration**: Watch mode as a user service

## Usage

### Basic Usage
```bash
# Dry run (safe preview)
smart-organizer --dry-run

# Run all modes
smart-organizer

# Specific modes
smart-organizer --clean
smart-organizer --organize
smart-organizer --folders

# Specific targets
smart-organizer --organize ~/Downloads
smart-organizer --clean system
```

### Options
| Option | Description |
|--------|-------------|
| `--dry-run` | Show what would be done without making changes |
| `--once` | Run once and exit |
| `--watch` | Continuously watch for changes |
| `--clean` | Run cleanup mode (cache, trash, bloat) |
| `--organize` | Run organization mode (sort files) |
| `--folders` | Run folder operations (merge, split, dedupe) |
| `--all` | Run all modes (default) |
| `--help` | Show help |

### Targets
- Default: `~/Downloads ~/Documents ~/Pictures ~/Videos ~/Music ~/Desktop`
- `system` - Systemwide cleanup
- Any path - Specific directory

## File Categories

| Category | Extensions | Target Directory |
|----------|-----------|------------------|
| Documents | pdf, doc, docx, txt, md, csv, json, xml | ~/Documents |
| Images | jpg, png, gif, svg, webp, heic, raw | ~/Pictures |
| Videos | mp4, mkv, avi, mov, webm | ~/Videos |
| Music | mp3, flac, wav, aac, ogg, m4a, opus | ~/Music |
| Archives | zip, rar, 7z, tar, gz, xz, zst, iso | ~/Archives |
| Code | py, js, ts, sh, rs, go, c, cpp, java, etc. | ~/Workspace |
| Installers | exe, msi, appimage, deb, rpm, dmg | ~/Downloads/Installers |
| Fonts | ttf, otf, woff, woff2 | ~/.local/share/fonts |
| Data | db, sqlite, parquet, csv, pkl, h5 | ~/Datasets |

## Cleanup Rules

### Cache Cleanup
- Location: `~/.cache`, `~/.config`, `~/.local/share`
- Age: Older than 30 days
- Size limit: Files under 100MB
- Protected: Credentials, SSH, GPG, passwords

### Trash Cleanup
- Locations: `~/.local/share/Trash`, `~/.trash`
- Age: Older than 30 days

### Bloat Cleanup
- Old logs (>30 days)
- Package caches (pacman, yay, pip, npm, cargo)
- Old installers (>90 days)
- Thumbnails (>30 days)
- Browser caches (>7 days)
- Empty directories

## Heuristic Scoring

Files are scored based on:
- **Age**: Older files score higher (more likely to be stale)
- **Size**: Larger files are more important to organize
- **Category**: Archives and installers score higher for cleanup
- **Path**: Downloads and temp directories score higher

Actions based on score:
- >50: Delete
- >30: Archive
- <=30: Keep

## Protected Paths

The following paths are never modified:
- `~/.ssh`, `~/.gnupg`, `~/.password-store`
- `~/.aws`, `~/.docker`, `~/.kube`
- `~/.config/git`, `~/.config/nvim`, `~/.config/hypr`
- `~/Workspace`, `~/Projects`, `~/Models`, `~/Datasets`
- `/etc`, `/usr`, `/var`, `/boot`, `/root`

## Folder Operations

### Merge
- Combines duplicate folders
- Handles file conflicts with suffix numbering
- Preserves both versions when files differ

### Split
- Splits oversized folders (>50 files by default)
- Creates numbered subfolders: `part_1`, `part_2`, etc.

### Dedupe
- Finds duplicate files by SHA256 hash
- Keeps first occurrence, removes duplicates

## Systemd Service

Watch mode can run as a systemd user service:
```bash
systemctl --user enable --now smart-organizer
systemctl --user status smart-organizer
```

Service file location: `~/.config/systemd/user/smart-organizer.service`
