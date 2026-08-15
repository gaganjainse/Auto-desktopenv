# shesh-desktop

![Hyprland](https://img.shields.io/badge/Hyprland-0.55-58e1ff)
![Quickshell](https://img.shields.io/badge/Quickshell-QML-7c3aed)
![OS](https://img.shields.io/badge/OS-CachyOS-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-blue) ![CI](https://github.com/gaganjainse/shesh-desktop/actions/workflows/arch-test.yml/badge.svg)

- **License:** GPL-3.0-or-later (same as upstream end-4/dots-hyprland)
- **Owner:** Gagan Jain ([@gaganjainse](https://github.com/gaganjainse))
- **Target:** CachyOS · Hyprland ≥0.55 · Quickshell (MSI Sword 16 HX)

**Forked from [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)**

Usability-first Hyprland dotfiles with automated desktop environment setup for Arch-based systems.

## What's added beyond upstream

This fork extends the upstream illogical-impulse dotfiles with:

### Smart organizer

Systemwide intelligent file organization and cleanup:
- Automatic file classification by type, extension, and path
- Cache, trash, and bloat cleanup with age-based rules
- Media organization (pictures, videos, music, documents)
- Downloads folder sorting with subdirectory handling
- Folder operations: create, merge, split, dedupe
- Heuristic-based decision making
- Dry-run mode for safety
- Protected paths and files safeguard

### MSI MUX switcher

GPU MUX switch control for MSI laptops:
- Switch between hybrid and dGPU-only modes
- Automatic detection of MSI hardware
- Status checking and display manager restart

### Online bootstrap

One-command fresh install:
```bash
bash <(curl -s https://raw.githubusercontent.com/gaganjainse/shesh-desktop/main/tools/bootstrap.sh)
```
 **Before you start:** read the offline install references —
[INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md) (BIOS → CachyOS → desktop, step by step) and
[PREBOOT_INSTRUCTIONS.md](PREBOOT_INSTRUCTIONS.md) (everything to do before booting the USB).
Compiled fleet docs: [shesh-docs](https://github.com/gaganjainse/shesh-docs).

## Quick start
### Fresh install (CachyOS/Arch)

```bash
bash <(curl -s https://raw.githubusercontent.com/gaganjainse/shesh-desktop/main/tools/bootstrap.sh)
```

### Manual install

```bash
# Clone repo

git clone https://github.com/gaganjainse/shesh-desktop.git
cd shesh-desktop

# Run installer

./setup install
```

### Smart organizer

```bash
# Dry run

smart-organizer --dry-run

# Clean system

smart-organizer --clean system

# Organize downloads

smart-organizer --organize ~/Downloads

# Watch mode

smart-organizer --watch

# As systemd service

systemctl --user enable --now smart-organizer
```

### MUX switcher

```bash
# Check status

sudo mux-switcher status

# Switch to hybrid

sudo mux-switcher hybrid

# Switch to dGPU only

sudo mux-switcher dgpu
```

## Supported hardware

- **MSI Sword 16 HX B14VEKG** (tested)
- Intel Core i7-14700HX (20C/28T, x86-64-v4)
- NVIDIA RTX 4050 Laptop (6GB)
- Hardware MUX switch

Other MSI laptops with MUX switch should work. Check `sudo mux-switcher status`.

## Directory structure

```
shesh-desktop/
├── setup                    # Main installer entry point
├── diagnose                 # Diagnostic tool
├── dots/                    # Core dotfiles
│   ├── .config/             # Application configs
│   └── .local/share/        # Local data
├── dots-extra/              # Extra configs (fonts, swaylock, etc.)
├── sdata/                   # Installer data
│   ├── lib/                 # Shared installer functions
│   ├── dist-*/              # Distro-specific installers
│   └── subcmd-*/            # Installer subcommands
├── tools/
│   ├── smart-organizer/     # Intelligent file organizer
│   │   ├── smart-organizer.sh
│   │   └── lib/             # Core libraries
│   ├── mux-switcher/        # MSI GPU MUX control
│   │   └── mux-switcher.sh
│   └── bootstrap.sh         # Online fresh-install script
├── licenses/
└── README.md
```

## Documentation

- [Setup Guide](setup)
- [Smart Organizer](tools/smart-organizer/README.md)
- [MUX Switcher](tools/mux-switcher/README.md)
- [Directory organisation](docs/SHESH/03_DISK_STRUCTURE.md)

## License

GPL-3.0 — same as upstream [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland).
See [`LICENSE`](LICENSE). Third-party components retain their own licenses; see
[`docs/SHESH/10_LICENSES_AND_SOURCES.md`](docs/SHESH/10_LICENSES_AND_SOURCES.md).

## Acknowledgments

- [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) - Base dotfiles
- [illogical-impulse](https://ii.clsty.link) - Original design

## Security

Security posture and vulnerability reporting: [canonical ecosystem security
policy](https://github.com/gaganjainse/shesh-ecosystem/blob/main/SECURITY.md).

## Status

CI green. Security: [SECURITY.md](SECURITY.md). Compiled reading:
[shesh-docs](https://github.com/gaganjainse/shesh-docs).
