# CachyOS + shesh-desktop Installation Guide
## MSI Sword 16 HX B14VEKG — Offline Reference

**Copy this file to your phone before starting.**

---

## PRE-INSTALLATION CHECKLIST

- [ ] CachyOS 260628 ISO downloaded
- [ ] 8GB+ USB drive ready
- [ ] Backup any important data from current system
- [ ] Read this entire guide before starting

---

## PHASE 1: BIOS SETUP

**Do this BEFORE booting from USB.**

1. Shut down completely
2. Power on, press **Del** or **F2** immediately
3. Advanced BIOS: press **Alt+RCtrl+RShift** then **F2**

### Critical Settings:

| Setting | Value |
|---------|-------|
| Secure Boot | **Disabled** |
| VT-d | **Enabled** |
| GPU Mode | **MSHybrid/Hybrid** |
| Fast Boot | **Disabled** |
| CSM | **Disabled** |
| TPM | **Enabled (fTPM)** |

⚠️ **DO NOT set GPU Mode to Discrete before installing.**

4. Press **F10** to save and exit

---

## PHASE 2: CREATE BOOTABLE USB

**On your current Ubuntu system:**

```bash
# Flash CachyOS ISO to USB
sudo dd if=/path/to/CachyOS-260628.iso of=/dev/sdX bs=4M status=progress oflag=sync
sync
```

Replace `/dev/sdX` with your USB drive device.

**Verify:**
```bash
# Check USB is mounted
lsblk
# Should show your USB drive
```

---

## PHASE 3: BOOT FROM USB

1. Reboot, press **F11** repeatedly for boot menu
2. Select USB drive
3. At CachyOS boot menu, select:
   ```
   CachyOS with NVIDIA closed-source Driver (latest cards only 900+)
   ```

❌ **DO NOT select:**
- Default "CachyOS" — uses nouveau driver, no CUDA
- Legacy Hardware — no NVIDIA driver
- Memtest86+ — RAM test only

---

## PHASE 4: CachyOS INSTALLATION

### 4.1 Calamares Settings

**Desktop Environment:**
- Select **"No Desktop"**
- Reason: dots-hyprland handles its own dependencies

**Additional Packages:**
- ✅ Check: **Base-devel + Common packages**
- ✅ Check: **CPU specific Microcode update packages** (Intel microcode for your i7-14700HX)
- ❌ Uncheck EVERYTHING else

### 4.2 Partitioning

**Option A: Automatic (Simpler)**
- Select "Erase disk"
- Filesystem: **BTRFS**
- Enable **Snapper** snapshots
- Enable **Encryption (LUKS2)** — optional

Result:
```
/dev/nvme0n1p1: 4 GB FAT32 → /boot
/dev/nvme0n1p2: Remaining → LUKS2 → BTRFS
    ├─ @ → /
    ├─ @home → /home
    ├─ @cache → /var/cache
    ├─ @tmp → /var/tmp
    ├─ @log → /var/log
    └─ @snapshots → /.snapshots
```

**Option B: Manual (Recommended for AI)**

Create partitions:

| Partition | Size | FS | Mount |
|-----------|------|----|-------|
| /dev/nvme0n1p1 | 4 GB | FAT32 | /boot |
| /dev/nvme0n1p2 | 100 GB | BTRFS | @ |
| /dev/nvme0n1p3 | 32 GB | BTRFS | @models |
| /dev/nvme0n1p4 | Remaining | BTRFS | @home |

**fstab entries for manual layout:**
```
UUID=<root-uuid> / btrfs noatime,compress=zstd:1,space_cache=v2,autodefrag,discard=async,subvol=@ 0 0
UUID=<home-uuid> /home btrfs noatime,compress=zstd:1,space_cache=v2,autodefrag,discard=async,subvol=@home 0 0
UUID=<models-uuid> /models btrfs noatime,compress=zstd:1,space_cache=v2,autodefrag,discard=async,subvol=@models 0 0
```

### 4.3 Bootloader
- Select **Limine** (the default in your Calamares)
- The installer will automatically add the required NVIDIA kernel parameters to the Limine entry
- **Refind** also works if you prefer it
- **GRUB** works too, but Limine is simpler for BTRFS setups

### 4.4 User Setup
- Username: **gagan**
- Set password
- Enable automatic login: **optional**

### 4.5 Install
- Review settings
- Click **Install Now**
- Wait 10-15 minutes
- Reboot when done

---

## PHASE 5: FIRST BOOT

1. At TTY login, log in as `gagan`
2. **Verify network:**
   ```bash
   ping -c 3 archlinux.org
   ```
3. **Verify GPUs:**
   ```bash
   lspci | grep -i vga
   # Should show: Intel UHD Graphics + NVIDIA RTX 4050
   ```
4. **STOP HERE.** Do not install anything else manually.

---

## PHASE 6: RUN BOOTSTRAP

**Run this command exactly:**

```bash
bash <(curl -s https://raw.githubusercontent.com/gaganjainse/shesh-desktop/main/tools/bootstrap.sh)
```

**If curl fails, try:**
```bash
curl -fsSL https://raw.githubusercontent.com/gaganjainse/shesh-desktop/main/tools/bootstrap.sh | bash
```

### What bootstrap does:
1. Checks not running as root
2. Checks sudo is available
3. Checks network connectivity
4. Confirms OS is CachyOS/Arch
5. Runs `sudo pacman -Syu` (full system update)
6. Installs: git, curl, wget, base-devel, yay, inotify-tools, python, python-pip, go, rustup
7. Clones repo to `~/Workspace/shesh-desktop`
8. Runs `./setup install`

**You will be prompted for sudo password multiple times.**

---

## PHASE 7: WHAT ./setup install DOES AUTOMATICALLY

### 7.1 Dependencies
- Removes deprecated packages
- Installs all dots-hyprland dependencies
- Installs AUR packages via yay

### 7.2 System Setup
- Creates `i2c` group if missing
- Adds user to `video`, `i2c`, `input` groups
- Enables Bluetooth service

### 7.3 MUX Switcher
- Detects MSI laptop
- Installs `msi-mux-switcher` to `~/.local/bin/`

### 7.4 NVIDIA + MUX Setup
- Installs: `nvidia-dkms`, `linux-cachyos-headers`, `nvidia-utils`, `lib32-nvidia-utils`, `nvidia-prime`
- Patches `/etc/mkinitcpio.conf`:
  ```
  MODULES=(i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm)
  ```
- Rebuilds initramfs: `mkinitcpio -P`
- Adds bootloader kernel parameters:
  ```
  nvidia-drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1
  ```
- Creates udev rules for stable GPU paths:
  - `/etc/udev/rules.d/igpu-device-path.rules`
  - `/etc/udev/rules.d/dgpu-device-path.rules`
- Creates Hyprland mode configs:
  - `~/.config/hypr/config/modes/hybrid.lua`
  - `~/.config/hypr/config/modes/dgpu.lua`
  - `~/.config/hypr/config/modes/igpu.lua`
- Installs `/usr/local/bin/nvidia-run`

### 7.5 AI/ML Stack
- Installs: `cuda`, `cudnn`, `ollama`, `ollama-cuda`, `python`, `python-pip`
- Enables `ollama.service`
- Installs PyTorch (CUDA 12.8)
- Installs: `transformers`, `datasets`, `accelerate`, `huggingface-hub`, `chromadb`, `langchain`

### 7.6 Power Management
- Installs `power-profiles-daemon`
- Enables service
- Sets balanced profile
- Enables ZRAM

### 7.7 Smart Organizer
- Installs to `~/.local/bin/smart-organizer`
- Installs config to `~/.config/smart-organizer/`
- Creates systemd user service (watch mode)
- Creates systemd user timer (every 1 hour)
- Creates backup timer (weekly)
- Creates maintenance timer (weekly)

### 7.8 Config Files
- Copies dots-hyprland configs to `~/.config/`

---

## PHASE 8: FIRST REBOOT

```bash
sudo reboot
```

At login screen, select **"Hyprland"** session.

---

## PHASE 9: POST-INSTALL VERIFICATION

### 9.1 Check MUX Status
```bash
sudo msi-gpu-switcher status
```

### 9.2 Verify NVIDIA
```bash
nvidia-smi
# Should show RTX 4050 with driver version
```

### 9.3 Test GPU Modes
```bash
# Test hybrid mode (default)
prime-run glxinfo | grep "OpenGL renderer string"
# Should show: NVIDIA RTX 4050

# Test dGPU mode
sudo msi-gpu-switcher dgpu
sudo reboot
# After reboot:
glxinfo | grep "OpenGL renderer string"
# Should show: NVIDIA RTX 4050

# Switch back to hybrid
sudo msi-gpu-switcher hybrid
sudo reboot
```

### 9.4 Test Ollama
```bash
ollama pull qwen2.5:7b
ollama run qwen2.5:7b
```

### 9.5 Test Smart Organizer
```bash
# Dry run first
smart-organizer --dry-run

# Run cleanup
smart-organizer --clean system
```

### 9.6 Check Services
```bash
systemctl --user status smart-organizer
systemctl --user list-timers | grep smart-organizer
systemctl --user list-timers | grep backup
systemctl --user list-timers | grep maintenance
```

---

## ESSENTIAL COMMANDS REFERENCE

### GPU/MUX
```bash
sudo msi-gpu-switcher status      # Check current mode
sudo msi-gpu-switcher hybrid      # Switch to hybrid
sudo msi-gpu-switcher dgpu        # Switch to dGPU
sudo msi-gpu-switcher igpu        # Switch to iGPU
```

### GPU Verification
```bash
nvidia-smi                         # Check NVIDIA driver
prime-run glxinfo | grep NVIDIA    # Test NVIDIA rendering
glxinfo | grep "OpenGL renderer"   # Check active GPU
```

### NVIDIA Apps
```bash
nvidia-run <app>   # Custom wrapper with full NVIDIA env
prime-run <app>    # Built-in PRIME wrapper
```

### Smart Organizer
```bash
smart-organizer --dry-run          # Preview changes
smart-organizer --clean system     # Clean systemwide
smart-organizer --once --all       # Run all modes once
smart-organizer --watch            # Continuous watch mode
```

### System
```bash
sudo pacman -Syu                   # Full system update
powerprofilesctl set balanced      # Set power profile
powerprofilesctl set power-saver   # Battery saving
ollama list                         # List installed models
```

---

## TROUBLESHOOTING

### NVIDIA Driver Not Loading
```bash
sudo dkms autoinstall
sudo dkms status | grep nvidia
sudo reboot
```

### Black Screen After Boot
```bash
# Check mkinitcpio.conf
grep "MODULES" /etc/mkinitcpio.conf
# Should show: MODULES=(i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm)

# Rebuild if wrong
sudo mkinitcpio -P
sudo reboot
```

### Suspend/Resume Broken
```bash
# Check kernel parameter
cat /proc/cmdline | grep "NVreg_PreserveVideoMemoryAllocations"
# Should show: nvidia.NVreg_PreserveVideoMemoryAllocations=1
```

### MUX Switcher Fails
```bash
# Check EC module
lsmod | grep ec_sys
# If not loaded:
sudo modprobe ec_sys write_support=1
```

### Black Screen After dGPU Switch
- Disconnect all external monitors
- Boot with external monitors disconnected
- Reconnect after boot

### Ollama GPU Not Detected
```bash
# Verify NVIDIA works
nvidia-smi

# Check Ollama service
sudo systemctl status ollama

# Ensure user in groups
sudo usermod -aG video,render $USER
# Logout and back in
```

---

## IMPORTANT FILES AFTER INSTALL

| File/Directory | Purpose |
|----------------|---------|
| `~/.config/hypr/config/` | Hyprland configuration |
| `~/.config/hypr/config/modes/` | GPU mode configs |
| `~/.config/smart-organizer/` | Smart Organizer config |
| `~/.local/bin/smart-organizer` | Smart Organizer script |
| `~/.local/bin/msi-gpu-switcher` | MUX switcher |
| `/usr/local/bin/nvidia-run` | NVIDIA wrapper script |
| `/.snapshots/` | BTRFS snapshots |
| `~/Workspace/shesh-desktop/` | This repo |

---

## DIRECTORY STRUCTURE

```
/home/gagan/
├── Workspace/          # Git repos
│   ├── shesh-desktop/
│   ├── shesh-kernel/
│   ├── SheshAOS/
│   └── SheshAOS/
├── Projects/           # Non-Git projects
├── Models/             # AI models
│   ├── ollama/         # Symlink
│   ├── huggingface/
│   └── checkpoints/
├── Datasets/           # Training data
│   ├── raw/
│   ├── processed/
│   └── experiments/
├── Documents/          # Personal docs
├── Downloads/          # Temporary downloads
├── Pictures/           # Images
├── Videos/             # Videos
├── Music/              # Audio
├── .ssh/               # SSH keys
└── .config/            # App configs
```

---

## POST-INSTALL CHECKLIST

- [ ] Restore SSH keys from phone backup
- [ ] Re-clone GitHub repos to `~/Workspace/`
- [ ] Configure Hyprland monitors/keybinds
- [ ] Test MUX switching
- [ ] Test PRIME Offload
- [ ] Install dev tools (neovim, etc.)
- [ ] Test Ollama with CUDA
- [ ] Configure power profiles
- [ ] Run `smart-organizer --dry-run`
- [ ] Setup backup strategy

---

## NOTES

- **Reboot required** after NVIDIA driver installation
- **Reboot required** after MUX mode switch
- First boot may take 2-3 minutes while rebuilding caches
- Ollama models are stored in `~/.ollama/` by default
- BTRFS snapshots are accessible from the boot menu (Limine/Refind)
- Smart Organizer runs automatically every 1 hour via systemd timer

---

## SUPPORT

- Repo: https://github.com/gaganjainse/shesh-desktop
- Guide: `/home/gagan/Downloads/CachyOS-Installation-Guide.md`
- Issues: https://github.com/gaganjainse/shesh-desktop/issues

---

**Good luck with the installation!**
