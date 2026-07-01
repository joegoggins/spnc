# jk3s

A small, reusable tool to provision **one Raspberry Pi 5 (NVMe/PCIe boot)** into a trimmed single-node k3s Kubernetes cluster and expose a service over **https** through a Cloudflare Tunnel — no port-forwarding, no public IP, no inbound firewall holes.

## Layout

Each sub-directory provides a core component to the build, details in each README describe how to use them. They should be executed in this sequence:

1. `setup-hardware`: Purchase and assemble the hardware. Provision RPi OS on the hardware. Boot from NVMe/PCIe. Configure static LAN IP/DHCP reservation.
1. `bootstrap-k3s`: Provision k3s on RPi in stripped down mode
1. `helmfile-base`: Deploy CloudFlared Tunnel and hello world http service

After this sequence of projects is worked. "hello world" content should be available at some `https://example.com` endpoint.

The next step from here is to build a `helmfile-app` project that deploys real software to this K3s cluster. Copy and modify `helmfile-base` as needed to achieve this. Commit this to a separate repo you control maybe along-side your app code at `deploy/helmfile-app`.

## Get started

Open `setup-hardware/README.md`. Work it end to end. When done, work `bootstrap-k3s/README.md`, and so on and so forth.
