# Testing

## Automated

```sh
make test                                   # evil_unittests
scripts/build.sh --target unit_tests        # upstream unit tests
scripts/build.sh --target browser_tests     # upstream browser tests (slow)
```

CI runs `evil_unittests` and a filtered subset of `browser_tests` on every pull
request, on all three platforms. The full upstream suite runs nightly.

## The manual pass before a release

Do this on each platform. It takes about twenty minutes and it catches the
things unit tests structurally cannot.

**Install and first run**
- [ ] Clean install; first-run flow completes without a network connection
- [ ] Import from Chrome, Firefox and Edge (where installed) — bookmarks,
      history, passwords, cookies, with the source browser *closed*
- [ ] Import again; entries merge rather than duplicate

**Shields**
- [ ] Ads and trackers blocked on a news site at Standard
- [ ] YouTube plays with no ads
- [ ] Strict breaks something; per-site override fixes it and persists

**Fingerprinting**
- [ ] Two different sites report different canvas hashes
- [ ] The same site reports a stable hash across a reload
- [ ] A canvas-based captcha completes

**Media**
- [ ] Netflix, Spotify and a DRM test stream all play
- [ ] Widevine appears in `evil://components`

**Burn**
- [ ] Burn clears cookies, history and cache across two profiles
- [ ] Burn exceptions survive the burn
- [ ] Bookmarks and saved passwords survive the burn

**Update**
- [ ] `evil://settings/updates` reports the correct channel
- [ ] With updates disabled, no request is made — verify with a proxy, not by
      trusting the setting

**Networking hygiene**
- [ ] With a proxy in front of a fresh profile: no request to any Google domain
      during startup and five minutes of idling

That last check is the one that matters most. It is the claim on the front page
of the website, and it is the one an outsider can most easily disprove.
