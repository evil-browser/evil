#!/usr/bin/env bash
set -euo pipefail

BUILD_USER="${EVIL_BUILD_USER:-evil}"
WORK_DIR="${EVIL_WORK_DIR:-/opt/evil}"
SWAP_GB="${EVIL_SWAP_GB:-16}"
CCACHE_GB="${EVIL_CCACHE_GB:-50}"

if [[ $EUID -ne 0 ]]; then
  echo "error: run as root (sudo $0)" >&2
  exit 1
fi

if command -v apt-get >/dev/null 2>&1; then
  PKG=apt
elif command -v dnf >/dev/null 2>&1; then
  PKG=dnf
else
  echo "error: need apt-get or dnf. On other distributions install the" >&2
  echo "       equivalents listed in docs/VPS.md by hand." >&2
  exit 1
fi

echo "==> System packages ($PKG)"
if [[ "$PKG" == "apt" ]]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y --no-install-recommends \
    git curl ca-certificates python3 python3-venv python3-pip \
    build-essential pkg-config ninja-build lsb-release xz-utils zip unzip \
    ccache tmux htop rsync file sudo gnupg patch
else
  dnf install -y -q epel-release || true
  dnf install -y -q \
    git curl ca-certificates python3 python3-pip \
    gcc gcc-c++ make pkgconf-pkg-config xz zip unzip \
    tmux rsync file sudo gnupg2 patch libatomic perl
  dnf install -y -q ccache || echo "    ccache unavailable, continuing without it"
  PY_VER="$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
  if [[ "$(printf '%s\n3.9\n' "$PY_VER" | sort -V | head -1)" != "3.9" ]]; then
    echo "error: Chromium needs Python 3.9 or newer, found $PY_VER" >&2
    echo "       dnf install python3.12 && alternatives --set python3 /usr/bin/python3.12" >&2
    exit 1
  fi
  echo "    python3 $PY_VER"
  echo "    ninja comes from depot_tools, not the distribution"
fi

echo "==> Build user"
if ! id -u "$BUILD_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$BUILD_USER"
  echo "    created $BUILD_USER"
else
  echo "    $BUILD_USER exists"
fi

echo "==> Work directory"
mkdir -p "$WORK_DIR"
chown -R "$BUILD_USER:$BUILD_USER" "$WORK_DIR"

TOTAL_RAM_GB=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
echo "==> Memory: ${TOTAL_RAM_GB} GB"
if [[ "$TOTAL_RAM_GB" -lt 32 ]]; then
  if ! swapon --show | grep -q '/swapfile'; then
    echo "    adding ${SWAP_GB} GB swap (linking Chromium needs it below 32 GB)"
    fallocate -l "${SWAP_GB}G" /swapfile
    chmod 600 /swapfile
    mkswap -q /swapfile
    swapon /swapfile
    grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  else
    echo "    swap already present"
  fi
fi

FREE_GB=$(df -BG --output=avail "$WORK_DIR" | tail -1 | tr -dc '0-9')
echo "==> Disk: ${FREE_GB} GB free at $WORK_DIR"
if [[ "$FREE_GB" -lt 150 ]]; then
  echo "    WARNING: a checkout plus one release build needs about 150 GB."
fi

echo "==> ccache"
if ! command -v ccache >/dev/null 2>&1; then
  echo "    not installed, skipping"
else
sudo -u "$BUILD_USER" ccache --max-size="${CCACHE_GB}G" >/dev/null
sudo -u "$BUILD_USER" ccache --set-config=compression=true
sudo -u "$BUILD_USER" ccache --set-config=sloppiness=include_file_mtime,include_file_ctime,time_macros

fi

echo "==> File descriptor limits"
if ! grep -q 'evil build limits' /etc/security/limits.conf; then
  cat >> /etc/security/limits.conf <<LIMITS

# evil build limits
$BUILD_USER soft nofile 65535
$BUILD_USER hard nofile 65535
LIMITS
fi

CORES=$(nproc)
LINK_JOBS=$(( TOTAL_RAM_GB / 8 ))
[[ "$LINK_JOBS" -lt 1 ]] && LINK_JOBS=1

echo
echo "==> Build sizing"
echo "    compile jobs:  $CORES"
echo "    link jobs:     $LINK_JOBS  (linking needs roughly 8 GB each)"
if [[ "$TOTAL_RAM_GB" -lt 24 ]]; then
  echo "    NOTE: under 24 GB, disable ThinLTO for the first build:"
  echo "          echo 'use_thin_lto = false' >> build/args/local.gni"
  echo "          echo 'concurrent_links = 1' >> build/args/local.gni"
fi

echo
echo "==> Ready"
echo "    user:     $BUILD_USER"
echo "    workdir:  $WORK_DIR"
echo "    cores:    $CORES"
echo "    ram:      ${TOTAL_RAM_GB} GB"
echo "    disk:     ${FREE_GB} GB free"
echo
echo "Next, as $BUILD_USER:"
echo "    sudo -iu $BUILD_USER"
echo "    cd $WORK_DIR && git clone https://github.com/evil-browser/evil.git ."
echo "    tmux new -s build"
echo "    make bootstrap && make sync && make patch && make build JOBS=$CORES"
