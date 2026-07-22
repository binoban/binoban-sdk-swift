// swift-tools-version:5.9
//
// Binoban Swift Package
//
// iOS SDK for integrating with Binoban, an enterprise CDXP infrastructure platform for
// customer data, activation, retail media, advertising, governance, and decisioning.
// Built for enterprise, on-premise, private, and white-label deployment models.
//
// Homepage:      https://binoban.io
// Documentation: https://docs.binoban.io
// License:       Apache-2.0 (see LICENSE)
//
// GENERATED FILE — do not edit by hand.
// Rendered from dist/swift/Package.swift.template by release.sh in the private SDK repo.

import PackageDescription

let version = "1.0.0"
let checksum = "9014d81fc13564084186a5c05adeeb90db6907d66fe8a5d28cb07623f16bc504"

let package = Package(
    name: "binoban",
    platforms: [.iOS(.v12)],
    products: [
        .library(name: "binoban", targets: ["binoban"])
    ],
    targets: [
        .binaryTarget(
            name: "binoban",
            url: "https://static.binoban.io/sdk/ios/\(version)/binoban.xcframework.zip",
            checksum: checksum
        )
    ]
)
