# jk3s

A small, reusable tool to provision **one Raspberry Pi 5 (NVMe/PCIe boot)** into a trimmed single-node k3s Kubernetes cluster and expose a service over **https** through a Cloudflare Tunnel — no port-forwarding, no public IP, no inbound firewall holes.

## Layout

Each sub-directory provides a core component to the build, details in each README describe how to use them. They should be executed in this sequence:

1. `setup-hardware`: Purchase and assemble the hardware
1. `bootstrap-host`: Provision RPi OS on the hardware, boot from NVMe/PCIe, configure static LAN IP
1. `bootstrap-k3s`: Provision k3s on RPi in stripped down mode
1. `helmfile-base`: Deploy CloudFlared Tunnel and hello world http service

After this sequence of projects is worked. "hello world" content should be available at some `https://example.com` endpoint.

The next step from here is to build a `helmfile-app` project that deploys real software to this K3s cluster. Copy and modify `helmfile-base` as needed to achieve this.

## End-to-end runbook

Do **sp-dev** first and prove it end-to-end before touching prod. Label the two boards now so they don't get swapped.

### Assemble + get it booting from NVMe (the fiddly Pi-5 part)

1. **Assemble:** active cooler + P33 HAT + NVMe on the Pi. **Seat the FPC ribbon firmly at both
   ends** (locking tabs click) — a loose ribbon reads as "drive not detected." Power via the
   **27W USB-C** brick for bring-up (not PoE; never both at once). *(done)*
2. **Flash Raspberry Pi OS Lite (64-bit)** with Raspberry Pi Imager — it's under
   **"Raspberry Pi OS (other)"** (Lite = headless server: less RAM/CPU/attack-surface than the
   desktop image). In Imager's ⚙️ advanced settings preset: **hostname `earth` (from Captain planet, earth/fire/wind/water/heart), enable SSH + your public key, wifi/locale, username.** Flash to the **SD card first** (it's the
   bootloader-update medium).
2. Connect to RPi over SSH via Wifi.
3. **Boot from SD → enable NVMe boot:**
   - `sudo rpi-eeprom-update -a` then `sudo reboot now`
   - `sudo raspi-config` → Advanced → **Boot Order → NVMe/USB Boot**
   - `lsblk` → confirm the NVMe appears. If not: reseat the FPC, then try the ASPM fixes in
     [bootstrap/README.md](bootstrap/README.md).
4. **Clone SD → NVMe (on the Pi, over SSH).** This copies your already-configured system
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
     `findmnt /` → device should be `/dev/nvme0n1p2` (not `mmcblk0`).
   - *(Alternatives: `sudo dd if=/dev/mmcblk0 of=/dev/nvme0n1 bs=4M status=progress conv=fsync`
     then expand root via `sudo raspi-config` → Advanced → Expand Filesystem; or fresh-flash the
     NVMe from a USB-NVMe adapter on your laptop — but then you re-enter the Imager presets.)*
5. **DHCP reservation** at the router: bind the Pi's MAC → a fixed IP (survives reflashes).
  -

### Provision + deploy

6. **Provision the node** — SSH in from your laptop, then: `sudo bootstrap/bin/bootstrap.sh sp-dev`
7. **Pull the kubeconfig** to your laptop (instructions printed by bootstrap).
8. **Create the tunnel** (one-time per box):
   ```
   cloudflared tunnel login
   cloudflared tunnel create sp-dev
   cloudflared tunnel route dns sp-dev japoofis.com
   ```
   Drop the credentials JSON into `helmfile-base/secrets/` (see its README).
9. **Deploy**: `cd helmfile-base && helmfile -e sp-dev apply`
10. **Verify**: open `https://japoofis.com` → "hello world".
11. **Prod**: repeat all steps with `sp-prod` / `mspsolarpunk.com`.

## What's generic vs. what's yours

Everything here is generic, reusable tooling **except** your Cloudflare account binding — the
tunnel credentials and the per-environment domain/tunnel values. See
[helmfile-base/README.md](helmfile-base/README.md) and
[helmfile-base/secrets/README.md](helmfile-base/secrets/README.md) for the externalization TODO
before sharing.

## Status

Scaffold. `TODO` markers flag the bits that need real hardware or real Cloudflare credentials.
