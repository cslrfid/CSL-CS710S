// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CSL-CS710S",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Core Objective-C library (low-level RFID operations)
        .library(
            name: "CSL-CS710S-Core",
            targets: ["CSL-CS710S-Core"]
        ),
        // Swift wrapper library (high-level API)
        .library(
            name: "CSL-CS710S-Library",
            targets: ["CSL-CS710S-Library"]
        ),
    ],
    targets: [
        // Core target - Objective-C implementation
        .target(
            name: "CSL-CS710S-Core",
            path: "CSL-CS710S-Core",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("CSLReader"),
                .headerSearchPath("CSLModel"),
                .headerSearchPath("include")
            ]
        ),
        // Swift wrapper target
        .target(
            name: "CSL-CS710S-Library",
            dependencies: ["CSL-CS710S-Core"],
            path: "CSL-CS710S-Library/Sources"
        ),
    ]
)
