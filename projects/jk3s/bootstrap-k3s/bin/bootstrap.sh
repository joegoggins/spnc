#!/usr/bin/env bash
#
# jk3s bootstrap-k3s — run from your LAPTOP. Drives a fresh, NVMe-booted Raspberry Pi 5
# over SSH into a trimmed single-node k3s cluster, then writes a localized kubeconfig.
#
# Config (env vars):
#   JK3S_HOST_IP        the Pi fixed LAN IP                e.g. 192.168.50.187
#   JK3S_USERNAME       SSH user on the Pi                e.g. jk3s
#   JK3S_SSH_KEY_PATH   private key to log in with        e.g. ~/.ssh/id_rsa
#   JK3S_CLUSTER_NAME   k3s cluster / kube-context name   e.g. gaia
#   JK3S_TAILNET        tailnet name (part before .ts.net) e.g. tail1a2b3
#   JK3S_TAILSCALE_DNS  (optional) the Pi MagicDNS name, added to the API cert as a SAN.
#                       default: <pi-hostname>.$JK3S_TAILNET.ts.net (e.g. earth.tail1a2b3.ts.net)
#   JK3S_K3S_VERSION    (optional) pin an exact k3s version (e.g. v1.36.2+k3s1); default: latest stable
#   JK3S_KUBECONFIG_OUT (optional) where to write the kubeconfig
#                       default: ~/.kube/$JK3S_CLUSTER_NAME.yaml
#
# Both JK3S_HOST_IP and JK3S_TAILSCALE_DNS are baked into the k3s API cert as --tls-san, so the
# cluster is reachable by LAN IP now and by Tailscale name later with no cert regeneration.
#
# Two-pass + idempotent: the first run sets the memory-cgroup kernel args and stops for a
# reboot (see README); after you reboot, re-run to install k3s and fetch the kubeconfig.
set -euo pipefail

: "${JK3S_HOST_IP:?set JK3S_HOST_IP (the Pi LAN IP)}"
: "${JK3S_USERNAME:?set JK3S_USERNAME (SSH user on the Pi)}"
: "${JK3S_SSH_KEY_PATH:?set JK3S_SSH_KEY_PATH (private key)}"
: "${JK3S_CLUSTER_NAME:?set JK3S_CLUSTER_NAME (k3s cluster / kube-context name)}"
: "${JK3S_TAILNET:?set JK3S_TAILNET (tailnet name, the part before .ts.net, e.g. tail1a2b3)}"

KEY="${JK3S_SSH_KEY_PATH/#\~/$HOME}"                          # expand a leading ~
OUT="${JK3S_KUBECONFIG_OUT:-$HOME/.kube/${JK3S_CLUSTER_NAME}.yaml}"
OUT="${OUT/#\~/$HOME}"

remote() {  # run a command on the Pi over SSH
  ssh -i "$KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
    "${JK3S_USERNAME}@${JK3S_HOST_IP}" "$@"
}

echo "==> preflight (${JK3S_USERNAME}@${JK3S_HOST_IP}, cluster ${JK3S_CLUSTER_NAME})"
remote true || { echo "!! cannot SSH with key ${KEY}" >&2; exit 1; }

# Derive the Tailscale MagicDNS name (a cert SAN) from the Pi hostname + tailnet, unless pinned.
PI_HOSTNAME="$(remote hostname)"
: "${JK3S_TAILSCALE_DNS:=${PI_HOSTNAME}.${JK3S_TAILNET}.ts.net}"

# Tailscale must be up before k3s so the cert gets the right SAN at install time. Cross-check the
# derived name against what Tailscale actually reports.
REAL_DNS="$(remote 'tailscale status --json 2>/dev/null' | grep -m1 '"DNSName"' | sed -E 's/.*"DNSName": *"([^"]+)\.".*/\1/' || true)"
if [[ -z "$REAL_DNS" ]]; then
  echo "!! Tailscale is not up on the Pi — do the Tailscale step first" >&2
  exit 1
elif [[ "$REAL_DNS" != "$JK3S_TAILSCALE_DNS" ]]; then
  echo "!! Tailscale reports ${REAL_DNS}, but the SAN would be ${JK3S_TAILSCALE_DNS}." >&2
  echo "   Fix JK3S_TAILNET, or set JK3S_TAILSCALE_DNS to the reported name." >&2
  exit 1
fi
echo "    tls-sans: ${JK3S_HOST_IP}, ${JK3S_TAILSCALE_DNS}"

ROOT_SRC="$(remote 'findmnt -n -o SOURCE /' || true)"
case "$ROOT_SRC" in
  *nvme*) echo "    root on NVMe ($ROOT_SRC)" ;;
  *)      echo "!! root is ${ROOT_SRC:-unknown}, not NVMe — finish setup-hardware first" >&2; exit 1 ;;
esac

echo "==> memory cgroup"
# Requires cgroup v2 (Raspberry Pi OS Lite, Bookworm+): the memory controller is enabled iff it
# is listed in cgroup.controllers.
if remote 'grep -qw memory /sys/fs/cgroup/cgroup.controllers'; then
  echo "    enabled"
else
  if remote 'grep -q cgroup_memory=1 /boot/firmware/cmdline.txt'; then
    echo "!! cmdline already has the args but the memory cgroup is still off after reboot." >&2
    echo "   Known Pi5/Bookworm DTB issue (k3s-io/k3s#9524) — see README Notes." >&2
    exit 1
  fi
  echo "    setting kernel args on /boot/firmware/cmdline.txt ..."
  remote "sudo sed -i 's/\$/ cgroup_memory=1 cgroup_enable=memory/' /boot/firmware/cmdline.txt"
  echo
  echo ">>> Kernel args set. Reboot the Pi and re-run this script. <<<"
  exit 0
fi

# ------------------------------------------------------------------------------
# TODO(nvme-stability): ESCALATION LADDER for the Pi 5 + DRAM-less NVMe read-only
# outages (refs: collabornet/stories/SPNC-0005, joe-notes .../crash-drive-goes-read-only.md).
#
# Failure mode: Inland TN320 (DRAM-less/HMB, Realtek RTS5765DL) stalls over the Pi 5
# PCIe link under write load -> nvme driver returns EIO -> ext4 aborts journal ->
# root remounts read-only -> k3s/sshd/dhcpcd die (box still pings via resident tailscaled,
# but is wedged). SMART clean (0 media_errors) => transport stall, not media failure.
# NOT auto-applied here: climb only as far as needed, and let journal evidence pick the rung.
#
# EACH recurrence, FIRST capture what the transport actually did (persistent journal is on,
# so the crash boot survives the reboot):
#     sudo journalctl -k -b -1 | grep -iE 'nvme|pcie|aer|ext4|under-voltage|read-only'
#     vcgencmd get_throttled          # bit 16 (0x10000) set == undervoltage occurred
#   'nvme .* reset'/timeout      => link/drive     -> Layer 1a (Gen1), then Layer 3a (DRAM drive)
#   'PCIe.*AER'/Correctable/Fatal=> signal integrity-> Layer 1a (Gen1) / reseat FPC / Layer 3
#   under-voltage / bit 16 set   => power           -> Layer 2
#
# Layer 0  DONE 2026-07-01, INSUFFICIENT (recurred same evening under `helmfile apply` load):
#     /boot/firmware/cmdline.txt:  nvme_core.default_ps_max_latency_us=0 pcie_aspm=off  (APST+ASPM off)
#     Persistent journal enabled (drop-in): printf '[Journal]\nStorage=persistent\n' \
#       | sudo tee /etc/systemd/journald.conf.d/persistent.conf; then mkdir /var/log/journal + restart journald.
#
# Layer 1  remaining FREE config levers (edit, reboot, then re-run a real deploy under the watch above):
#   a. Force PCIe Gen1 — biggest untried lever, relaxes FPC signal integrity (currently links Gen2/5.0GT/s):
#          /boot/firmware/config.txt:  dtparam=pciex1_gen=1     # (verify param vs current RPi docs)
#   b. cmdline.txt: add  pcie_port_pm=off   (complements pcie_aspm=off)
#   c. Experiment: HMB off  nvme.max_host_mem_size_mb=0  (DRAM-less drives vary — try with/without)
#
# Layer 2  power (their own notes: "underpowered supplies are a top cause of flaky NVMe"):
#   Confirm official RPi 27W USB-C PD (NOT PoE; never both). If throttled bit 16 ever sets, this IS
#   the cause -> better PSU / shed peripherals. (Active cooler already fitted; temps were fine.)
#
# Layer 3  swap the storage medium — the "make it just work" fixes (pick one):
#   a. DRAM-equipped NVMe from a Pi-5-known-good list (e.g. Jeff Geerling's pipci). Removes the
#      DRAM-less/HMB stall class ENTIRELY and makes Layer 0/1 workarounds unnecessary. Caveats:
#      DRAM drives draw MORE power (do Layer 2 first) and won't help a PCIe-signal fault (Layer 1)
#      -> so gate the purchase on the journal evidence above.
#   b. Boot from a USB3 SSD (UASP) instead of NVMe: bypasses the PCIe/FPC path entirely, proven
#      stable, at throughput cost. Surest single-node fix; if a DRAM NVMe *still* stalls, that
#      implicates the HAT/FPC/board, not the drive.
#
# Layer 4  ARCHITECTURE — the real production answer, folds into the SPNC-0006 mini-rack:
#   Single-node k3s on flaky storage is inherently fragile (one drive fault = whole cluster down).
#   Go multi-node HA: 3 server nodes w/ embedded etcd so one node's storage death doesn't kill the
#   API; add restic/Velero backups (SPNC-0005). Survive storage faults instead of preventing each one.
# ------------------------------------------------------------------------------

if [[ -n "${JK3S_K3S_VERSION:-}" ]]; then
  echo "==> install k3s (pinned ${JK3S_K3S_VERSION}; trimmed: no traefik, no servicelb; local-path kept)"
else
  echo "==> install k3s (latest stable; trimmed: no traefik, no servicelb; local-path kept)"
fi
if remote 'command -v k3s >/dev/null 2>&1'; then
  echo "    k3s already installed, skipping installer"
else
  # node name defaults to the Pi hostname (e.g. earth). Both SANs make the API cert valid for the
  # LAN IP (now) and the Tailscale name (remote, later). The installer sudo's the privileged parts.
  # JK3S_K3S_VERSION pins an exact release; empty => latest stable channel.
  remote "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${JK3S_K3S_VERSION:-}' INSTALL_K3S_EXEC='--disable traefik --disable servicelb --write-kubeconfig-mode 644 --tls-san ${JK3S_HOST_IP} --tls-san ${JK3S_TAILSCALE_DNS}' sh -"
fi

echo "==> wait for the node to be Ready"
for i in $(seq 1 30); do
  if remote 'sudo k3s kubectl get nodes 2>/dev/null | grep -q " Ready "'; then
    echo "    Ready"; break
  fi
  [[ "$i" -eq 30 ]] && { echo "!! node did not reach Ready in ~90s" >&2; exit 1; }
  sleep 3
done

echo "==> fetch + localize kubeconfig -> $OUT"
mkdir -p "$(dirname "$OUT")"
remote 'sudo cat /etc/rancher/k3s/k3s.yaml' \
  | sed -e "s/127\.0\.0\.1/${JK3S_HOST_IP}/g" \
        -e "s/: default\$/: ${JK3S_CLUSTER_NAME}/g" \
  > "$OUT"
chmod 600 "$OUT"

echo
echo "Done. k3s is up; kubeconfig written to $OUT (context ${JK3S_CLUSTER_NAME})."
echo "SANs baked: ${JK3S_HOST_IP} (LAN) + ${JK3S_TAILSCALE_DNS} (Tailscale) — remote later needs no regen."
if command -v kubectl >/dev/null 2>&1; then
  echo "Verify:  KUBECONFIG=$OUT kubectl get nodes"
else
  echo "(install kubectl, then:  KUBECONFIG=$OUT kubectl get nodes)"
fi
echo "Next:    helmfile-base to deploy cloudflared + hello-world against context ${JK3S_CLUSTER_NAME}."
