<div align="center">

<img src="resources/branding/evil-mark-white-256.png" alt="evil" width="88" height="88">

# evil

**The browser that works for you.** Chromium with Google taken out, the tools you
actually want built in, and nothing you have to take on trust.

[Website](https://evil.st) · [Documentation](https://evil.st/docs) ·
[FAQ](https://evil.st/faq) · [Build from source](docs/BUILDING.md) ·
[What is turned off](docs/HARDENING.md)

</div>

---

## What this is

A Chromium fork maintained as a **patch set plus a configuration payload**, not a
copy of the tree. This repository holds build configuration, the bundled
extensions, the theme, the packaging scripts and evil's own patches — a few
megabytes. Chromium itself is fetched at build time and pinned in
[`CHROMIUM_VERSION`](CHROMIUM_VERSION).

The de-Googling layer is [ungoogled-chromium](https://github.com/ungoogled-software/ungoogled-chromium)'s
patch set, pinned in [`UNGOOGLED_VERSION`](UNGOOGLED_VERSION) and fetched at
build time. They have maintained that work across upstream releases for years;
reimplementing it would take months and be worse. evil adds branding, the
extension suite, the configuration payload, the performance profile and its own
patches on top. See [docs/UPSTREAM.md](docs/UPSTREAM.md).

That structure is deliberate. It keeps the diff against upstream small enough
for a person to read, and it means a Chromium security fix is a version bump and
a patch refresh rather than a merge.

## What it changes

| Area | What happens |
| --- | --- |
| **Google services** | API keys blanked at compile time, Safe Browsing compiled out, variations, metrics, domain reliability, translate, spell-check upload, prefetch and sign-in all off. [Full list](docs/HARDENING.md). |
| **Search** | DuckDuckGo by default, keyword `duck.com`, suggestions off — nothing leaves while you type. |
| **Fingerprinting** | On from the first launch. Canvas, WebGL, audio, screen, locale and hardware are scrambled per site; the reported OS is a setting. |
| **Content blocking** | uBlock Origin, with Manifest V2 kept alive so it keeps working. |
| **Extensions** | The Chrome Web Store stays fully open. Everything installed is audited by evil Guard. |
| **Cleaning** | One shortcut clears cookies, storage, history and cache. Optionally at startup or on a timer. |
| **Theme** | Black, white, grey. No accent colour. |
| **Weight** | LTO and PGO build, telemetry stripped, tab freezing and discarding tuned. |

Every privacy claim above is a file in this repository, and
[docs/TESTING.md](docs/TESTING.md) has the procedure for proving it with a proxy
rather than believing it.

## Try it in thirty seconds

The extensions, the theme and the hardening flags run on any Chromium you
already have — no 40 GB checkout needed:

```sh
git clone https://github.com/evil-browser/evil.git
cd evil
make dev
```

That launches your local Chromium or Chrome against a throwaway profile in
`.dev-profile/`, with evil Shield, evil Clean, evil Guard and the theme loaded,
DuckDuckGo as the engine, and background networking off. It is not the packaged
browser, but everything except the C++ layer behaves the same.

## Building the browser

On a machine with 16 GB of RAM and 100 GB of free disk:

```sh
make bootstrap   # depot_tools and prerequisite checks
make sync        # fetch Chromium at the pinned tag (slow, 40+ GB)
make upstream    # fetch the pinned ungoogled-chromium patch set
make patch       # prune, apply upstream patches, then evil's
make build       # gn gen + autoninja
make pack        # pack the bundled extensions into CRXs
make package     # installers into dist/
make checksums   # dist/SHA256SUMS
```

A first build takes two to six hours; incremental builds take minutes. Per
platform prerequisites, cross-compilation and the common failure modes are in
**[docs/BUILDING.md](docs/BUILDING.md)** — read the page for your OS before
starting.

## Repository layout

```
browser/
├── CHROMIUM_VERSION       Pinned upstream tag. Everything builds against this.
├── Makefile               dev / pack / bootstrap / sync / patch / build / package
├── build/args/            GN arguments, per platform and per configuration
├── config/                initial preferences, enterprise policy, Web Store hooks
├── extensions/            evil Shield, evil Clean, evil Guard
├── theme/evil-dark/       The monochrome theme
├── UNGOOGLED_VERSION      Pinned ungoogled-chromium release, must match the above
├── patches/               evil's own patches, plus the upstream exclusion list
├── resources/branding/    Icons and product strings
├── scripts/               The build pipeline and the dev runner
├── tools/                 Packaging helpers
└── docs/                  Building, hardening, extensions, theme, releasing
```

## Documentation

| Document | Covers |
| --- | --- |
| [BUILDING.md](docs/BUILDING.md) | Full build, per platform, and what to do when it breaks |
| [UPSTREAM.md](docs/UPSTREAM.md) | The ungoogled-chromium base, exclusions, version pinning |
| [VPS.md](docs/VPS.md) | Building on a rented machine, and registering it as a runner |
| [PERFORMANCE.md](docs/PERFORMANCE.md) | Build profiles, instruction sets, how to measure |
| [HARDENING.md](docs/HARDENING.md) | Every Google connection removed, by layer, and how to verify |
| [EXTENSIONS.md](docs/EXTENSIONS.md) | What ships, Shield's design, Guard's risk model |
| [THEME.md](docs/THEME.md) | Palette and how to change it |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Why it is a patch set, and where each feature lives |
| [PATCHES.md](docs/PATCHES.md) | Adding, refreshing and rebasing patches |
| [FLAGS.md](docs/FLAGS.md) | Command-line switches, internal pages, policy keys |
| [TESTING.md](docs/TESTING.md) | The automated suite and the manual release pass |
| [RELEASING.md](docs/RELEASING.md) | Versioning, channels, signing, publishing |

## Honest status

v1.0.0 has not shipped. Concretely:

- **Working today:** the extension suite, the theme, the configuration payload,
  the build and packaging pipeline. `make dev` runs all of it.
- **Working, unbuilt:** the de-Googling layer. 108 upstream patches and 13,848
  pruned binaries are wired into `make patch` and pinned to Chromium 152, but no
  full build has been run yet — the first one is what turns this from a
  configuration into a browser.
- **Not written yet:** evil's own C++ patches. `patches/series` is empty. The
  renderer-level fingerprint defences, the in-network-service content blocker
  and cross-profile burning all live in
  [patches/PLANNED.md](patches/PLANNED.md).

The renderer-level fingerprint defences, the in-network-service content blocker
and cross-profile burning all live in that second list. The extension layer is a
real mitigation and the right place to prototype, but it is detectable in ways a
Blink-level implementation is not, and this README is not going to pretend
otherwise.

## Contributing

Testing on hardware and distributions we do not have is the most useful thing
right now. See [CONTRIBUTING.md](CONTRIBUTING.md); security issues go through
[SECURITY.md](SECURITY.md), privately, before disclosure.

## Licence

BSD 3-Clause, matching Chromium — [LICENSE](LICENSE) and [NOTICE](NOTICE). The
name and logo are excluded; see
[resources/branding/README.md](resources/branding/README.md). Fork it freely; if
you ship a build, ship it under your own name.
