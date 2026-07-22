# Binoban iOS SDK — Swift Package

Enterprise CDXP infrastructure for customer data, activation, retail media,
advertising, and decisioning.

This package distributes the Binoban iOS SDK as a prebuilt XCFramework.

## Requirements

| | |
|---|---|
| Platform | iOS 12.0+ |
| Xcode | 15.0+ (Swift tools 5.9) |
| Distribution | binary XCFramework |

## Installation

In Xcode: **File → Add Package Dependencies…**, then enter:

```
https://github.com/binoban/binoban-sdk-swift
```

Or in a `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/binoban/binoban-sdk-swift", from: "1.0.0")
]
```

CocoaPods is also supported:

```ruby
pod 'binoban', '~> 1.0'
```

## Getting started

```swift
import binoban

let config = Configuration(writeKey: "YOUR_SOURCE_ID", apiKey: "YOUR_API_KEY")
config.apiHost = "your-api-host"
let binoban = Binoban.create(configuration: config)

binoban.track(name: "order_completed", properties: ["total": 42.0])
```

`apiHost` is required. Without it the SDK initializes disabled and reports the
reason to `Configuration.errorHandler` rather than sending events anywhere.

## Push notifications

The SDK never registers its own `UNUserNotificationCenterDelegate` and never
touches Firebase/APNs setup — that stays your app's responsibility. Once your own
delegates are in place, forward the relevant callbacks to the SDK's top-level
functions.

**Configure once at launch** with an iOS notification configuration — this is
required for the SDK to present pushes and (optionally) request permission on start:

```swift
initializeNotifications(configuration: NotificationPlatformConfiguration.Ios(
    askNotificationPermissionOnStart: true,
    notificationSoundName: nil
))
```

**1. Incoming data pushes** — from
`application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`. This is what
**presents** a Binoban data push (and reports `delivered`); it ignores non-Binoban
payloads:

```swift
func application(_ application: UIApplication,
                 didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                 fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    onApplicationDidReceiveRemoteNotification(userInfo: userInfo)
    completionHandler(.newData)
}
```

**2. Foreground delivery** — from your `UNUserNotificationCenterDelegate`'s
`willPresent`, reports the `delivered` event:

```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                             willPresent notification: UNNotification,
                             withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    onWillPresentForwarded(userInfo: notification.request.content.userInfo)
    completionHandler([.banner, .sound])
}
```

**3. User interaction** — from `didReceive response`, reports `clicked` or
`closed`:

```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                             didReceive response: UNNotificationResponse,
                             withCompletionHandler completionHandler: @escaping () -> Void) {
    let actionId = response.actionIdentifier == UNNotificationDefaultActionIdentifier
        ? nil : response.actionIdentifier
    let dismissed = response.actionIdentifier == UNNotificationDismissActionIdentifier
    onDidReceiveForwarded(
        userInfo: response.notification.request.content.userInfo,
        actionId: actionId,
        dismissed: dismissed
    )
    completionHandler()
}
```

`actionId` is `nil` for a plain body tap (the default action) or the tapped action
button's identifier otherwise; `dismissed` is `true` only when the user swiped the
notification away.

**Opening a deep link / reading custom data.** The SDK reports the tap but does **not**
open the deep link on iOS — iOS already hands the tap to your app, and routing belongs
to your navigation. Register a handler (subclass `DefaultNotificationInteractionHandler`
and call `super` so the SDK's delivered/click/close tracking still fires), then read
`interaction.uri` and `interaction.customData` and route them yourself:

```swift
class MyNotificationHandler: DefaultNotificationInteractionHandler {
    override func onNotificationInteraction(interaction: NotificationInteraction) {
        super.onNotificationInteraction(interaction: interaction) // keep SDK analytics
        if let uri = interaction.uri, let url = URL(string: uri) {
            // route in-app, or hand to the system:
            UIApplication.shared.open(url)
        }
        let data = interaction.customData // your push customData, or nil
        _ = data
    }
}

// once, at startup:
NotificationInteractionManager.shared.setHandler(handler: MyNotificationHandler())
```

`interaction.uri` resolves to the tapped action button's target when a button was
pressed, or the main notification target for a body tap.

**4. Token registration** — from Firebase's `MessagingDelegate`:

```swift
func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    guard let token = fcmToken else { return }
    onNewToken(token: token)
}
```

## Advertising identifier (ATT)

The SDK reads the IDFA **only when the user has already authorized tracking**.
It never presents the ATT prompt. To request authorization, add
`NSUserTrackingUsageDescription` to your Info.plist and call `ATTrackingManager`
yourself.

## Privacy manifest

The XCFramework ships with a bundled `PrivacyInfo.xcprivacy` in every slice, so
Apple's privacy-report aggregation picks it up automatically at build time. It
declares the SDK's own data collection — Device ID (IDFA/IDFV), User ID, and
product-interaction events — and its use of the UserDefaults and file-timestamp
Required-Reason APIs. You do not copy this file anywhere.

Two things stay **your** responsibility, because the SDK cannot know them:

- **Tracking domains.** The manifest lists no `NSPrivacyTrackingDomains` — the
  Binoban endpoint is your per-deployment `apiHost`, unknown to the SDK. If your
  privacy review requires declaring it as a tracking domain, add it to your
  **app's** privacy manifest. Note that a domain listed there is blocked by the
  system when the user denies ATT, which also stops non-tracking analytics
  upload — so weigh this per deployment.
- **Custom traits.** Any personal data you pass to `identify(...)` (name, email,
  phone, …) is declared by **you**: add the matching `NSPrivacyCollectedDataType`
  entries to your app's manifest for whatever traits you send.

## Links

- Documentation — https://docs.binoban.io
- Example app — https://github.com/binoban/binoban-example-ios
- Changelog — [CHANGELOG.md](CHANGELOG.md)

## License

Apache-2.0. See [LICENSE](LICENSE).
