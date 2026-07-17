# About

Helmfile deployment for mspsolarpunk's static site — plain HTML/CSS behind
nginx, no API/DB. Same helmfile+sops+cloudflared pattern as
[`collabornet/deploy/helmfile`](../../../collabornet/deploy/helmfile/README.md)
(env prefix `wb-` instead of `sp-`) — see that README for the fuller
walkthrough (sops/age setup, GHCR PAT secrets, etc.). This one stays brief.

# Environments

| env        | cluster ctx    | namespace  | public URL              | cloudflared      |
|------------|----------------|------------|--------------------------|------------------|
| wb-local   | kind-wb-local  | wb-local   | http://localhost:6173    | none — NodePort  |
| wb-staging | gaia           | wb-staging | https://japoofis.com     | own tunnel       |
| wb-prod    | hope-island    | wb-prod    | https://mspsolarpunk.com | own tunnel       |

CI (`.github/workflows/mspsolarpunk-web.yml`) builds+pushes on every `main`
push touching `services/web/**`. **One-time:** after its first run, set the
`mspsolarpunk-web` GHCR package to public (Package settings → Change
visibility) — it's a plain static site, and staying public means no
imagePullSecret is wired up for wb-staging/wb-prod.

# Local (wb-local)

One command does everything: creates+targets the `wb-local` kind cluster
(idempotent), builds `services/web` into an image, `kind load`s it, and
deploys — see the `prepare` hook in `helmfile-hook-commands/`.

```sh
cd projects/mspsolarpunk/deploy/helmfile
helmfile -e wb-local apply
open http://localhost:6173
```

Teardown: `kind delete cluster --name wb-local`

# Remote (wb-staging / wb-prod)

Prereqs + sops/age setup: same as collabornet, see its README.

One-time per env — create the tunnel and SOPS-encrypt its credentials:

```sh
export SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/keys.txt
cd projects/mspsolarpunk/deploy/helmfile
cloudflared tunnel create wb-staging   # or wb-prod; note the UUID it prints
UUID=<uuid-from-above>
f=environments/wb-staging/secrets/cloudflared.yaml   # swap env as needed

# credentialsJson must end up a YAML *string* holding the raw JSON, not a
# nested mapping — `jq -Rs .` JSON-encodes it (adds quotes + escaping) so it
# round-trips as a string. Skipping that step is what breaks cloudflared with
# "invalid character 'm' looking for beginning of value" (Helm's `quote`
# stringifying a Go map as `map[AccountTag:...]`).
COMPACT="$(jq -c . "$HOME/.cloudflared/$UUID.json")"
CREDS_JSON="$(printf '%s' "$COMPACT" | jq -Rs .)"
printf 'cloudflared:\n  tunnelId: %s\n  credentialsJson: %s\n' "$UUID" "$CREDS_JSON" > "$f"
sops --config .sops.yaml -e -i "$f"
sops -d "$f" >/dev/null && echo "encrypted + decrypts OK"
```

DNS (one-time):

`cloudflared tunnel route dns <uuid> japoofis.com` (or
`mspsolarpunk.com` for wb-prod) — a proxied apex record to
`<uuid>.cfargotunnel.com`.

> **Gotcha — two zones, one cert:** `route dns` picks the zone from whichever
> zone `~/.cloudflared/cert.pem` is currently scoped to (from the last
> `cloudflared tunnel login`), *not* from the hostname you pass it. Since this
> project spans two zones (japoofis.com, mspsolarpunk.com), the wrong active
> cert makes it silently create `mspsolarpunk.com.japoofis.com` (or the
> reverse) instead of erroring. Keep one cert per zone and pass it explicitly:
> ```sh
> cloudflared tunnel login   # pick the zone in the browser, then:
> cp ~/.cloudflared/cert.pem ~/.cloudflared/cert-<zone>.pem
> cloudflared tunnel route dns --origincert ~/.cloudflared/cert-japoofis.pem <uuid> japoofis.com
> cloudflared tunnel route dns --origincert ~/.cloudflared/cert-mspsolarpunk.pem <uuid> mspsolarpunk.com
> ```
> If you skip this, double check the record landed in the right zone in the
> dashboard before moving on.

Deploy:


```sh
export KUBECONFIG=~/.kube/gaia.yaml
export SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/keys.txt
helmfile -e wb-staging diff                # or -e wb-prod
helmfile -e wb-staging apply
```

## Deploy software change:

Make a software change, push it github, wait for CI to finish the build, then:

`kubectl rollout restart deploy/web -n wb-staging`


# Later

`gaia` ends up running two independent cloudflared tunnels (collabornet's +
this one). Centralize into one shared tunnel for the cluster once there's a
second real app to justify it.
