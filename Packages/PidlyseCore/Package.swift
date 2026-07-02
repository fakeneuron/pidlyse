// swift-tools-version:5.9
import PackageDescription

// Scan + kill core shared by the Pidlyse app and the cli-companion binary
// (PID-EPIC-57). Holds the side-effect-light enumeration + classification logic,
// the process model, the port registry, and the synchronous kill path with its
// docker CLI layer — everything a second consumer needs to scan and clean
// without linking the SwiftUI app target.
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
