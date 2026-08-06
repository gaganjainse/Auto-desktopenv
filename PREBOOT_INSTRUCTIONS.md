# PRE-BOOT INSTRUCTIONS
## Everything to do BEFORE booting from USB

**Current time:** 2026-08-07 03:13 IST  
**Target:** MSI Sword 16 HX B14VEKG → CachyOS 260628 + dots-hyprland

---

## STEP 1: DOWNLOAD CachyOS ISO

**On your current Ubuntu system:**

```bash
# Create a downloads directory
mkdir -p ~/Downloads/CachyOS

# Download CachyOS 260628 ISO
# Option A: Direct download (if you have the URL)
wget -O ~/Downloads/CachyOS/CachyOS-260628.iso "https://download.cachyos.org/CachyOS-Server-260628-x86_64.iso"

# Option B: If you already have the ISO downloaded elsewhere, copy it
cp /path/to/your/CachyOS-260628.iso ~/Downloads/CachyOS/
```

**Verify the download:**
```bash
# Check file size (should be ~2-4 GB)
ls -lh ~/Downloads/CachyOS/

# Verify ISO integrity (if you have the checksum)
sha256sum ~/Downloads/CachyOS/CachyOS-260628.iso
```

---

## STEP 2: PREPARE USB DRIVE

**Requirements:**
- 8GB+ USB drive (minimum 8GB, 16GB+ recommended)
- All data on USB will be **permanently erased**

**Find your USB device:**
```bash
# List all block devices
lsblk

# Or more detailed
sudo fdisk -l

# Identify your USB drive (usually /dev/sdb, /dev/sdc, etc.)
# Look for:
# - Size matches your USB drive (8GB, 16GB, etc.)
# - Type: disk
# - Mountpoint: may show as /media/... or nothing
```

**Example output:**
```
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda      8:0    0 238.5G  0 disk 
├─sda1   8:1    0   512M  0 part /boot/efi
├─sda2   8:2    0   128M  0 part /boot
└─sda3   8:3    0 237.9G  0 part /
sdb      8:16   1  14.9G  0 disk /media/gagan/USB
```

In this example, USB is `/dev/sdb` (not `/dev/sdb1` — use the disk, not partition).

**Unmount the USB drive:**
```bash
# Replace /dev/sdX with your USB device
sudo umount /dev/sdX* 2>/dev/null || true
```

**Flash ISO to USB:**
```bash
# WARNING: This will erase ALL data on the USB drive
# Double-check the device path before running!

sudo dd if=~/Downloads/CachyOS/CachyOS-260628.iso of=/dev/sdX bs=4M status=progress oflag=sync

# After dd completes:
sync
```

**Verify USB is ready:**
```bash
# Check USB is present
lsblk

# You should see your USB drive listed
```

---

## STEP 3: BACKUP IMPORTANT DATA

**Before proceeding, backup:**
- [ ] SSH keys: `~/.ssh/` → copy to phone/encrypted USB
- [ ] Important documents: `~/Documents/`
- [ ] Photos: `~/Pictures/`
- [ ] Any local environment configs you want to preserve

**Quick backup commands:**
```bash
# Backup to external drive (if you have one)
sudo mount /dev/sdb1 /mnt/backup
rsync -av --progress ~/.ssh /mnt/backup/ssh-backup/
rsync -av --progress ~/Documents /mnt/backup/documents-backup/
rsync -av --progress ~/Pictures /mnt/backup/pictures-backup/
sudo umount /mnt/backup
```

---

## STEP 4: PREPARE CURRENT SYSTEM

**Update Ubuntu before installing:**
```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

**Note down your current system details (optional but helpful):**
```bash
# Check disk layout
sudo fdisk -l

# Check if you have any important data
df -h
```

---

## STEP 5: PREPARE INSTALLATION ENVIRONMENT

**Create installation workspace:**
```bash
mkdir -p ~/Workspace
cd ~/Workspace
```

**Save this guide to your phone:**
- Open GitHub repo on your current system browser
- Navigate to `INSTALLATION_GUIDE.md`
- Save/export as PDF or markdown to your phone
- OR use GitHub mobile app to view offline

**Print/save critical info:**
- [ ] BIOS settings (see below)
- [ ] Bootstrap command: `bash <(curl -s https://raw.githubusercontent.com/gaganjainse/Auto-desktopenv/main/tools/bootstrap.sh)`
- [ ] Username: `gagan`
- [ ] Partition choice: Option A or B
- [ ] Bootloader: Systemd-boot

---

## STEP 6: BIOS SETTINGS CHECKLIST

**Write this down or save to phone:**

```
BIOS SETTINGS FOR MSI SWORD 16 HX B14VEKG
===========================================

1. Enter BIOS: Press Del or F2 during boot
   - Advanced: Alt+RCtrl+RShift then F2

2. Settings to change:
   □ Secure Boot: DISABLED
   □ VT-d: ENABLED
   □ GPU Mode: MSHybrid/Hybrid (NOT Discrete)
   □ Fast Boot: DISABLED
   □ CSM: DISABLED
   □ TPM: Enabled (fTPM)

3. Save and Exit: Press F10
```

**Critical reminders:**
- ⚠️ **DO NOT** set GPU Mode to "Discrete" before installing
- ⚠️ **DO NOT** enable Secure Boot
- ✅ GPU Mode must be **MSHybrid/Hybrid** for installation

---

## STEP 7: VERIFY BOOT ORDER

**Ensure USB boot is enabled:**
```bash
# On Ubuntu, check boot order (optional)
sudo efibootmgr -v
```

**In BIOS:**
- Set USB drive as first boot priority OR
- Use boot menu key (F11 on MSI) during boot

---

## STEP 8: FINAL PRE-BOOT CHECKLIST

**Before shutting down to boot USB:**

- [ ] CachyOS ISO downloaded to `~/Downloads/CachyOS/`
- [ ] USB drive flashed with ISO (8GB+)
- [ ] Important data backed up externally
- [ ] BIOS settings noted/remembered:
  - Secure Boot: Disabled
  - VT-d: Enabled
  - GPU Mode: MSHybrid/Hybrid
  - Fast Boot: Disabled
  - CSM: Disabled
- [ ] Installation guide saved to phone
- [ ] Bootstrap command noted: `bash <(curl -s https://raw.githubusercontent.com/gaganjainse/Auto-desktopenv/main/tools/bootstrap.sh)`
- [ ] Username: `gagan`
- [ ] Partition choice decided: Option A (automatic) or Option B (manual with @models)
- [ ] Bootloader choice: Systemd-boot
- [ ] Current system fully updated and rebooted

---

## STEP 9: BOOT FROM USB

**When ready:**

1. **Shut down completely:**
   ```bash
   sudo shutdown -h now
   ```

2. **Power on and immediately press F11 repeatedly** for boot menu

3. **Select your USB drive** from the boot menu

4. **At CachyOS boot menu, select:**
   ```
   CachyOS with NVIDIA closed-source Driver (latest cards only 900+)
   ```

5. **You should see CachyOS live desktop/environment**

6. **Double-click "Install CachyOS"** to start Calamares

---

## IMPORTANT NOTES

**During installation:**
- You will need internet for `./setup install` step (after first boot)
- The CachyOS ISO itself does not need internet for base install
- Have your WiFi/Ethernet credentials ready for after first boot

**Time estimate:**
- CachyOS install: 10-15 minutes
- First boot + bootstrap: 30-60 minutes
- Total: ~1-2 hours

**If something goes wrong:**
- BTRFS + Snapper allows rollback from boot menu
- Keep the USB drive handy for reinstallation if needed
- All installer steps are logged to `~/Workspace/Auto-desktopenv/`

---

## QUICK REFERENCE CARD

```
PRE-BOOT CHECKLIST:
□ ISO downloaded
□ USB flashed (8GB+)
□ Data backed up
□ BIOS settings noted
□ Guide saved to phone
□ Username: gagan
□ Partition: Option A or B
□ Bootloader: Systemd-boot

BIOS SETTINGS:
□ Secure Boot: OFF
□ VT-d: ON
□ GPU Mode: MSHybrid
□ Fast Boot: OFF
□ CSM: OFF

FIRST BOOT COMMAND:
bash <(curl -s https://raw.githubusercontent.com/gaganjainse/Auto-desktpenv/main/tools/bootstrap.sh)

AFTER REBOOT:
□ Select Hyprland session
□ Run: sudo msi-gpu-switcher status
□ Run: nvidia-smi
□ Run: ollama run qwen2.5:7b
```

---

**You are now ready to proceed with the installation.**

Next: BIOS setup → Boot USB → CachyOS install → First boot → Bootstrap script → Done.
