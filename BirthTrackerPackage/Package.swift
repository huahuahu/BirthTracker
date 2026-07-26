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
    .library(name: "Logging", targets: ["Logging"]),
    .library(name: "Models", targets: ["Models"]),
    .library(name: "Persistence", targets: ["Persistence"]),
    .library(name: "TestingSupport", targets: ["TestingSupport"]),
    .library(name: "BirthTrackerWidgetIntents", targets: ["BirthTrackerWidgetIntents"]),
    .library(name: "BirthTrackerWidgets", targets: ["BirthTrackerWidgets"]),
  ],
  dependencies: [
    .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols.git", .upToNextMajor(from: "7.0.0")),
  ],
  targets: [
    .target(
      name: "App",
      dependencies: ["DesignSystem", "Features", "Persistence"],
      path: "Sources/App",
      swiftSettings: [.defaultIsolation(MainActor.self)]
    ),
    .target(
      name: "DesignSystem",
      dependencies: ["Models"],
      path: "Sources/DesignSystem",
      swiftSettings: [.defaultIsolation(MainActor.self)]
    ),
    .target(
      name: "Features",
      dependencies: ["DesignSystem", "Localization", "Logging", "Models", "Persistence", "SFSafeSymbols"],
      path: "Sources/Features",
      swiftSettings: [.defaultIsolation(MainActor.self)]
    ),
    .target(
      name: "Localization",
      path: "Sources/Localization",
      resources: [.process("Resources")]
    ),
    .target(
      name: "Logging",
      path: "Sources/Logging"
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
    .target(
      name: "BirthTrackerWidgetIntents",
      dependencies: ["Logging", "Persistence"],
      path: "Sources/BirthTrackerWidgetIntents"
    ),
    .target(
      name: "BirthTrackerWidgets",
      dependencies: ["BirthTrackerWidgetIntents", "Logging", "Models", "Persistence", "SFSafeSymbols"],
      path: "Sources/BirthTrackerWidgets",
      resources: [.process("Resources")]
    ),
    .testTarget(
      name: "BirthTrackerPackageTests",
      dependencies: ["BirthTrackerWidgets", "Features", "Logging", "Models", "Persistence", "TestingSupport"],
      path: "Tests/BirthTrackerTests"
    ),
  ]
)
