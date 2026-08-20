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
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "602.0.0"..<"603.0.0"),
        .package(
            url: "https://github.com/swift-primitives/swift-witness-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-source-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-optic-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-finite-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-ownership-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-dependency-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-either-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-async-primitives.git",
            branch: "main"
        ),
    ],
    targets: [
        .target(
            name: "Witnesses",
            dependencies: [
                "Witnesses Macros",
                .product(name: "Witness Primitives", package: "swift-witness-primitives"),
                .product(name: "Source Primitives", package: "swift-source-primitives"),
                .product(name: "Ownership Primitives", package: "swift-ownership-primitives"),
                .product(name: "Dependency Primitives", package: "swift-dependency-primitives"),
                .product(name: "Either Primitives", package: "swift-either-primitives"),
                .product(name: "Async Lifecycle Primitives", package: "swift-async-primitives"),
            ]
        ),
        .target(
            name: "Witnesses Macros",
            dependencies: [
                "Witnesses Macros Implementation",
                .product(name: "Witness Primitives", package: "swift-witness-primitives"),
                .product(name: "Optic Primitives", package: "swift-optic-primitives"),
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
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
                .product(name: "Either Primitives", package: "swift-either-primitives"),
                .product(name: "Async Lifecycle Primitives", package: "swift-async-primitives"),
            ],
            swiftSettings: [
                // Toolchain-defect opt-out, not a semantic setting: the Swift
                // 6.4-dev/nightly release optimizer introduces SIL ownership
                // leaks compiling this test module (@Witness-generated observe
                // closures and noncopyable fixtures), aborting swift-frontend —
                // first in CopyPropagation, then in pre-OwnershipModelEliminator
                // verification once the first site is suppressed. The class is
                // module-pervasive, so release CI builds this test module
                // unoptimized. The library products stay fully optimized; this
                // target ships in no product, so the unsafe flag never blocks
                // consumers. Tracked at
                // https://github.com/swift-institute/Issues/issues/90.
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
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
