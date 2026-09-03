// swift-tools-version: 6.4

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "swift-witnesses",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(
            name: "Witnesses",
            targets: ["Witnesses"]
        ),
        .library(
            name: "Witnesses Macros",
            targets: ["Witnesses Macros"]
        ),
        .library(
            name: "Witnesses Test Support",
            targets: ["Witnesses Test Support"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "603.0.2"..<"604.0.0"),
        .package(
            url: "https://github.com/swift-molecules/swift-witness.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-source.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-optic.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-finite.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-ownership.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-dependency.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-either.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-async.git",
            branch: "main"
        ),
    ],
    targets: [
        .target(
            name: "Witnesses",
            dependencies: [
                "Witnesses Macros",
                .product(name: "Witness", package: "swift-witness"),
                .product(name: "Source", package: "swift-source"),
                .product(name: "Ownership", package: "swift-ownership"),
                .product(name: "Dependency", package: "swift-dependency"),
                .product(name: "Either", package: "swift-either"),
                .product(name: "Async Lifecycle", package: "swift-async"),
            ]
        ),
        .target(
            name: "Witnesses Macros",
            dependencies: [
                "Witnesses Macros Implementation",
                .product(name: "Witness", package: "swift-witness"),
                .product(name: "Optic", package: "swift-optic"),
                .product(name: "Finite", package: "swift-finite"),
            ]
        ),
        .macro(
            name: "Witnesses Macros Implementation",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Witnesses Test Support",
            dependencies: [
                "Witnesses"
            ],
            path: "Tests/Support"
        ),
        .testTarget(
            name: "Witnesses Tests",
            dependencies: [
                "Witnesses",
                .product(name: "Either", package: "swift-either"),
                .product(name: "Async Lifecycle", package: "swift-async"),
            ],
            swiftSettings: [

                .unsafeFlags(["-Onone"], .when(configuration: .release))
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
