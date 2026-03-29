// swift-tools-version: 6.2
import Foundation
import PackageDescription

private struct PackagingMetadata: Decodable {
    var packageName: String
    var libraryProductName: String
    var executableProductName: String
    var coreTargetName: String
    var appTargetName: String
    var testTargetName: String
    var minimumMacOSVersion: String

    static func load() -> PackagingMetadata {
        let metadataURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("packaging-metadata.json")
        let data = try! Data(contentsOf: metadataURL)
        return try! JSONDecoder().decode(PackagingMetadata.self, from: data)
    }
}

private let metadata = PackagingMetadata.load()

let package = Package(
    name: metadata.packageName,
    platforms: [
        .macOS(metadata.minimumMacOSVersion),
    ],
    products: [
        .library(name: metadata.libraryProductName, targets: [metadata.coreTargetName]),
        .executable(name: metadata.executableProductName, targets: [metadata.appTargetName]),
    ],
    targets: [
        .target(
            name: metadata.coreTargetName,
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
        .executableTarget(
            name: metadata.appTargetName,
            dependencies: [
                .byName(name: metadata.coreTargetName),
            ],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                // The SwiftUI app entry point lives in an executable target, but the
                // menu bar lifecycle still needs library-style parsing under SwiftPM.
                .unsafeFlags(["-parse-as-library"]),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SwiftUI"),
            ]
        ),
        .testTarget(
            name: metadata.testTargetName,
            dependencies: [
                .byName(name: metadata.coreTargetName),
            ]
        ),
    ]
)
