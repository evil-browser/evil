#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

[[ -d "$DIST_DIR" ]] || die "nothing in dist/ — run 'make package' first."
cd "$DIST_DIR" || die "cannot enter $DIST_DIR"

shopt -s nullglob
files=(*.exe *.zip *.dmg *.tar.xz *.AppImage *.deb *.rpm)
[[ ${#files[@]} -gt 0 ]] || die "no artefacts found in dist/"

: > SHA256SUMS
for f in "${files[@]}"; do
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" >> SHA256SUMS
  else
    shasum -a 256 "$f" >> SHA256SUMS
  fi
done

log "dist/SHA256SUMS"
cat SHA256SUMS
info "sign it before publishing: gpg --armor --detach-sign SHA256SUMS"
