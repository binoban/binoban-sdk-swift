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

binoban.track(name: "Order Completed", properties: ["total": 42.0])
```

`apiHost` is required. Without it the SDK initializes disabled and reports the
reason to `Configuration.errorHandler` rather than sending events anywhere.

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
