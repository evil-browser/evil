# The ungoogled-chromium base

evil's privacy layer is [ungoogled-chromium](https://github.com/ungoogled-software/ungoogled-chromium)'s
patch set, not a reimplementation of it. Their 109 patches strip Google's
services out of Chromium, they have been maintained across upstream releases for
years, and they are BSD-3 licensed. Rewriting that from scratch would take
months and would be worse.

evil's own contribution sits on top: branding, the extension suite, the
configuration payload, the performance profile, and the features in
[../patches/PLANNED.md](../patches/PLANNED.md).

## Version pinning

Two files, and they must agree:

```
CHROMIUM_VERSION     152.0.7977.64
UNGOOGLED_VERSION    152.0.7977.64-1
```

`scripts/upstream.sh fetch` clones their repository at `UNGOOGLED_VERSION` and
refuses to continue if their `chromium_version.txt` does not match ours. A
mismatch means patches written against a different tree, which fails in
confusing ways hours into a build.

To bump both:

```sh
scripts/upstream.sh latest
echo 152.0.8000.10   > CHROMIUM_VERSION
echo 152.0.8000.10-1 > UNGOOGLED_VERSION
make unpatch && make sync && make upstream && make patch
```

## What `make patch` does, in order

1. **Prune** — deletes 13,848 bundled binaries and blobs from the tree.
2. **Apply upstream patches** — their series, minus our exclusions.
3. **Domain substitution** — *skipped by default*, see below.
4. **Apply evil patches** — `patches/series`, on top.

## Exclusions

`patches/upstream-exclude.list` names upstream patches we deliberately skip.
Each one is a product decision, and each costs something.

| Excluded | Why |
| --- | --- |
| `core/ungoogled-chromium/disable-webstore-urls.patch` | It disables Chrome Web Store integration and extension auto-updates. evil keeps the store open on purpose: the answer to a hostile extension ecosystem is auditing what you install ([evil Guard](EXTENSIONS.md)), not walling off the only place most people get extensions. |

Excluding an upstream patch is not free. It can break a later patch that assumed
it, and it has to be re-justified on every version bump. Add one only when a
product requirement genuinely conflicts, and write the reason in this table.

## Domain substitution is off by default

Their `domain_substitution.py` rewrites every Google-owned hostname in the
source to a non-resolving placeholder — `google.com` becomes `9oo91e.qjz9zk`.
It is a good belt-and-braces measure against a URL nobody noticed.

It also rewrites `clients2.google.com`, which is the Chrome Web Store's update
endpoint. With substitution on, the Web Store cannot install or update
anything, and the first-run extension fetch in `config/external_extensions/`
silently fails.

Those two facts cannot both be satisfied. evil keeps the store, so substitution
is opt-in:

```sh
EVIL_DOMSUB=1 make patch
```

Turn it on if you would rather have the stronger guarantee and install
extensions by dropping CRXs in by hand. The build is otherwise identical.

## GN argument layering

Their `flags.gn` is read first, then ours override it:

```
ungoogled flags.gn → common.gni → <platform>.gni → <config>.gni → performance.gni → local.gni
```

Deliberate overrides worth knowing:

| Argument | Upstream | evil | Why |
| --- | --- | --- | --- |
| `chrome_pgo_phase` | `0` | `2` | They disable profile-guided optimisation for reproducibility. We want the ~10% it buys on real page loads, and `sync.sh` already fetches the profiles. |

Anything they set that we do not override stays exactly as they set it. Our
`common.gni` deliberately does not repeat their values — duplicating a flag
means two places to update and one to forget.

## Credit

BSD-3 requires the copyright notice to travel with the code. It is in
[../NOTICE](../NOTICE), and it belongs there permanently. If evil is ever useful
to anyone, a large share of the reason is work these people did first.
