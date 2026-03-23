// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "gestures",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "GesturesCore", targets: ["GesturesCore"]),
        .executable(name: "GesturesApp", targets: ["GesturesApp"]),
    ],
    targets: [
        .target(
            name: "GesturesCore",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
        .executableTarget(
            name: "GesturesApp",
            dependencies: ["GesturesCore"],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"]),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("SwiftUI"),
            ]
        ),
        .testTarget(
            name: "GesturesCoreTests",
            dependencies: ["GesturesCore"]
        ),
    ]
)
