# Security policy

## Reporting a vulnerability

**Do not open a public issue for a security bug.**

Use GitHub's private vulnerability reporting on this repository
(Security → Report a vulnerability), or email `security@evil.st`. A PGP key for
that address is published at `https://evil.st/.well-known/security.txt`.

Include: affected version (`evil://version`), platform, reproduction steps or a
proof of concept, and what an attacker gains. If you have a suggested fix, say
so — it usually shortens the timeline considerably.

## What to expect

| | Target |
| --- | --- |
| Acknowledgement | 48 hours |
| Initial assessment | 5 days |
| Fix for critical/high | 14 days |
| Fix for medium/low | Next scheduled release |
| Public disclosure | After a fix ships, coordinated with you |

We will keep you updated on the schedule, credit you in the release notes unless
you'd rather we didn't, and tell you honestly if we think a report is not a
vulnerability, with the reasoning.

## Scope

**In scope:** the patch set in this repository, the build and packaging
pipeline, the update mechanism, and anything where evil is *less* safe than the
Chromium it is built on.

**Out of scope:** vulnerabilities in unmodified upstream Chromium — report those
to [Chromium](https://issues.chromium.org/issues/new?component=1363614), which
runs a bounty programme; findings that require a compromised device or a
malicious extension the user installed; and fingerprinting protection being
imperfect, which it is, by construction (see below).

## On the privacy claims specifically

Fingerprint randomization raises the cost of tracking; it does not make anyone
anonymous, and a demonstration that a determined script can still correlate
sessions is a useful bug report but not a vulnerability. A demonstration that
the browser **sends data it claims not to send** absolutely is one, and we would
very much like to hear about it.

## Upstream security releases

Chromium security fixes are merged and shipped within 72 hours of the upstream
release, on every channel. If you are running a build older than the current
release, you are missing those fixes.
