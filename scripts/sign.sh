#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

CONFIG=release
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG="$2"; shift 2 ;;
    -h|--help) echo "usage: sign.sh [--config release|debug]"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -d "$DIST_DIR" ]] || die "nothing in dist/ — run 'make package' first."

case "$(host_os)" in
  mac)
    : "${APPLE_TEAM_ID:?set APPLE_TEAM_ID}"
    : "${APPLE_NOTARY_PROFILE:?set APPLE_NOTARY_PROFILE (see: xcrun notarytool store-credentials)}"
    app="$OUT_ROOT/$CONFIG/evil.app"
    [[ -d "$app" ]] || die "no app bundle at $app"

    log "Signing $app"
    codesign --force --deep --timestamp --options runtime \
             --entitlements "$REPO_ROOT/build/entitlements.plist" \
             --sign "Developer ID Application: ($APPLE_TEAM_ID)" "$app"
    codesign --verify --deep --strict --verbose=2 "$app"

    for dmg in "$DIST_DIR"/*.dmg; do
      [[ -e "$dmg" ]] || continue
      log "Notarising $(basename "$dmg")"
      codesign --force --timestamp --sign "Developer ID Application: ($APPLE_TEAM_ID)" "$dmg"
      xcrun notarytool submit "$dmg" --keychain-profile "$APPLE_NOTARY_PROFILE" --wait
      xcrun stapler staple "$dmg"
      xcrun stapler validate "$dmg"
    done
    ;;

  win)
    : "${WINDOWS_CERT_THUMBPRINT:?set WINDOWS_CERT_THUMBPRINT}"
    require_cmd signtool
    for f in "$DIST_DIR"/*.exe; do
      [[ -e "$f" ]] || continue
      log "Authenticode signing $(basename "$f")"
      signtool sign //sha1 "$WINDOWS_CERT_THUMBPRINT" //fd sha256 //tr http://timestamp.digicert.com //td sha256 "$f"
      signtool verify //pa //v "$f"
    done
    ;;

  linux)
    : "${GPG_KEY_ID:?set GPG_KEY_ID}"
    require_cmd gpg
    [[ -f "$DIST_DIR/SHA256SUMS" ]] || die "run 'make checksums' first"
    log "Signing SHA256SUMS"
    gpg --batch --yes --local-user "$GPG_KEY_ID" --armor --detach-sign "$DIST_DIR/SHA256SUMS"
    gpg --verify "$DIST_DIR/SHA256SUMS.asc" "$DIST_DIR/SHA256SUMS"
    ;;
esac

log "Signed. Verify on a different machine before publishing (docs/RELEASING.md)."
