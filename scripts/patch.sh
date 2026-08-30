#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

SERIES="$REPO_ROOT/patches/series"
STAMP="$SRC_DIR/.evil-patches-applied"

read_series() {
  [[ -f "$SERIES" ]] || die "missing $SERIES"
  grep -vE '^\s*(#|$)' "$SERIES" || true
}

cmd_apply() {
  require_checkout
  local applied=0 total=0
  if [[ -f "$STAMP" ]]; then
    warn "patches already applied (per $STAMP). Run 'patch.sh revert' first."
    exit 1
  fi
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
      die "patch failed: patches/$rel — see docs/PATCHES.md on refreshing patches."
    fi
  done < <(read_series)

  if [[ "$total" -eq 0 ]]; then
    warn "patches/series is empty — nothing to apply. You are building stock Chromium."
    exit 0
  fi
  date -u +"%Y-%m-%dT%H:%M:%SZ" > "$STAMP"
  log "Applied $applied/$total patches"
}

cmd_revert() {
  require_checkout
  log "Resetting src/ to $CHROMIUM_VERSION"
  git -C "$SRC_DIR" checkout -- .
  git -C "$SRC_DIR" clean -fd
  rm -f "$STAMP"
  log "Clean"
}

cmd_status() {
  require_checkout
  echo "chromium:  $CHROMIUM_VERSION"
  echo "checkout:  $(git -C "$SRC_DIR" rev-parse --short HEAD 2>/dev/null || echo '?')"
  if [[ -f "$STAMP" ]]; then
    echo "patches:   applied $(cat "$STAMP")"
  else
    echo "patches:   not applied"
  fi
  local n; n="$(read_series | wc -l | tr -d ' ')"
  echo "series:    $n patches"
  local dirty; dirty="$(git -C "$SRC_DIR" status --porcelain | wc -l | tr -d ' ')"
  echo "dirty:     $dirty modified files in src/"
}

cmd_export() {
  require_checkout
  local target="${1:-}"
  [[ -n "$target" ]] || die "usage: patch.sh export <category/name.patch>  (e.g. privacy/0007-drop-safe-browsing.patch)"
  local out="$REPO_ROOT/patches/$target"
  mkdir -p "$(dirname "$out")"
  git -C "$SRC_DIR" diff --binary > "$out"
  [[ -s "$out" ]] || { rm -f "$out"; die "no changes in src/ to export"; }
  log "Wrote patches/$target ($(wc -l < "$out" | tr -d ' ') lines)"
  grep -qxF "$target" "$SERIES" || {
    echo "$target" >> "$SERIES"
    info "appended to patches/series — reorder it if it must apply earlier"
  }
}

case "${1:-}" in
  apply)  cmd_apply ;;
  revert) cmd_revert ;;
  status) cmd_status ;;
  export) shift; cmd_export "$@" ;;
  *) echo "usage: patch.sh {apply|revert|status|export <path>}"; exit 1 ;;
esac
