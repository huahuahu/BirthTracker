import Foundation
import SwiftData

enum DebugStorageMode: String, CaseIterable, Identifiable {
  case memory
  case local
  case cloud

  var id: String { rawValue }

  var title: String {
    switch self {
    case .memory: "Memory"
    case .local: "Local"
    case .cloud: "iCloud"
    }
  }

  static var current: DebugStorageMode {
    #if DEBUG
      let value = UserDefaults.standard.string(forKey: AppSettingsKey.storageMode)
      return value.flatMap(DebugStorageMode.init(rawValue:)) ?? .local
    #else
      return .cloud
    #endif
  }
}

enum BirthTrackerModelContainer {
  static let schema = Schema([TrackedPerson.self])

  static func make() throws -> ModelContainer {
    try make(storageMode: DebugStorageMode.current)
  }

  static func make(storageMode: DebugStorageMode) throws -> ModelContainer {
    let configuration: ModelConfiguration

    switch storageMode {
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
