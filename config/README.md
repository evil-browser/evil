# Configuration payload

Files installed alongside the binary. What each key does and why is in
[../docs/HARDENING.md](../docs/HARDENING.md).

| File | Installed to | Effect |
| --- | --- | --- |
| `initial_preferences` | next to the executable | Defaults for every new profile |
| `external_extensions/*.json` | the browser's External Extensions directory | Fetches the Web Store extensions on first run |
| `policies/managed_policies.json` | `/etc/evil/policies/managed/` | Linux policy |
| `policies/st.evil.browser.plist` | `/Library/Managed Preferences/` | macOS policy |
| `policies/windows.reg` | `HKLM\SOFTWARE\Policies\evil` | Windows policy |

`scripts/package.sh` installs the first two automatically. Policy files are
optional for an individual install and are the mechanism for deploying evil
across a fleet.

## Testing the payload against a stock Chromium

The policies work on any Chromium build, which is the easy way to check them
without a full compile:

```sh
sudo mkdir -p /etc/chromium/policies/managed
sudo cp policies/managed_policies.json /etc/chromium/policies/managed/evil.json
chromium --user-data-dir=/tmp/evil-policy-test
```

Then open `chrome://policy` and confirm every key applied. On macOS:

```sh
sudo cp policies/st.evil.browser.plist "/Library/Managed Preferences/org.chromium.Chromium.plist"
sudo killall cfprefsd
```

## Default search

DuckDuckGo, keyword `duck.com`, `https://duckduckgo.com/?q={searchTerms}&t=evil`.
Suggestions are off, so nothing is sent while typing — only when you press
Enter. `duck.com` redirects to `duckduckgo.com`, so the search URL points
straight at the destination and skips the hop.

Policy pins it, but the prepopulated engine list inside Chromium still has
Google in it until the patch in [../patches/PLANNED.md](../patches/PLANNED.md)
lands.
