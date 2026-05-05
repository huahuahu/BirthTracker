import Foundation
import SwiftData

enum DebugStorageMode: String {
  case memory
  case local
  case cloud

  static var current: DebugStorageMode {
    #if DEBUG
      let value = ProcessInfo.processInfo.environment["BIRTHTRACKER_STORAGE_MODE"]
      return value.flatMap(DebugStorageMode.init(rawValue:)) ?? .local
    #else
      return .cloud
    #endif
  }
}

enum BirthTrackerModelContainer {
  static let schema = Schema([TrackedPerson.self])

  static func make() throws -> ModelContainer {
    let configuration: ModelConfiguration

    switch DebugStorageMode.current {
    case .memory:
      configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    case .local:
      configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
    case .cloud:
      configuration = ModelConfiguration(
        schema: schema,
        cloudKitDatabase: .private(cloudKitContainerIdentifier))
    }

    return try ModelContainer(for: schema, configurations: [configuration])
  }

  private static var cloudKitContainerIdentifier: String {
    Bundle.main.object(forInfoDictionaryKey: "CloudKitContainerIdentifier") as? String
      ?? "iCloud.com.example.BirthTracker"
  }
}
