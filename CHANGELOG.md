# Changelog

All notable changes to evil. The user-facing version of this list, with more
context, is at <https://evil.st/changelog.html>.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions are evil's own; the Chromium base is noted per release.

## [Unreleased]

Base: ungoogled-chromium 152.0.7977.64-1. Working toward 1.0.0: crash-rate targets on all three platforms, and an import
path that stops surprising people.

## [0.9.4] — 2026-08-21 — Chromium 152.0.7977

### Added
- Container assignment rules: map a domain to a container once, and every
  navigation to it lands in the right cookie jar.
- Command palette (`Ctrl`/`Cmd` + `Shift` + `K`) covering tabs, settings pages
  and shield toggles.

### Fixed
- Import detects a locked Chromium profile up front and reports it, instead of
  silently skipping history and cookies.
- Firefox password import no longer fails on profiles using a primary password.

### Changed
- Cold start on Windows is ~140 ms faster; the extension registry scan is
  deferred past first paint.

### Security
- Merged Chromium 152.0.7977 security fixes.

## [0.9.3] — 2026-08-04 — Chromium 151.0.7922

### Added
- Fingerprint noise seeds derived per session *and* per eTLD+1.
- `--no-fingerprint-noise` switch for isolating breakage reports.

### Fixed
- Canvas-based captchas no longer fail on the second attempt.
- AudioContext jitter is genuinely sub-audible; some web-audio instruments were
  picking it up.
- Screen-metric bucketing no longer breaks fullscreen video on ultrawide
  displays.

## [0.9.2] — 2026-07-17 — Chromium 150.0.7871

### Added
- Burn clears every profile at once, including service workers and their
  registrations.
- Burn exceptions: a per-site allowlist.
- Burn on exit, combinable with session restore.

### Fixed
- DNS cache and socket pool were surviving a burn.

### Changed
- Burning a large profile: ~9 s → under 1 s.

## [0.9.1] — 2026-06-30 — Chromium 150.0.7871

### Added
- Discarded tabs keep title, favicon and scroll position; they reload on focus.
- Low-memory mode, entered automatically under 4 GB of RAM.
- Vertical tabs (`Ctrl` + `Alt` + `T`).

### Fixed
- Pinned tabs and tabs holding a live WebSocket are exempt from discarding.

## [0.9.0] — 2026-06-09 — Chromium 149.0.7794

First build with the full feature set enabled.

### Added
- uBlock Origin's engine compiled into the network stack.
- Fingerprint randomization on canvas, WebGL, audio, fonts and client hints.
- Tampermonkey and Cookie-Editor bundled.
- Widevine in official builds.

### Removed
- Google Safe Browsing; badware and phishing lists moved into the local blocker.

## [0.8.0] — 2026-03-28 — Chromium 147.0.7583

Groundwork: Google update service, field trials, crash upload and first-run
pings removed; LTO/PGO build; own update mechanism; profile and container
plumbing; enterprise policy keys.

[Unreleased]: https://github.com/evil-browser/evil/compare/v0.9.4...HEAD
[0.9.4]: https://github.com/evil-browser/evil/releases/tag/v0.9.4
[0.9.3]: https://github.com/evil-browser/evil/releases/tag/v0.9.3
[0.9.2]: https://github.com/evil-browser/evil/releases/tag/v0.9.2
[0.9.1]: https://github.com/evil-browser/evil/releases/tag/v0.9.1
[0.9.0]: https://github.com/evil-browser/evil/releases/tag/v0.9.0
[0.8.0]: https://github.com/evil-browser/evil/releases/tag/v0.8.0
