# Working with the patch set

## Adding a change

```sh
make patch                        # start from the applied state
$EDITOR src/some/file.cc          # make your change in the Chromium tree
scripts/build.sh                  # verify it builds and does what you claim
scripts/patch.sh export privacy/0040-short-description.patch
```

`export` writes `git diff` from `src/` into that file and appends it to
`patches/series` if it isn't listed. **Open the file afterwards** and:

1. Add a header comment: what it changes, why, and which upstream files it will
   conflict with next time.
2. Delete anything unrelated that crept in.
3. Move it to the right position in `series` if order matters.

Then verify it applies from clean:

```sh
scripts/patch.sh revert
scripts/patch.sh apply
```

A patch that only applies to your working tree is not a patch.

## Splitting a change

`export` captures the whole diff of `src/`. If you have made two unrelated
changes, export them one at a time: stash the other, export, unstash. Two
concerns in one patch is the most common review rejection.

## Rebasing onto a new Chromium

```sh
git checkout -b bump/141.0.7420.42
echo 141.0.7420.42 > CHROMIUM_VERSION
make unpatch
make sync
make patch                        # stops at the first patch that no longer applies
```

When one fails:

```sh
cd src
git apply --3way ../patches/privacy/0030-example.patch   # leaves conflict markers
# resolve the conflicts in the affected files
cd ..
scripts/patch.sh export privacy/0030-example.patch       # overwrite with the fixed version
```

Then `revert` and `apply` the whole series again from clean, and keep going
until the series applies end to end. Commit the refreshed patches and the
`CHROMIUM_VERSION` bump together, one commit, with the upstream release notes
linked in the message.

If a patch has been fighting the rebase for three releases running, it is a
signal, not bad luck: either the feature belongs upstream as a proper extension
point, or it should be reimplemented somewhere more stable. Say so in the PR
rather than refreshing it a fourth time.

## Removing a patch

Delete the file and its line in `series`. Don't leave commented-out entries —
git remembers, `series` should only describe the present.

## What does not belong in a patch

- **Anything a GN argument can do.** Put it in `build/args/`.
- **Anything a runtime flag can do.** Put it in [FLAGS.md](FLAGS.md).
- **Formatting.** `git diff --stat` on your patch should be small and boring.
- **Generated files.** Patch the generator, not its output.
- **Vendored third-party code.** Add it through DEPS, or reconsider.

## Reviewing a patch

The questions a reviewer asks, in order:

1. Can this be done without patching?
2. Does it touch a security boundary? (If yes: it needs a second reviewer.)
3. How hard will this be to refresh in three months?
4. Is the claim it makes on the website actually true of this code?
