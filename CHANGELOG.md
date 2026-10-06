# Changelog

All notable changes to the Binoban Kotlin Multiplatform SDK are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
the project aims for **source compatibility** — see *Migration notes*.

## [1.3.0] — 2026-10-06

### Added

- **`screen()` is public, and screen views reach Binoban.** A screen view is delivered as a
  track event named `screen`, the same shape the Web SDK sends, so app and browser screen
  views land together. The screen's title is copied into `properties.name`, so screen views
  stay distinguishable from one another. Other destinations still receive a real screen
  event.

### Fixed

- **An event tracked immediately after construction is no longer dropped.** A `track()`
  issued right after `Binoban(...)`, for example from `onCreate()`, could arrive before the
  SDK finished initializing. The SDK then reported an internal error through `errorHandler`
  and lost the event. It is now sent with the same identity it would have had a moment
  later.
- **Remotely configured `apiHost` and `apiKey` are now applied.** They were ignored before,
  so a device stayed on the values compiled into the app. This affected both Android and
  iOS.
- **Remote settings in the server's current response format are read correctly.** Before
  this fix, the SDK kept its defaults and kept sending, but changes made to a source's
  settings never reached the device. Both the current and the previous response formats
  are accepted.
- **The remote kill switch is honored on its own.** A response of `{"enabled": false}`
  stops the SDK whether or not it also carries settings for the SDK. A malformed settings
  body no longer prevents the flag from being read. A string value such as `"false"` is
  no longer mistaken for the boolean.
- **A source that was disabled remotely is picked up as soon as it is re-enabled.** While
  a source is disabled, the SDK fetches its settings in full rather than relying on a cached
  answer. A re-enabled source therefore resumes on the next launch.
- **A remote `enabled: true` no longer overrides `binoban.enabled = false`.** If your app
  disables the SDK itself, only your app can enable it again.
- **`disableCloudIntegrations()` now disables device-mode destinations.** Delivery to
  Binoban itself continues, as it should.
- **Successful diagnostic uploads are no longer reported to `errorHandler` as errors.**
  Before this fix, a success status other than `200` was treated as a failure.
- **The SDK's `User-Agent` header is now sent.** Requests used to go out with the HTTP
  client's default value.
- **Trace codes are case-insensitive.** A code entered in capitals now joins the same
  session as the lowercase code shown in the panel.
- **`DestinationPlugin.process()` copies the event before your destination's hooks run.**
  So a destination that changes an event no longer changes the caller's copy.

### Removed

- **`Settings` no longer has `plan`, `edgeFunction`, `middlewareSettings` or
  `consentSettings`.** The SDK never read any of these four. `Settings` now has three
  fields, matching the Web SDK: `enabled`, `integrations` and `metrics`. Settings stored by
  an earlier version still load correctly after the upgrade.

  This change breaks source compatibility for code that named one of these properties. Our
  compatibility policy keeps removals for major releases, so this is a deliberate, one-time
  exception. We made it because the properties never had any effect. The policy itself is
  unchanged.

### Migration notes

- If you passed `plan`, `edgeFunction`, `middlewareSettings` or `consentSettings` to
  `Settings`, for example through `Configuration`'s `defaultSettings`, remove the argument.
  No replacement is needed. No other code changes are required.
- 1.3.0 is the first published release with the 1.2.0 changes below.

## [1.2.0] — 2026-08-17

Not published. Everything in this entry first ships in 1.3.0.

### Added

- **Trace sessions — follow one device through the pipeline.** A device can be enrolled in a
  short-lived, opt-in, expiring window during which every event carries
  `context.traceSessionId`, so a support engineer can follow one visitor from the call your
  code makes to what Binoban did with it.

  ```kotlin
  binoban.joinTrace("the-code-from-the-panel")   // or scan the panel's QR
  binoban.activeTraceSessionId                   // null when no session is active
  binoban.traceDeliveryLog()                     // upload outcomes, for a support bundle
  binoban.leaveTrace()
  ```

  Two entry paths ship together. The **manual code** needs no App Links, Universal Links or
  URL scheme and therefore works in every app on day one. The **QR / deep link** carries a
  `bnb_trace` query parameter: on Android the SDK picks it up automatically (see *Changed*),
  on iOS the host forwards the URL via `BinobanTrace.shared.handleUrl(url:)`, the same shape
  the notification forwarding already uses.

  The session ends on `leaveTrace()`, after 12 hours, or after 250 events — whichever comes
  first, all enforced by the SDK itself. The SDK never asks the server whether a trace is
  still valid; self-limiting is what keeps an abandoned trace from becoming a permanent
  tracking identifier. Tunables: `Configuration.traceMaxDurationMillis`, `traceMaxEvents`,
  `traceDeliveryLogSize`.

  Trace inherits the SDK's existing consent and enablement gating rather than adding a
  second one: a disabled instance sends nothing, so it traces nothing. The session survives
  process death — it is read back during `build()`, before the first event is dispatched, so
  a QR scan that launches the app from cold has its id on the *first* event.

- **Client-side capture of delivery outcomes, including rejections.** While a trace session
  is active, `traceDeliveryLog()` returns a bounded, in-memory list of upload outcomes —
  timestamp, event names, HTTP status, and the `code` / `field` / `reason` the tracker
  returns on a rejection. This exists because a rejection is stored nowhere on the server:
  it lives only as the HTTP response the app receives and normally discards. Error metadata
  only — payloads are never recorded.

- **`BinobanTrace` — a Swift-facing entry point for trace**, mirroring `BinobanNotifications`:
  `join(traceSessionId:)`, `leave()`, `handleUrl(url:)`, `activeSessionId()`, `deliveryLog()`.

### Changed

- **`AndroidDeepLinkPlugin` is now registered automatically by `Binoban.build()`, and
  `Configuration.trackDeepLinks` now defaults to `false`.** Read both halves together.

  The plugin has been public, functional, tested and *never registered* since before `1.0.0`.
  `Configuration.trackDeepLinks` was documented as defaulting to `false` and declared `= true`
  — harmless only because nothing read it. Registering the plugin makes that flag
  load-bearing for the first time, and leaving it `true` would have started emitting
  `deep_link_opened` events for every upgrading customer who sets `Configuration.application`.

  So the default is corrected to `false`, which matches its own documentation and the
  behaviour every existing customer experiences today. **If you set `trackDeepLinks = true`
  explicitly, nothing changes for you. If you relied on the undocumented `true` default,
  deep-link tracking is now off until you set it.** If you already call
  `binoban.add(AndroidDeepLinkPlugin())`, remove it — the extra instance detects the
  automatic one and stays inert, so you will not get duplicate events either way.

  **Trace joining is gated separately from `trackDeepLinks`.** A customer who has not opted
  into deep-link *tracking* can still join a trace by scanning a QR, because those are
  different decisions: one is analytics, the other is diagnostics.

- **`AndroidDeepLinkPlugin` no longer fails setup when `Configuration.application` is
  absent.** It registers inert and logs at debug instead of reporting through
  `errorHandler`. Now that the plugin is registered for everyone, a missing `application` is
  the ordinary case rather than a misconfiguration — `application` is optional for every
  other part of the SDK. Deep-link tracking and QR trace entry are unavailable without it;
  `joinTrace(code)` still works.

### Fixed

- **Re-joining the trace session that is already active is now a no-op.** It used to
  reset the session's event count, push its 12-hour deadline out afresh, and clear the
  recorded delivery outcomes. Automatic entry paths deliver the same link more than
  once, so this was reachable in normal use: rotating an Android device after a
  QR-launched trace re-processed the launch intent and wiped the trace's state. Joining
  a *different* id still replaces the session, and re-joining an *expired* id still
  starts a fresh one.

- **A recreated Activity no longer reprocesses its launch deep link.** Android delivers
  the original launch intent again when it recreates an Activity for a configuration
  change (rotation, locale, dark mode), so a single deep link emitted a duplicate
  `deep_link_opened` event each time. The intent is now marked once it has been handled.

- **`AndroidDeepLinkPlugin` now unregisters its activity-lifecycle callbacks in
  `teardown()`.** Removing the plugin previously left it attached to the `Application`.

### Migration notes

- Source-compatible. The three new `Configuration` properties are appended, and
  `Storage.Constants.TraceSession` is appended to the enum.
- `Configuration.trackDeepLinks` changes **default**, not signature. Set it explicitly if you
  want deep-link tracking.
- Remove any `binoban.add(AndroidDeepLinkPlugin())` call; registration is automatic.
- iOS hosts that want QR trace entry must forward URLs:
  `BinobanTrace.shared.handleUrl(url: url)` from `application(_:open:options:)`. Omitting it
  is silent — the trace simply never starts.

## [1.1.0] — 2026-08-02

### Added

- **`BinobanNotifications` — a Swift-facing entry point for notification forwarding.**
  The forwarding entry points are Kotlin top-level functions, which Kotlin/Native exports
  as static members of a generated class name (`NotificationForwarding_iosKt`). Swift
  callers can now use `BinobanNotifications.shared.onNewToken(token:)` and friends instead.

  **Purely additive.** `NotificationForwarding_iosKt` still exports and still works, so no
  existing iOS integration breaks. Kotlin Multiplatform callers should keep calling the
  top-level functions unqualified — that spelling is idiomatic in Kotlin and is unchanged.
  Every member delegates with no added behavior.

- **Android deep-link tracking is now documented.** `AndroidDeepLinkPlugin` has shipped as
  public API since 1.0.0 but was never registered by default and was never mentioned in the
  docs, so there was no way to discover it. The Kotlin README now has a *Deep-link tracking
  (Android)* section. It stays opt-in — `binoban.add(...)` — and is the only part of the SDK
  that reads `Configuration.application`.

### Changed

- **`AndroidDeeplinkPlugin` renamed to `AndroidDeepLinkPlugin`** and reduced to what it
  actually does. The old name remains as a deprecated `typealias`, so existing source keeps
  compiling. Unused internal fields and a lifecycle-observer registration that overrode no
  callbacks were removed. Deep-link tracking behavior is unchanged.

### Fixed

- **A deep link can no longer spoof its own attribution.** `deep_link_opened` wrote the
  Android-reported `referrer` before the link's query parameters, so a link ending in
  `?referrer=...` overwrote the referrer the OS actually reported — letting the link forge
  the attribution data it was itself being attributed by. Query parameters are now written
  first and the OS-reported `referrer`/`url` last, so real values win. **This changes
  emitted payloads** for links carrying a `referrer` parameter. When Android reports no
  referrer, a `referrer` parameter is still used, which is the normal campaign-tagging case.

- **iOS notification examples in the docs corrected.** They showed unqualified calls and
  `NotificationPlatformConfiguration.Ios`, neither of which resolves in Swift (the type is
  exported flat, as `NotificationPlatformConfigurationIos`).

## [1.0.1] — 2026-07-25

### Added

- **`NotificationInteractionManager.drainPendingInteractions()` + an internal replay
  buffer.** The manager now records recent interactions in a small bounded, lock-free
  buffer and forwards them through a single `dispatch()` entry point. A consumer that
  installs its handler *after* an interaction already fired can recover it via
  `drainPendingInteractions()` (consumed once, delivery-only — tracking already happened).
  Fixes an **Android cold-start gap**: a tap that launches the app from a killed state is
  delivered by the notification trampoline during process startup, before a late-attaching
  UI/JS layer (e.g. the React Native bridge) has called `setHandler`, so it previously
  never reached that layer. Tracking was always unaffected; this only restores the
  app-facing delivery of the launching tap. No behavior change for existing consumers.

### Fixed

- **Notification `customData` now reaches the tap handler.** `customData` sent in a push
  is surfaced on `NotificationInteraction.customData` for click/dismiss (and delivered)
  interactions on both platforms. It was previously always `null` on the response path:
  Android dropped the intent extras in the trampoline; iOS never read them back out of
  `userInfo`. customData is now transported under an internal `binoban_cd_` namespace so
  it can never collide with SDK-reserved keys or leak FCM/APNs internals.
- **iOS per-action-button deep links now resolve.** A `UNNotificationAction` carries only
  an id + title, so each button's target URI is now stashed in `userInfo` (keyed by action
  id) and resolved by `actionId` on tap. Previously a button tap on iOS always reported the
  main notification URI regardless of which button was pressed; a body tap is unchanged.
  As before, the SDK does not itself open URLs on iOS — read `interaction.uri` in a handler
  and route it (see the README).

## [1.0.0] — 2026-07-20

**The first stable release.** A focused effort to make the SDK unable to harm a host
app (crash, ANR, deadlock, unbounded growth), then resilient and efficient, then at
iOS/Android parity.

`1.0.0` begins the semantic-versioning commitment, so this release also **removes every
previously deprecated API** — the last opportunity to do so without a major bump. Most
integrators need no code change: the `Binoban(apiKey, sourceIdentifier) { … }` factory
and all event APIs (`track`/`identify`/`flush`/`reset`) are
unchanged. See *Migration notes* if you call any removed member.

### Added

- **`Binoban.create(configuration)`** — a factory that **never throws**. On invalid
  config or a hostile environment it returns a disabled-but-safe instance (calls are
  no-ops) and reports the cause via `Configuration.errorHandler`, with an in-memory
  storage fallback. Prefer it over the constructor.
- **`Configuration` tunables** (all with safe defaults): `uploadMaxRetries` (3),
  `backoffBaseMillis` (1000), `backoffFactor` (2.0), `backoffMaxMillis` (60000),
  `maxFilesPerFlush` (20).
- **`Plugin.teardown()`** — optional lifecycle hook (default no-op) called on
  `Timeline.remove`, so plugins can release store/lifecycle subscriptions.
- **iOS parity:** events now include `context.device.advertisingId` /
  `adTrackingEnabled` (IDFA, **only when ATT-authorized**) and
  `context.network.{wifi,cellular,bluetooth}` (bluetooth always `false` on iOS).
- **iOS privacy manifest:** a `PrivacyInfo.xcprivacy` is baked into every slice
  of the XCFramework, declaring collected data (Device ID, User ID, product
  interaction) and Required-Reason API use (UserDefaults `CA92.1`, file
  timestamp `C617.1`). `NSPrivacyTracking` is `true` (the SDK reads the IDFA);
  tracking domains and custom `identify` traits stay the integrating app's to
  declare, since the SDK cannot know its per-deployment host or which traits a
  customer sends.
- Safety/efficiency machinery: a `safely { }` boundary that routes any throwable to
  `errorHandler`, capped full-jitter upload backoff, a single reused Ktor `HttpClient`,
  and rate-limited internal error reporting.
- **Swift Package Manager** is now a supported iOS distribution channel alongside
  CocoaPods — both ship the same prebuilt XCFramework.

### Changed

- **`apiHost` is now required.** It previously defaulted to a hardcoded private-range IP;
  that default is removed and `apiHost`/`cdnHost` now default to
  empty. A blank `apiHost` makes the configuration invalid, so `Binoban.create(...)`
  returns a disabled (no-op) instance and reports via `errorHandler` instead of sending
  events to a stray host. Recompiling needs no code change; a functioning instance now
  requires an explicit `apiHost`. See *Migration notes*.
- **Resilient upload:** transient failures (HTTP 429/5xx, network errors) are now
  **retried with capped exponential backoff and kept** for a later flush; a batch is
  **dropped only on a 4xx (≠429)**. Previously some transient/network failures
  deleted the batch.
- **Bounded by default:** write/upload channels (1000, drop-oldest), on-disk storage
  (5 MB / 20 batch files, drop-oldest), and files-per-flush are all capped.
- **Durable storage:** events now persist in an **app-private directory** (Android
  `filesDir`, iOS Application Support) instead of the OS temp dir, with a temp-dir
  fallback. See *Migration notes*.
- `settings()` now returns a **non-blocking cached snapshot** instead of blocking on a
  network fetch (avoids ANR). Use `settingsAsync()` for a fresh fetch.
- Public event APIs (`track`/`identify`/…/`flush`/`reset`) are now fully guarded and
  serialize off the caller thread — they never throw to or block the caller.
- iOS `IOSIdfaPlugin` is now an `Enrichment` plugin (was `Before`).
- iOS framework linkage: `binoban.podspec` and the framework build now declare
  `SystemConfiguration` + `AdSupport`, and **weak-link** `AppTrackingTransparency`
  (iOS 14+; weak so the iOS 12 floor still loads).

### Fixed

- The SDK no longer crashes, hangs/ANRs, deadlocks, or grows unbounded inside a host:
  guarded native checksum load (Android `UnsatisfiedLinkError`) and null-safe free
  (iOS); null-safe iOS Info.plist reads (no force-cast crashes); `withLock`
  releases its semaphore on throw (no persistence deadlock); a failed plugin
  `setup()` is no longer registered; a throwing state reducer retains the previous
  state; `Error`s are contained at the upload boundary.
- Android: cancel the device-id lookup coroutine when its 2 s timeout fires; do not
  show or false-report a notification when permission is denied.
- Packaging: ship consumer ProGuard/R8 rules, declare explicit ABI filters, declare
  the `INTERNET` permission, and correct malformed POM SCM URLs.
- `Binoban.version()` (and the destination plugin's `version()`) now return the real
  build version instead of a stale hardcoded that never matched the
  published artifact.
- Duplicate `<license>` and `<developer>` entries in the published POM are gone — each
  now appears exactly once.
- **License is now consistently Apache-2.0** across the `LICENSE` file, the POM, and
  `binoban.podspec` (the POM and podspec previously declared MIT).

### Removed

All previously deprecated APIs are gone as of `1.0.0`. Each had a drop-in replacement
that has shipped since `0.1.x`.

- **`Binoban(configuration: Configuration)`** constructor → **`Binoban.create(configuration)`**.
  This was the only public constructor, so `Binoban(config)` no longer compiles. The
  replacement never throws: invalid config yields a disabled-but-safe instance reported via
  `Configuration.errorHandler`. The `Binoban(apiKey, sourceIdentifier) { … }` convenience
  factory now delegates to `create()` and so **no longer throws on invalid config** — a
  behavior change for that factory, and the intended end-state of the host-safety work.
- **`settings()`** → **`settingsAsync()`**. The removed accessor read the persisted snapshot
  from disk (`@BlockingApi`); `settingsAsync()` reads in-memory system state and does no I/O.
- **`userIdAsync()`** → `userId()`, **`traitsAsync()`** → `traits()`,
  **`anonymousIdAsync()`** → `anonymousId()`. All three were pass-throughs to the
  synchronous member and never did async work.
- **`StorageProvider.getStorage(...)`** → `createStorage(vararg params)`. Only affects a
  custom `StorageProvider` that *overrode* the removed method; implementations that override
  `createStorage` (including `ConcreteStorageProvider` and `InMemoryStorageProvider`) are
  unaffected.
- **`KVS.getInt(key, default)` / `KVS.putInt(key, value)`** → the overloaded `get` / `put`.

---

## Migration notes

**For app integrators (Android & iOS):** if you construct the SDK with the
`Binoban(apiKey, sourceIdentifier) { … }` factory and use the event APIs, recompiling
requires **no code changes**. If you call any API listed under *Removed*, switch to its
replacement — all replacements have shipped since `0.1.x`, so you can migrate before
upgrading.

- **`Binoban(config)` → `Binoban.create(config)`.** The direct constructor is gone. Beyond
  the rename, `create()` **never throws**: where the constructor raised on invalid config,
  `create()` returns a disabled instance whose calls are no-ops and reports the cause to
  `Configuration.errorHandler`. If you relied on a `try/catch` around construction to detect
  bad config, move that check to `errorHandler`. The same applies to the
  `Binoban(apiKey, sourceIdentifier) { … }` factory, which now delegates to `create()`.
- **iOS — advertising ID & ATT.** The SDK now reads the IDFA, but **only when the user
  has already authorized tracking** (it never presents the prompt). If you want the
  ATT prompt, add `NSUserTrackingUsageDescription` to your app's Info.plist and call
  `ATTrackingManager` yourself. iOS events now also carry network transport booleans.
  CocoaPods consumers get the new system frameworks automatically via the podspec.
- **`apiHost` is now required.** If you construct `Configuration`/`Binoban` without
  setting `apiHost`, the SDK initializes **disabled** (calls are no-ops) and reports via
  `errorHandler`, rather than defaulting to a built-in host. Pass your real API host.
  (Previously it silently defaulted to a private-range IP — a misconfigured integrator's
  events went to a dev machine instead of failing loudly.)
- **Remote-settings integration key `"Binoban.io"`.** If your deployment relies on the
  remote Settings API to push an `apiHost` override, make sure the backend returns the
  integration under the key `"Binoban.io"`. Setting `apiHost` in `Configuration` directly
  is unaffected.
- **Storage location change (one-time).** Events move from the OS temp directory to an
  app-private directory. Any events still queued in the **old** temp location at the
  moment of upgrade are not re-read (a small, one-time in-flight loss). No crash, no
  API change.
- **Source vs binary compatibility.** The new `Configuration` fields are
  **source-compatible** (recompile against this version — the normal Maven/CocoaPods
  path). Code running old precompiled bytecode without recompiling could see
  `data class` constructor/`copy()` differences; recompiling resolves it.
