# About

This project picks up where `projects/jk3s/helmfile-base` left off. Make sure the Done Criteria and Clean are good there first.

# Prerequisites

Same as jk3s/helmfile-base, plus some extras to manage secrets: (initial versions noted, may not be required unless noted)

- sops 3.13.1
- age (tool for encrypting files)
- helmfile v1.3.1
- helm 3 (not 4; incompat with helm-secrets 4.x)
- helm-secrets v4.6.5

# Usage

## Destroy helmfile-base resources; we don't want them getting in the way of actual software deployment

```bash
export KUBECONFIG=~/.kube/gaia.yaml
cd projects/jk3s/helmfile-base
helmfile -e sp-staging destroy
```

## Create an `age` sops key

You only do this once per operator machine. The **public** recipient lives in
[`.sops.yaml`](.sops.yaml) (safe to commit); the **private** key never leaves the
machine and is what decrypts every secret here.

1. Generate the keypair (prints the public recipient on the last line):

   ```sh
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   # public key: age1........  <- copy this
   ```

1. Put the `age1...` recipient in [`.sops.yaml`](.sops.yaml) under `creation_rules[].age`.
   To add a second operator later, append their recipient and re-key existing
   secrets: `sops updatekeys environments/<env>/secrets/*.yaml`.

1. **Back up the private key** (`~/.config/sops/age/keys.txt`) in your password
   manager. Lose it and these secrets are unrecoverable.

1. **macOS gotcha:** sops' default key path on macOS is
   `~/Library/Application Support/sops/age/keys.txt`, *not* `~/.config/...`. Point
   sops at the real file explicitly (add to your shell profile):

   ```sh
   export SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/keys.txt
   ```

1. Validate encryption/decryption round-trips:

   ```sh
   sops -d environments/sp-staging/secrets/cloudflared.yaml >/dev/null && echo "decrypt OK"
   ```

## Deploy Cloudflared

Serves `https://radius.collabornet.japoofis.com`.

First confirm the manifests render with secrets decrypted (needs a valid `gaia`
context for the guard hook, but does not touch the cluster):

```sh
export KUBECONFIG=~/.kube/gaia.yaml
export SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/keys.txt
cd projects/collabornet/deploy/helmfile
helmfile -e sp-staging template   # expect "Decrypting secret ..." + rendered manifests
```

Then `diff` / `apply` (`radius-ui` gets added in the next increment):

```sh
helmfile -e sp-staging diff -l name=cloudflared
helmfile -e sp-staging apply -l name=cloudflared
```

## Deploy Radius UI

```sh
helmfile -e sp-staging diff -l name=radius-ui
helmfile -e sp-staging apply -l name=radius-ui
```
