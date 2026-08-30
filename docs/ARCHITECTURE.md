# Architecture

## The shape of the project

evil is not a copy of Chromium with edits. It is:

```
  Chromium @ CHROMIUM_VERSION        (fetched, never committed)
+ patches/series                     (a few hundred KB, reviewable)
+ build/args/*.gni                   (what can be done without patching)
+ resources/branding/                (name, icons, strings)
= evil
```

Keeping it that way is the single most important constraint in the repository.
Every time someone copies a Chromium file into this tree "just to change one
line", the cost of the next security bump goes up permanently.

**Rule of thumb:** if upstream exposes a GN argument or a runtime flag that does
what you want, use it. If it exposes an extension point, use it. Patch the tree
only when neither exists — and when you do, patch the smallest surface you can.

## Where each feature lives

| Feature | Layer | Notes |
| --- | --- | --- |
| Google service removal | `build/args/common.gni` + `patches/privacy/` | Most of it is GN arguments; the patches remove code paths GN can't reach. |
| Content blocking | `patches/features/` | The filtering engine sits in the network service, below the extension system, so Manifest V3 policy cannot restrict it. |
| Fingerprint noise | `patches/privacy/` | Hooks in Blink at the point each surface is read: canvas readback, WebGL parameter queries, `AudioContext`, font enumeration, client hints. |
| Burn-all | `patches/features/` | Drives the existing `BrowsingDataRemover` across every profile, plus network-stack state upstream does not clear. |
| Containers | `patches/features/` | A `StoragePartition` per container, with the tab strip carrying the container id. |
| Tab freezing/discarding | `patches/features/` | Tightens upstream's `TabLifecycleUnit` policy; keeps title, favicon and scroll offset. |
| Branding | `patches/branding/` + `resources/branding/` | Product strings, icons, and the `chrome://` → `evil://` rename. |
| Update mechanism | `patches/features/` | Replaces the Google update client; see [FLAGS.md](FLAGS.md) and the privacy statement. |

## The fingerprinting model, briefly

Two properties have to hold at once, and they pull against each other:

1. **Across sites and sessions**, the same machine must look like different
   machines, or the noise achieves nothing.
2. **Within one site and one session**, the machine must look *stable*, or
   logins, canvas-based captchas and WebGL apps break in ways users blame on the
   browser rather than on the tracker.

So the noise seed is derived from `(session id, eTLD+1)` rather than being
per-call random. That is the whole design, and it is why "just randomise every
call" — which several forks do — produces a browser people uninstall.

## Process model

Unchanged from upstream: same sandbox, same site isolation, same renderer
boundary. None of the patches weaken a security boundary, and a patch that does
will not be merged. Where a privacy patch and a security boundary conflict, the
boundary wins and the privacy feature is implemented somewhere else.

## Upstream cadence

- Chromium ships a security release roughly every two weeks.
- We bump `CHROMIUM_VERSION`, refresh the patch set, build all three platforms,
  and ship within 72 hours of that release.
- A patch that cannot be refreshed in time is *dropped*, not held — shipping
  late on a security fix to preserve a feature is the wrong trade, every time.

That deadline is the reason for every "keep the patch set small" rule above.
