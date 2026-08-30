# Theme

Black, white, and grey. No accent colour — the interface should disappear and
leave the page as the only coloured thing on screen.

## Palette

| Token | Hex | Used for |
| --- | --- | --- |
| Frame | `#080808` | Window frame, inactive tab strip |
| Toolbar | `#1a1a1a` | Toolbar, active tab |
| Omnibox | `#262626` | Address bar field |
| Text | `#f2f2f2` | Active tab and toolbar text |
| Text dim | `#969696` | Inactive tab text |
| Text dimmer | `#6e6e6e` | Disabled states |
| Icon | `#e2e2e2` | Toolbar button glyphs |
| New tab page | `#0a0a0a` | Background |

The same tokens drive the extension UIs (`extensions/*/ui/ui.css`) and the
website, so the browser and evil.st read as one thing.

## Where it lives

`theme/evil-dark/manifest.json` is a standard Chromium theme extension. It is
installed like any other component and can be removed, which is the point: a
theme is a preference, not a brand statement.

The button tints are set to `[-1.0, -1.0, -1.0]`, which leaves Chromium's icons
alone rather than letting it tint them toward a hue. Anything else reintroduces
colour.

## Changing it

Edit the `colors` block and reload from `evil://extensions`. Values are RGB
triples, 0–255. Keep contrast at or above 4.5:1 between any text colour and the
surface behind it; the palette above clears that everywhere except the dimmest
grey on the toolbar, which is only used for disabled controls.

## Beyond a theme

A theme extension cannot reach the tab shape, the corner radius, the density of
the toolbar, or the new-tab page layout. Those are C++ and are listed in
[../patches/PLANNED.md](../patches/PLANNED.md) under branding. The theme gets
the colours right today; the patches get the geometry right later.
