#!/usr/bin/env bash
set -euo pipefail
OUT_DIR="$1"; DIST_DIR="$2"; VERSION="$3"; CPU="$4"
command -v fpm >/dev/null || { echo "fpm not on PATH (gem install fpm)" >&2; exit 1; }

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(mktemp -d)"
mkdir -p "$ROOT/opt/evil" "$ROOT/usr/share/applications" "$ROOT/usr/bin"

cp -a "$OUT_DIR"/{chrome,chrome_crashpad_handler,icudtl.dat} "$ROOT/opt/evil/"
cp -a "$OUT_DIR"/*.pak "$OUT_DIR"/*.so "$ROOT/opt/evil/" 2>/dev/null || true
cp -a "$OUT_DIR"/locales "$OUT_DIR"/resources "$ROOT/opt/evil/" 2>/dev/null || true
mv "$ROOT/opt/evil/chrome" "$ROOT/opt/evil/evil"
ln -s /opt/evil/evil "$ROOT/usr/bin/evil"
cp "$REPO/resources/branding/evil.desktop" "$ROOT/usr/share/applications/"

for size in 16 32 48 64 128 256; do
  d="$ROOT/usr/share/icons/hicolor/${size}x${size}/apps"
  mkdir -p "$d"
  cp "$REPO/resources/branding/product_logo_$size.png" "$d/evil.png"
done

case "$CPU" in x64) DEB_ARCH=amd64; RPM_ARCH=x86_64 ;; arm64) DEB_ARCH=arm64; RPM_ARCH=aarch64 ;; esac

common=(
  -s dir -C "$ROOT"
  --name evil --version "$VERSION" --license BSD-3-Clause
  --vendor "The evil browser authors" --maintainer "packages@evil.st"
  --url "https://evil.st" --description "Fast, private, feather-light browser"
  --category net
)

fpm "${common[@]}" -t deb --architecture "$DEB_ARCH" \
  --depends libnss3 --depends libgtk-3-0 --depends libasound2 \
  -p "$DIST_DIR/evil_${VERSION}_${DEB_ARCH}.deb" .

fpm "${common[@]}" -t rpm --architecture "$RPM_ARCH" \
  --depends nss --depends gtk3 --depends alsa-lib \
  -p "$DIST_DIR/evil-${VERSION}.${RPM_ARCH}.rpm" .

echo "wrote deb and rpm into $DIST_DIR"
