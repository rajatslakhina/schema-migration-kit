// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "SchemaMigrationKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(name: "SchemaMigrationKit", targets: ["SchemaMigrationKit"]),
        .executable(name: "SchemaMigrationDemo", targets: ["SchemaMigrationDemo"])
    ],
    targets: [
        .target(
            name: "SchemaMigrationKit"
        ),
        .executableTarget(
            name: "SchemaMigrationDemo",
            dependencies: ["SchemaMigrationKit"]
        ),
        .testTarget(
            name: "SchemaMigrationKitTests",
            dependencies: ["SchemaMigrationKit"]
        )
    ]
)
