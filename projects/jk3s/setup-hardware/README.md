# About

This project begins at the component acquisition stage and ends at the point when an RPi with NVMe/PCIe + SD card can be plugged in for the first time.

# Bill of Materials

RPi5: https://www.microcenter.com/product/702590/raspberry-pi-5

52Pi P33 M.2 NVME M-KEY PoE Hat w/ Official Pi 5 Active Cooler for RPi 5: https://www.microcenter.com/product/698687/52pi-p33-m2-nvme-m-key-poe-hat-w-official-pi-5-active-cooler-for-rpi-5

Inland TN320 256GB SSD NVMe PCIe Gen 3.0x4 M.2 2280 3D NAND TLC Internal Solid State Drive: https://www.microcenter.com/product/661858/TN320_256GB_SSD_NVMe_PCIe_Gen_30x4_M2_2280_3D_NAND_TLC_Internal_Solid_State_Drive?_gl=1*anx1on*_gcl_au*MTQ0Nzk1OTQ4Ni4xNzgyODQxNzc5*_ga*MjA1MDQyOTkyNS4xNzcxODExMTc2*_ga_CSBPEX4VCV*czE3ODI5MjI2ODkkbzE0JGcxJHQxNzgyOTIyNzQwJGo5JGwxJGgxMDUzODg1OTg1

> **Heads-up on the TN320 — this drive is DRAM-less/HMB.** On the Pi 5 PCIe link it can stall under
> write load and remount root read-only (this took `earth` down mid-deploy — see
> [bootstrap-k3s/README.md → NVMe stability](../bootstrap-k3s/README.md#nvme-stability)). `bootstrap.sh`
> now auto-applies the stability flags that mitigate it, and `bin/nvme-recon.sh` diagnoses it if it
> recurs — but the *durable* fix is a **DRAM-equipped NVMe** (or a USB3 SSD). We're knowingly staying on
> the TN320 for this build; that section is the escalation path if the flags don't hold.

Domains via Cloudflare

Official RPi 27W USB-C Power supply

microSD > 16Gb

# Steps

1. **Assemble:** active cooler + HAT + NVMe on the Pi. **Seat the FPC ribbon firmly at both
   ends** (locking tabs click) — a loose ribbon reads as "drive not detected." Power via the
   **27W USB-C** brick for bring-up (not PoE; never both at once). *(done)*
1. **Flash Raspberry Pi OS Lite (64-bit)** with Raspberry Pi Imager — it's under
   **"Raspberry Pi OS (other)"** (Lite = headless server: less RAM/CPU/attack-surface than the
   desktop image). In Imager's ⚙️ advanced settings preset: **hostname `earth` (from Captain planet, earth/fire/wind/water/heart), enable SSH + your public key, wifi/locale, username.** Flash to the **SD card first** (it's the
   bootloader-update medium).
1. Connect to RPi over SSH via Wifi.
1. **Boot from SD → enable NVMe boot:**
   - `sudo rpi-eeprom-update -a` then `sudo reboot now`
   - `sudo raspi-config` → Advanced → **Boot Order → NVMe/USB Boot**
   - `lsblk` → confirm the NVMe appears. If not: reseat the FPC, then try the ASPM fixes in
     [bootstrap-k3s/README.md → NVMe stability](../bootstrap-k3s/README.md#nvme-stability).
   - Don't reboot yet, we'll clone the SD card over to NVMe
1. **Clone SD → NVMe (on the Pi, over SSH).** This copies your already-configured system
   (hostname `earth`, SSH key, wifi) onto the NVMe — nothing to re-enter. Headless Lite has no GUI
   SD-Card-Copier, so use `rpi-clone`:
   - Confirm the disks: `lsblk` → SD is `mmcblk0`, the NVMe is `nvme0n1`.
   - Install the **maintained** fork (the original `billw2` one is abandoned and makes a
     non-bootable clone on Pi 5 / Bookworm — wrong PARTUUID in cmdline.txt):
     ```
     sudo apt-get update && sudo apt-get install -y git rsync
     git clone https://github.com/geerlingguy/rpi-clone.git
     sudo cp rpi-clone/rpi-clone /usr/local/sbin/
     ```
   - Clone (partitions + rsyncs the live system + resizes to fill the NVMe + fixes PARTUUIDs):
     ```
     sudo rpi-clone nvme0n1
     ```
   - **Shut down, remove the SD, power back on.** Verify it booted from NVMe:
     `sudo shutdown now`, remove SD, unplug and plug in
     `findmnt /` → device should be `/dev/nvme0n1p2` (not `mmcblk0`).
1. **DHCP reservation with your home Router** at the router: bind the Pi's MAC → a fixed IP (survives reflashes).

# Done Criteria

1. Can ssh into the RPi like this: `ssh -i ~/.ssh/<some_key> <some_user>@<some_ip>`
1. `findmnt /` shows RPi is booting from NVMe
1. `nslookup <hostname>` returns the DHCP reservation to keep its IP static
