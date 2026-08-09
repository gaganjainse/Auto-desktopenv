# shesha-desktop

**Forked from [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)**

Usability-first Hyprland dotfiles with automated desktop environment setup for Arch-based systems.

## What's Added Beyond Upstream

This fork extends the upstream illogical-impulse dotfiles with:

### 🧠 Smart Organizer
Systemwide intelligent file organization and cleanup:
- Automatic file classification by type, extension, and path
- Cache, trash, and bloat cleanup with age-based rules
- Media organization (pictures, videos, music, documents)
- Downloads folder sorting with subdirectory handling
- Folder operations: create, merge, split, dedupe
- Heuristic-based decision making
- Dry-run mode for safety
- Protected paths and files safeguard

### 🎮 MSI MUX Switcher
GPU MUX switch control for MSI laptops:
- Switch between hybrid and dGPU-only modes
- Automatic detection of MSI hardware
- Status checking and display manager restart

### 🚀 Online Bootstrap
One-command fresh install:
```bash
bash <(curl -s https://raw.githubusercontent.com/gaganjainse/shesha-desktop/main/tools/bootstrap.sh)
```

## Quick Start

### Fresh Install (CachyOS/Arch)
```bash
bash <(curl -s https://raw.githubusercontent.com/gaganjainse/shesha-desktop/main/tools/bootstrap.sh)
```

### Manual Install
```bash
# Clone repo
git clone https://github.com/gaganjainse/shesha-desktop.git
cd shesha-desktop

# Run installer
./setup install
```

### Smart Organizer
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

### MUX Switcher
```bash
# Check status
sudo mux-switcher status

# Switch to hybrid
sudo mux-switcher hybrid

# Switch to dGPU only
sudo mux-switcher dgpu
```

## Supported Hardware

- **MSI Sword 16 HX B14VEKG** (tested)
- Intel Core i7-14700HX (20C/28T, x86-64-v4)
- NVIDIA RTX 4050 Laptop (6GB)
- Hardware MUX switch

Other MSI laptops with MUX switch should work. Check `sudo mux-switcher status`.

## Directory Structure

```
shesha-desktop/
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

- [Setup Guide](docs/SETUP.md)
- [Smart Organizer](tools/smart-organizer/README.md)
- [MUX Switcher](tools/mux-switcher/README.md)
- [Directory Organization](docs/DIRECTORY-ORGANIZATION.md)

## License

GPL-3.0 — same as upstream [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland).
See [`LICENSE`](LICENSE). Third-party components retain their own licenses; see
[`docs/SHESHA/10_LICENSES_AND_SOURCES.md`](docs/SHESHA/10_LICENSES_AND_SOURCES.md).

## Acknowledgments

- [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) - Base dotfiles
- [illogical-impulse](https://ii.clsty.link) - Original design
