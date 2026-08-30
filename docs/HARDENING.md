# What is turned off, and how

Three layers do the work, in order of how hard they are to undo:

| Layer | File | Undone by |
| --- | --- | --- |
| Build flags | `build/args/*.gni` | Recompiling |
| Enterprise policy | `config/policies/` | An administrator |
| Initial preferences | `config/initial_preferences` | The user, in settings |

Anything that must *never* be reachable belongs in the build layer. Anything a
user could reasonably want back belongs in preferences. Policy sits between the
two and is what makes a stock Chromium behave like evil for testing.

## Removed at build time

| GN argument | Effect |
| --- | --- |
| `google_api_key = ""` and the two client-secret keys | Google APIs are not merely unused, they are unusable. No shared quota, no fallback. |
| `safe_browsing_mode = 0` | No Safe Browsing code path at all, so no URL lookups and no download reputation pings. |
| `enable_reporting = false` | No Reporting API upload endpoint. |
| `enable_remoting = false` | No Chrome Remote Desktop host. |
| `enable_mdns = false`, `enable_service_discovery = false` | No local-network device discovery chatter. |
| `enable_hangout_services_extension = false` | Drops the built-in Google Meet helper extension. |
| `disable_fieldtrial_testing_config = true` | No field trials baked into the build. |
| `enable_nacl = false` | Dead code path, smaller binary. |
| `is_chrome_branded = false` | No Chrome-branded services or assets. |

Kept deliberately: `proprietary_codecs`, `ffmpeg_branding = "Chrome"`,
`enable_widevine`, `enable_platform_hevc`. A privacy browser that cannot play
video is a browser people stop using, and DRM playback is the price of that.

## Turned off by policy

`config/policies/managed_policies.json` and its Windows and macOS equivalents
cover the connections that survive a stock build:

- `MetricsReportingEnabled`, `UrlKeyedAnonymizedDataCollectionEnabled` — usage statistics
- `ChromeVariations: 2` — the variations (field trial) server, which stock Chromium contacts on startup
- `DomainReliabilityAllowed` — Google's network-error reporting
- `SafeBrowsingProtectionLevel: 0` plus the extended-reporting and deep-scanning keys
- `SearchSuggestEnabled` — omnibox suggestions, which send keystrokes to the search engine
- `SpellCheckServiceEnabled` — the "enhanced spell check" that uploads typed text
- `TranslateEnabled` — the translate service
- `AlternateErrorPagesEnabled` — Google's navigation-error suggestions
- `NetworkPredictionOptions: 2` — DNS prefetch and preconnect
- `BrowserSignin: 0`, `SyncDisabled` — no account, no sync
- `BackgroundModeEnabled: false` — no process left running after the last window closes
- `EnableMediaRouter: false` — no Cast discovery
- The four `PrivacySandbox*` keys — Topics, FLEDGE, ad measurement, and the prompt
- `PasswordLeakDetectionEnabled` — password checks against a remote service

## Set as first-run defaults

`config/initial_preferences` ships with the browser and applies to a new profile:

- **DuckDuckGo as the default engine**, keyword `duck.com`, suggestions off
- Geolocation, notifications, sensors, MIDI, USB, serial, HID and Bluetooth default to blocked
- Third-party cookies blocked
- No sign-in promo, no welcome page, no default-browser nag
- Autofill for payment cards off; the password manager stays on
- `first_run_tabs` opens the documentation once, and nothing else

## What still talks to the network

Being straight about the remainder, because a list of removals is not the same
as silence:

| Connection | When | Turn it off with |
| --- | --- | --- |
| Update check | Every 12 hours | `EvilUpdateEnabled` policy, or settings |
| Filter list refresh | Daily, if the blocker is on | uBlock Origin's own settings |
| Widevine CDM download | First DRM playback | Never play DRM |
| Extension updates | If extensions are installed | Per-extension |
| DNS resolution | Always | Your resolver choice; `DnsOverHttpsMode` is `automatic` |

## Verifying it

Claims are worth nothing without a packet capture. The procedure is in
[TESTING.md](TESTING.md) under the networking hygiene check: point a fresh
profile at a proxy, start the browser, idle for five minutes, and read the log.
There should be no request to a Google domain.

That test is the one an outsider can most easily use to prove the front page of
the website wrong, which is exactly why it is in the release checklist.
