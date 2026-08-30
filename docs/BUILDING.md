# Building evil

evil is a patch set on top of Chromium. Building it means fetching Chromium,
applying the patches, and running Chromium's own build — so if you have built
Chromium before, none of this will surprise you, and if you haven't, budget an
afternoon for the first one.

## What you need

| | Minimum | Comfortable |
| --- | --- | --- |
| Disk | 100 GB free | 200 GB on an SSD |
| RAM | 16 GB | 32 GB |
| CPU | 4 cores | 8+ cores |
| Network | patience | 500 Mbit |
| Time (first build) | ~6 hours | ~1.5 hours |
| Time (incremental) | minutes | seconds |

Platform prerequisites differ, and each has its own page:

- [Linux](building/linux.md)
- [macOS](building/macos.md)
- [Windows](building/windows.md)

Read yours before continuing — the rest of this page is the same everywhere.

## The five steps

```sh
make bootstrap   # depot_tools + prerequisite check
make sync        # fetch Chromium at the pinned tag  (slow, 40+ GB)
make patch       # apply patches/series
make build       # gn gen + autoninja
make package     # installers into dist/
```

`make` prints every target with `make help`. Each target is a wrapper around a
script in `scripts/`, and each script takes more options than the Makefile
exposes — `scripts/build.sh --help` and friends.

### 1. bootstrap

Clones [depot_tools] into `third_party/depot_tools`, checks for Python 3.9+,
git, and a working compiler toolchain, and warns if the disk is too small. The
build scripts add depot_tools to `PATH` themselves, so you do not have to.

### 2. sync

Fetches the Chromium tree into `src/`, detaches at the tag in
[`CHROMIUM_VERSION`](../CHROMIUM_VERSION), and runs `gclient sync`. This is the
step that takes an hour and 40 GB.

`src/` is gitignored. It is not part of this repository and never will be.

```sh
scripts/sync.sh --install-deps   # Linux: also run install-build-deps.sh
scripts/sync.sh --no-hooks       # skip gclient hooks (rarely what you want)
```

Sync refuses to run over a dirty tree. Run `make unpatch` first — that is not a
safety rail you should route around, because syncing over applied patches
produces conflicts that look like upstream bugs.

### 3. patch

Applies every entry in [`patches/series`](../patches/series) with
`git apply --3way`, in order, stopping at the first failure and telling you
which patch failed.

```sh
scripts/patch.sh status    # what is applied, and is src/ dirty
scripts/patch.sh revert    # back to clean upstream
```

If a patch fails after a version bump, that is a rebase, and
[PATCHES.md](PATCHES.md) covers it.

### 4. build

```sh
make build                      # release, host architecture
make build CONFIG=debug         # debug
make build JOBS=8               # cap parallelism (helps on 16 GB machines)
scripts/build.sh --cpu arm64    # cross-compile
scripts/build.sh --gn-only      # write args.gn and stop
```

GN arguments are assembled from `build/args/`, in this order:

```
common.gni  →  <platform>.gni  →  <config>.gni  →  local.gni (optional, gitignored)
```

The result is written to `out/<config>/args.gn`. Don't edit that file — it is
regenerated on every build. Put machine-local overrides (a different sysroot, a
smaller `symbol_level`, `cc_wrapper = "ccache"`) in `build/args/local.gni`.

Useful targets beyond the default:

```sh
scripts/build.sh --target mini_installer   # Windows installer
scripts/build.sh --target chrome_sandbox   # Linux SUID sandbox
scripts/build.sh --target evil_unittests   # our tests
```

### 5. package

Produces artefacts in `dist/` for the host platform: `.tar.xz` plus AppImage,
`.deb` and `.rpm` on Linux (if `appimagetool` and `fpm` are installed), a `.dmg`
on macOS, and an installer plus portable `.zip` on Windows. Then:

```sh
make checksums   # dist/SHA256SUMS
```

Signing and notarisation are release-only steps and live in
[RELEASING.md](RELEASING.md).

## Running what you built

```sh
out/release/chrome --user-data-dir=/tmp/evil-profile   # Linux
out/release/evil.app/Contents/MacOS/evil               # macOS
out\release\chrome.exe --user-data-dir=%TEMP%\evil     # Windows
```

Always use a throwaway `--user-data-dir` for development builds. A crash in a
patched renderer can corrupt a profile, and it is your daily profile that it
will pick.

## When it breaks

| Symptom | Cause | Fix |
| --- | --- | --- |
| `gclient sync` fails on a hook | Missing system dependency | Linux: `scripts/sync.sh --install-deps` |
| Link runs out of memory | Too many parallel link jobs | `make build JOBS=4`, or `symbol_level = 0` in `local.gni` |
| `patch failed` after a version bump | Upstream moved the code | [PATCHES.md](PATCHES.md#rebasing-onto-a-new-chromium) |
| `gn gen` complains about an unknown argument | Argument removed upstream | Drop it from `build/args/`, check `gn args --list out/release` |
| Build succeeds, browser won't start | Sandbox not configured (Linux) | Build `chrome_sandbox`, or run with `--no-sandbox` for testing only |
| Everything is slow | No ccache/sccache | Set `cc_wrapper = "ccache"` in `local.gni` |

If none of those fit, open an issue with the output of `scripts/patch.sh status`
and the last 50 lines of the build log.

[depot_tools]: https://chromium.googlesource.com/chromium/tools/depot_tools.git
