import Foundation
import Models
import SwiftData

public enum WidgetSnapshotStoreError: LocalizedError, Equatable {
  case appGroupUnavailable

  public var errorDescription: String? {
    switch self {
    case .appGroupUnavailable:
      "Unable to access the BirthTracker App Group container."
    }
  }
}

public enum WidgetSnapshotStore {
  public static let schema = Schema([WidgetPersonSnapshotRecord.self])

  public static func makeContainer(
    url: URL? = AppGroup.widgetStoreURL,
    allowsSave: Bool = true
  ) throws -> ModelContainer {
    guard let url else {
      throw WidgetSnapshotStoreError.appGroupUnavailable
    }

    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true)

    let configuration = ModelConfiguration(
      "WidgetSnapshotStore",
      schema: schema,
      url: url,
      allowsSave: allowsSave,
      cloudKitDatabase: .none)
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  public static func makeInMemoryContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: true,
      cloudKitDatabase: .none)
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  public static func rebuild(
    with snapshots: [WidgetPersonSnapshot],
    in container: ModelContainer? = nil
  ) throws {
    let activeContainer: ModelContainer
    if let container {
      activeContainer = container
    } else {
      activeContainer = try makeContainer(allowsSave: true)
    }

    let context = ModelContext(activeContainer)
    try context.delete(model: WidgetPersonSnapshotRecord.self)

    for snapshot in snapshots {
      context.insert(WidgetPersonSnapshotRecord(snapshot: snapshot))
    }

    try context.save()
  }

  public static func fetchAll(in container: ModelContainer? = nil) throws -> [WidgetPersonSnapshot] {
    let activeContainer: ModelContainer
    if let container {
      activeContainer = container
    } else {
      activeContainer = try makeContainer(allowsSave: true)
    }

    let context = ModelContext(activeContainer)
    let descriptor = FetchDescriptor<WidgetPersonSnapshotRecord>(
      sortBy: [
        SortDescriptor(\.sortIndex),
        SortDescriptor(\.displayName),
      ])
    return try context.fetch(descriptor).map(WidgetPersonSnapshot.init(record:))
  }

  public static func fetchPerson(
    id personID: UUID,
    in container: ModelContainer? = nil
  ) throws -> WidgetPersonSnapshot? {
    let activeContainer: ModelContainer
    if let container {
      activeContainer = container
    } else {
      activeContainer = try makeContainer(allowsSave: true)
    }

    let context = ModelContext(activeContainer)
    var descriptor = FetchDescriptor<WidgetPersonSnapshotRecord>(
      predicate: #Predicate { record in
        record.personID == personID
      })
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first.map(WidgetPersonSnapshot.init(record:))
  }
}
