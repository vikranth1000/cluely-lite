// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "axhelper",
    platforms: [ .macOS(.v13) ],
    products: [ .executable(name: "axhelper", targets: ["AXHelper"]) ],
    targets: [
        .executableTarget(
            name: "AXHelper",
            path: "Sources/AXHelper",
            linkerSettings: [.linkedFramework("Cocoa"), .linkedFramework("ApplicationServices")]
        )
    ]
)

