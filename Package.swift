// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClipBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClipBar",
            path: "Sources/ClipBar",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
