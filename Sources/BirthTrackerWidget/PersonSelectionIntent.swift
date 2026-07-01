import AppIntents
import Foundation
import Localization
import Models
import OSLog
import Persistence

let logger = Logger(subsystem: "birthTracc11", category: "widget")

struct SelectPersonIntent: WidgetConfigurationIntent {
  static let title: LocalizedStringResource = "Choose Person"
  static let description = IntentDescription("Choose which person's birthday this widget shows.")

  @Parameter(title: "Person")
  var person: WidgetPersonEntity?

  init() {}

  init(person: WidgetPersonEntity?) {
    self.person = person
  }
}

struct WidgetPersonEntity: AppEntity {
  static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Person")
  static let defaultQuery = WidgetPersonQuery()

  let id: UUID

  @Property(title: "Person")
  var name: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(name)")
  }

  init(id: UUID, name: String) {
    self.id = id
    self.name = name
  }
}

struct WidgetPersonQuery: EntityQuery {
  func entities(for identifiers: [UUID]) async throws -> [WidgetPersonEntity] {
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
    logger.info("entities for \(identifiers), result is \(result)")
    return result
  }

  func suggestedEntities() async throws -> [WidgetPersonEntity] {
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
