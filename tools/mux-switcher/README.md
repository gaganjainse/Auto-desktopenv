# MUX Switcher

MSI Sword 16 HX B14VEKG GPU MUX Switch Controller.

## Supported Hardware

- **MSI Sword 16 HX B14VEKG** (primary target)
- Other MSI laptops with compatible EC/UEFI MUX interface may work

## Modes

| Mode | Description |
|------|-------------|
| `hybrid` | Intel UHD primary display, NVIDIA available via PRIME Offload |
| `dgpu` | NVIDIA RTX 4050 direct via MUX, no PRIME overhead |
| `igpu` | Intel UHD only, NVIDIA powered off where supported |

## Usage

```bash
sudo python3 tools/mux-switcher/msi-mux-switcher.py status
sudo python3 tools/mux-switcher/msi-mux-switcher.py hybrid
sudo python3 tools/mux-switcher/msi-mux-switcher.py dgpu
sudo python3 tools/mux-switcher/msi-mux-switcher.py igpu
```

### Options
| Flag | Description |
|------|-------------|
| `--dry-run` | Preview changes without applying |
| `--debug` | Enable debug logging |

## Requirements

- Root privileges
- `ec_sys` kernel module with `write_support=1`, or `msi-ec` driver
- `efivarfs` mounted at `/sys/firmware/efi/efivars`
- `debugfs` mounted at `/sys/kernel/debug`

## Notes

- Reboot is required after switching modes
- This uses the existing `msi-mux-switcher` Python implementation with UEFI variable + EC register methods
- Do not use this on non-MSI hardware
