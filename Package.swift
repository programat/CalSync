// swift-tools-version: 6.2

import PackageDescription

let approachableConcurrency: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InferSendableFromCaptures"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "CalSync",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "CalSync", targets: ["CalSync"]),
    ],
    targets: [
        .executableTarget(
            name: "CalSync",
            path: "CalSync",
            exclude: [
                "Assets.xcassets",
                "CalSync.entitlements",
                "CalSync.xcdatamodeld",
            ],
            swiftSettings: approachableConcurrency
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["CalSync"],
            path: "AppTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
