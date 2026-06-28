import AppIntents
import Foundation
import Localization
import Models
import Persistence

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
    return
      identifiers.map { identifier in
        entitiesByID[identifier]
          ?? WidgetPersonEntity(
            id: identifier,
            name: L10n.string(L10n.Widget.selectedPersonUnavailable))
      }
  }

  func suggestedEntities() async throws -> [WidgetPersonEntity] {
    try WidgetSnapshotStore.fetchAll().map(WidgetPersonEntity.init(snapshot:))
  }
}

extension WidgetPersonEntity {
  fileprivate init(snapshot: WidgetPersonSnapshot) {
    self.init(id: snapshot.personID, name: snapshot.displayName)
  }
}
