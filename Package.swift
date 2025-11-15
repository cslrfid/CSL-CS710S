// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CSL-CS710S",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "CSL-CS710S",
            targets: ["CSL-CS710S"]
        ),
    ],
    targets: [
        .target(
            name: "CSL-CS710S",
            path: "CSL-CS710S",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("CSLReader"),
                .headerSearchPath("CSLModel"),
                .headerSearchPath("include")
            ]
        ),
    ]
)
