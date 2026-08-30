# Extensions

Three components ship with the browser. Full documentation, including the risk
model behind Guard and the design of Shield's two-layer spoofing, is in
[../docs/EXTENSIONS.md](../docs/EXTENSIONS.md).

| Directory | Name | Surface |
| --- | --- | --- |
| `evil-shield` | evil Shield | Fingerprint randomization, platform masquerade |
| `evil-clean` | evil Clean | Burn browsing data |
| `evil-guard` | evil Guard | Extension permission auditing |

The theme lives one level up in [`../theme/evil-dark`](../theme/evil-dark).

## Layout

```
evil-shield/
├── manifest.json
├── background.js         service worker: settings, script registration, rulesets
├── page/
│   ├── core.js           MAIN-world overrides
│   └── profile-*.js      one per platform, loaded before core.js
├── rules/*.json          declarativeNetRequest header rewrites, one per platform
└── ui/                   popup and options
```

`evil-clean` and `evil-guard` follow the same shape without `page/` and `rules/`.
`evil-guard/risk.js` holds the scoring table and is the only file worth reading
first.

## Running them

```sh
../scripts/dev-run.sh --fresh
```

## Packing for release

```sh
../tools/pack-extensions.sh
```

Writes CRXs to `dist/extensions/` and keeps the signing keys in `.keys/`, which
is gitignored. The keys determine the extension IDs — losing them means every
installed copy is treated as a different extension on the next update. Back them
up somewhere that is not this repository.
