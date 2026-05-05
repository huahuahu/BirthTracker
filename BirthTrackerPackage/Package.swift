// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "BirthTrackerPackage",
  platforms: [
    .iOS(.v26),
    .macOS(.v14),
  ],
  products: [
    .library(name: "App", targets: ["App"]),
    .library(name: "DesignSystem", targets: ["DesignSystem"]),
    .library(name: "Features", targets: ["Features"]),
    .library(name: "Models", targets: ["Models"]),
    .library(name: "Persistence", targets: ["Persistence"]),
    .library(name: "TestingSupport", targets: ["TestingSupport"]),
  ],
  targets: [
    .target(
      name: "App",
      dependencies: ["DesignSystem", "Features", "Persistence"],
      path: "Sources/App"
    ),
    .target(
      name: "DesignSystem",
      dependencies: ["Models"],
      path: "Sources/DesignSystem"
    ),
    .target(
      name: "Features",
      dependencies: ["DesignSystem", "Models", "Persistence"],
      path: "Sources/Features"
    ),
    .target(
      name: "Models",
      path: "Sources/Models"
    ),
    .target(
      name: "Persistence",
      dependencies: ["DesignSystem", "Models"],
      path: "Sources/Persistence"
    ),
    .target(
      name: "TestingSupport",
      dependencies: ["Models", "Persistence"],
      path: "Sources/TestingSupport"
    ),
    .testTarget(
      name: "BirthTrackerPackageTests",
      dependencies: ["Models", "Persistence", "TestingSupport"],
      path: "Tests/BirthTrackerTests"
    ),
  ]
)
