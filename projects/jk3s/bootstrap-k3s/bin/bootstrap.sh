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
# Two-pass + idempotent: the first run enables the persistent journal and sets the kernel args
# (memory cgroup + NVMe/PCIe stability), then stops for a reboot (see README); after you reboot,
# re-run to install k3s and fetch the kubeconfig.
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

echo "==> persistent journal (so a crash boot's kernel log survives the reboot)"
# The Pi 5 + DRAM-less NVMe read-only-remount outage (SPNC-0005) leaves no trace unless the journal
# is persistent — sshd dies with root read-only, so evidence is only readable from the *previous*
# boot after a reboot. `Storage=auto` did NOT promote on this Pi OS build; force it via a drop-in.
# Enabled here (not gated on a crash) so the very first stall on a fresh box is diagnosable.
remote 'sudo bash -s' <<'EOF'
set -uo pipefail
d=/etc/systemd/journald.conf.d; f="$d/persistent.conf"
mkdir -p "$d" /var/log/journal
if grep -qs '^Storage=persistent' "$f"; then
  echo "    already persistent"
else
  printf '[Journal]\nStorage=persistent\n' > "$f"
  systemctl restart systemd-journald
  journalctl --flush >/dev/null 2>&1 || true
  echo "    enabled (Storage=persistent)"
fi
EOF

echo "==> kernel args (memory cgroup + NVMe/PCIe stability)"
# Both classes live on the single-line /boot/firmware/cmdline.txt:
#   cgroup_memory=1 cgroup_enable=memory     -> k3s needs the cgroup v2 memory controller
#   nvme_core.default_ps_max_latency_us=0    -> NVMe APST off
#   pcie_aspm=off  pcie_port_pm=off          -> PCIe ASPM + port power-management off
# The NVMe/PCIe flags disable the low-power states the Pi 5 + DRAM-less NVMe combo stalls on under
# write load (root cause of the `earth` read-only-remount outage, SPNC-0005). They cost a little idle
# power, never throughput — so they are safe to default, and codifying them means a fresh box is
# hardened from first boot. The throughput-costing / drive-specific rungs (PCIe Gen1, HMB off) are
# NOT auto-applied — those stay evidence-gated in the README "NVMe stability" ladder.
#
# This fleet is DRAM-less by design: every box is an Inland TN320 (same drive as `earth`), so the
# three NVMe/PCIe flags are applied UNCONDITIONALLY — the DRAM-less/HMB drive is the whole reason
# they're needed. IF YOU EVER BUILD ON A DRAM-CACHE NVMe (Layer 3a) instead: drop those three flags
# and keep only `cgroup_memory=1 cgroup_enable=memory` — a DRAM drive doesn't stall on the low-power
# states, so it runs stock. Don't make this branch on the drive; just edit `needed` below if that day comes.
CHANGED="$(remote 'sudo bash -s' <<'EOF'
set -uo pipefail
f=/boot/firmware/cmdline.txt
needed=(cgroup_memory=1 cgroup_enable=memory nvme_core.default_ps_max_latency_us=0 pcie_aspm=off pcie_port_pm=off)
line="$(tr '\n' ' ' < "$f")"           # cmdline.txt is a single line; fold any stray newline
declare -A have=()
for tok in $line; do have["$tok"]=1; done
add=()
for a in "${needed[@]}"; do [ -n "${have[$a]:-}" ] || add+=("$a"); done
if [ "${#add[@]}" -gt 0 ]; then
  cp -a "$f" "$f.bak.$(date +%Y%m%d-%H%M%S)"
  printf '%s %s\n' "${line% }" "${add[*]}" > "$f"   # keep it one line: append the missing args
  echo CHANGED
else
  echo OK
fi
EOF
)"
if [ "$CHANGED" = CHANGED ]; then
  echo "    added missing kernel args to /boot/firmware/cmdline.txt (timestamped backup alongside)"
  echo
  echo ">>> Kernel args set. Reboot the Pi, wait ~30s, then re-run this script: <<<"
  echo ">>>   ssh -i \"\$JK3S_SSH_KEY_PATH\" \"\$JK3S_USERNAME@\$JK3S_HOST_IP\" sudo reboot   <<<"
  exit 0
fi
echo "    cmdline args present"
# The memory cgroup must actually be ACTIVE, not merely requested: the Pi5/Bookworm DTB has
# historically re-disabled the memory controller even with the arg set. Check cgroup.controllers
# (cgroup v2), not /proc/cgroups (which omits memory under v2).
if ! remote 'grep -qw memory /sys/fs/cgroup/cgroup.controllers'; then
  echo "!! cmdline has the args but the memory cgroup is still off after reboot." >&2
  echo "   Known Pi5/Bookworm DTB issue (k3s-io/k3s#9524) — see README Notes." >&2
  exit 1
fi
echo "    memory cgroup: enabled"

# ------------------------------------------------------------------------------
# NVMe/PCIe stability: the proven Layer 0/1 power-state flags are applied above (kernel-args step)
# and the persistent journal is enabled, so a fresh box is hardened from first boot and any future
# crash boot is diagnosable. If a box STILL remounts root read-only under load, don't guess —
# run `bin/nvme-recon.sh` to capture the transport evidence, then climb the escalation ladder in
# bootstrap-k3s/README.md ("NVMe stability"). The Inland TN320 is DRAM-less; the durable fix is a
# DRAM-equipped NVMe. Refs: SPNC-0005; incident joe-notes/.../crash-drive-goes-read-only.md.
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
