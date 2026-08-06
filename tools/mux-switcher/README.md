# MUX Switcher

MSI Laptop GPU MUX Switch Control tool.

## Supported Hardware

- MSI Sword 16 HX B14VEKG (tested)
- Other MSI laptops with hardware MUX switch

## Usage

```bash
# Check current mode
sudo mux-switcher status

# Switch to hybrid mode (iGPU + dGPU)
sudo mux-switcher hybrid

# Switch to dGPU-only mode (maximum performance)
sudo mux-switcher dgpu

# Restart display manager after switching
sudo mux-switcher restart
```

## Modes

### Hybrid Mode
- Uses both iGPU and dGPU
- Better battery life
- Suitable for browsing, office work, coding

### dGPU Mode
- Uses only NVIDIA dGPU
- Maximum performance
- Higher power consumption
- Suitable for gaming, AI/ML, video editing

## Display Managers

The `restart` command supports:
- GDM (GNOME)
- SDDM (KDE)
- LightDM
- Ly

## Installation

Automatically installed by `./setup install` on MSI laptops.

Manual installation:
```bash
ln -sf /path/to/mux-switcher.sh ~/.local/bin/mux-switcher
```

## Detection

The script automatically detects MSI laptops via DMI:
```bash
grep -qi "MSI" /sys/class/dmi/id/sys_vendor
```

## Troubleshooting

### Mode not switching
1. Ensure you're running as root (sudo)
2. Check if `msi-gpu-switcher` is installed
3. Verify `/sys/kernel/debug/vgaswitcheroo/switch` exists

### Display manager not restarting
Manually restart your display manager:
```bash
sudo systemctl restart gdm    # GNOME
sudo systemctl restart sddm   # KDE
sudo systemctl restart lightdm  # LightDM
```

### Black screen after switching
1. Switch back to hybrid mode
2. Restart display manager
3. Check Hyprland logs: `journalctl --user -u hyprland`
