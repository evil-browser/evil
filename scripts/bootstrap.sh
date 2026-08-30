#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

OS="$(host_os)"

log "Checking prerequisites"
require_cmd git
require_cmd python3 "Chromium's build needs Python 3.9 or newer."
require_cmd curl

py_ver="$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
info "python3 $py_ver"
python3 - <<'PY' || die "Python 3.9+ is required."
import sys
sys.exit(0 if sys.version_info >= (3, 9) else 1)
PY

case "$OS" in
  linux)
    require_cmd pkg-config
    info "host: linux $(host_cpu)"
    warn "Run 'src/build/install-build-deps.sh' after the first sync to pull system packages."
    ;;
  mac)
    xcode-select -p >/dev/null 2>&1 || die "Xcode command line tools missing: run 'xcode-select --install'."
    info "host: macOS $(sw_vers -productVersion 2>/dev/null || echo '?') $(host_cpu)"
    info "Xcode: $(xcodebuild -version 2>/dev/null | head -1 || echo 'command line tools only')"
    ;;
  win)
    info "host: windows"
    warn "Visual Studio 2022 with the 'Desktop development with C++' workload and the"
    warn "Windows 11 SDK (incl. Debugging Tools) must be installed. See docs/building/windows.md."
    ;;
esac

avail="$(free_gb "$REPO_ROOT")"
if [[ -n "$avail" && "$avail" -lt 100 ]]; then
  warn "only ${avail} GB free here — a checkout plus one build configuration needs about 100 GB."
fi

log "Fetching depot_tools"
if [[ -d "$DEPOT_TOOLS_DIR/.git" ]]; then
  info "already present, updating"
  git -C "$DEPOT_TOOLS_DIR" pull --ff-only --quiet
else
  mkdir -p "$(dirname "$DEPOT_TOOLS_DIR")"
  git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT_TOOLS_DIR"
fi

log "Done"
cat <<MSG

  depot_tools is at:
    $DEPOT_TOOLS_DIR

  The scripts add it to PATH themselves. To use gn/ninja by hand, add it too:
    export PATH="$DEPOT_TOOLS_DIR:\$PATH"

  Next:
    make sync     # fetch Chromium $CHROMIUM_VERSION (40+ GB, slow)
MSG
