import AppIntents
import Foundation
import Localization
import Logging
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

    let result =
      identifiers.map { identifier in
        entitiesByID[identifier]
          ?? WidgetPersonEntity(
            id: identifier,
            name: L10n.string(L10n.Widget.selectedPersonUnavailable))
      }
    BirthLogger.widget.info(
      "Resolved widget person entities.",
      tags: [.data],
      values: [
        .private(identifiers.map(\.uuidString).joined(separator: ",")),
        .public("result-count=\(result.count)"),
      ])
    return result
  }

  func suggestedEntities() async throws -> [WidgetPersonEntity] {
    let result = try WidgetSnapshotStore.fetchAll().map(WidgetPersonEntity.init(snapshot:))
    BirthLogger.widget.info(
      "Loaded suggested widget person entities.",
      tags: [.data],
      values: [
        .private(result.map(\.id.uuidString).joined(separator: ",")),
        .public("result-count=\(result.count)"),
      ])
    return result
  }
}

extension WidgetPersonEntity {
  fileprivate init(snapshot: WidgetPersonSnapshot) {
    self.init(id: snapshot.personID, name: snapshot.displayName)
  }
}
