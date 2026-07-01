# About

Starts from a fresh, NVMe-booted RPi (the output of `setup-hardware`) reachable over SSH.
Ends with a trimmed single-node **k3s** cluster reachable with `kubectl`/`helmfile` from your
laptop — on the LAN now, and over Tailscale later without re-issuing certs.

`bin/bootstrap.sh` runs on your **laptop** and drives the Pi over SSH. Everything automatable is
in the script; only the interactive bits (Tailscale login, one reboot, and post-boot checks) are
steps here.

# Prerequisites / To install on laptop

- `kubectl`
- TailScale account and known tail-net value

# Steps

## TailScale setup

1. Signup and download TailScale app: https://tailscale.com/
1. Identify your tailnet, navigate to https://login.tailscale.com/admin/dns

## Configure your shell

1. Run `cd bootstrap-k3s`
1. Set these in your shell (example values, be sure to sub for each TBD or override as needed)
      ```
      export JK3S_HOST_IP=TBD.TBD.TBD.TBD     # the Pi's fixed LAN IP (from setup-hardware)
      export JK3S_USERNAME=jk3s               # SSH user on the Pi
      export JK3S_SSH_KEY_PATH=~/.ssh/id_rsa  # private key that logs into the Pi
      export JK3S_CLUSTER_NAME=gaia           # k3s cluster / kube-context name
      export JK3S_TAILNET=TBD                 # your tailnet name (part before .ts.net, like tailabc123)
      ```
3. Validate RPi connectivity: `ssh -i "$JK3S_SSH_KEY_PATH" "$JK3S_USERNAME@$JK3S_HOST_IP"  uptime`

## K3s Bootstrapping

Assumes passwordless `sudo` for that user on the Pi (Raspberry Pi Imager sets this up by default)

1. **Put the Pi on your tailnet (do this before k3s).** Gives `earth` a `100.x` tailnet IP and a
   MagicDNS name `earth.<tailnet>.ts.net`, reachable from anywhere without routing your
   `192.168.x` LAN — and doing it first means the k3s API cert gets that name as a SAN at install
   time (no later cert regen).
   - Install Tailscale on the Pi:
     ```
     ssh -i "$JK3S_SSH_KEY_PATH" "$JK3S_USERNAME@$JK3S_HOST_IP" 'curl -fsSL https://tailscale.com/install.sh | sh'
     ```
   - Bring it up — prints a login URL; open it and approve `earth`. Let the device name default to
     the hostname (`earth`); don't pass `--hostname`:
     ```
     ssh -i "$JK3S_SSH_KEY_PATH" "$JK3S_USERNAME@$JK3S_HOST_IP" sudo tailscale up --accept-dns=false
     ```
   - Enable **MagicDNS** if it isn't already, it default to enabled. (tailnet admin console → DNS).
   - Read the Pi's MagicDNS name and set `JK3S_TAILNET` to the middle part:
     ```
     ssh -i "$JK3S_SSH_KEY_PATH" "$JK3S_USERNAME@$JK3S_HOST_IP" 'tailscale status --json | grep -m1 DNSName'
     #  "DNSName": "earth.tail1a2b3.ts.net."   ->   export JK3S_TAILNET=tail1a2b3
     ```
   - (For remote use later: install Tailscale on your laptop and join the same tailnet. Not needed
     today — on the LAN the kubeconfig still uses `JK3S_HOST_IP`.)

1. **Enable the memory cgroup (needs one reboot).** Run the script once — it verifies Tailscale,
   sets the required kernel args, and stops:
   ```
   bin/bootstrap.sh
   ```
   Reboot the Pi:
   ```
   ssh -i "$JK3S_SSH_KEY_PATH" "$JK3S_USERNAME@$JK3S_HOST_IP" sudo reboot
   ```
   Wait ~30s for it to come back, then confirm the memory cgroup is really on. Bookworm uses
   cgroup **v2**, so check `cgroup.controllers` (not `/proc/cgroups`, which omits memory under v2):
   ```
   ssh -i "$JK3S_SSH_KEY_PATH" "$JK3S_USERNAME@$JK3S_HOST_IP" cat /sys/fs/cgroup/cgroup.controllers
   ```
   The output must include `memory`. (If it doesn't, see Notes.)

1. **Install k3s + write the kubeconfig.** Run the script again:
   ```
   bin/bootstrap.sh
   ```
   It installs k3s trimmed (no traefik, no servicelb; local-path kept for PVCs), bakes both
   `JK3S_HOST_IP` and the Tailscale name into the API cert as SANs, and writes a localized
   kubeconfig to `~/.kube/$JK3S_CLUSTER_NAME.yaml` (server → the Pi's LAN IP, context →
   `$JK3S_CLUSTER_NAME`).

# Done Criteria

1. The Pi is on the tailnet:
   ```
   ssh -i "$JK3S_SSH_KEY_PATH" "$JK3S_USERNAME@$JK3S_HOST_IP" tailscale status
   ```
   → shows the Pi with a `100.x` IP; its MagicDNS name is `earth.$JK3S_TAILNET.ts.net`.
1. From your laptop, the node is Ready:
   ```
   KUBECONFIG=~/.kube/$JK3S_CLUSTER_NAME.yaml kubectl get nodes
   ```
   → one node (named for the Pi's hostname, e.g. `earth`) in `Ready` state.

# Notes

- **The SAN name is the hostname, not the cluster.** Tailscale names each device by its hostname,
  so the Pi is `earth.<tailnet>.ts.net` — not `gaia...`. That's deliberate: it scales when you add
  more nodes (`fire`, `wind`), each its own tailnet device, all in cluster `gaia`. The script
  derives the SAN as `<pi-hostname>.$JK3S_TAILNET.ts.net`; set `JK3S_TAILSCALE_DNS` to override if
  you ever rename the Tailscale device.
- **Going remote later:** the cert already carries the Tailscale name, so to deploy off-LAN just
  point the kubeconfig `server:` at `https://earth.<tailnet>.ts.net:6443` — no cert regeneration.
  On-LAN it stays the faster `JK3S_HOST_IP`.
- **`memory` missing from `cgroup.controllers` after reboot:** known Pi 5 / Bookworm issue — the
  firmware DTB can re-disable the memory cgroup despite the cmdline
  ([k3s-io/k3s#9524](https://github.com/k3s-io/k3s/issues/9524)).
- **Why the trim:** the Cloudflare Tunnel (next project, `helmfile-base`) is the only ingress, so
  traefik + servicelb aren't needed; local-path stays as the default StorageClass so PVCs land on
  the NVMe.
- **Naming:** the k3s node inherits the Pi's hostname (`earth`); the kubeconfig context is
  `$JK3S_CLUSTER_NAME` (`gaia`). `helmfile-base` deploys against that context.
