# What still needs a patch

Everything the extension and configuration layers can do, they already do — see
[../docs/HARDENING.md](../docs/HARDENING.md) and
[../docs/EXTENSIONS.md](../docs/EXTENSIONS.md). This file lists what they
*cannot* do, with the upstream file each item lands in. These are the patches
`patches/series` will grow, in roughly this order.

## build

**Toolchain and packaging only.** Most of what would go here is already a GN
argument in `build/args/`. Add a patch only when upstream offers no flag.

## branding

| Item | Upstream location |
| --- | --- |
| Product name, bundle id, copyright strings | `chrome/app/theme/chromium/BRANDING` → point at `resources/branding/BRANDING` |
| Application icons | `chrome/app/theme/chromium/` |
| `chrome://` → `evil://` scheme | `chrome/common/webui_url_constants.cc`, `content/public/common/url_constants.cc` |
| Tab shape, corner radius, toolbar density | `chrome/browser/ui/views/tabs/`, `chrome/browser/ui/layout_constants.cc` |
| New tab page without Google assets | `chrome/browser/new_tab_page/` |
| Remove the Chrome Web Store hint from the extensions page | `chrome/browser/resources/extensions/` |

The theme extension already carries the palette. These patches are about
geometry and strings, not colour.

## privacy

| Item | Why an extension cannot do it | Upstream location |
| --- | --- | --- |
| Canvas, WebGL and audio noise in the renderer | An extension patches JavaScript objects; a page can compare against a fresh iframe's prototypes to detect it. Doing it in Blink is invisible and cannot be raced at `document_start`. | `third_party/blink/renderer/core/html/canvas/`, `platform/graphics/`, `modules/webaudio/` |
| Font enumeration limits | Fonts are measured through layout, not an API a content script can intercept. | `third_party/blink/renderer/platform/fonts/` |
| DNS cache, socket pool and HSTS clearing on burn | `chrome.browsingData` does not expose them. | `chrome/browser/browsing_data/chrome_browsing_data_remover_delegate.cc` |
| Cross-profile burn | An extension only sees its own profile. | `chrome/browser/browsing_data/` |
| Update client replacement | Not reachable from an extension at all. | `chrome/browser/component_updater/`, `components/update_client/` |
| DuckDuckGo as the built-in default engine | Policy sets it, but the prepopulated list still ships Google first. | `components/search_engines/prepopulated_engines.json`, `template_url_prepopulate_data.cc` |
| Remove the remaining startup connections | Some survive both GN and policy. | `chrome/browser/browser_process_impl.cc`, `components/variations/service/` |

## features

| Item | Upstream location |
| --- | --- |
| uBlock Origin's engine in the network service | `services/network/`, `components/subresource_filter/` |
| Containers: a `StoragePartition` per tab group | `content/browser/storage_partition_impl.cc`, `chrome/browser/ui/tabs/` |
| Burn-all as a first-class UI surface and shortcut | `chrome/browser/ui/browser_commands.cc`, `chrome/app/chrome_command_ids.h` |
| Tab freezing and discarding policy | `chrome/browser/performance_manager/` |
| Shield level as a browser setting rather than an extension option | `chrome/browser/ui/webui/settings/` |
| Low-memory mode | `chrome/browser/performance_manager/`, `content/browser/renderer_host/render_process_host_impl.cc` |

## The rule that governs this list

Every item here costs a rebase every two weeks, forever. Before adding one, be
sure it cannot be a GN argument, a policy key, a preference, or an extension.
Half of what forks patch is a flag they did not find.
