## What this changes

<!-- One or two sentences. The diff says what; say why. -->

## Why it can't be a GN argument or a runtime flag

<!-- If it is a patch, answer this. If it is not a patch, delete the section. -->

## Verification

- [ ] `scripts/patch.sh revert && scripts/patch.sh apply` — the series applies clean
- [ ] `make build` succeeds
- [ ] `make test` passes
- [ ] Manually tested on: <!-- Linux / macOS / Windows, and version -->

<!-- If this changes what the browser sends over the network, say how you
     verified it — a proxy log, not an assertion. -->

## Rebase risk

<!-- Which upstream files does this touch, and how likely are they to move? -->

## Related

<!-- Issue numbers, upstream bugs, the website page that documents this. -->
