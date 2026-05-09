// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WideAwake",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "WideAwake",
            path: "Sources/WideAwake",
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        ),
    ]
)
