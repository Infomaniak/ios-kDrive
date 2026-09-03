# iOS Sentry Evidence And Correlation

## Available Production Evidence

`Logging.initLogging()` starts Sentry in the app and extensions through shared `kDriveCore` code. A production Sentry event can provide:

- Native exception/signal, Sentry mechanism, handled state, crashed/blocked thread, and other thread stacks.
- Breadcrumbs captured by the SDK and selected application instrumentation.
- Custom contexts/extras from `SentryDebug`, including upload state, root errors, retry information, Realm context, API/File Provider details, and app preference state.
- Release/build, bundle identifier, app name/start time/lifecycle state, current view when available, iOS/device/memory/thermal/network context, and environment.
- Issue frequency, affected identities, release/device/OS distributions, first/last seen, status, and regression metadata.
- User reports, attachments, traces, spans, or profiles only when the specific event/project actually contains them.

The app sets Sentry's user to the numeric backend account ID after a nonzero account becomes current. Before account initialization or without an account, Sentry can use an SDK-generated installation identifier. Treat the semantics as event-dependent and keep every value out of reports.

## Evidence That Is Not Available By Default

- There is no complete production application log file or support-log archive to retrieve for ordinary RCA.
- `ABLog` writes to Apple unified logging through OSLog. OSLog entries are not uploaded wholesale to Sentry.
- Some `Log.*` wrappers add Sentry breadcrumbs, but coverage varies. General File Provider, app/scene lifecycle, photo uploader, background task/session, upload queue, and download queue wrappers use the default breadcrumb handler. Upload-operation and file-list wrappers mirror selected error paths. Other direct OSLog/`Logger` calls may remain device-local.
- Session replay is explicitly disabled (`sessionSampleRate = 0`, `onErrorSampleRate = 0`). Do not request or promise replay evidence.
- Debug and test events are dropped. Production events are dropped when the user's Sentry authorization preference is disabled.
- Sentry breadcrumbs can be scheduled asynchronously. Abrupt crashes, watchdog kills, extension termination, or process suspension can omit the final operation or slightly distort observed ordering.

Absence from Sentry is therefore not proof that an operation did not happen.

## Custom Event Caveats

The project intentionally captures messages that are not crashes. Known examples include:

- `UploadCompletedSuccess`: successful upload telemetry and potentially the largest issue group by event count.
- `appSizeUsage`: diagnostic telemetry.
- `UploadErrorHandling` and related upload messages: manually captured operation state that can represent handled/retried/local/external errors rather than a termination.
- Authentication, File Provider, view-model, PHAsset, Realm, and "no window" messages: inspect the capture site and outcome before classifying severity.

Issue title, Sentry level, and volume are insufficient to classify these groups. Inspect `mechanism`, `handled`, threads/stack, capture source, extras, and whether a separate terminal event exists.

## Apple Failure Modes

### Native Crash Or Trap

- Start with exception/signal/mechanism and the crashed thread.
- `SIGABRT`, `abort`, `swift_fatalError`, assertion/precondition helpers, forced cast/unwrap traps, and uncaught Objective-C exceptions are enforcement mechanisms. Trace caller state backward.
- `EXC_BAD_ACCESS` can indicate lifetime, data race, invalid pointer, framework misuse, or memory corruption. A top allocator/runtime frame does not distinguish them.
- Check all threads for Realm confinement, mutation during observation, actor/queue violations, and owner/deallocation races.

### App Hang And Watchdog

- For a hang, fetch the complete main-thread stack even if the issue summary selects another thread.
- Distinguish synchronous disk/network/Realm/Photos work, lock/semaphore waits, dispatch sync cycles, main-actor contention, and expensive UI/layout loops.
- A single sampled frame can be incidental. Compare events/stacks and find the stable blocking call or lock relationship.
- A fatal app hang/watchdog event describes the terminal OS behavior. The product defect is the blocking work, deadlock, or lifecycle contract violation that preceded it.
- Extension hangs have tighter lifecycle constraints; inspect completion handlers, file coordination, and cancellation/expiration paths.

### Memory Or Resource Termination

- Compare device class, physical/free/usable memory, app memory when present, foreground state, operation, payload scale, and recurrence.
- Look for image/video decoding, archive creation, full Realm materialization, large arrays/data buffers, File Provider enumeration, and concurrent transfers.
- Low free memory is supporting evidence, not proof. A missing crash stack or user-reported disappearance does not confirm OOM without termination evidence.
- Thermal state, low power mode, storage pressure, and extension limits can influence timing but are not root causes by themselves.

### Background And Extension Lifecycle

- Check background-task expiration, URL-session callbacks, cancellation, app suspension, process relaunch, and completion-handler ordering.
- Main app, File Provider, share, and action extensions are distinct processes even though they share app-group storage, Realm files, account state, and core code.
- A later main-app event can be recovery from an extension failure rather than the same process continuing.

## Correlation Hierarchy

Use the strongest available combination, in this order:

1. Exact Sentry event/trace relationship or an identifier explicitly shared by both records from the same operation domain.
2. Matching upload-file, File Provider item, background task/session, API request, or other operation identifier whose semantics are verified in source.
3. Matching backend request ID or an identical error/operation sequence with the same release and executable transition.
4. Matching backend account/drive/file identity only when source proves both values use the same domain.
5. Same marketing version/build, iOS/device family, build type, app/extension pairing, narrowly matching time, and a distinctive causal sequence.
6. Timestamp alone, which is only a search lead and never sufficient proof.

There is no universal cross-process app/extension session ID. `app_start_time` identifies a process lifetime and can help reject false matches. Sentry `trace_id` is useful only when instrumentation actually propagated the same trace; two unrelated trace values are not correlators.

When correlating:

1. Normalize Sentry timestamps to UTC and use a narrow initial window.
2. Confirm each event's bundle identifier, release/build, build type, and process start time.
3. Search breadcrumbs/extras for identifiers from the same source-defined domain.
4. Compare operation and error sequence, not merely terminal titles.
5. State which fields matched, which were non-comparable, and which were absent.
6. Redact every raw identity/operation value from the final report.

## Symbolication And Source Caveats

- CI attempts to upload the archive and dSYMs, but upload failure does not fail the release. Verify usable first-party symbols in the selected event.
- Generic system-only stacks, `<unknown>` frames, or missing line/function information materially reduce source confidence.
- One Sentry issue can group events from several releases or executable bundle identifiers. Compare variants before assuming one cause.
- Release source should come from the matching repository tag. Current `HEAD` is not a substitute for historical source.
- Sentry consent filtering, SDK grouping, hang sampling, and event volume mean issue counts are useful impact estimates, not complete ground truth.
