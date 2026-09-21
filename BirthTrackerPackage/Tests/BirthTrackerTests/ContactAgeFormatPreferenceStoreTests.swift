import BirthTrackerWidgetIntents
import Foundation
import Models
import Persistence
import Testing

@Suite("Contact age format preference store")
struct ContactAgeFormatPreferenceStoreTests {
  @Test("Restored widget configurations keep cycling without affecting identical widgets")
  func restoredConfigurationsKeepIndependentState() throws {
    let fixture = try PreferenceStoreFixture()
    defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
    let personID = UUID()
    let first = SelectPersonIntent(personID: personID)
    let second = SelectPersonIntent(personID: personID)
    let secondStateID = try #require(second.contactAgeStateID)

    for expectedFormat: ContactAgeDisplayFormat in [.monthDay, .day, .yearMonthDay] {
      let restored = SelectPersonIntent()
      restored.personID = first.personID
      let stateID = try #require(restored.contactAgeStateID)
      try fixture.store.toggleFormat(for: stateID, configuredFormat: .yearMonthDay)

      let reloaded = SelectPersonIntent()
      reloaded.personID = first.personID
      let reloadedStateID = try #require(reloaded.contactAgeStateID)
      let reopenedStore = ContactAgeFormatPreferenceStore(userDefaults: fixture.defaults)

      #expect(reopenedStore.format(for: reloadedStateID, configuredFormat: .yearMonthDay) == expectedFormat)
      #expect(reopenedStore.format(for: secondStateID, configuredFormat: .yearMonthDay) == .yearMonthDay)
    }
  }

  @Test("Configured format is the default")
  func configuredFormatIsTheDefault() throws {
    let fixture = try PreferenceStoreFixture()

    #expect(
      fixture.store.format(
        for: "widget-a",
        configuredFormat: .monthDay
      ) == .monthDay)
  }

  @Test("Identical widget configurations keep independent tap state")
  func identicalWidgetConfigurationsKeepIndependentTapState() throws {
    let fixture = try PreferenceStoreFixture()

    #expect(
      try fixture.store.toggleFormat(
        for: "widget-a",
        configuredFormat: .yearMonthDay
      ) == .monthDay)
    #expect(
      fixture.store.format(
        for: "widget-a",
        configuredFormat: .yearMonthDay
      ) == .monthDay)
    #expect(
      fixture.store.format(
        for: "widget-b",
        configuredFormat: .yearMonthDay
      ) == .yearMonthDay)
  }

  @Test("Store cycles through all contact age formats")
  func storeCyclesThroughAllContactAgeFormats() throws {
    let fixture = try PreferenceStoreFixture()
    let stateID = "widget-a"

    #expect(
      try fixture.store.toggleFormat(
        for: stateID,
        configuredFormat: .yearMonthDay
      ) == .monthDay)
    #expect(
      try fixture.store.toggleFormat(
        for: stateID,
        configuredFormat: .yearMonthDay
      ) == .day)
    #expect(
      try fixture.store.toggleFormat(
        for: stateID,
        configuredFormat: .yearMonthDay
      ) == .yearMonthDay)
  }

  @Test("Legacy initial format changes do not reset an existing tap selection")
  func legacyInitialFormatDoesNotResetTapSelection() throws {
    let fixture = try PreferenceStoreFixture()
    let stateID = "widget-a"

    _ = try fixture.store.toggleFormat(
      for: stateID,
      configuredFormat: .yearMonthDay)

    #expect(
      fixture.store.format(
        for: stateID,
        configuredFormat: .day
      ) == .monthDay)
    #expect(
      try fixture.store.toggleFormat(
        for: stateID,
        configuredFormat: .day
      ) == .day)
  }

  @Test("Removing legacy format configuration and changing calendar retains the selected format")
  func removingLegacyFormatKeepsSelection() throws {
    let fixture = try PreferenceStoreFixture()
    defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
    let legacy = SelectPersonIntent(personID: UUID(), ageDisplayFormat: .monthDay)
    let stateID = try #require(legacy.contactAgeStateID)
    try fixture.store.toggleFormat(for: stateID, configuredFormat: legacy.resolvedAgeDisplayFormat)

    let restored = SelectPersonIntent()
    restored.personID = legacy.personID
    restored.displayCalendar = WidgetDisplayCalendar.islamicUmmAlQura.rawValue
    let restoredStateID = try #require(restored.contactAgeStateID)

    #expect(restoredStateID == stateID)
    #expect(restored.resolvedAgeDisplayFormat == .yearMonthDay)
    #expect(fixture.store.format(for: restoredStateID, configuredFormat: restored.resolvedAgeDisplayFormat) == .day)
  }

  @Test("Reset returns the widget to its configured format")
  func resetReturnsWidgetToItsConfiguredFormat() throws {
    let fixture = try PreferenceStoreFixture()
    let stateID = "widget-a"

    _ = try fixture.store.toggleFormat(
      for: stateID,
      configuredFormat: .monthDay)
    fixture.store.resetFormat(for: stateID)

    #expect(
      fixture.store.format(
        for: stateID,
        configuredFormat: .monthDay
      ) == .monthDay)
  }
}

private struct PreferenceStoreFixture {
  let suiteName: String
  let defaults: UserDefaults
  let store: ContactAgeFormatPreferenceStore

  init() throws {
    suiteName = "ContactAgeFormatPreferenceStoreTests.\(UUID().uuidString)"
    defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    store = ContactAgeFormatPreferenceStore(userDefaults: defaults)
  }
}
