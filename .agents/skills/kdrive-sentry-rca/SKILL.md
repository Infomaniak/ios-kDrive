---
name: kdrive-sentry-rca
description: "Investigate iOS kDrive crashes, app hangs, watchdog terminations, extension failures, and Sentry issues to produce source-grounded root cause analyses. Use when asked to perform RCA, diagnose a crash or Sentry issue/URL, analyze a File Provider/share/action extension failure, investigate an upload or background-execution failure, rank crash issues, or explain why the iOS app stopped responding or terminated."
---
# kDrive iOS Sentry Root Cause Analysis

Use the self-hosted mobile Sentry at `https://sentry-mobile.infomaniak.com`, organization `sentry`, project `kdrive-ios`, together with repository source. Never use Sentry SaaS or the desktop Sentry instance for iOS incidents.

Sentry is the primary production runtime evidence source. The app does not provide complete application log files for RCA: it writes local unified logs through OSLog, mirrors only selected operations to Sentry breadcrumbs or events, and has session replay disabled. Do not ask for an app log archive by default or imply that Sentry contains a complete log stream.

The objective is an evidence-based causal explanation, not a paraphrase of the issue title or top stack frame. Trace the failure backward through the exact event, all relevant threads, breadcrumbs, contexts/extras, release metadata, and source until identifying the violated invariant, invalid state transition, blocking operation, resource pressure, lifecycle race, or external condition that made the failure possible.

Read `references/sentry-projects.md` for executable and source routing. Read `references/ios-evidence-and-correlation.md` for telemetry coverage, Apple failure modes, and app/extension correlation.

## Investigation Rules

- Start read-only. Do not resolve, assign, comment on, merge, or otherwise mutate a Sentry issue unless the user explicitly asks.
- Treat issue frequency, affected-user count, first/last seen, release, environment, iOS version, device model/class, app identifier, build type, regression state, and foreground/background state as evidence.
- Inspect a representative event, not only aggregate issue metadata. Prefer a recent production event with usable symbols in the affected release and executable. Compare multiple events when stacks, app identifiers, releases, iOS versions, or device classes vary.
- Use exact Sentry URLs returned by tools. Do not invent issue IDs, organization slugs, project links, event links, or query links.
- Never expose access tokens, DSNs, emails, user names, IP addresses, geolocation, device or installation identifiers, customer filenames, local paths, request/response bodies containing personal data, or raw user/drive/file/upload/task/request identifiers. Use identifiers internally for matching, then report only that values matched or a minimally masked suffix when essential.
- Do not equate Sentry's `user.id` across events without verifying its source semantics. It can be the backend account ID after account initialization or an SDK-generated identifier before that. Never publish either value.
- Do not claim that app and extension events are one incident based on time or user alone. Require a matching operation identifier from the same domain, trace, backend request, release/build plus a distinctive causal sequence, or other source-validated evidence.
- Do not equate the crash site with the root cause. `swift_fatalError`, `abort`, `SIGABRT`, `EXC_BAD_ACCESS`, allocator frames, `objc_exception_throw`, watchdog termination, and Sentry's app-hang mechanism are terminal symptoms.
- Classify the event before analyzing it. A manually captured message or handled error is not proof of a crash. The project intentionally captures high-volume telemetry such as `UploadCompletedSuccess`, so an issue list sorted by events is not a crash ranking.
- Distinguish product defects from expected external failures such as network loss, backend errors, removed files, revoked Photo Library access, low storage, extension cancellation, and iOS resource limits. If an expected condition leads to a crash or permanent stall, explain the defective handling.
- Treat missing breadcrumbs as weak evidence. Only selected OSLog calls become Sentry breadcrumbs, breadcrumb creation can be asynchronous, abrupt process termination can prevent late telemetry, and users can disable Sentry reporting.
- Account for consent filtering and build filtering. Debug/test events are discarded and production events are discarded when Sentry authorization is disabled, so event and user totals understate real-world incidence.
- If Sentry access, symbols, exact release source, event context, or correlation identifiers are missing, state the limitation and reduce confidence when it affects the conclusion.

## Workflow

### 1. Verify Sentry Access

When the request involves an issue/event, crash ranking, frequency, regression, release impact, or app/extension correlation, verify authenticated access to the mobile self-hosted Sentry instance before making Sentry-backed claims.

If Sentry access is unavailable:

- State that mobile Sentry could not be queried and recommend connecting/authenticating the Sentry MCP for the most accurate analysis.
- Continue with a supplied crash diagnostic, stack trace, reproduction steps, screenshots, and repository source when useful.
- Clearly distinguish user-supplied evidence from data independently verified in Sentry.
- Do not infer issue status, event volume, affected users, release distribution, regression state, symbolication quality, or the absence of related events.
- Reduce confidence when unavailable Sentry evidence is material. Do not repeatedly request access after acknowledging the limitation.

### 2. Frame The Incident

Extract or ask for only information that materially narrows the search:

- Exact Sentry issue/event URL or issue ID, or the observable symptom.
- Approximate timestamp and timezone when trying to isolate one occurrence.
- User action or subsystem involved: launch, browsing, preview, upload, photo backup, download, authentication, File Provider, share/action extension, or background refresh.
- App version/build and production, TestFlight/beta, or internal channel when known.
- Scope requested: one occurrence, one issue group, a release regression, or highest-impact crashes.

Do not ask for unavailable app logs. Ask for reproduction steps or an exported Apple crash/termination diagnostic only when Sentry lacks the evidence needed to distinguish hypotheses.

If the user supplies a Sentry URL, fetch that exact resource first. Otherwise search `kdrive-ios` over the narrowest reasonable period. For broad ranking requests, default to unresolved crash, fatal hang, watchdog-like, and unhandled exception issue groups active in the last 30 days. Exclude manual success/diagnostic events and handled operational errors unless the user asks about them.

Prefer explicit Sentry query syntax. If AI-powered search is unavailable, continue with direct filters, issue-event search, tag distributions, and aggregate fields rather than treating it as a connectivity failure.

### 3. Identify The Executable

All iOS app and extension events share `kdrive-ios`; route by event metadata, not by project name alone. Prefer `app_identifier`, then the bundle prefix in `release`, then `app_name`:

- `com.infomaniak.drive`: main app. Start in `kDrive/`; shared data, networking, upload/download, and persistence logic is in `kDriveCore/`.
- `com.infomaniak.drive.FileProvider`: Files app extension. Start in `kDriveFileProvider/`, then follow calls into `kDriveCore/`.
- `com.infomaniak.drive.ShareExtension`: share sheet extension. Start in `kDriveShareExtension/` and shared save/upload code.
- `com.infomaniak.drive.ActionExtension`: action extension. Start in `kDriveActionExtension/` and shared save/upload code.

Do not assume a main-app crash because the issue title says kDrive. App extensions are separate, short-lived processes with their own memory, lifecycle, and execution limits.

### 4. Classify The Failure

Determine which evidence model applies before tracing source:

- **Native crash:** inspect exception/signal/mechanism, crashed thread, first-party frames, and other threads relevant to ownership or concurrency.
- **Swift/Objective-C trap:** treat `fatalError`, failed precondition, assertion, forced cast/unwrap, or uncaught exception as the terminal enforcement point; identify the invalid state and how it arrived.
- **App hang:** inspect the complete main-thread stack and compare representative samples. Determine whether it is CPU work, synchronous I/O, lock/semaphore wait, Realm work, main-actor contention, or a dependency call. A sampled frame alone is not proof of the blocker.
- **Fatal hang/watchdog termination:** separate the blocking sequence from the OS termination. Inspect lifecycle state, duration, extension process, and all implicated threads.
- **Memory/resource termination:** use memory context, device class, operation, recurrence, and any Apple termination evidence. A disappearance, low free-memory value, or unsymbolicated termination alone does not confirm OOM.
- **Handled error/manual message:** inspect capture call, level, extras, retries, and user-visible outcome. Do not describe it as a crash unless an unhandled event or termination is independently present.
- **Extension failure:** consider cancellation, expiration, memory pressure, coordination, stale shared Realm/app-group state, and completion-handler ordering as well as ordinary exceptions.

### 5. Inspect Representative Events Deeply

Capture the following from each selected event:

- Exact event ID, timestamp, issue/event URL, exception/signal/assertion, mechanism, handled state, and level.
- Full stack of the crashed or blocked thread. For hangs, explicitly fetch the main thread; inspect lock owners or worker threads when relevant.
- Breadcrumbs immediately preceding the failure. Compare breadcrumbs across events instead of assuming the latest event is typical.
- `release`, `dist`, environment, `app_identifier`, `app_name`, app version/build, build type, app start time, foreground/active state, current view, iOS version/build, device model/class/architecture, and simulator state.
- Relevant memory, storage, thermal, low-power, battery, network, orientation, and locale context when present. Do not over-interpret absent fields.
- Custom contexts/extras from `SentryDebug`, especially upload state, root/underlying errors, retry state, Realm migration/opening context, API errors, File Provider operation, and background expiration.
- Symbolication quality, missing first-party frames/debug files, suspect grouping, and whether the issue combines different executables or mechanisms.

Use issue-event search and tag distributions to choose variants by release, bundle identifier, iOS, and device. Use full event stacktrace and breadcrumb tools rather than relying on condensed issue output. Inspect user reports or event attachments only when present and relevant; do not assume they exist.

### 6. Build A Sentry Timeline

Normalize timestamps, normally to UTC, and record:

- Process/app start and foreground/background or extension lifecycle state.
- Last successful operation or known-good state.
- First anomalous warning, error, retry, cancellation, expiration, memory warning, or state transition.
- Navigation, API, Realm, upload/download, Photo Library, File Provider, and background-session breadcrumbs relevant to the failure.
- Blocking/crashing operation and terminal mechanism.
- Subsequent relaunch, retry, or related app/extension event when independently correlated.

Use the correlation hierarchy in `references/ios-evidence-and-correlation.md`. State which identifier domains matched and which evidence was unavailable. Timestamp proximity alone is only a lead.

### 7. Align The Event With Source

Before drawing conclusions from current source:

1. Record the current branch and `HEAD` commit.
2. Extract bundle identifier, marketing version, build number, release, build type, and distribution from the event.
3. Resolve the release to the exact repository tag when possible. Current tags normally use `Release-<version>-b<build>` for App Store and `Beta-<version>-b<build>` for beta builds.
4. Compare incident source with the current checkout.

Do not check out tags, switch/modify branches, reset the worktree, or otherwise change the user's checkout. Inspect historical revisions with read-only commands such as `git show`, `git log`, `git diff`, and `git blame`.

When the incident revision differs from the current checkout:

- Prefer source from the exact incident tag/commit for causal analysis.
- Compare it with current implementation only to assess whether relevant behavior changed.
- Cite historical source as `<tag-or-commit>:<path>:<line>` rather than applying current-worktree line numbers to it.
- Do not claim the issue is fixed merely because source differs. Identify the change and verify it addresses the observed sequence.
- If no exact tag/source is available, label source conclusions provisional and reduce confidence.

### 8. Trace Into Source

Search exact function names, assertion/trap text, custom event names, breadcrumb messages, error descriptions, enum cases, and context keys. Read enough surrounding code, callers, and async/queue boundaries to reconstruct state, ownership, lifecycle, and thread confinement.

Follow the relevant path:

- App launch/lifecycle/deep link -> `AppDelegate`, `SceneDelegate`, `AppRouter` -> controller/view model -> `kDriveCore` manager.
- Upload/photo backup -> uploader/queue -> `UploadOperation` -> background session -> publish/Realm state.
- File Provider request -> extension override/enumerator -> `DriveFileManager`/upload/download service -> completion handler.
- API request -> endpoint/fetcher -> `DriveError` mapping -> retry/authentication -> caller state transition.
- Realm notification/write/migration -> accessor/manager -> freeze/thread boundary -> observer/UI update.
- Hang -> main-thread frame -> synchronous dependency/lock/I/O -> owner thread or awaited work -> lifecycle constraint.
- Background expiration/cancellation -> task/session owner -> cancellation/completion ordering -> persisted state and next launch.

Inspect tests that encode the intended invariant. A missing test is supporting evidence, not proof. When the failure originates in Realm, Sentry Cocoa, Alamofire, UIKit, FileProvider, Photos, or another dependency, establish whether app code violated the dependency contract before labeling it a third-party or Apple defect.

### 9. Test Competing Hypotheses

Maintain at least one alternative until evidence rules it out. For each hypothesis record:

- Evidence for it.
- Evidence against it.
- What observation, event variant, source path, or reproduction would confirm/falsify it.

Use these confidence levels:

- **Confirmed:** direct event evidence and source establish the causal chain, ideally with reproduction or a failing regression test.
- **High:** multiple independent signals support the cause and no material evidence conflicts, but no reproduction exists.
- **Medium:** source makes the cause plausible and runtime evidence matches partially, but a key transition, symbol, or correlation marker is missing.
- **Low:** inferred mainly from the terminal stack, issue title, or timing; substantial alternatives remain.

Never state "root cause" as fact below Confirmed confidence. Use "probable cause" or "leading hypothesis."

### 10. Report With Progressive Disclosure

Perform the full investigation before answering, but default to a concise report unless the user asks for a full RCA, developer analysis, detailed timeline, or fix proposal:

```markdown
## RCA Summary
**Likely cause:** One precise, plain-language causal statement.
**Confidence:** Confirmed, High, Medium, or Low.
**Impact:** Executable, releases/iOS/devices, and scale when verified.

**Why:** Two or three strongest evidence points, including the exact Sentry link and relevant source area.

**Fix direction:** One sentence naming the likely correction and component.

**Limitations:** The most important missing evidence, if any.
```

Keep the initial report support-friendly. Do not include a raw user identifier, full stack, exhaustive timeline, or all rejected hypotheses. Offer the detailed RCA when useful.

For a requested full RCA, use:

```markdown
## Conclusion
**Probable cause:** One precise causal statement.
**Confidence:** Confirmed, High, Medium, or Low.
**Impact:** Executable, releases, iOS/devices, event/user counts, and time window.
**Source alignment:** Exact incident tag/commit or current-source-only limitation.

## Evidence
1. Runtime evidence with timestamp and exact Sentry link.
2. Thread, breadcrumb, context, or correlated process evidence.
3. Source evidence with `path:line` or `<tag>:<path>:<line>` references.

## Failure Sequence
1. Initiating condition.
2. Invalid transition, blocking operation, or mishandled state.
3. Terminal mechanism and visible symptom.

## Alternatives
- Alternative explanation and why it is less likely or remains open.

## Recommended Fix
- Smallest code-level correction and target area.
- Regression test reproducing the causal sequence.
- Telemetry improvement if missing Sentry evidence prevented confirmation.

## Unknowns
- Missing symbols, event fields, exact source, Apple diagnostic, or reproduction evidence.
```

For ranking requests, state the metric. If "biggest" is unspecified, rank crash issue groups by affected users first and event volume second, with recency and regression state as context. Exclude known success/diagnostic events and clearly separate unhandled crashes, fatal hangs, nonfatal hangs, and handled operational errors. Label uninvestigated rows **crash issue groups** or **terminal signatures**, not root causes. Fully investigate only the top item unless the user asks for every cause.

## Completion Standard

An investigation is complete only when it:

- Names the executable/bundle identifier and `kdrive-ios` project.
- Classifies the event and separates initiating condition, product defect, and terminal mechanism.
- Cites exact Sentry runtime evidence and source evidence.
- Uses representative events or explains why only one event was available.
- Verifies source against the incident tag/commit or discloses a mismatch.
- Assigns confidence and records a material alternative.
- Proposes the smallest plausible fix area, regression test, and any necessary telemetry improvement.
- Does not assume app logs or session replay exist.
- Avoids exposing customer data, identifiers, or credentials.
