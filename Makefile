SHELL := /bin/bash
.DEFAULT_GOAL := help

CONFIG ?= release
JOBS   ?=

.PHONY: help dev pack bootstrap sync patch unpatch status build build-debug package checksums test clean distclean version

help: ## Show this help
	@echo "evil — make targets"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[1m%-14s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Variables: CONFIG=release|debug  JOBS=<n>"

dev: ## Run the extensions and theme on a locally installed Chromium
	@scripts/dev-run.sh

pack: ## Pack the bundled extensions and theme into CRXs
	@tools/pack-extensions.sh

bootstrap: ## Fetch depot_tools and check prerequisites
	@scripts/bootstrap.sh

sync: ## Fetch/update the Chromium tree at the pinned version
	@scripts/sync.sh

patch: ## Apply the patch set to src/
	@scripts/patch.sh apply

unpatch: ## Revert the patch set, leaving a clean upstream tree
	@scripts/patch.sh revert

status: ## Show patch and checkout status
	@scripts/patch.sh status

build: ## Build the browser (CONFIG=release by default)
	@scripts/build.sh --config $(CONFIG) $(if $(JOBS),--jobs $(JOBS),)

build-debug: ## Build the debug configuration
	@scripts/build.sh --config debug $(if $(JOBS),--jobs $(JOBS),)

package: ## Package the built browser into dist/
	@scripts/package.sh --config $(CONFIG)

checksums: ## Write dist/SHA256SUMS for everything in dist/
	@scripts/checksums.sh

test: ## Run the evil-specific test targets
	@scripts/build.sh --config $(CONFIG) --target evil_unittests
	@out/$(CONFIG)/evil_unittests

version: ## Print the pinned Chromium version
	@cat CHROMIUM_VERSION

clean: ## Remove build output, keep the checkout
	rm -rf out dist

distclean: clean ## Also remove the Chromium checkout (40+ GB)
	rm -rf src .gclient .gclient_entries .gclient_previous_sync_commits
