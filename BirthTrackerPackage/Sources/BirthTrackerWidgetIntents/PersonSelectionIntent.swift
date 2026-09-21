import AppIntents
import Foundation
import Logging
import Models
import Persistence

public struct SelectPersonIntent: WidgetConfigurationIntent {
  // LocalizedStringResource defaults to the main bundle, which owns Intents.xcstrings.
  // Xcode 27.1's App Intents metadata extractor rejects an explicit bundle: .main.
  public static let title = LocalizedStringResource("Choose Person", table: "Intents")
  public static let description = IntentDescription(
    LocalizedStringResource("Choose which person this widget shows.", table: "Intents"))

  @Parameter(
    title: LocalizedStringResource("Contact", table: "Intents"),
    optionsProvider: ContactAgePersonOptionsProvider())
  public var personID: String?

  @Parameter(
    title: LocalizedStringResource("Display Calendar", table: "Intents"),
    optionsProvider: WidgetDisplayCalendarOptionsProvider())
  public var displayCalendar: String?

  // Read-only compatibility for existing widgets. New widgets choose their
  // format by tapping, so this parameter is intentionally absent from Summary.
  @Parameter(
    title: LocalizedStringResource("Age Format", table: "Intents"),
    optionsProvider: WidgetAgeDisplayFormatOptionsProvider())
  public var ageDisplayFormat: String?

  @Parameter(
    title: LocalizedStringResource("Widget ID", table: "Intents"))
  public var widgetInstanceIDValue: String?

  public static var parameterSummary: some ParameterSummary {
    Summary {
      \.$personID
      \.$displayCalendar
    }
  }

  // WidgetKit also calls this initializer when restoring saved parameters. A UUID
  // created here is not persisted and would change on every timeline reload.
  public init() {}

  public init(
    personID: UUID?,
    displayCalendar: WidgetDisplayCalendar = .followContact,
    ageDisplayFormat: WidgetAgeDisplayFormat = .yearMonthDay,
    widgetInstanceID: UUID = UUID()
  ) {
    self.personID = personID.map {
      WidgetPersonSelection(personID: $0, widgetInstanceID: widgetInstanceID).rawValue
    }
    self.displayCalendar = displayCalendar.rawValue
    self.ageDisplayFormat = ageDisplayFormat.rawValue
  }

  public var selectedPersonID: UUID? {
    guard let personID else { return nil }
    return WidgetPersonSelection(rawValue: personID)?.personID
  }

  public var widgetInstanceID: UUID? {
    if let legacyInstanceID = personID.flatMap({
      WidgetPersonSelection(rawValue: $0)?.widgetInstanceID
    }) {
      return legacyInstanceID
    }
    guard let widgetInstanceIDValue else { return nil }
    return UUID(uuidString: widgetInstanceIDValue)
  }

  public var resolvedDisplayCalendar: WidgetDisplayCalendar {
    WidgetDisplayCalendar(rawValue: displayCalendar ?? "") ?? .followContact
  }

  public var resolvedAgeDisplayFormat: ContactAgeDisplayFormat {
    let selection = WidgetAgeDisplayFormat(rawValue: ageDisplayFormat ?? "") ?? .yearMonthDay
    return selection.displayFormat
  }

  public var contactAgeStateID: String? {
    if let widgetInstanceID {
      return "instance:v1:\(widgetInstanceID.uuidString)"
    }

    guard let selectedPersonID else { return nil }
    return [
      "legacy:v1",
      selectedPersonID.uuidString,
      resolvedDisplayCalendar.rawValue,
      resolvedAgeDisplayFormat.rawValue,
    ].joined(separator: ":")
  }
}

public struct WidgetPersonOptionsProvider: DynamicOptionsProvider {
  public init() {}

  public func results() async throws -> IntentItemCollection<String> {
    let snapshots = try WidgetSnapshotStore.fetchAll()
    let items = snapshots.map { snapshot in
      IntentItem(snapshot.personID.uuidString, title: "\(snapshot.displayName)")
    }
    BirthLogger.widget.info(
      "Loaded suggested widget person IDs.",
      tags: [.data],
      values: [
        .private(snapshots.map(\.personID.uuidString).joined(separator: ",")),
        .public("result-count=\(items.count)"),
      ])
    return IntentItemCollection(sections: [IntentItemSection(items: items)])
  }
}

public struct ContactAgePersonOptionsProvider: DynamicOptionsProvider {
  public init() {}

  public func results() async throws -> IntentItemCollection<String> {
    let snapshots = try WidgetSnapshotStore.fetchAll()
    // The chosen String and its display title are saved by WidgetKit. Give each
    // selection a token here, not in the configuration initializer. This also
    // keeps two widgets with otherwise identical settings independently tappable.
    let widgetInstanceID = UUID()
    let items = snapshots.map { snapshot in
      let selection = WidgetPersonSelection(
        personID: snapshot.personID,
        widgetInstanceID: widgetInstanceID)
      return IntentItem(selection.rawValue, title: "\(snapshot.displayName)")
    }
    return IntentItemCollection(sections: [IntentItemSection(items: items)])
  }
}
