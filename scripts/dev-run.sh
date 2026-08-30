#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

PROFILE_DIR="${EVIL_DEV_PROFILE:-$REPO_ROOT/.dev-profile}"
FRESH=0
BINARY="${EVIL_DEV_BINARY:-}"
URL="https://evil.st/"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fresh) FRESH=1; shift ;;
    --binary) BINARY="$2"; shift 2 ;;
    --url) URL="$2"; shift 2 ;;
    -h|--help)
      echo "usage: dev-run.sh [--fresh] [--binary /path/to/chrome] [--url URL]"
      echo
      echo "Runs the evil extension and theme set on a locally installed Chromium"
      echo "build, with the hardening flags the packaged browser applies by default."
      exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

find_binary() {
  local candidates=()
  case "$(host_os)" in
    mac)
      candidates=(
        "/Applications/Chromium.app/Contents/MacOS/Chromium"
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
        "/Applications/Thorium.app/Contents/MacOS/Thorium"
      ) ;;
    linux)
      candidates=(chromium chromium-browser google-chrome google-chrome-stable brave-browser thorium-browser) ;;
    win)
      candidates=(
        "/c/Program Files/Google/Chrome/Application/chrome.exe"
        "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe"
      ) ;;
  esac
  for c in "${candidates[@]}"; do
    if [[ -x "$c" ]]; then echo "$c"; return 0; fi
    if command -v "$c" >/dev/null 2>&1; then command -v "$c"; return 0; fi
  done
  return 1
}

[[ -n "$BINARY" ]] || BINARY="$(find_binary)" || die "no Chromium-based browser found. Pass --binary /path/to/chrome"

[[ "$FRESH" == "1" ]] && rm -rf "$PROFILE_DIR"
mkdir -p "$PROFILE_DIR"

EXTENSIONS="$REPO_ROOT/extensions/evil-shield,$REPO_ROOT/extensions/evil-clean,$REPO_ROOT/extensions/evil-guard,$REPO_ROOT/theme/evil-dark"

FLAGS=(
  "--user-data-dir=$PROFILE_DIR"
  "--load-extension=$EXTENSIONS"
  "--homepage=https://duckduckgo.com/"
  "--no-first-run"
  "--no-default-browser-check"
  "--disable-search-engine-choice-screen"
  "--disable-background-networking"
  "--disable-component-update"
  "--disable-domain-reliability"
  "--disable-breakpad"
  "--disable-crash-reporter"
  "--disable-client-side-phishing-detection"
  "--safebrowsing-disable-auto-update"
  "--disable-sync"
  "--disable-features=OptimizationHints,Translate,MediaRouter,InterestFeedContentSuggestions,PrivacySandboxSettings4,SafeBrowsingEnhancedProtection,AutofillServerCommunication,CalculateNativeWinOcclusion,OptimizationTargetPrediction"
  "--enable-features=ExtensionManifestV2,ParallelDownloading"
  "--force-dark-mode"
  "--metrics-recording-only"
  "--no-pings"
  "--no-service-autorun"
  "--password-store=basic"
  "--use-mock-keychain"
)

log "Launching $(basename "$BINARY")"
info "profile:    ${PROFILE_DIR#$REPO_ROOT/}"
info "extensions: evil-shield, evil-clean, evil-guard, evil-dark"
info "search:     DuckDuckGo (duck.com)"
echo

exec "$BINARY" "${FLAGS[@]}" "$URL"
