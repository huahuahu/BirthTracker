// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "BirthTrackerPackage",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v26),
    .macOS(.v26),
  ],
  products: [
    .library(name: "App", targets: ["App"]),
    .library(name: "DesignSystem", targets: ["DesignSystem"]),
    .library(name: "Features", targets: ["Features"]),
    .library(name: "Localization", targets: ["Localization"]),
    .library(name: "Models", targets: ["Models"]),
    .library(name: "Persistence", targets: ["Persistence"]),
    .library(name: "TestingSupport", targets: ["TestingSupport"]),
  ],
  dependencies: [
    .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols.git", .upToNextMajor(from: "7.0.0")),
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
      dependencies: ["DesignSystem", "Localization", "Models", "Persistence", "SFSafeSymbols"],
      path: "Sources/Features"
    ),
    .target(
      name: "Localization",
      path: "Sources/Localization",
      resources: [.process("Resources")]
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
