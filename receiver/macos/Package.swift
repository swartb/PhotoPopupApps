// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PhotoPopupReceiverMac",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "PhotoPopupReceiverMac",
            path: "Sources/PhotoPopupReceiverMac",
            resources: [
                .process("en.lproj"),
                .process("nl.lproj")
            ]
        )
    ]
)
