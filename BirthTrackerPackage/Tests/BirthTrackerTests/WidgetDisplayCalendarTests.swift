import BirthTrackerWidgetIntents
import Foundation
import Models
import Testing

struct WidgetDisplayCalendarTests {
  @Test(
    "Widget calendar defaults to following the contact",
    .bug("https://github.com/huahuahu/BirthTracker/issues/43"))
  func defaultSelectionFollowsContact() {
    let intent = SelectPersonIntent()

    #expect(intent.resolvedDisplayCalendar == .followContact)
  }

  @Test(
    "Widget calendar uses a stable raw identifier across the intent boundary",
    .bug("https://github.com/huahuahu/BirthTracker/issues/43"),
    arguments: WidgetDisplayCalendar.allCases)
  func selectionRoundTripsThroughRawIdentifier(selection: WidgetDisplayCalendar) {
    let intent = SelectPersonIntent(personID: nil, displayCalendar: selection)

    #expect(intent.displayCalendar == selection.rawValue)
    #expect(intent.resolvedDisplayCalendar == selection)
  }

  @Test(
    "Unknown or missing widget calendar falls back to following the contact",
    .bug("https://github.com/huahuahu/BirthTracker/issues/43"),
    arguments: [nil, "unsupported-calendar"])
  func invalidRawIdentifierFallsBackToFollowingContact(rawValue: String?) {
    let intent = SelectPersonIntent()
    intent.displayCalendar = rawValue

    #expect(intent.resolvedDisplayCalendar == .followContact)
  }

  @Test(
    "Calendar options provider defaults to the stable follow-contact identifier",
    .bug("https://github.com/huahuahu/BirthTracker/issues/43"))
  func optionsProviderDefaultsToFollowContact() async {
    let rawValue = await WidgetDisplayCalendarOptionsProvider().defaultResult()

    #expect(rawValue == WidgetDisplayCalendar.followContact.rawValue)
  }

  @Test(
    "Following the contact resolves each person's own calendar",
    .bug("https://github.com/huahuahu/BirthTracker/issues/43"),
    arguments: BirthdayCalendarKind.allCases)
  func followContactResolvesIndividualCalendar(contactCalendarKind: BirthdayCalendarKind) {
    #expect(
      WidgetDisplayCalendar.followContact.resolve(following: contactCalendarKind)
        == contactCalendarKind)
  }

  @Test(
    "Explicit widget calendar overrides the contact calendar",
    .bug("https://github.com/huahuahu/BirthTracker/issues/43"),
    arguments: [
      (WidgetDisplayCalendar.gregorian, BirthdayCalendarKind.gregorian),
      (WidgetDisplayCalendar.chinese, BirthdayCalendarKind.chinese),
      (WidgetDisplayCalendar.buddhist, BirthdayCalendarKind.buddhist),
      (WidgetDisplayCalendar.hebrew, BirthdayCalendarKind.hebrew),
      (WidgetDisplayCalendar.islamicUmmAlQura, BirthdayCalendarKind.islamicUmmAlQura),
    ])
  func explicitSelectionResolvesRequestedCalendar(
    selection: WidgetDisplayCalendar,
    expectedCalendarKind: BirthdayCalendarKind
  ) {
    #expect(selection.resolve(following: .gregorian) == expectedCalendarKind)
  }

  @Test("Upcoming birthdays configuration resolves its calendar independently")
  func upcomingBirthdaysConfigurationResolvesCalendar() {
    let intent = SelectUpcomingBirthdaysIntent(
      personID: UUID(),
      displayCalendar: .islamicUmmAlQura)

    #expect(intent.resolvedDisplayCalendar == .islamicUmmAlQura)
  }
}
