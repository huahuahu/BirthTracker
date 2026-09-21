import AppIntents
import Models

public enum WidgetAgeDisplayFormat: String, AppEnum {
  case yearMonthDay
  case monthDay
  case day

  public static let typeDisplayRepresentation = TypeDisplayRepresentation(
    name: LocalizedStringResource("Age Format", table: "Intents"))

  public static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
    .yearMonthDay: DisplayRepresentation(
      title: LocalizedStringResource("Years, Months, Days", table: "Intents")),
    .monthDay: DisplayRepresentation(
      title: LocalizedStringResource("Months, Days", table: "Intents")),
    .day: DisplayRepresentation(
      title: LocalizedStringResource("Days", table: "Intents")),
  ]

  public var displayFormat: ContactAgeDisplayFormat {
    switch self {
    case .yearMonthDay: .yearMonthDay
    case .monthDay: .monthDay
    case .day: .day
    }
  }
}

public struct WidgetAgeDisplayFormatOptionsProvider: DynamicOptionsProvider {
  public init() {}

  public func results() async throws -> IntentItemCollection<String> {
    let items = WidgetAgeDisplayFormat.allCases.map { format in
      IntentItem(format.rawValue, title: title(for: format))
    }
    return IntentItemCollection(sections: [IntentItemSection(items: items)])
  }

  public func defaultResult() async -> String? {
    WidgetAgeDisplayFormat.yearMonthDay.rawValue
  }

  private func title(for format: WidgetAgeDisplayFormat) -> LocalizedStringResource {
    switch format {
    case .yearMonthDay:
      LocalizedStringResource("Years, Months, Days", table: "Intents")
    case .monthDay:
      LocalizedStringResource("Months, Days", table: "Intents")
    case .day:
      LocalizedStringResource("Days", table: "Intents")
    }
  }
}
