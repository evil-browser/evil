# evil's own patches

The de-Googling layer is [ungoogled-chromium](../docs/UPSTREAM.md)'s and is
already wired in. This file is what remains for evil specifically, in the order
it should be written.

Reading their patch set changed this list considerably: several things that
would have been months of Blink work already exist upstream as flags. Our job
for those is to turn them on, not to build them.

## 1. Defaults for the fingerprinting switches

**Status: the highest-value patch in the project, and a small one.**

Upstream adds renderer-level fingerprint noise, but ships it off:

| Switch | Adds |
| --- | --- |
| `--fingerprinting-canvas-image-data-noise` | Per-session noise on canvas image data |
| `--fingerprinting-canvas-measuretext-noise` | Noise on text measurement |
| `--fingerprinting-client-rects-noise` | Noise on element geometry |
| `--webgl-renderer-info-spoof` | Generic WebGL vendor and renderer strings |
| `--reduce-system-info` | Trims exposed hardware detail |
| `--remove-client-hints` | Drops the `Sec-CH-UA-*` family |

evil promises "scrambled by default from the very first launch", so these have
to be on without the user finding a flags page. Append them to the command line
in the browser process at startup, and let an explicit `--no-fingerprint-noise`
turn them off again.

Land in: `chrome/app/chrome_main_delegate.cc`, in the `PreSandboxStartup` path
where the command line is already being modified.

These are renderer-level, unlike evil Shield's JavaScript overrides, so they
cannot be detected by comparing against a fresh iframe's prototypes. Once this
lands, Shield's canvas and WebGL layers become redundant and should be turned
off by default to avoid double-noising.

## 2. DuckDuckGo as the built-in default engine

Policy and preferences already pin it, but the prepopulated list still ships
Google first, so a profile reset or a policy failure falls back to Google.

Upstream's `extra/ungoogled-chromium/prepopulated-search-engines.patch` already
edits this list — our patch should stack on it rather than fight it.

Land in: `components/search_engines/prepopulated_engines.json`,
`template_url_prepopulate_data.cc`.

## 3. Burn-all as a first-class command

evil Clean covers most of it from an extension, but three things are out of
reach of `chrome.browsingData`:

- the DNS cache and the socket pool
- HSTS state
- other profiles

Upstream's `add-flag-to-clear-data-on-exit.patch` adds a `ClearDataOnExit`
feature, disabled by default — worth enabling as part of this.

Land in: `chrome/browser/browsing_data/chrome_browsing_data_remover_delegate.cc`,
`chrome/browser/ui/browser_commands.cc`, `chrome/app/chrome_command_ids.h`.

## 4. Branding

| Item | Location |
| --- | --- |
| Product strings, bundle id | `chrome/app/theme/chromium/BRANDING` → `resources/branding/BRANDING` |
| Icons | `chrome/app/theme/chromium/` |
| `chrome://` → `evil://` | `chrome/common/webui_url_constants.cc`, `content/public/common/url_constants.cc` |
| Tab geometry, toolbar density | `chrome/browser/ui/views/tabs/`, `chrome/browser/ui/layout_constants.cc` |

The theme extension already carries the palette; this is strings and geometry.

## 5. Content blocking in the network service

Move uBlock Origin's engine below the extension system so Manifest V3 policy can
never restrict it. The largest item on this list by a wide margin, and the
extension works today, so it is last.

Land in: `services/network/`, `components/subresource_filter/`.

## 6. Tab lifecycle and low-memory mode

Tighten upstream's freezing and discarding policy; keep title, favicon and
scroll offset on discard; lower the renderer process cap under 4 GB of RAM.

Land in: `chrome/browser/performance_manager/`,
`content/browser/renderer_host/render_process_host_impl.cc`.

## The rule that governs this list

Every patch here is rebased onto a new Chromium every two weeks, forever. Before
adding one, check it is not already a GN argument, a policy key, a preference,
an upstream flag, or something an extension can do. Reading
`third_party/ungoogled-chromium/patches/series` first has already saved this
project months.
