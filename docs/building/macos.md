# Building on macOS

Reference platform: macOS 14, Apple Silicon. Intel works; it is slower and
tested less often.

## Prerequisites

- **Xcode 15 or newer**, plus the command line tools:
  ```sh
  xcode-select --install
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -license accept
  ```
- The macOS 14 SDK (ships with Xcode 15).
- ~120 GB free on an APFS volume. **Case-sensitive is not required**, but a
  case-insensitive volume will occasionally produce confusing conflicts — if you
  can spare a case-sensitive APFS volume for `src/`, use it.

## Build

```sh
make bootstrap
make sync
make patch
make build
open out/release/evil.app
```

Deployment target is macOS 12, set in `build/args/mac.gni`. Lower it there if
you need to, and expect to fix the resulting API-availability errors yourself.

## Universal binaries

Build each slice, then merge:

```sh
scripts/build.sh --cpu x64   --config release
scripts/build.sh --cpu arm64 --config release
tools/make_universal.sh out/release-x64 out/release-arm64 out/release-universal
```

`make_universal.sh` is not written yet — the release pipeline currently builds
the two slices on separate runners and lipos them in CI. See
[RELEASING.md](../RELEASING.md).

## Signing

Development builds are unsigned and will show up as unidentified. Gatekeeper
will let you run them after the first right-click → Open. Do not disable
Gatekeeper globally to work around this.

Release signing and notarisation: [RELEASING.md](../RELEASING.md).

## Known annoyances

| Symptom | Fix |
| --- | --- |
| `xcrun: error: SDK "macosx" cannot be located` | `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| Link dies with "out of memory" on 16 GB | `make build JOBS=4` |
| `dyld: Library not loaded` running the app | You moved `out/`; rebuild rather than copying |
