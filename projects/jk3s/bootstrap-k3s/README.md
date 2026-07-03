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

Most of the commands assume you are executing commands from your workstation/laptop (not RPi)

1. Run `cd bootstrap-k3s`
1. Set these in your shell (example values, be sure to sub for each TBD or override as needed)
      ```
      export JK3S_HOST_IP=TBD.TBD.TBD.TBD     # the Pi's fixed LAN IP (from setup-hardware)
      export JK3S_USERNAME=jk3s               # SSH user on the Pi
      export JK3S_SSH_KEY_PATH=~/.ssh/id_rsa  # private key that logs into the Pi
      export JK3S_CLUSTER_NAME=gaia           # k3s cluster / kube-context name
      export JK3S_TAILNET=TBD                 # your tailnet name (part before .ts.net, like tailabc123)
      # Optional — pin an exact k3s version for reproducible/identical clusters (unset => latest stable):
      # export JK3S_K3S_VERSION=v1.36.2+k3s1
      ```

   Find a version to pin on the [k3s releases page](https://github.com/k3s-io/k3s/releases) — copy a
   tag like `v1.36.2+k3s1`. Or print what *stable* currently resolves to (the version is the last path
   segment of the URL):
   ```
   curl -s https://update.k3s.io/v1-release/channels/stable -o /dev/null -w '%{redirect_url}\n'
   ```
   Leave `JK3S_K3S_VERSION` unset to take latest stable at install time (fine for one cluster); pin it
   so a second box comes up on the exact same version.
1. Validate RPi connectivity: `ssh -i "$JK3S_SSH_KEY_PATH" "$JK3S_USERNAME@$JK3S_HOST_IP"  uptime`

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
   - Validate access like this: `nc -zv earth.tail61e694.ts.net 22`
     ```
   - (For remote use later: install Tailscale on your laptop and join the same tailnet. Not needed
     today — on the LAN the kubeconfig still uses `JK3S_HOST_IP`.)

1. **Set the kernel args (needs one reboot).** Run the script once — it verifies Tailscale, enables
   the persistent journal, sets the required kernel args (the cgroup memory controller **plus** the
   NVMe/PCIe stability flags — see [NVMe stability](#nvme-stability)), and stops:
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
   The output must include `memory`. (If it doesn't, see Notes.) While you're here, spot-check that
   the NVMe stability flags took effect too:
   ```
   ssh -i "$JK3S_SSH_KEY_PATH" "$JK3S_USERNAME@$JK3S_HOST_IP" \
     'cat /proc/cmdline; cat /sys/module/nvme_core/parameters/default_ps_max_latency_us'
   ```
   Expect `pcie_aspm=off pcie_port_pm=off nvme_core.default_ps_max_latency_us=0` on the cmdline and
   `0` from the module parameter.

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

1. Can connect to cluster using the TailScale DNS
  - `vim ~/.kube/$JK3S_CLUSTER_NAME.yaml`
  - Edit `server: https://x.y.z.a:6443` to be `server: https://TBD.TBD.ts.net:6443`
  - Run `kubectl get pods -A`; expect to see them

Typically, you leave this edit in place and default using TailScale DNS for interacting with the cluster.
You can change it base to IP based approach when interacting without the Internet on the local network without TailScale.

# NVMe stability (Can ignore unless needed)

**The failure this guards against.** On 2026-07-01 the `earth` node went dead mid-deploy: it still
pinged over Tailscale but SSH reset, `:6443` refused, and it dropped its LAN IP. Root cause was a
single event — the **DRAM-less Inland TN320 NVMe stalled over the Pi 5 PCIe link under write load**,
the NVMe driver returned EIO, ext4 aborted its journal and **remounted root read-only**, and then
everything that writes to disk (sshd, k3s, dhcpcd) died while the already-resident `tailscaled` kept
answering — "alive but wedged." SMART was clean (0 media_errors) → a **transport stall, not a failing
drive**. (Full incident: `joe-notes/.../crash-drive-goes-read-only.md`; story SPNC-0005.)

> ⚠️ **The TN320 is DRAM-less/HMB — it is the weak link, and every jk3s box uses it.** The flags below
> reduce the odds but the Layer 0 subset was already shown *insufficient alone* on `earth` (it recurred
> the same evening). If a box needs to be dependable, the durable fix is **Layer 3a — a DRAM-equipped
> NVMe** (or Layer 3b, USB3 SSD). Treat the defaults as harm-reduction on known-marginal hardware, not
> a guarantee.

**What bootstrap.sh now applies automatically** (so a fresh box is hardened from first boot):

- **Persistent journal** (`Storage=persistent` drop-in). Without it a crash leaves no trace — sshd is
  dead while root is read-only, so the evidence is only readable from the *previous* boot after a
  reboot. This makes that possible.
- **NVMe/PCIe power-state flags** on `/boot/firmware/cmdline.txt`, folded into the one kernel-args
  reboot: `nvme_core.default_ps_max_latency_us=0` (NVMe APST off) + `pcie_aspm=off pcie_port_pm=off`
  (PCIe ASPM + port PM off). These disable the low-power states the drive stalls on. They cost a little
  idle power, never throughput, so they are safe to default. The **throughput-costing / drive-specific**
  rungs below (PCIe Gen1, HMB off) are deliberately *not* auto-applied — climb to them only on evidence.

## If a box still remounts read-only under load

**1. Capture the evidence first — don't guess.** Reboot the wedged Pi (`sudo reboot` or power-cycle;
you can't ssh in while root is read-only), let it come back, then from your laptop:

```
bin/nvme-recon.sh
```

It reads the crash boot (`journalctl -k -b -1`, preserved by the persistent journal), the throttle
state, the live cmdline, and SMART, and prints which rung the evidence points to. Read it as:

| Evidence | Meaning | Go to |
|---|---|---|
| `nvme .* reset` / timeout | transport stall | L1a (Gen1), then L3 (swap drive) |
| `PCIe.*AER` / Correctable / Fatal | signal integrity | L1a (Gen1) / reseat FPC / L3 |
| under-voltage / `vcgencmd get_throttled` bit 16 (`0x10000`) | power | L2 (confirm 27W PSU) |
| SMART `media_errors` > 0 | failing media | replace the drive (RMA) |
| SMART clean **and** ext4 EIO / read-only | DRAM-less stall | L3a (DRAM NVMe) is the durable fix |

**2. Climb only as far as the evidence warrants.** Layer 0 (persistent journal + APST/ASPM off) is
already applied by `bootstrap.sh`; the rest are manual:

- **Layer 1 — remaining free config levers** (edit, reboot, re-run a real deploy under `bin/nvme-recon.sh`):
  - **a. Force PCIe Gen1** — the biggest untried lever; relaxes FPC signal integrity (the link is
    Gen2/5.0GT/s by default). In `/boot/firmware/config.txt`: `dtparam=pciex1_gen=1` *(verify the param
    name against current RPi docs)*. Costs ~½ the link throughput — fine for a homelab node.
  - **b. HMB off** — experiment only: `nvme.max_host_mem_size_mb=0` on the cmdline. DRAM-less drives lean
    on the Host Memory Buffer, so this can *hurt*; try with and without and keep whatever is stable.
- **Layer 2 — power.** Confirm the official RPi **27W USB-C PD** supply (never PoE and USB-C at once).
  If `get_throttled` bit 16 ever sets, power *is* the cause → better PSU / shed peripherals. (The active
  cooler is already fitted; temps were fine on `earth`.)
- **Layer 3 — swap the storage medium** (the "make it just work" fixes; pick one):
  - **a. DRAM-equipped NVMe** from a Pi-5-known-good list (e.g. Jeff Geerling's pipci). Removes the
    DRAM-less/HMB stall class *entirely* and makes Layer 0/1 moot. Caveats: DRAM drives draw more power
    (do Layer 2 first) and won't fix a genuine PCIe-signal fault — so gate the buy on the evidence above.
  - **b. USB3 SSD (UASP)** instead of NVMe: bypasses the PCIe/FPC path entirely; proven stable at a
    throughput cost. Surest single-node fix. If a DRAM NVMe *still* stalls, that implicates the
    HAT/FPC/board, not the drive.
- **Layer 4 — architecture** (the real production answer; folds into the SPNC-0006 mini-rack). Single-node
  k3s on flaky storage is inherently fragile — one drive fault = whole cluster down. Go **multi-node HA**:
  3 server nodes with embedded etcd so one node's storage death doesn't kill the API, plus restic/Velero
  backups (SPNC-0005). Survive storage faults instead of preventing each one.