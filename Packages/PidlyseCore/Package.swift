// swift-tools-version:5.9
import PackageDescription

// Pure scan core shared by the Pidlyse app and the (future) LaunchAgent helper
// (PID-EPIC-27). Holds the side-effect-light enumeration + classification logic,
// the process model, and the port registry — everything the helper needs to run
// one scan per invocation without linking the SwiftUI app target.
let package = Package(
    name: "PidlyseCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "PidlyseCore", targets: ["PidlyseCore"])
    ],
    targets: [
        .target(name: "PidlyseCore")
    ]
)
