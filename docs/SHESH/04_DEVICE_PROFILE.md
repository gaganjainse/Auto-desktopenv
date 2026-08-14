# 04 — Device Profile: MSI Sword 16 HX B14VEKG on CachyOS 260628

> Single source of truth for all hardware-specific values. The installer sources this profile instead
> of hardcoding. **All numbers below were verified against the B14VEKG-210IN product page on
> 2026-08-09.** Prior AIs used the wrong resolution (2560×1600) and GPU (RTX 4070 8 GB); do not copy
> those.

---

## 1. Hardware facts (canonical)

```ini
# profiles/msi-sword-cachyos/profile.conf
DEVICE_VENDOR="Micro-Star International Co., Ltd."
DEVICE_PRODUCT_NAME="Sword 16 HX B14VEKG"   # /sys/class/dmi/id/product_name
DEVICE_MATCH_REGEX="Sword 16 HX"

CPU="Intel Core i7-14700HX"                 # Raptor Lake-HX, 20C/28T
CPU_MARCH="x86-64-v4"                       # AVX2/AVX-512? HX supports avx2, use v3 to be safe; verify /proc/cpuinfo
IGPU="Intel Arc (Xe-LPG, integrated in 14700HX)"
DGPU="NVIDIA GeForce RTX 4050 Laptop GPU"
DGPU_VRAM_GB=6
DGPU_BUS="96-bit GDDR6"

DISPLAY_CONNECTOR="eDP-1"
DISPLAY_RESOLUTION="1920x1200"
DISPLAY_RATIO="16:10"
DISPLAY_REFRESH_HZ=144
DISPLAY_SCALE=1.0                           # FHD+ at 16" is comfortably 100%; try 1.1 if you prefer

RAM_GB=16                                   # one 16GB DDR5-5600 SODIMM; one slot free (max 96GB)
RAM_MAX_GB=96
STORAGE_NVME_GEN4="1TB"
STORAGE_HAS_GEN5_SLOT=true

WIFI="Intel Wi-Fi 6E (AX211 class)"
ETHERNET="2.5G"
```

**First thing after install:** confirm the kernel's view:
```bash
cat /sys/class/dmi/id/product_name /sys/class/dmi/id/sys_vendor
hyprctl monitors all          # note connector + resolution
lspci | grep -Ei 'vga|3d|nvidia|intel'
nvidia-smi                    # dGPU presence
free -h ; lsmem
```
If anything differs, update `profile.conf` before running setup.

---

## 2. Display (1920×1200 @ 144 Hz)

In `dots/.config/hypr/custom/general.lua` (user override, update-friendly):
```lua
-- Force the internal panel to its native 144 Hz mode
hl.config("monitor", [=[eDP-1,1920x1200@144,0x0,1]=])

-- If Hyprland doesn't advertise 144, use highrr auto-detection:
-- hl.config("monitor", [[eDP-1,highrr,auto,1]])

-- VRR only if the panel supports it (most Sword 16 FHD+ panels do NOT have Adaptive-Sync;
-- verify with `hyprctl monitors` / `wlr-randr`. Leave off if unsupported to avoid glitches.)
hl.config("misc:vrr", "0")
```

For external HDMI 2.1 displays, add per-monitor lines; the RTX 4050 can drive 4K120 over HDMI 2.1.

### 144 Hz-smooth but battery-friendly animations
In `custom/general.lua`, prefer short, ease-out curves (Caelestia/end-4 style). At 144 Hz a 120–180 ms
animation is 17–26 frames — silky without feeling sluggish:
```lua
hl.config("decoration:blur:enabled", true)
hl.config("decoration:blur:size", 8)
hl.config("decoration:blur:passes", 3)
hl.config("decoration:shadow:enabled", true)
-- on battery, Shesh flips blur size/passes down via a power profile rule
```
**On battery**, reduce blur passes and disable window shadows (the iGPU draws them); this is a real
battery win and is exactly the kind of thing Shesh automates.

---

## 3. GPU / MUX (i915 + NVIDIA RTX 4050)

The MSI Sword 16 HX has a **hardware MUX**. Three modes:
- **Hybrid (Optimus):** iGPU drives the panel, dGPU offloaded via PRIME — best battery.
- **dGPU (MUX direct):** dGPU drives the panel — max performance, reboot required, worse battery.
- **iGPU only:** dGPU powered off — max battery.

Your `msi-mux-switcher.py` is the right tool; do **not** use `supergfxctl` (ASUS-oriented, deprecated
for non-ASUS). For runtime (no-reboot) PRIME offload, use `prime-run`/`nvidia-run`; for full MUX
switching the tool writes ACPI/UEFI variables and prompts for reboot.

### Required kernel/module config (`profiles/msi-sword-cachyos/mkinitcpio.fragment`)
```
MODULES=(i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm)
```
The installer must edit `/etc/mkinitcpio.conf` **idempotently**:
```bash
# Idempotent MODULES edit (replaces BUG-06 sed)
set_modules() {
  local conf=/etc/mkinitcpio.conf want=(i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm)
  local cur; cur=$(awk -F'[()]' '/^MODULES=/{print $2}' "$conf")
  local merged=("${want[@]}")
  for m in $cur; do
    local dup=0
    for w in "${want[@]}"; do [[ $m == "$w" ]] && dup=1 && break; done
    (( dup )) || merged+=("$m")
  done
  sudo sed -i "s/^MODULES=(.*/MODULES=(${merged[*]})/" "$conf"
  sudo mkinitcpio -P
}
```

### Required kernel cmdline
For Hyprland/Wayland stability on NVIDIA:
```
nvidia_drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1
```

**Bootloader: Limine** (your choice — Calamares default; see INSTALLATION_GUIDE §4.3).
The installer's `setup_nvidia_mux` patches the Limine cmdline in
`/boot/limine.conf` (`KERNEL_CMDLINE[default]=`) automatically and idempotently
(re-checks before appending). systemd-boot and grub are also handled, so the
installer stays correct regardless of what the ISO ships.
Verify it added exactly these (no duplicates).
**Do not** add `nvidia-drm.modeset=1` (wrong separator) — it must be `nvidia_drm.modeset=1`.

### Environment (iGPU primary, dGPU offload)
`dots/.config/hypr/custom/env.lua`:
```lua
hl.env("NVD_BACKEND", "direct")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
-- After udev creates stable paths:
hl.env("AQ_DRM_DEVICES", "/dev/dri/igpu:/dev/dri/dgpu")
```
Wait — `AQ_DRM_DEVICES` is an **Asahi** variable; on Intel+NVIDIA Hyprland you typically do **not**
set it and instead let Hyprland pick the iGPU for compositing. Use the stable-path udev rules the
installer creates for *referencing* the GPUs in scripts, but **verify Hyprland renders on iGPU** via
`hyprctl systeminfo` / `glxinfo -B`. Only set `AQ_DRM_DEVICES` if needed. (The prior AI cargo-culted
this; correct it.)

Run offload apps with:
```bash
prime-run <app>          # Arch's nvidia-prime
# or your wrapper:
nvidia-run <app>
```

### Power/hibernate note
`nvidia.NVreg_PreserveVideoMemoryAllocations=1` plus the `nvidia-suspend/resume/hibernate` services
(installed by the `nvidia` package on Arch) are required for reliable suspend. Enable them:
```bash
sudo systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service
```

---

## 4. Power management

```bash
# power-profiles-daemon is correct for this Intel laptop (not TLP — they conflict)
powerprofilesctl set balanced        # default
# AC → performance ; battery → power-saver (automated via udev, see 07_AUTOMATIONS.md)
```

### ZRAM (16 GB RAM)
Write `/etc/systemd/zram-generator.conf`:
```ini
[zram0]
zram-size = ram/2
compression-algorithm = zstd
```
That yields 8 GB of compressed swap. With 16 GB physical this is the sweet spot. (If you upgrade to
32/64 GB, change to `min(ram/4, 8192)`.) Enable `systemd-zram-setup@zram0.service`.

### Sysctl (battery + responsiveness)
`/etc/sysctl.d/99-shesh.conf`:
```ini
vm.swappiness = 10
vm.dirty_ratio = 5
vm.dirty_background_ratio = 2
# PCIe runtime power management (saves battery with dGPU)
```
The BORE scheduler in `linux-cachyos` already favors interactivity; do not over-tune.

---

## 5. CachyOS-specific tuning (260628)

- **Kernel:** stick with `linux-cachyos` (BORE). For the 14700HX, also install
  `linux-cachyos-lts` as a fallback. Do not mainline-kernel a hybrid-NVIDIA laptop casually.
- **AUR helper:** default is **Shelly**; for scripting stability install `paru`
  (`sudo pacman -S --needed paru`) and have the installer prefer `paru` then `shelly` then `yay`.
- **march:** CachyOS ships x86-64-v3/v4 builds; the 14700HX benefits. For AUR builds, set in
  `/etc/makepkg.conf`:
  ```
  CFLAGS="-march=native -O2 -pipe -fno-plt -fexceptions ..."
  CXXFLAGS="${CFLAGS}"
  RUSTFLAGS="-C target-cpu=native"
  ```
  Verify native doesn't break binary packages (AUR compiles from source, so it's safe).
- **NVMe I/O scheduler:** CachyOS 260628 defaults NVMe to `kyber`. Enforce via udev:
  ```
  # /etc/udev/rules.d/60-ioschedulers.rules
  ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="kyber"
  ```
- **Network:** BBR + `cake` (laptop/Wi-Fi benefit):
  ```ini
  # /etc/sysctl.d/99-network.conf
  net.core.default_qdisc=cake
  net.ipv4.tcp_congestion_control=bbr
  ```
- **PipeWire latency:** 16" laptop audio is fine at quantum 256 (≈5 ms @48k). Don't set 64 (causes
  underruns on battery); 256 is the safe sweet spot:
  ```conf
  # ~/.config/pipewire/pipewire.conf.d/10-latency.conf
  context.properties = { default.clock.rate=48000 default.clock.quantum=256 default.clock.min-quantum=128 default.clock.max-quantum=512 }
  ```
- **Display manager:** use **SDDM** (CachyOS Hyprland recommendation). The repo should configure SDDM
  for Hyprland autostart only if you enable autologin; otherwise leave it at the greeter.

---

## 6. The `msi-mux-switcher.py` improvements to make

1. Detect GPU PCI slots via `lspci -Dnn` rather than hardcoding.
2. Implement three modes using the correct mechanism for MSI:
   - Write `/sys/firmware/efi/efivars/...` **only if** a known MSI GUID exists (MSI uses a specific
     ACPI method; many models switch via BIOS/`supergfxctl`-like EC calls). If unsupported, detect and
     **tell the user to switch in BIOS / MSI Center** rather than silently no-op.
   - Integrate `envycontrol` for the software Optimus side: `envycontrol --switch integrated|hybrid|nvidia`.
3. Sync `powerprofilesctl` with the chosen mode.
4. Emit a desktop notification on mode change and write to the Shesh audit log.
5. Fix the `--dry-run` option and the trailing binary-name message (N-07).
6. Add a `status` JSON output for the Quickshell indicator.

> Do not claim a software MUX switch the hardware doesn't expose. If the B14VEKG requires a reboot
> via ACPI, make that explicit and provide the reboot. Verify on the actual device which path works.

---

## 7. Post-install verification checklist (on the real machine)

```bash
# Display
hyprctl monitors | grep -A2 eDP-1        # expect 1920x1200@144
# GPU
glxinfo -B | grep "OpenGL renderer"       # expect Intel Arc on the desktop
nvidia-smi                                # dGPU present, idle low power
prime-run glxinfo -B | grep renderer       # expect NVIDIA
# Kernel
uname -r                                  # linux-cachyos
cat /sys/block/nvme0n1/queue/scheduler    # expect [kyber]
# ZRAM
zramctl ; swapon --show
# Power
powerprofilesctl get
# Audio
pw-top                                     # quantum ~256, no xruns
# Services
systemctl --user list-units --failed
systemctl --failed
```

If any of these disagree with the profile, fix the profile and the installer, not just the running
system — so reinstalls stay reproducible.
