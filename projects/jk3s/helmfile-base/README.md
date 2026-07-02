# About

Helmfile deployment for the k3s cluster. The `cloudflared` release runs a
Cloudflare Tunnel — the only HTTPS ingress into the cluster. Cloudflare
terminates TLS at the edge and forwards public traffic to in-cluster origins
over the tunnel. Routing lives in-repo (`charts/cloudflared`); the tunnel
credentials live in a k8s Secret (never committed).

# Prerequisites / To install on laptop

- `cloudflared`
- `helmfile`
- `helm`
- `kubectl`

# Steps

## cloudflared — first-time setup (per environment)

Example uses the `sp-staging` env (the `gaia` cluster).

1. Create the tunnel and note its UUID (writes `~/.cloudflared/<uuid>.json`):

   ```sh
   cloudflared tunnel create sp-staging
   ```

2. In `environments/sp-staging/values.yaml.gotmpl`, set:
   - `cloudflared.ingress` — the hostname **prefix** → in-cluster service (the base
     domain is appended from `JK3S_BASE_DNS` at render time)

   Two values are kept out of the repo and passed at deploy time via env vars (see the
   Deploy step); `helmfile` errors if either is unset:
   - `JK3S_CLOUDFLARED_TUNNEL_ID` — the tunnel **UUID** (not the connector token)
   - `JK3S_BASE_DNS` — the public base domain (e.g. `example.com`)

3. Point DNS at the tunnel:

   ```sh
   cloudflared tunnel route dns sp-staging hello-world.<your_domain_name>
   ```

3. Create the `sp-staging` namespace: `kubectl create namespace sp-staging`
3. Load the tunnel credentials into a Secret (do **not** commit this file):

   ```sh
   kubectl -n sp-staging create secret generic cloudflared-credentials \
     --from-file=credentials.json="$HOME/.cloudflared/<uuid>.json"
   ```

3. Deploy:

   ```sh
   export KUBECONFIG=~/.kube/gaia.yaml
   export JK3S_CLOUDFLARED_TUNNEL_ID=<uuid>   # tunnel UUID from step 1
   export JK3S_BASE_DNS=<your_domain_name>    # public base domain, e.g. example.com
   helmfile -e sp-staging diff  # Inspect
   helmfile -e sp-staging apply # Apply if it looks good
   ```

# Done Criteria

1. `kubectl -n sp-staging rollout status deploy/cloudflared` reports available.
2. The configured hostname serves the in-cluster origin over HTTPS.
