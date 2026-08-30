set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC_DIR="${EVIL_SRC_DIR:-$REPO_ROOT/src}"
OUT_ROOT="${EVIL_OUT_DIR:-$REPO_ROOT/out}"
DIST_DIR="${EVIL_DIST_DIR:-$REPO_ROOT/dist}"
DEPOT_TOOLS_DIR="${DEPOT_TOOLS:-$REPO_ROOT/third_party/depot_tools}"
CHROMIUM_VERSION="$(tr -d ' \n' < "$REPO_ROOT/CHROMIUM_VERSION")"

if [[ -t 1 ]]; then
  C_DIM=$'\033[2m'; C_RED=$'\033[31m'; C_YEL=$'\033[33m'; C_BLD=$'\033[1m'; C_OFF=$'\033[0m'
else
  C_DIM=''; C_RED=''; C_YEL=''; C_BLD=''; C_OFF=''
fi

log()  { printf '%s==>%s %s\n' "$C_BLD" "$C_OFF" "$*"; }
info() { printf '    %s%s%s\n' "$C_DIM" "$*" "$C_OFF"; }
warn() { printf '%swarning:%s %s\n' "$C_YEL" "$C_OFF" "$*" >&2; }
die()  { printf '%serror:%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not on PATH.${2:+ $2}"
}

host_os() {
  case "$(uname -s)" in
    Linux)  echo linux ;;
    Darwin) echo mac ;;
    MINGW*|MSYS*|CYGWIN*) echo win ;;
    *) die "unsupported host OS: $(uname -s)" ;;
  esac
}

host_cpu() {
  case "$(uname -m)" in
    x86_64|amd64) echo x64 ;;
    arm64|aarch64) echo arm64 ;;
    *) die "unsupported host CPU: $(uname -m)" ;;
  esac
}

use_depot_tools() {
  [[ -d "$DEPOT_TOOLS_DIR" ]] || die "depot_tools not found. Run 'make bootstrap' first."
  export PATH="$DEPOT_TOOLS_DIR:$PATH"
  export DEPOT_TOOLS_UPDATE="${DEPOT_TOOLS_UPDATE:-1}"
  export DEPOT_TOOLS_METRICS=0
}

require_checkout() {
  [[ -d "$SRC_DIR" ]] || die "no Chromium checkout at $SRC_DIR. Run 'make sync' first."
}

free_gb() {
  df -Pk "$1" 2>/dev/null | awk 'NR==2 {printf "%d", $4/1024/1024}'
}

confirm() {
  [[ "${EVIL_ASSUME_YES:-0}" == "1" ]] && return 0
  read -r -p "$1 [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}
