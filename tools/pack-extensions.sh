#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$REPO_ROOT/dist/extensions}"
KEY_DIR="${EVIL_EXT_KEYS:-$REPO_ROOT/.keys}"
BROWSER="${EVIL_PACK_BINARY:-}"

find_binary() {
  local candidates=(
    "/Applications/Chromium.app/Contents/MacOS/Chromium"
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    chromium chromium-browser google-chrome google-chrome-stable
  )
  for c in "${candidates[@]}"; do
    [[ -x "$c" ]] && { echo "$c"; return 0; }
    command -v "$c" >/dev/null 2>&1 && { command -v "$c"; return 0; }
  done
  return 1
}

[[ -n "$BROWSER" ]] || BROWSER="$(find_binary)" || {
  echo "error: no Chromium binary found to pack with. Set EVIL_PACK_BINARY." >&2
  exit 1
}

mkdir -p "$OUT_DIR" "$KEY_DIR"

pack() {
  local name="$1" src="$2"
  local key="$KEY_DIR/$name.pem"
  local args=(--pack-extension="$src")
  [[ -f "$key" ]] && args+=(--pack-extension-key="$key")
  "$BROWSER" "${args[@]}" --no-message-box >/dev/null 2>&1 || true
  local crx="${src}.crx"
  local newkey="${src}.pem"
  [[ -f "$crx" ]] || { echo "error: packing $name produced no crx" >&2; return 1; }
  [[ -f "$newkey" ]] && mv "$newkey" "$key"
  mv "$crx" "$OUT_DIR/$name.crx"
  local version
  version="$(python3 -c "import json,sys;print(json.load(open('$src/manifest.json'))['version'])")"
  cat > "$OUT_DIR/$name.version" <<VER
$version
VER
  echo "  $name  $version  $(du -h "$OUT_DIR/$name.crx" | cut -f1)"
}

echo "Packing with $(basename "$BROWSER")"
pack evil-shield "$REPO_ROOT/extensions/evil-shield"
pack evil-clean  "$REPO_ROOT/extensions/evil-clean"
pack evil-guard  "$REPO_ROOT/extensions/evil-guard"
pack evil-dark   "$REPO_ROOT/theme/evil-dark"

echo
echo "CRX files:  ${OUT_DIR#$REPO_ROOT/}"
echo "Signing keys: ${KEY_DIR#$REPO_ROOT/} (never commit these)"
