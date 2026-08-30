#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

CONFIG=release
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG="$2"; shift 2 ;;
    -h|--help) echo "usage: package.sh [--config release|debug]"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

use_depot_tools
OUT_DIR="$OUT_ROOT/$CONFIG"
[[ -d "$OUT_DIR" ]] || die "no build at ${OUT_DIR#$REPO_ROOT/} — run 'make build' first."
VERSION="$(awk -F= '/^MAJOR/{m=$2} /^MINOR/{n=$2} /^BUILD/{b=$2} /^PATCH/{p=$2} END{print m"."n"."b"."p}' "$SRC_DIR/chrome/VERSION")"
CPU="$(host_cpu)"
mkdir -p "$DIST_DIR"

install_payload() {
  local target="$1"
  mkdir -p "$target/extensions" "$target/External Extensions"
  cp "$REPO_ROOT/config/initial_preferences" "$target/initial_preferences"
  cp "$REPO_ROOT"/config/external_extensions/*.json "$target/External Extensions/" 2>/dev/null || true
  if [[ -d "$DIST_DIR/extensions" ]]; then
    cp "$DIST_DIR"/extensions/*.crx "$target/extensions/" 2>/dev/null || true
    for crx in "$DIST_DIR"/extensions/*.crx; do
      [[ -e "$crx" ]] || continue
      local name version
      name="$(basename "$crx" .crx)"
      version="$(cat "$DIST_DIR/extensions/$name.version" 2>/dev/null || echo 1.0.0)"
      cat > "$target/External Extensions/$name.json" <<JSON
{
  "external_crx": "extensions/$name.crx",
  "external_version": "$version"
}
JSON
    done
  else
    warn "no packed extensions in dist/extensions — run tools/pack-extensions.sh first"
  fi
}

log "Packaging evil $VERSION ($(host_os)/$CPU, $CONFIG)"

case "$(host_os)" in
  linux)
    stage="$DIST_DIR/evil-$VERSION-$CPU"
    rm -rf "$stage"; mkdir -p "$stage"
    for item in chrome chrome_crashpad_handler chrome_sandbox icudtl.dat *.pak *.so locales resources; do
      cp -a "$OUT_DIR"/$item "$stage/" 2>/dev/null || true
    done
    mv "$stage/chrome" "$stage/evil"
    cp "$REPO_ROOT/resources/branding/evil.desktop" "$stage/" 2>/dev/null || true
    install_payload "$stage"
    tar -C "$DIST_DIR" -cJf "$DIST_DIR/evil-$VERSION-$CPU.tar.xz" "$(basename "$stage")"
    rm -rf "$stage"
    info "wrote dist/evil-$VERSION-$CPU.tar.xz"

    if command -v appimagetool >/dev/null 2>&1; then
      info "appimagetool found — building AppImage"
      "$REPO_ROOT/tools/make_appimage.sh" "$OUT_DIR" "$DIST_DIR" "$VERSION" "$CPU"
    else
      warn "appimagetool not on PATH — skipping AppImage (see docs/RELEASING.md)"
    fi
    if command -v fpm >/dev/null 2>&1; then
      info "fpm found — building .deb and .rpm"
      "$REPO_ROOT/tools/make_packages.sh" "$OUT_DIR" "$DIST_DIR" "$VERSION" "$CPU"
    else
      warn "fpm not on PATH — skipping .deb/.rpm (see docs/RELEASING.md)"
    fi
    ;;

  mac)
    app="$OUT_DIR/evil.app"
    [[ -d "$app" ]] || app="$OUT_DIR/Chromium.app"
    [[ -d "$app" ]] || die "no .app bundle in ${OUT_DIR#$REPO_ROOT/}"
    dmg="$DIST_DIR/evil-$VERSION-$CPU.dmg"
    rm -f "$dmg"
    if command -v create-dmg >/dev/null 2>&1; then
      create-dmg --volname "evil $VERSION" --app-drop-link 480 220 "$dmg" "$app"
    else
      hdiutil create -volname "evil $VERSION" -srcfolder "$app" -ov -format UDZO "$dmg"
    fi
    info "wrote ${dmg#$REPO_ROOT/}"
    warn "unsigned. Signing and notarisation: docs/RELEASING.md"
    ;;

  win)
    installer="$OUT_DIR/mini_installer.exe"
    [[ -f "$installer" ]] || die "mini_installer.exe not built — run: scripts/build.sh --target mini_installer"
    cp "$installer" "$DIST_DIR/evil-$VERSION-$CPU.exe"
    info "wrote dist/evil-$VERSION-$CPU.exe"
    (cd "$OUT_DIR" && zip -qr "$DIST_DIR/evil-$VERSION-$CPU-portable.zip" . -i 'chrome.exe' '*.dll' '*.pak' 'locales/*' 'resources/*')
    info "wrote dist/evil-$VERSION-$CPU-portable.zip"
    ;;
esac

log "Done — now run 'make checksums'"
