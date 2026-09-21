import BirthTrackerWidgetIntents
import Foundation
import Models
import Testing

struct WidgetAgeDisplayFormatTests {
  @Test("Contact age format defaults to years months and days")
  func defaultFormat() {
    let intent = SelectPersonIntent()

    #expect(intent.resolvedAgeDisplayFormat == .yearMonthDay)
  }

  @Test("Legacy widgets retain their saved initial format after removing the configuration control")
  func sameContactCanUseIndependentFormats() {
    let personID = UUID()
    let first = SelectPersonIntent(
      personID: personID,
      ageDisplayFormat: .monthDay)
    let second = SelectPersonIntent(
      personID: personID,
      ageDisplayFormat: .day)

    #expect(first.selectedPersonID == second.selectedPersonID)
    #expect(first.resolvedAgeDisplayFormat == .monthDay)
    #expect(second.resolvedAgeDisplayFormat == .day)
  }

  @Test(
    "Age format uses stable raw identifiers across the intent boundary",
    arguments: WidgetAgeDisplayFormat.allCases)
  func selectionRoundTripsThroughRawIdentifier(selection: WidgetAgeDisplayFormat) {
    let intent = SelectPersonIntent(personID: nil, ageDisplayFormat: selection)

    #expect(intent.ageDisplayFormat == selection.rawValue)
    #expect(intent.resolvedAgeDisplayFormat == selection.displayFormat)
  }

  @Test(
    "Unknown or missing age format falls back to years months and days",
    arguments: [nil, "unsupported-format"])
  func invalidRawIdentifierFallsBackToDefault(rawValue: String?) {
    let intent = SelectPersonIntent()
    intent.ageDisplayFormat = rawValue

    #expect(intent.resolvedAgeDisplayFormat == .yearMonthDay)
  }

  @Test("Age format options provider defaults to years months and days")
  func optionsProviderDefaultsToYearMonthDay() async {
    let rawValue = await WidgetAgeDisplayFormatOptionsProvider().defaultResult()

    #expect(rawValue == WidgetAgeDisplayFormat.yearMonthDay.rawValue)
  }
}
