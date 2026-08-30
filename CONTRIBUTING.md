# Contributing

## What helps most right now

1. **Testing on hardware and distributions we don't have.** Unusual GPUs,
   Wayland compositors, non-Debian distributions, older macOS, Windows on ARM.
2. **Site breakage reports.** A page that only breaks with shields on, or only
   with fingerprint noise on, is a concrete, fixable bug — and the report is
   nearly useless without the URL and the shield level.
3. **Filter list maintenance.** Rules that break sites, and rules that should
   exist and don't.
4. **Documentation.** If something in `docs/` was wrong or missing when you
   followed it, that is a bug in the docs, and the fix is welcome.

Feature-sized patches are welcome too, but read
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) first — the constraint that the
patch set stays small and rebaseable shapes what can be accepted.

## Reporting a bug

Include:

- The output of `evil://version` (version, Chromium base, patch-set hash)
- Your OS and version
- Exact steps, and what you expected instead
- Whether it reproduces with shields off (`Alt`+`S`) and with
  `--no-fingerprint-noise`
- Whether it reproduces in stock Chromium of the same version — if it does, it
  belongs in [Chromium's tracker](https://issues.chromium.org), and saying so
  saves everyone a day

Nightly bugs: reproduce on beta before reporting.

## Pull requests

```sh
git checkout -b feature/short-description
# work in src/, then:
scripts/patch.sh export features/0050-short-description.patch
scripts/patch.sh revert && scripts/patch.sh apply    # verify it applies clean
make build && make test
```

- One concern per PR, and one concern per patch inside it.
- Explain in the description what it changes, why, and what it will conflict
  with on the next Chromium bump.
- Anything touching a security boundary, the sandbox, or site isolation needs a
  second reviewer and will take longer. That is not distrust; it is the process.
- If your change makes a claim the website repeats — "sends nothing", "clears
  everything" — say how you verified it. A proxy log beats an assertion.

Commit messages: imperative mood, a subject under 72 characters, and a body that
explains *why*. The diff already says what.

## Style

Chromium's, because most of the code you touch is Chromium's:
[C++](https://chromium.googlesource.com/chromium/src/+/main/styleguide/c++/c++.md),
[Python](https://chromium.googlesource.com/chromium/src/+/main/styleguide/python/python.md).
For this repository's own shell and Markdown, follow `.editorconfig` and the
surrounding files.

## Licence of contributions

By submitting a patch you agree it can be distributed under the BSD 3-Clause
licence in [LICENSE](LICENSE). Don't submit code you don't have the right to
relicense — including code produced by a tool whose output terms you haven't
read.
