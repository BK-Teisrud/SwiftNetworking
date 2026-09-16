// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Networking",
  platforms: [.iOS(.v17), .macOS(.v13)],
  products: [
    .library(name: "Networking", targets: ["Networking"]),
    .library(name: "NetworkingTransfers", targets: ["NetworkingTransfers"]),
    .library(name: "NetworkingRealtime", targets: ["NetworkingRealtime"]),
    .library(name: "NetworkingSync", targets: ["NetworkingSync"]),
  ],
  targets: [
    .target(name: "Networking"),
    .target(name: "NetworkingTransfers", dependencies: ["Networking"]),
    .target(name: "NetworkingRealtime", dependencies: ["Networking"]),
    .target(name: "NetworkingSync"),
    .testTarget(name: "NetworkingTests", dependencies: ["Networking"]),
    .testTarget(
      name: "NetworkingTransfersTests", dependencies: ["Networking", "NetworkingTransfers"]),
    .testTarget(
      name: "NetworkingRealtimeTests", dependencies: ["Networking", "NetworkingRealtime"]),
    .testTarget(name: "NetworkingSyncTests", dependencies: ["NetworkingSync"]),
    .testTarget(
      name: "NetworkingIntegrationTests",
      dependencies: ["Networking", "NetworkingTransfers", "NetworkingRealtime", "NetworkingSync"]),
  ]
)
