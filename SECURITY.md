# Security Policy

## Scope and context

SignalBox is a learning repository. It contains **deliberately seeded bugs**,
documented in [`docs/SEEDED_BUGS.md`](docs/SEEDED_BUGS.md). None of them is a
security vulnerability: they are logic errors in filtering, sorting, paging,
state refresh and preference persistence. They do not weaken permissions, expose
data off the device, or enable code execution.

If you believe one of them *does* have a security consequence we missed, report
it as described below rather than opening a public issue.

## Supported versions

| Version | Supported |
| --- | --- |
| `main` | Yes |
| tagged releases | Latest only |

SignalBox is pre-1.0 and has no long-term support branches.

## Reporting a vulnerability

**Do not open a public issue for a security problem.**

Use GitHub's private vulnerability reporting:
[**Report a vulnerability**](../../security/advisories/new).

Please include:

- what the issue is and what an attacker can achieve
- the affected version, commit or branch
- step-by-step reproduction, including device and Android version
- any proof-of-concept you have
- whether you intend to disclose publicly, and when

What to expect:

- acknowledgement within **5 working days**
- an initial assessment within **10 working days**
- credit in the release notes, unless you ask us not to

Please give us a reasonable window to ship a fix before disclosing publicly.

## What is in scope

- Unauthorised access to the local notification database
- Leaking notification content off the device, or to another application
- Misuse or escalation of the Android notification-listener permission
- Exported Android components that should not be exported
- Dependencies with known, exploitable vulnerabilities that affect SignalBox
- Data leaking through logs, crash reports, backups or the recents screenshot

## What is out of scope

- The seeded bugs catalogued in `docs/SEEDED_BUGS.md`
- The unfinished features catalogued in `docs/MISSING_FEATURES.md`
- Attacks requiring a rooted device, physical access with an unlocked screen, or a malicious debug build
- Anything that requires the user to install a modified SignalBox APK
- The absence of at-rest encryption for the local database. SignalBox relies on
  Android's app sandbox and full-disk encryption. If you think that is the wrong
  trade-off, open a normal feature request so we can discuss it in public.
- Reports produced solely by an automated scanner, with no demonstrated impact

## Our security posture

SignalBox is local-first by design, which removes whole classes of risk:

- **No backend, no account, no telemetry.** There is no server to breach.
- **No network calls in the data path.** Notification content never leaves the device.
- **No third-party analytics or crash reporting.**
- **Minimal permissions.** `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, and the system notification-listener binding.
- **The listener service is not exported** and is protected by
  `android.permission.BIND_NOTIFICATION_LISTENER_SERVICE`, so only the system can bind to it.
- **SignalBox never captures its own notifications.**

Notification access is a sensitive Android permission and SignalBox can read the
content of every notification on the device. We take that seriously; please do
too when you contribute. A change that logs notification content, sends it over
the network, or widens the permission surface will not be merged.
