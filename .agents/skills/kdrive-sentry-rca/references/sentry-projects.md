# kDrive iOS Sentry Routing

## Instance

- Base URL: `https://sentry-mobile.infomaniak.com`
- Organization slug: `sentry`
- Project slug: `kdrive-ios`
- Discover the organization/project again if tools report that either slug is unavailable. Never fall back to Sentry SaaS, `sentry-desktop.infomaniak.com`, or an Android project.

## Executables In The Project

All production app and extension processes use the same Sentry project. Identify the failing executable from event metadata before searching source.

| Bundle identifier / release prefix | Executable | Primary source | Notes |
|---|---|---|---|
| `com.infomaniak.drive` | Main iPhone/iPad app | `kDrive/`, then `kDriveCore/` | UIKit/SwiftUI UI, app/scene lifecycle, routing, account selection, photo backup, foreground/background work. |
| `com.infomaniak.drive.FileProvider` | File Provider extension | `kDriveFileProvider/`, then `kDriveCore/` | Files app enumeration/actions, item materialization, coordination, uploads/downloads. Separate process with extension resource/lifecycle limits. |
| `com.infomaniak.drive.ShareExtension` | Share sheet extension | `kDriveShareExtension/`, shared save/upload code, `kDriveCore/` | Separate short-lived process handling input item providers. |
| `com.infomaniak.drive.ActionExtension` | Action extension | `kDriveActionExtension/`, shared save/upload code, `kDriveCore/` | Separate short-lived process handling action-extension input. |

Use `app_identifier` as the authoritative routing field when present. Fall back to the bundle prefix in `release`, then `app_name`. Do not route solely from the issue title because one issue group can contain variants and the project is shared.

## Release To Source

Sentry Cocoa releases normally use:

```text
<bundle-identifier>@<marketing-version>+<build-number>
```

Examples of source-tag candidates:

```text
com.infomaniak.drive@6.1.0+125              -> Release-6.1.0-b125 or Beta-6.1.0-b125
com.infomaniak.drive.FileProvider@6.1.0+125 -> same repository tag, different executable
```

Use event `build_type`, environment, distribution, and release metadata to select `Release-...` versus `Beta-...`. Verify that the tag exists. Older versions use older tag naming conventions, so search tags rather than inventing one.

The CI post-build script uploads the Xcode archive and debug information to Sentry. Unsymbolicated first-party frames can still mean upload failure, UUID mismatch, processing delay, or unavailable artifacts. Treat symbolication as a prerequisite for stack-based conclusions, not as guaranteed by the script.

## Search Guidance

- Exact issue/event URL: fetch it unchanged first.
- One issue across variants: inspect issue events and distributions for `release`, `dist`, `os`, `device`, and executable metadata.
- Broad crash search: include unhandled native crashes, fatal app hangs/watchdog-like terminations, and relevant exception mechanisms; do not rely only on `level:fatal`.
- Production scope: use `environment:production` when present and verify `build_type`/release channel.
- Regression: compare first seen, release distribution, affected identities, event volume, executable, iOS, and device class. First seen in a release does not by itself prove the release introduced the defect.
- "Biggest": rank crash groups by affected users first, event volume second, after excluding manually captured success/diagnostic messages and handled errors.

## Link Policy

- Prefer exact issue, event, and query URLs returned by Sentry tools.
- Never construct a URL from a guessed numeric project or event ID.
- Link a related app/extension event only when correlation is supported by more than timestamp or user identity.
