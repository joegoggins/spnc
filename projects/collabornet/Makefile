.PHONY: up down migrate seed revision \
        kind-up kind-down kind-use tilt-ci tilt-up tilt-down \
        lint format typecheck check test \
        helmfile-diff helmfile-apply helmfile-destroy

up:
	$(MAKE) kind-up
	$(MAKE) kind-use
	$(MAKE) tilt-ci
	@echo "If workloads are healthy, run 'make tilt-up'"

down:
	$(MAKE) tilt-down
	$(MAKE) kind-down

MIGRATE_ENV ?= sp-local
# Local charts render un-namespaced and land in `default` (see Tiltfile); remote
# envs deploy into a namespace named after the env.
MIGRATE_NAMESPACE := $(if $(filter sp-local,$(MIGRATE_ENV)),default,$(MIGRATE_ENV))
SEED_FIXTURE_SET ?= demo
CONTEXT_GUARD := ./deploy/helmfile/helmfile-hook-commands/ensure-kubectl-context-is-ok-for-env.sh

migrate:
	$(CONTEXT_GUARD) $(MIGRATE_ENV)
	kubectl -n $(MIGRATE_NAMESPACE) exec deployment/app-api -- \
		alembic upgrade head

seed:
	$(CONTEXT_GUARD) $(MIGRATE_ENV)
	kubectl -n $(MIGRATE_NAMESPACE) exec deployment/app-api -- \
		python -m app_api.seed --fixture-set $(SEED_FIXTURE_SET)

###
# Commands for interacting with a local Kubernetes on Docker with Kind
###
KIND := kind

# Extra @if logic is to make this idempotent.
kind-up:
	@if $(KIND) get clusters 2>/dev/null | grep -qx sp-local; then \
		echo "kind cluster 'sp-local' already exists — skipping create"; \
	else \
		$(KIND) create cluster --name sp-local --config kind-cluster.yaml; \
	fi

kind-down:
	$(KIND) delete cluster --name sp-local

kind-use:
	$(KIND) export kubeconfig --name sp-local

###
# Commands for interacting with tilt
###
TILT := tilt

tilt-ci:
	$(TILT) ci

tilt-up:
	$(TILT) up

tilt-down:
	$(TILT) down

# --- Lint / typecheck / test ----------------------------------------------- #
lint:
	uv run ruff check services

format:
	uv run ruff format services
	uv run ruff check --fix services

typecheck:
	uv run pyright

check: lint typecheck

test:
	uv run pytest services/app-api


# --- Deploy --------------------------------------------------------------- #
HELMFILE := helmfile
HELMFILE_DIR := deploy/helmfile/app
HELMFILE_ENV ?= sp-staging
helmfile-diff:
	cd $(HELMFILE_DIR) && exec $(HELMFILE) -e $(HELMFILE_ENV) diff
helmfile-apply:
	cd $(HELMFILE_DIR) && exec $(HELMFILE) -e $(HELMFILE_ENV) apply
helmfile-destroy:
	cd $(HELMFILE_DIR) && exec $(HELMFILE) -e $(HELMFILE_ENV) destroy