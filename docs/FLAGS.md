# Runtime flags and settings

Every standard Chromium switch works. These are the ones evil adds.

## Command-line switches

| Switch | Effect |
| --- | --- |
| `--shields=strict\|standard\|off` | Shield level for this launch |
| `--no-fingerprint-noise` | Disable fingerprint randomization (for isolating breakage) |
| `--burn-on-exit` | Burn all browsing data when the last window closes |
| `--profile-dir=NAME` | Launch straight into a named profile |
| `--container=NAME` | Open the given URLs in a container |
| `--force-low-memory` | Enter low-memory mode regardless of installed RAM |
| `--no-low-memory` | Never enter low-memory mode |
| `--no-update-check` | Skip the update check for this run |

## Internal pages

| Page | Shows |
| --- | --- |
| `evil://settings/shields` | Shield levels, per-site rules, custom filter lists |
| `evil://settings/burn` | Burn scope and exceptions |
| `evil://settings/containers` | Container definitions and domain rules |
| `evil://settings/updates` | Channel and update behaviour |
| `evil://memory` | Per-tab and per-extension resident set |
| `evil://policy` | Active enterprise policy, with its source |
| `evil://version` | Version, Chromium base, applied patch-set hash |
| `evil://credits` | Third-party licences for this build |

## Enterprise policy

Read from Chromium's usual locations, plus these keys:

| Key | Type | Values |
| --- | --- | --- |
| `EvilShields` | string | `strict`, `standard`, `off` |
| `EvilBurnOnExit` | bool | |
| `EvilFingerprintNoise` | bool | |
| `EvilUpdateChannel` | string | `stable`, `beta`, `nightly` |
| `EvilUpdateEnabled` | bool | |

```
Windows  HKLM\SOFTWARE\Policies\evil\
macOS    /Library/Managed Preferences/st.evil.browser.plist
Linux    /etc/evil/policies/managed/*.json
```

## Adding a flag

Runtime flags are cheaper than patches for anything a user might want to turn
off, and much cheaper than a fork of the feature. When you add one:

1. Register it in the switches patch, with a comment.
2. Document it here **and** on the website's docs page — a flag nobody can find
   is a flag that generates bug reports.
3. Give it a policy key too, if an administrator would plausibly want it.
