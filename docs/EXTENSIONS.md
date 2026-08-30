# Extensions

evil ships four of its own components and pulls four well-known extensions from
the Chrome Web Store on first run. The Web Store stays fully available — the
point of Guard is that you can install anything and still know what it can do.

## What ships with the browser

| Component | Directory | What it does |
| --- | --- | --- |
| evil Shield | `extensions/evil-shield` | Fingerprint randomization and platform masquerade |
| evil Clean | `extensions/evil-clean` | Burn browsing data on demand, on a schedule, or at startup |
| evil Guard | `extensions/evil-guard` | Audits every installed extension for dangerous capabilities |
| evil dark | `theme/evil-dark` | The monochrome theme |

These are ours, BSD-3 like the rest, and packed into CRXs at release time by
`tools/pack-extensions.sh`. They install through Chromium's external-extension
mechanism, which means they behave like normal extensions: visible in
`evil://extensions`, and removable.

## What is pulled from the Web Store

Declared in `config/external_extensions/`, one file per extension, each holding
the Web Store update URL. On first run the browser fetches them; the user can
remove any of them afterwards.

| Extension | ID | Why |
| --- | --- | --- |
| uBlock Origin | `cjpalhdlnbpafiamejdnhcphjbkeiagm` | Content blocking. Needs Manifest V2, which this build keeps enabled. |
| Cookie-Editor | `hlkenndednhfkekhgcdicdfddnkalmdm` | Inspect and edit cookies per site. |
| Tampermonkey | `dhdgffkkebhmkfjojejmpbldmpobfkfo` | Userscripts. |
| SponsorBlock | `mnjggcdmjocbbbhaepdhchncahnbgone` | Skips sponsor segments on YouTube. uBlock Origin already handles the ads. |

They are fetched rather than bundled for two reasons: bundling means shipping a
stale copy until the next release, and Tampermonkey's licence does not permit
redistributing its package at all.

**The uBlock Origin risk, stated plainly.** uBO is Manifest V2. Google is
removing MV2 extensions from the Web Store. This build keeps MV2 working
(`ExtensionManifestV2Availability: 2`), so uBO runs fine — but if the listing
disappears, first-run installation breaks. The fallback is to self-host the CRX
and point `config/external_extensions/cjpalhdlnbpafiamejdnhcphjbkeiagm.json` at
it with `external_crx`, which is what the `patches/features/` blocker work is
meant to make unnecessary.

## evil Shield

Two mechanisms, because either alone is detectable:

1. **Request headers**, rewritten by `declarativeNetRequest`: `User-Agent` and
   the whole `Sec-CH-UA-*` family, plus `X-Client-Data` removed.
2. **JavaScript surfaces**, overridden by a `MAIN`-world content script at
   `document_start`: `navigator`, `screen`, canvas readback, WebGL parameters,
   `AudioContext`, WebRTC candidates, device APIs.

Both are driven by one profile — Windows, Linux, macOS, or the real platform —
so the header story and the JavaScript story always agree. Mismatched spoofing
is worse than none: it is a signal no ordinary browser produces.

### Canvas noise

The seed is derived from the page origin, so a given site sees one stable
machine for as long as it looks, while two different sites see two unrelated
machines. Random-per-call noise, which several forks use, breaks canvas-based
captchas and makes the browser *more* identifiable, not less.

### Default profile

Windows x64. Not because it is the truth on your machine, but because it is the
largest crowd on the web, and blending into the largest crowd is the whole game.
Linux and macOS are one click away in the options page.

### Adding a platform

Copy `page/profile-windows.js`, change the values, add a matching ruleset in
`rules/`, register it in `manifest.json` under `declarative_net_request`, and add
the option to `ui/options.html`. Keep the header values and the JavaScript values
consistent with each other.

## evil Clean

A burn calls `chrome.browsingData.remove` twice: once for origin-scoped data,
honouring the keep-list, and once for the global categories that have no origin
(history, downloads, form data). Saved passwords are excluded by default.

Automatic modes: at startup, or on an interval while the browser runs. The
shortcut is <kbd>Alt</kbd> + <kbd>Shift</kbd> + <kbd>X</kbd>.

What an extension cannot reach: the DNS cache, the socket pool, and the HSTS
list. Those need `BrowsingDataRemover` at the C++ level and are listed in
[../patches/PLANNED.md](../patches/PLANNED.md).

## evil Guard

Scores every installed extension on what it *could* do:

| Signal | Weight |
| --- | --- |
| `debugger` | 45 |
| `nativeMessaging` | 35 |
| `desktopCapture` | 30 |
| Installed by another program (sideload) | 30 |
| `pageCapture`, `proxy` | 28 |
| Access to every site | 25 |
| `management`, loaded unpacked | 25 |
| Updates from outside the Web Store | 20 |
| `privacy`, `tabCapture` | 20 |
| `cookies`, `webRequest` | 18 |
| New permissions requested after install | 15 |

A score of 55 or more is `high`, 25 to 54 is `review`. Guard notifies when a
newly installed extension lands in either band, and re-scans every 12 hours.

**What it is not.** Guard does not analyse extension code, and cannot tell a
password manager that legitimately needs `<all_urls>` from a credential stealer
that wants the same thing. It tells you what an extension is *able* to do, which
is the part the Web Store listing buries. Judge it against what the extension is
for.

## Development

```sh
scripts/dev-run.sh --fresh
```

Launches a locally installed Chromium with all four components loaded from disk
and the hardening flags applied, against a throwaway profile in `.dev-profile/`.
Reload an extension from `evil://extensions` after editing; changes to the
`MAIN`-world scripts apply on the next page load.
