import AppIntents
import Foundation

public struct SelectUpcomingBirthdaysIntent: WidgetConfigurationIntent {
  public static let title = LocalizedStringResource("Choose Person", table: "Intents")
  public static let description = IntentDescription(
    LocalizedStringResource("Choose which person this widget shows.", table: "Intents"))

  @Parameter(
    title: LocalizedStringResource("Contact", table: "Intents"),
    optionsProvider: WidgetPersonOptionsProvider())
  public var personID: String?

  @Parameter(
    title: LocalizedStringResource("Display Calendar", table: "Intents"),
    optionsProvider: WidgetDisplayCalendarOptionsProvider())
  public var displayCalendar: String?

  public static var parameterSummary: some ParameterSummary {
    Summary {
      \.$personID
      \.$displayCalendar
    }
  }

  public init() {}

  public init(
    personID: UUID?,
    displayCalendar: WidgetDisplayCalendar = .followContact
  ) {
    self.personID = personID?.uuidString
    self.displayCalendar = displayCalendar.rawValue
  }

  public var selectedPersonID: UUID? {
    guard let personID else { return nil }
    return UUID(uuidString: personID)
  }

  public var resolvedDisplayCalendar: WidgetDisplayCalendar {
    WidgetDisplayCalendar(rawValue: displayCalendar ?? "") ?? .followContact
  }
}
