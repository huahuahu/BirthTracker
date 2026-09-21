import AppIntents
import Models

public enum WidgetDisplayCalendar: String, AppEnum {
  case followContact
  case gregorian
  case chinese
  case buddhist
  case hebrew
  case islamicUmmAlQura

  public static let typeDisplayRepresentation = TypeDisplayRepresentation(
    name: LocalizedStringResource("Display Calendar", table: "Intents"))

  public static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
    .followContact: DisplayRepresentation(
      title: LocalizedStringResource("Follow Contact", table: "Intents")),
    .gregorian: DisplayRepresentation(
      title: LocalizedStringResource("Gregorian", table: "Intents")),
    .chinese: DisplayRepresentation(
      title: LocalizedStringResource("Chinese", table: "Intents")),
    .buddhist: DisplayRepresentation(
      title: LocalizedStringResource("Buddhist", table: "Intents")),
    .hebrew: DisplayRepresentation(
      title: LocalizedStringResource("Hebrew", table: "Intents")),
    .islamicUmmAlQura: DisplayRepresentation(
      title: LocalizedStringResource("Islamic", table: "Intents")),
  ]

  public func resolve(following contactCalendarKind: BirthdayCalendarKind) -> BirthdayCalendarKind {
    switch self {
    case .followContact: contactCalendarKind
    case .gregorian: .gregorian
    case .chinese: .chinese
    case .buddhist: .buddhist
    case .hebrew: .hebrew
    case .islamicUmmAlQura: .islamicUmmAlQura
    }
  }
}

public struct WidgetDisplayCalendarOptionsProvider: DynamicOptionsProvider {
  public init() {}

  public func results() async throws -> IntentItemCollection<String> {
    let items = WidgetDisplayCalendar.allCases.map { calendar in
      IntentItem(calendar.rawValue, title: title(for: calendar))
    }
    return IntentItemCollection(sections: [IntentItemSection(items: items)])
  }

  public func defaultResult() async -> String? {
    WidgetDisplayCalendar.followContact.rawValue
  }

  private func title(for calendar: WidgetDisplayCalendar) -> LocalizedStringResource {
    switch calendar {
    case .followContact:
      LocalizedStringResource("Follow Contact", table: "Intents")
    case .gregorian:
      LocalizedStringResource("Gregorian", table: "Intents")
    case .chinese:
      LocalizedStringResource("Chinese", table: "Intents")
    case .buddhist:
      LocalizedStringResource("Buddhist", table: "Intents")
    case .hebrew:
      LocalizedStringResource("Hebrew", table: "Intents")
    case .islamicUmmAlQura:
      LocalizedStringResource("Islamic", table: "Intents")
    }
  }
}
