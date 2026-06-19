// swift-tools-version: 5.9
// Builds Hush as a plain SwiftPM executable so it can be assembled into a
// menu-bar .app with only Command Line Tools installed (no full Xcode needed).
// The Xcode project (Hush.xcodeproj) still works for development; this is the
// alternate, script-driven build path used for releases.

import PackageDescription

let package = Package(
    name: "Hush",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // @main lives in Hush/HushApp.swift; SwiftPM uses it as the entry point.
        .executableTarget(
            name: "Hush",
            path: "Hush",
            exclude: [
                "Info.plist",
                "Hush.entitlements",
                "Assets.xcassets",
            ]
        )
    ]
)
