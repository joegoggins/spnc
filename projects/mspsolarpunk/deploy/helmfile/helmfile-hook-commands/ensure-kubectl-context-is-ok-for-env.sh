#!/usr/bin/env bash
###
# helmfile `prepare` hook.
#
# wb-local: idempotently creates the `wb-local` kind cluster, targets it, and
# builds+loads services/web — so `helmfile -e wb-local apply` alone is enough,
# no separate `kind create`/`docker build` step (unlike collabornet's sp-local,
# which relies on Tilt for this).
# wb-staging / wb-prod: refuses to apply if the current kubectl context
# doesn't match the env's expected cluster.
#
# To skip: comment out the hook in helmfile.yaml.gotmpl.
###
set -euo pipefail

ENV_NAME=${1:?"1st arg required: env name (e.g. wb-local, wb-staging, wb-prod)"}
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$HERE/../../.." && pwd)"

ok() { echo "ctx '$(kubectl config current-context)' OK for env '$ENV_NAME'"; }
die() { echo "Refusing: ctx='$(kubectl config current-context)' is not a valid target for env '$ENV_NAME'"; exit 1; }

case "$ENV_NAME" in
  wb-local)
    if ! kind get clusters 2>/dev/null | grep -qx wb-local; then
      kind create cluster --name wb-local --config "$PROJECT_ROOT/kind-cluster.yaml"
    fi
    kind export kubeconfig --name wb-local
    docker build -t mspsolarpunk-web:local "$PROJECT_ROOT/services/web"
    kind load docker-image mspsolarpunk-web:local --name wb-local
    # Same tag every build, so helmfile's own diff sees no manifest change and
    # won't roll the pod on its own — force it so edits under services/web
    # actually show up. `|| true`: no-op before the release's first install.
    kubectl -n wb-local rollout restart deployment/web 2>/dev/null || true
    ok
    ;;
  wb-staging)
    [[ "$(kubectl config current-context)" == *"gaia"* ]] && ok || die ;;
  wb-prod)
    # hope-island is down/broken; gaia is a temporary stand-in until it's back.
    ctx="$(kubectl config current-context)"
    [[ "$ctx" == *"gaia"* || "$ctx" == *"hope-island"* ]] && ok || die ;;
  *)
    echo "Unknown env '$ENV_NAME'"; exit 1 ;;
esac
