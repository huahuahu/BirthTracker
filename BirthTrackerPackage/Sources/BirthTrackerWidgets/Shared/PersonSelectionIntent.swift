import AppIntents
import Foundation
import Localization
import Models
import Persistence

public struct SelectPersonIntent: WidgetConfigurationIntent {
  public static let title: LocalizedStringResource = "Choose Person"
  public static let description = IntentDescription("Choose which person this widget shows.")

  @Parameter(title: "Person")
  public var person: WidgetPersonEntity?

  public init() {}

  public init(personID: UUID?) {
    person = personID.map { WidgetPersonEntity(id: $0, name: L10n.string(L10n.Widget.selectedPersonUnavailable)) }
  }

  public var selectedPersonID: UUID? {
    person?.id
  }
}

public struct WidgetPersonEntity: AppEntity {
  public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Person")
  public static let defaultQuery = WidgetPersonQuery()

  public let id: UUID

  @Property(title: "Person")
  public var name: String

  public var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(name)")
  }

  public init(id: UUID, name: String) {
    self.id = id
    self.name = name
  }
}

public struct WidgetPersonQuery: EntityQuery {
  public init() {}

  public func entities(for identifiers: [UUID]) async throws -> [WidgetPersonEntity] {
    let snapshots = try WidgetSnapshotStore.fetchAll()
    let entitiesByID = Dictionary(
      uniqueKeysWithValues: snapshots.map { snapshot in
        (snapshot.personID, WidgetPersonEntity(snapshot: snapshot))
      })

    let result =
      identifiers.map { identifier in
        entitiesByID[identifier]
          ?? WidgetPersonEntity(
            id: identifier,
            name: L10n.string(L10n.Widget.selectedPersonUnavailable))
      }
    logger.info("entities for \(identifiers), result is \(result.map(\.id))")
    return result
  }

  public func suggestedEntities() async throws -> [WidgetPersonEntity] {
    let result = try WidgetSnapshotStore.fetchAll().map(WidgetPersonEntity.init(snapshot:))
    logger.info("suggestedEntities \(result.map(\.id))")
    return result
  }
}

extension WidgetPersonEntity {
  fileprivate init(snapshot: WidgetPersonSnapshot) {
    self.init(id: snapshot.personID, name: snapshot.displayName)
  }
}
