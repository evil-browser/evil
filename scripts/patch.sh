#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

SERIES="$REPO_ROOT/patches/series"
UNGOOGLED_DIR="$REPO_ROOT/third_party/ungoogled-chromium"
DOMSUB_CACHE="$REPO_ROOT/out/domsubcache.tar.gz"
STAMP="$SRC_DIR/.evil-patches-applied"
EXCLUDE_LIST="$REPO_ROOT/patches/upstream-exclude.list"

require_upstream() {
  [[ -d "$UNGOOGLED_DIR/patches" ]] || die "ungoogled-chromium not fetched. Run 'make upstream' first."
  local want have
  want="$CHROMIUM_VERSION"
  have="$(tr -d ' \n' < "$UNGOOGLED_DIR/chromium_version.txt")"
  [[ "$want" == "$have" ]] || die "ungoogled targets Chromium $have, checkout is pinned to $want"
}

read_series() {
  [[ -f "$SERIES" ]] || die "missing $SERIES"
  grep -vE '^\s*(#|$)' "$SERIES" || true
}

cmd_apply() {
  require_checkout
  require_upstream
  [[ -f "$STAMP" ]] && die "patches already applied. Run 'make unpatch' first."

  log "Pruning bundled binaries"
  python3 "$UNGOOGLED_DIR/utils/prune_binaries.py" "$SRC_DIR" "$UNGOOGLED_DIR/pruning.list"

  local staged="$OUT_ROOT/upstream-patches"
  rm -rf "$staged"
  mkdir -p "$OUT_ROOT"
  cp -a "$UNGOOGLED_DIR/patches" "$staged"

  local excluded=0
  if [[ -f "$EXCLUDE_LIST" ]]; then
    while IFS= read -r skip; do
      [[ -n "$skip" ]] || continue
      case "$skip" in \#*) continue ;; esac
      if grep -qxF "$skip" "$staged/series"; then
        grep -vxF "$skip" "$staged/series" > "$staged/series.tmp"
        mv "$staged/series.tmp" "$staged/series"
        excluded=$((excluded + 1))
        info "excluded $skip"
      else
        warn "exclusion not found upstream, drop it from patches/upstream-exclude.list: $skip"
      fi
    done < "$EXCLUDE_LIST"
  fi

  log "Applying ungoogled-chromium patches ($(grep -cv '^\s*$' "$staged/series") applied, $excluded excluded)"
  python3 "$UNGOOGLED_DIR/utils/patches.py" apply "$SRC_DIR" "$staged"

  if [[ "${EVIL_DOMSUB:-0}" == "1" ]]; then
    log "Substituting Google domains"
    warn "this breaks Chrome Web Store installation and first-run extension fetch"
    mkdir -p "$(dirname "$DOMSUB_CACHE")"
    rm -f "$DOMSUB_CACHE"
    python3 "$UNGOOGLED_DIR/utils/domain_substitution.py" apply \
      -r "$UNGOOGLED_DIR/domain_regex.list" \
      -f "$UNGOOGLED_DIR/domain_substitution.list" \
      -c "$DOMSUB_CACHE" \
      "$SRC_DIR"
  else
    info "domain substitution skipped, set EVIL_DOMSUB=1 to enable"
  fi

  local applied=0 total=0
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    total=$((total + 1))
    local file="$REPO_ROOT/patches/$rel"
    [[ -f "$file" ]] || die "listed in series but missing: patches/$rel"
    printf '  %-58s' "$rel"
    if git -C "$SRC_DIR" apply --3way --whitespace=nowarn "$file" 2>/tmp/evil-patch-err; then
      echo "ok"
      applied=$((applied + 1))
    else
      echo "FAILED"
      cat /tmp/evil-patch-err >&2
      die "patch failed: patches/$rel"
    fi
  done < <(read_series)

  if [[ "$total" -gt 0 ]]; then
    log "Applied $applied/$total evil patches on top"
  else
    info "no evil patches in series yet"
  fi

  date -u +"%Y-%m-%dT%H:%M:%SZ" > "$STAMP"
  log "Tree patched"
}

cmd_revert() {
  require_checkout
  if [[ -f "$DOMSUB_CACHE" ]]; then
    log "Reverting domain substitution"
    python3 "$UNGOOGLED_DIR/utils/domain_substitution.py" revert -c "$DOMSUB_CACHE" "$SRC_DIR" || true
    rm -f "$DOMSUB_CACHE"
  fi
  log "Resetting src/ to $CHROMIUM_VERSION"
  git -C "$SRC_DIR" checkout -- .
  git -C "$SRC_DIR" clean -fd
  rm -f "$STAMP"
  log "Clean"
}

cmd_status() {
  require_checkout
  echo "chromium:   $CHROMIUM_VERSION"
  echo "checkout:   $(git -C "$SRC_DIR" rev-parse --short HEAD 2>/dev/null || echo '?')"
  if [[ -d "$UNGOOGLED_DIR/patches" ]]; then
    echo "ungoogled:  $(tr -d ' \n' < "$REPO_ROOT/UNGOOGLED_VERSION") ($(grep -cv '^\s*$' "$UNGOOGLED_DIR/patches/series") patches)"
  else
    echo "ungoogled:  not fetched"
  fi
  echo "excluded:   $(grep -cvE '^\s*(#|$)' "$EXCLUDE_LIST" 2>/dev/null || echo 0) upstream patches"
  echo "evil:       $(read_series | grep -c . || echo 0) patches"
  echo "domsub:     ${EVIL_DOMSUB:-0}"
  if [[ -f "$STAMP" ]]; then
    echo "state:      applied $(cat "$STAMP")"
  else
    echo "state:      not applied"
  fi
  echo "dirty:      $(git -C "$SRC_DIR" status --porcelain | wc -l | tr -d ' ') modified files in src/"
}

cmd_export() {
  require_checkout
  local target="${1:-}"
  [[ -n "$target" ]] || die "usage: patch.sh export <category/name.patch>"
  local out="$REPO_ROOT/patches/$target"
  mkdir -p "$(dirname "$out")"
  git -C "$SRC_DIR" diff --binary > "$out"
  [[ -s "$out" ]] || { rm -f "$out"; die "no changes in src/ to export"; }
  log "Wrote patches/$target ($(wc -l < "$out" | tr -d ' ') lines)"
  grep -qxF "$target" "$SERIES" || {
    echo "$target" >> "$SERIES"
    info "appended to patches/series"
  }
}

case "${1:-}" in
  apply)  cmd_apply ;;
  revert) cmd_revert ;;
  status) cmd_status ;;
  export) shift; cmd_export "$@" ;;
  *) echo "usage: patch.sh {apply|revert|status|export <path>}"; exit 1 ;;
esac
