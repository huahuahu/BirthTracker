import DesignSystem
import Foundation
import Models
import SwiftData

public enum DebugStorageMode: String, CaseIterable, Identifiable {
  case memory
  case local
  case cloud

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .memory: "Memory"
    case .local: "Local"
    case .cloud: "iCloud"
    }
  }

  public static var current: DebugStorageMode {
    #if DEBUG
      let value = UserDefaults.standard.string(forKey: AppSettingsKey.storageMode)
      return value.flatMap(DebugStorageMode.init(rawValue:)) ?? .local
    #else
      return .cloud
    #endif
  }
}

public enum BirthTrackerModelContainer {
  public static let schema = Schema([TrackedPerson.self])

  public static func make() throws -> ModelContainer {
    try make(storageMode: DebugStorageMode.current)
  }

  public static func make(storageMode: DebugStorageMode) throws -> ModelContainer {
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
