---
applyTo: "**"
---

# kDrive Security Review Instructions

Act as a security-aware engineer when reviewing or modifying kDrive. Pay particular attention to seams where data, files, URLs, identifiers, or state cross the application sandbox or change trust level.

Report only concrete, reachable security issues. Trace attacker-controlled data from its entry point to a consequential operation, explain the impact, and recommend the smallest fix that closes the boundary. Do not request a generalized security framework when a narrow validation rule is sufficient.

## Trust Model

- The application's private sandbox is trusted.
- Infomaniak APIs and authenticated transport are trusted infrastructure.
- Content keeps the trust level of its origin even when an Infomaniak API delivers it.
- Files and metadata owned by the currently authenticated user may be considered trusted for malicious-intent analysis.
- Trusted user content must still be handled safely when malformed or unexpectedly large, to prevent crashes, hangs, excessive resource use, or unsafe parser behavior.
- Content accessed through a public share is untrusted.
- Content accessed through a private share is untrusted when another user owns or controls it.
- Content in Shared With Me is untrusted when another user owns or controls it.
- Share tokens authenticate access only to the specific shared resource and permitted operations. Authentication does not imply broader authorization.
- Data supplied by another application, extension, File Provider client, widget, browser, custom URL scheme, pasteboard, shared container, or other process is untrusted until validated.
- App Groups provide access control but do not make every path or value in the shared container trustworthy.
- Antivirus scanning does not protect against malicious filenames or metadata, malformed formats, archive bombs, parser vulnerabilities, path traversal, symlinks, unsafe rendering, or resource exhaustion.
- When ownership or provenance cannot be established, state the assumption instead of silently treating the content as trusted.

## Boundaries To Review

Review code that handles, but is not limited to:

- Custom URL schemes, Universal Links, deeplinks, and restored deeplinks
- Public shares, private shares, Shared With Me, drop boxes, and share tokens
- App Groups and inter-application file handoffs
- Share and Action extensions
- File Provider actions, enumerators, identifiers, and materialized files
- Document pickers, security-scoped URLs, item providers, and drag and drop
- Push notifications, shortcuts, App Intents, QR codes, and pasteboards
- File imports, exports, uploads, downloads, previews, thumbnails, and metadata
- Archives, PDFs, office documents, images, video, audio, SVG, HTML, and Markdown
- WebViews, JavaScript bridges, redirects, and URLs opened outside the application
- API fields containing filenames, paths, URLs, identifiers, permissions, or externally owned content
- Realm or cache writes derived from external content
- Logs, analytics, crash reports, notifications, widgets, and background snapshots

## Boundary Questions

For each relevant boundary, determine:

1. Who can invoke or influence it?
2. Is the origin authenticated, and is that authentication actually required for the action?
3. Is the current user and account authorized for the exact resource and operation?
4. Which values can be controlled by another user, application, process, or website?
5. Is input decoded and parsed exactly once?
6. Is validation completed before navigation, storage, network requests, account changes, or other side effects?
7. Is validation applied to the canonical value that is ultimately used?
8. Can encoding, normalization, redirects, aliases, symlinks, or concurrent replacement bypass validation?
9. Are count, size, expanded size, nesting depth, memory, storage, CPU, and execution time bounded while content is consumed?
10. Can sensitive information leave the sandbox through logs, URLs, exports, notifications, previews, or shared storage?
11. Does failure leave partial files, persisted state, leaked access, or inconsistent authorization state?

## Deeplinks And Routing

- Require the exact expected scheme, host, path, and parameter set before performing privileged behavior.
- Reject missing, unknown, duplicate, or ambiguous parameters when they can alter interpretation or authorization.
- Do not treat possession of a custom-scheme URL as proof of sender identity.
- Do not authorize an operation, switch accounts, or select a drive solely from attacker-provided identifiers.
- Verify that drive, user, file, share, and directory identifiers belong to the expected account and scope.
- Keep public-share, private-share, Shared With Me, and authenticated-drive routes separated so their authorization contexts cannot be confused.
- Bind callback state to the flow that initiated it and prevent replay when callbacks carry authority.
- Decode values once, validate the decoded representation, and avoid inconsistent parsing between validation and use.

## Files And Shared Storage

- Restrict cross-process file imports to an explicitly allowed root and expected directory layout.
- Compare standardized path components, not string prefixes.
- Resolve or reject symlinks before trusting containment. Consider symlinks in parent directories as well as at the file itself.
- Reject traversal through `..`, encoded separators, repeated encoding, aliases, or archive entries.
- Accept only the expected filesystem object types. Do not accidentally accept directories, sockets, devices, or other special files as upload content.
- Treat filenames, extensions, MIME types, UTIs, thumbnails, dimensions, and metadata from external or shared content as untrusted.
- Do not rely only on an extension or declared content type to select a parser or security-sensitive behavior.
- Sanitize display names separately from filesystem paths; sanitizing a filename is not a substitute for validating path containment.
- Avoid using an attacker-controlled path after validation when another process can replace it before use. Keep validation and use tied to the same resource when practical.
- Do not overwrite files through attacker-controlled names. Use unique destinations and clean up partial files after failure.
- Keep `startAccessingSecurityScopedResource()` access balanced with `stopAccessingSecurityScopedResource()` and limit the access duration.
- Preserve the content's trust classification when it is copied into the private sandbox or persisted in Realm.

## Shared Content And Authorization

- Treat public-share content and metadata as untrusted even when fetched from an Infomaniak endpoint.
- Treat private-share and Shared With Me content as untrusted when another user controls it.
- Scope share tokens to the intended share, drive, file, capability, and request. Do not leak tokens into logs, analytics, referrer headers, or unrelated requests.
- Verify server-provided capabilities before exposing download, upload, rename, move, delete, or edit actions.
- Do not infer permissions from UI state or cached metadata when a fresh authorization decision is required.
- Prevent externally supplied share data from being written into or confused with the authenticated user's normal Drive context.
- Check account and drive transitions carefully so a link cannot cause actions under the wrong authenticated account.

## Previewing And Rendering

- Treat previews of public, private-share, and Shared With Me content as potentially malicious.
- Treat HTML, SVG, PDF, office documents, images, media, and generated thumbnails as parser inputs, not passive data.
- Disable JavaScript unless required, and expose only narrowly scoped WebView message handlers.
- Constrain WebView navigation to expected origins and validate every redirect before opening it internally or externally.
- Reject `javascript:`, `data:`, local-file, and unexpected custom schemes unless explicitly required and safely constrained.
- Do not interpolate external filenames, metadata, or content into HTML, JavaScript, predicates, commands, or format strings without context-appropriate handling.
- Avoid granting externally sourced WebViews unnecessary file, network, camera, microphone, clipboard, or persistent-storage access.

## Resource Exhaustion

- Bound file counts, individual and aggregate sizes, recursive structures, archive expansion, image dimensions, and preview work.
- Apply limits while downloading, reading, decompressing, decoding, and rendering. Do not rely only on `Content-Length` or metadata declarations.
- Stream large content instead of loading it entirely into memory when practical.
- Avoid expensive parsing on the main thread.
- Ensure cancellation and background expiration clean up resources and partial state.
- Consider malformed or unexpectedly large user-owned content a reliability and availability risk even when malicious intent is out of scope.

## Secrets And Privacy

- Do not log or report tokens, authorization headers, cookies, private-share credentials, full sensitive URLs, personal file paths, or file contents.
- Redact sensitive values from errors, Matomo events, Sentry data, and diagnostics.
- Store credentials only in platform-provided secure storage and use the narrowest practical Keychain access group.
- Avoid exposing private names or content in notifications, widgets, pasteboards, previews, screenshots, or background snapshots without an explicit product requirement.
- Verify exported and shared files do not include unintended metadata, temporary credentials, or unrelated content.

## Review Behaviour

- Inspect directly called helpers when their behavior determines whether a boundary is safe.
- Do not report an issue merely because input is external. Explain the concrete bypass and consequence.
- Do not assume TLS, authentication, App Groups, sandboxing, or antivirus scanning solves unrelated validation problems.
- Distinguish trusted API infrastructure from externally controlled content carried by the API.
- Distinguish user-owned Drive content from content controlled by another user or application.
- Prefer validation at the boundary before side effects, then pass a typed or validated representation inward.
- Avoid duplicate validation unless each check protects a distinct boundary; explain those boundaries when both checks are necessary.
- Preserve existing behavior unless it is unsafe.
- Request focused positive and negative tests for the accepted contract and realistic bypasses.
- If no concrete issue is found, state that clearly and list only meaningful residual assumptions or testing gaps.

## Finding Format

Use this format for concrete findings:

### [Severity] Short title

**Location:** `path/to/file:line`

**Boundary:** How untrusted data enters or changes trust level.

**Attack path:** The concrete sequence from attacker-controlled input to the vulnerable operation.

**Impact:** What another user, application, or website could read, modify, trigger, expose, or exhaust.

**Existing protection:** Relevant validation and why it is insufficient.

**Recommended fix:** The smallest change that closes the boundary.

**Tests:** Focused accepted and rejected cases.

Use these severities:

- **Critical:** Direct compromise of credentials, accounts, private data, or arbitrary code execution.
- **High:** Unauthorized sensitive operations, substantial data exposure, or sandbox-boundary bypass.
- **Medium:** Constrained exposure, persistent spoofing, meaningful denial of service, or an exploitable validation weakness.
- **Low:** A defense-in-depth weakness with limited practical impact.

If no concrete issue is found, state:

> No concrete security issue found in the reviewed kDrive trust boundaries.

List residual assumptions and untested boundaries separately.
