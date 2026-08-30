#!/usr/bin/env bash
set -euo pipefail
OUT_DIR="$1"; DIST_DIR="$2"; VERSION="$3"; CPU="$4"
command -v appimagetool >/dev/null || { echo "appimagetool not on PATH" >&2; exit 1; }

APPDIR="$(mktemp -d)/evil.AppDir"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/256x256/apps"

cp -a "$OUT_DIR"/{chrome,chrome_crashpad_handler,icudtl.dat} "$APPDIR/usr/bin/"
cp -a "$OUT_DIR"/*.pak "$OUT_DIR"/*.so "$APPDIR/usr/bin/" 2>/dev/null || true
cp -a "$OUT_DIR"/locales "$OUT_DIR"/resources "$APPDIR/usr/bin/" 2>/dev/null || true
mv "$APPDIR/usr/bin/chrome" "$APPDIR/usr/bin/evil"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cp "$REPO/resources/branding/evil.desktop" "$APPDIR/evil.desktop"
cp "$REPO/resources/branding/evil.desktop" "$APPDIR/usr/share/applications/"
cp "$REPO/resources/branding/product_logo_256.png" "$APPDIR/evil.png"
cp "$REPO/resources/branding/product_logo_256.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/evil.png"
sed -i 's#^Exec=.*#Exec=evil %U#' "$APPDIR/evil.desktop" "$APPDIR/usr/share/applications/evil.desktop"

cat > "$APPDIR/AppRun" <<'RUN'
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/evil" "$@"
RUN
chmod +x "$APPDIR/AppRun"

case "$CPU" in
  x64)   ARCH=x86_64 ;;
  arm64) ARCH=aarch64 ;;
  *)     echo "unknown cpu: $CPU" >&2; exit 1 ;;
esac
export ARCH
appimagetool "$APPDIR" "$DIST_DIR/evil-$VERSION-$ARCH.AppImage"
echo "wrote $DIST_DIR/evil-$VERSION-$ARCH.AppImage"
