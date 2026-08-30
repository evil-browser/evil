#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

RUN_HOOKS=1
INSTALL_DEPS=0
for arg in "$@"; do
  case "$arg" in
    --no-hooks) RUN_HOOKS=0 ;;
    --install-deps) INSTALL_DEPS=1 ;;
    -h|--help) echo "usage: sync.sh [--no-hooks] [--install-deps]"; exit 0 ;;
    *) die "unknown argument: $arg" ;;
  esac
done

use_depot_tools
log "Target: Chromium $CHROMIUM_VERSION"

if [[ ! -d "$SRC_DIR" ]]; then
  log "First checkout — this downloads tens of gigabytes and can take hours"
  confirm "Continue?" || exit 1
  cd "$REPO_ROOT" || die "cannot enter $REPO_ROOT"
  cat > .gclient <<GCLIENT
solutions = [
  {
    "name": "src",
    "url": "https://chromium.googlesource.com/chromium/src.git",
    "managed": False,
    "custom_deps": {},
    "custom_vars": {
      "checkout_pgo_profiles": True,
    },
  },
]
GCLIENT
  fetch --nohooks --no-history chromium
else
  log "Updating existing checkout"
fi

require_checkout

if [[ -n "$(git -C "$SRC_DIR" status --porcelain)" ]]; then
  die "src/ has local modifications. Run 'make unpatch' before syncing."
fi

log "Fetching tag $CHROMIUM_VERSION"
git -C "$SRC_DIR" fetch --tags --depth 1 origin "refs/tags/$CHROMIUM_VERSION"
git -C "$SRC_DIR" checkout --detach "$CHROMIUM_VERSION"

log "gclient sync"
sync_args=(--with_branch_heads --with_tags --delete_unversioned_trees --reset)
[[ "$RUN_HOOKS" == "1" ]] || sync_args+=(--nohooks)
gclient sync "${sync_args[@]}"

if [[ "$INSTALL_DEPS" == "1" && "$(host_os)" == "linux" ]]; then
  log "Installing system build dependencies (sudo)"
  "$SRC_DIR/build/install-build-deps.sh" --no-prompt
fi

log "Synced to $CHROMIUM_VERSION"
info "next: make patch"
