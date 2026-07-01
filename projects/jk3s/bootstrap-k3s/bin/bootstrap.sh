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

echo "==> install k3s (trimmed: no traefik, no servicelb; local-path kept for PVCs)"
if remote 'command -v k3s >/dev/null 2>&1'; then
  echo "    k3s already installed, skipping installer"
else
  # node name defaults to the Pi hostname (e.g. earth). Both SANs make the API cert valid for the
  # LAN IP (now) and the Tailscale name (remote, later). The installer sudo's the privileged parts.
  remote "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='--disable traefik --disable servicelb --write-kubeconfig-mode 644 --tls-san ${JK3S_HOST_IP} --tls-san ${JK3S_TAILSCALE_DNS}' sh -"
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
echo "Next:    helmfile-base deploys cloudflared + hello-world against context ${JK3S_CLUSTER_NAME}."
