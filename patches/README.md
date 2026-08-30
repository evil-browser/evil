# The patch set

Everything evil changes about Chromium lives here as a patch against the tag in
[`../CHROMIUM_VERSION`](../CHROMIUM_VERSION). The order of application is given
by [`series`](series) — not by filename, not by directory listing.

```
patches/
├── series        the ordered list; the only thing that decides what applies
├── build/        toolchain, GN and packaging changes
├── branding/     product name, icons, evil:// scheme
├── privacy/      Google service removal, fingerprint defences, burn-all
└── features/     content blocker, containers, tab management
```

## Naming

```
<category>/<NNNN>-<short-imperative-description>.patch
privacy/0003-remove-safe-browsing-pings.patch
```

The number orders patches *within* a category and is four digits with gaps of
ten, so a patch can be inserted later without renumbering the world.

## Rules for a patch

- **One concern per patch.** A reviewer should be able to state what it does in
  one sentence, and revert it without touching anything else.
- **A header comment at the top.** What it changes, why, and what upstream file
  it will conflict with on the next rebase.
- **No unrelated formatting.** A patch that reflows a file it barely touches is
  a patch nobody can rebase.
- **Prefer a GN flag to a patch.** If upstream already has a build argument that
  does the job, put it in `build/args/` and delete the patch.
- **Never patch generated files.** Patch the generator.

Adding, refreshing and rebasing patches is walked through in
[`../docs/PATCHES.md`](../docs/PATCHES.md).

## Why the directory is empty

Everything that can be done without patching Chromium is done in
[`../build/args/`](../build/args), [`../config/`](../config) and
[`../extensions/`](../extensions) — which is most of it. `series` is the source
of truth for what is applied today; it is empty, so `make patch` is currently a
no-op and `make build` produces a Chromium configured by the GN arguments alone.

The work that genuinely requires C++ is enumerated, with the upstream file each
item lands in, in [PLANNED.md](PLANNED.md).
