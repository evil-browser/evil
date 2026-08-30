#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

UNGOOGLED_REPO="${UNGOOGLED_REPO:-https://github.com/ungoogled-software/ungoogled-chromium.git}"
UNGOOGLED_VERSION="$(tr -d ' \n' < "$REPO_ROOT/UNGOOGLED_VERSION")"
UNGOOGLED_DIR="$REPO_ROOT/third_party/ungoogled-chromium"

case "${1:-fetch}" in
  fetch)
    if [[ -d "$UNGOOGLED_DIR/.git" ]]; then
      log "Updating ungoogled-chromium"
      git -C "$UNGOOGLED_DIR" fetch --tags --quiet origin
    else
      log "Cloning ungoogled-chromium"
      mkdir -p "$(dirname "$UNGOOGLED_DIR")"
      git clone --quiet "$UNGOOGLED_REPO" "$UNGOOGLED_DIR"
    fi
    git -C "$UNGOOGLED_DIR" checkout --quiet --detach "$UNGOOGLED_VERSION"

    upstream_chromium="$(tr -d ' \n' < "$UNGOOGLED_DIR/chromium_version.txt")"
    if [[ "$upstream_chromium" != "$CHROMIUM_VERSION" ]]; then
      die "version mismatch: UNGOOGLED_VERSION $UNGOOGLED_VERSION targets Chromium $upstream_chromium, but CHROMIUM_VERSION says $CHROMIUM_VERSION"
    fi

    log "ungoogled-chromium $UNGOOGLED_VERSION for Chromium $upstream_chromium"
    info "$(grep -cv '^\s*$' "$UNGOOGLED_DIR/patches/series") upstream patches"
    info "$(grep -cv '^\s*$' "$UNGOOGLED_DIR/pruning.list") files to prune"
    ;;

  status)
    if [[ ! -d "$UNGOOGLED_DIR/.git" ]]; then
      echo "ungoogled: not fetched"
      exit 0
    fi
    echo "ungoogled:  $UNGOOGLED_VERSION"
    echo "chromium:   $(tr -d ' \n' < "$UNGOOGLED_DIR/chromium_version.txt")"
    echo "checkout:   $(git -C "$UNGOOGLED_DIR" rev-parse --short HEAD)"
    ;;

  latest)
    log "Latest ungoogled-chromium releases"
    git ls-remote --tags --refs --sort=-v:refname "$UNGOOGLED_REPO" \
      | awk -F/ '{print "  " $NF}' | head -10
    ;;

  *)
    echo "usage: upstream.sh {fetch|status|latest}"
    exit 1
    ;;
esac
