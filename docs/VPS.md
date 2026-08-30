# Building on a VPS

A Chromium build is not a small job. Renting a big machine for a day is cheaper
and far less painful than fighting a small one for a week.

## What the machine needs

| | Minimum | Sensible | Why |
| --- | --- | --- | --- |
| Cores | 8 | 16–32 | Build time scales almost linearly |
| RAM | 16 GB | 32–64 GB | The final link is the spike, not the compile |
| Disk | 150 GB | 250 GB NVMe | Checkout 40 GB, one build 60 GB, artefacts on top |
| OS | Ubuntu 22.04 | Ubuntu 24.04 | What upstream tests against |
| Swap | 16 GB | 16 GB | Below 32 GB of RAM the link will OOM without it |

Rough wall-clock for a first release build: **8 cores ≈ 5–6 h, 16 cores ≈ 2.5–3 h,
32 cores ≈ 1.5 h.** Incremental builds after that are minutes.

Cross-compiling Windows and macOS from Linux is not supported by upstream, so
those two need their own machines. See [Per-platform](#per-platform) below.

## Provision

```sh
ssh root@your-vps
git clone https://github.com/evil-browser/evil.git /tmp/evil
sudo /tmp/evil/scripts/vps-provision.sh
```

Installs the toolchain, creates an unprivileged `evil` user, adds swap if RAM is
under 32 GB, sizes ccache, and raises the file-descriptor limit. It prints the
next commands when it finishes.

## Build

```sh
sudo -iu evil
cd /opt/evil
git clone https://github.com/evil-browser/evil.git .

tmux new -s build
make bootstrap
make sync
make patch
make build JOBS=$(nproc)
```

**Use tmux.** An SSH drop during `gclient sync` leaves a half-written checkout
that is faster to delete than to repair. Detach with <kbd>Ctrl</kbd>+<kbd>B</kbd>
then <kbd>D</kbd>; reattach with `tmux attach -t build`.

Enable ccache for the second build onward:

```sh
echo 'cc_wrapper = "ccache"' >> build/args/local.gni
```

## Package and collect

```sh
make pack
make package
make checksums
```

Artefacts land in `dist/`. Pull them to your machine:

```sh
rsync -avP evil@your-vps:/opt/evil/dist/ ./dist/
```

Do not sign on the VPS unless the keys live there. Signing belongs on a machine
you control — see [RELEASING.md](RELEASING.md).

## Per-platform

| Target | Where | Notes |
| --- | --- | --- |
| Linux x86_64 | The VPS | The default |
| Linux aarch64 | Same VPS | `scripts/build.sh --cpu arm64`, sysroot comes from gclient |
| Windows x64 | A Windows instance | `scripts/windows-provision.ps1`, see [building/windows.md](building/windows.md) |
| macOS | Real Apple hardware | Xcode is required and cannot be licensed on a Linux VPS |

Anyone offering "macOS in the cloud" for this is renting you a Mac mini. That is
fine, and it is the only legal route.

## Keeping the VPS around

The expensive part is the checkout, not the build. Keep the machine, or snapshot
`/opt/evil/src` to object storage, and later builds start from `make sync` in
minutes rather than hours.

To register it as a GitHub Actions runner so the workflows in `.github/workflows`
can drive it:

```sh
sudo -iu evil
mkdir -p ~/actions-runner && cd ~/actions-runner
curl -fsSL -o runner.tar.gz \
  https://github.com/actions/runner/releases/latest/download/actions-runner-linux-x64.tar.gz
tar xzf runner.tar.gz
./config.sh --url https://github.com/evil-browser/evil \
            --labels self-hosted,linux,chromium-checkout
sudo ./svc.sh install evil && sudo ./svc.sh start
```

The `chromium-checkout` label is what the workflows target, and it is a promise
that `src/` is already on the machine. A runner without it will pick up a job and
spend an hour syncing before it starts.

## When it fails

| Symptom | Cause | Fix |
| --- | --- | --- |
| Killed during link, no message | OOM | Add swap, or `make build JOBS=4` |
| `No space left on device` at 90% | Underestimated disk | `make clean` keeps the checkout; resize the volume |
| `gclient sync` hangs at 99% | A hook downloading through a slow link | Leave it; it resumes |
| Disconnected mid-build | SSH timeout | tmux, always |
| Second build as slow as the first | ccache not wired in | `ccache -s` should show hits |
