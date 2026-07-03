#!/usr/bin/env bash
#
# jk3s nvme-recon — run from your LAPTOP after a Pi read-only-remount crash (the Pi 5 + DRAM-less
# NVMe outage documented in README.md "NVMe stability" / SPNC-0005). It turns the "FIRST capture the
# evidence" runbook into one command and points you at the right escalation rung.
#
# Do this first: the wedged Pi can't spawn ssh sessions while root is read-only, so `sudo reboot`
# it (or power-cycle) and let it come back. bootstrap.sh enabled the *persistent* journal, so the
# crash boot's kernel log survives — this reads the PREVIOUS boot (`journalctl -b -1`).
#
# Config (env vars) — the same subset bootstrap.sh uses:
#   JK3S_HOST_IP       the Pi fixed LAN IP         e.g. 192.168.50.187
#   JK3S_USERNAME      SSH user on the Pi          e.g. jk3s
#   JK3S_SSH_KEY_PATH  private key to log in with  e.g. ~/.ssh/id_rsa
set -euo pipefail

: "${JK3S_HOST_IP:?set JK3S_HOST_IP (the Pi LAN IP)}"
: "${JK3S_USERNAME:?set JK3S_USERNAME (SSH user on the Pi)}"
: "${JK3S_SSH_KEY_PATH:?set JK3S_SSH_KEY_PATH (private key)}"

KEY="${JK3S_SSH_KEY_PATH/#\~/$HOME}"                          # expand a leading ~

remote() {  # run a command on the Pi over SSH
  ssh -i "$KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
    "${JK3S_USERNAME}@${JK3S_HOST_IP}" "$@"
}

echo "==> nvme-recon (${JK3S_USERNAME}@${JK3S_HOST_IP})"
remote true || { echo "!! cannot SSH — reboot the wedged Pi and wait for it to come back first" >&2; exit 1; }

remote 'sudo bash -s' <<'EOF'
set -uo pipefail   # not -e: grep-no-match (rc 1) is normal here and must not abort the report

echo "== root filesystem now (want: rw; 'ro' means it is still/again read-only) =="
findmnt -n -o SOURCE,FSTYPE,OPTIONS / || true
echo

echo "== booted kernel cmdline (are the stability flags active this boot?) =="
cat /proc/cmdline
apst="$(cat /sys/module/nvme_core/parameters/default_ps_max_latency_us 2>/dev/null || echo '?')"
echo "nvme_core.default_ps_max_latency_us = ${apst}   (0 = NVMe APST off, the stable setting)"
echo

echo "== power / throttling (bit 16 == 0x10000 set => under-voltage occurred) =="
if command -v vcgencmd >/dev/null 2>&1; then vcgencmd get_throttled; else echo "vcgencmd not found"; fi
echo

echo "== previous boot: transport errors (the crash boot, -b -1) =="
prev="$(journalctl -k -b -1 2>/dev/null | grep -iE 'nvme|pcie|aer|ext4|under-voltage|read-only|remount' || true)"
if [ -z "$prev" ]; then
  echo "(no matching previous-boot kernel log — either no prior crash boot, or the persistent"
  echo " journal was not yet enabled when it crashed. bootstrap.sh enables it going forward.)"
else
  echo "$prev"
fi
echo

echo "== SMART (is the media actually failing, or is this only the transport?) =="
if command -v nvme >/dev/null 2>&1; then
  nvme smart-log /dev/nvme0n1 2>/dev/null \
    | grep -iE 'critical_warning|media_errors|num_err_log_entries|percentage_used|unsafe_shutdowns|temperature' || true
else
  echo "nvme-cli not installed (sudo apt-get install -y nvme-cli) — skipping SMART"
fi
EOF

cat <<'HINT'

-- reading the evidence (full ladder: README "NVMe stability") --
  'nvme .* reset' / timeout          -> transport stall  -> L1a PCIe Gen1, then L3 swap the drive
  'PCIe.*AER' / Correctable / Fatal  -> signal integrity -> L1a Gen1 / reseat the FPC / L3 swap
  under-voltage / throttled bit 16   -> power            -> L2 confirm the official 27W USB-C PSU
  SMART media_errors > 0             -> failing media    -> replace the drive (RMA)
  SMART clean + ext4 EIO/read-only   -> DRAM-less stall  -> L3a DRAM-equipped NVMe is the durable fix
HINT
