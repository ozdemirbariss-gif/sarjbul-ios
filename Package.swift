// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SarjBulCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "SarjBulCore", targets: ["SarjBulCore"])
    ],
    targets: [
        .target(
            name: "SarjBulCore",
            path: "SarjBulCore"
        ),
        .testTarget(
            name: "SarjBulTests",
            dependencies: ["SarjBulCore"],
            path: "SarjBulTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)

