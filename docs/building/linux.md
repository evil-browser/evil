# Building on Linux

Reference platform: Ubuntu 22.04 LTS, x86_64. Debian 12, Fedora 40 and Arch all
work; only the package names differ.

## Prerequisites

```sh
sudo apt install git python3 python3-venv curl pkg-config build-essential \
                 ninja-build lsb-release xz-utils
```

Everything else comes from Chromium's own dependency script, which the sync step
can run for you:

```sh
make bootstrap
scripts/sync.sh --install-deps      # runs src/build/install-build-deps.sh
```

On non-Debian distributions `install-build-deps.sh` will refuse to run. Use the
pinned sysroot instead — it is already the default (`use_sysroot = true` in
`build/args/linux.gni`), so you only need the host tools listed above.

## Build

```sh
make patch
make build
out/release/chrome --user-data-dir=/tmp/evil-profile
```

## The sandbox

A development build has no SUID sandbox binary, so the zygote will fail to
start. Either build it:

```sh
scripts/build.sh --target chrome_sandbox
sudo chown root:root out/release/chrome_sandbox
sudo chmod 4755 out/release/chrome_sandbox
export CHROME_DEVEL_SANDBOX="$PWD/out/release/chrome_sandbox"
```

…or pass `--no-sandbox`, which is fine for a throwaway test and unacceptable for
anything you actually browse with.

## Wayland

Ozone is compiled with both backends. X11 is the default; select Wayland at
runtime:

```sh
out/release/chrome --ozone-platform=wayland
```

## Packaging

```sh
make package                      # .tar.xz always
gem install --user-install fpm    # then also .deb and .rpm
# appimagetool on PATH            # then also .AppImage
```

## Cross-compiling for arm64

```sh
scripts/build.sh --cpu arm64
```

The sysroot is fetched by `gclient sync`; no cross toolchain needs installing.
