#!/usr/bin/env bash
###
# helmfile `prepare` hook — refuses to apply if the current kubectl context
# doesn't match the env's expected cluster.
#
# To skip: comment out the hook in helmfile.yaml.gotmpl.
###
set -euo pipefail

ENV_NAME=${1:?"1st arg required: env name (e.g. sp-local, sp-staging)"}

current_context=$(kubectl config current-context)

ok() { echo "ctx '$current_context' OK for env '$ENV_NAME'"; }
die() { echo "Refusing: ctx='$current_context' is not a valid target for env '$ENV_NAME'"; exit 1; }

case "$ENV_NAME" in
  sp-local)
    [[ "$current_context" == "kind-sp-local" ]] && ok || die ;;
  sp-staging)
    [[ "$current_context" == *"gaia"* ]] && ok || die ;;
  *)
    echo "Unknown env '$ENV_NAME'"; exit 1 ;;
esac
