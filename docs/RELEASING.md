# Releasing

## Version scheme

`MAJOR.MINOR.PATCH`, independent of Chromium's numbering. The Chromium base for
a release is recorded in `CHROMIUM_VERSION`, shown in `evil://version`, and
listed in the release notes. Users should never have to guess which Chromium a
build is based on.

## Channels

| Channel | Cadence | Cut from |
| --- | --- | --- |
| Stable | On merit | A beta that held for two weeks |
| Beta | Weekly, Thursday | `main`, after the automated suite passes |
| Nightly | Daily | Tip of `main`, tagged with the date and short SHA |

Nightlies are pruned after 30 days. Tagged builds referenced from the changelog
stay available.

## Checklist

1. **Bump.** `CHROMIUM_VERSION` if this rides a new Chromium; refresh the patch
   set ([PATCHES.md](PATCHES.md)).
2. **Build all three platforms** from a clean checkout — no incremental builds
   in a release.
3. **Run the suite.** `make test`, plus the manual pass in [TESTING.md](TESTING.md).
4. **Package and checksum.** `make package && make checksums`.
5. **Sign.**
   - Windows: Authenticode sign the installer and `chrome.exe`.
   - macOS: `codesign --deep --options runtime`, then `notarytool submit`, then
     `xcrun stapler staple`.
   - Linux: detached GPG signature over `SHA256SUMS`.
6. **Verify the signatures on a different machine** than the one that made them.
7. **Publish** to GitHub Releases with the `SHA256SUMS` and its signature.
8. **Update the site**: `changelog.html`, and the version strings on
   `download.html`. The website repository is `evil-browser/evil.st`.
9. **Point the updater** at the new build only after the artefacts are live and
   the checksums have been verified from the published URLs.

## Security releases

Upstream security fixes ship within 72 hours of the Chromium release, on every
channel, and skip the beta soak. A patch that cannot be refreshed in that window
is dropped for the release rather than delaying it.

## Never

- Never publish an artefact whose checksum is not in a signed `SHA256SUMS`.
- Never rebuild a released version in place. Cut a new patch number.
- Never ship a build made from a tree with uncommitted patch changes; CI refuses
  it, and so should you.
