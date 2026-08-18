// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TempoTasks",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TempoTasks", targets: ["TempoTasks"])
    ],
    targets: [
        .executableTarget(
            name: "TempoTasks",
            path: "Sources/TempoTasks"
        ),
        .testTarget(
            name: "TempoTasksTests",
            dependencies: ["TempoTasks"],
            path: "Tests/TempoTasksTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
