import Foundation
import Persistence
import Testing

@Suite("Contact age format preference store")
struct ContactAgeFormatPreferenceStoreTests {
  @Test("Store returns year month day by default")
  func storeReturnsYearMonthDayByDefault() throws {
    let fixture = try PreferenceStoreFixture()

    #expect(fixture.store.format(for: UUID()) == .yearMonthDay)
  }

  @Test("Store persists formats per contact")
  func storePersistsFormatsPerContact() throws {
    let fixture = try PreferenceStoreFixture()
    let firstPersonID = UUID()
    let secondPersonID = UUID()

    fixture.store.setFormat(.day, for: firstPersonID)

    #expect(fixture.store.format(for: firstPersonID) == .day)
    #expect(fixture.store.format(for: secondPersonID) == .yearMonthDay)
  }

  @Test("Store cycles through all contact age formats")
  func storeCyclesThroughAllContactAgeFormats() throws {
    let fixture = try PreferenceStoreFixture()
    let personID = UUID()

    #expect(fixture.store.toggleFormat(for: personID) == .monthDay)
    #expect(fixture.store.format(for: personID) == .monthDay)
    #expect(fixture.store.toggleFormat(for: personID) == .day)
    #expect(fixture.store.format(for: personID) == .day)
    #expect(fixture.store.toggleFormat(for: personID) == .yearMonthDay)
    #expect(fixture.store.format(for: personID) == .yearMonthDay)
  }

  @Test("Store maps legacy format raw values")
  func storeMapsLegacyFormatRawValues() throws {
    let fixture = try PreferenceStoreFixture()
    let durationPersonID = UUID()
    let daysPersonID = UUID()

    fixture.defaults.set("durationComponents", forKey: fixture.key(for: durationPersonID))
    fixture.defaults.set("totalDays", forKey: fixture.key(for: daysPersonID))

    #expect(fixture.store.format(for: durationPersonID) == .yearMonthDay)
    #expect(fixture.store.format(for: daysPersonID) == .day)
  }

  @Test("Store reset returns a contact to the default format")
  func storeResetReturnsAContactToTheDefaultFormat() throws {
    let fixture = try PreferenceStoreFixture()
    let personID = UUID()

    fixture.store.setFormat(.day, for: personID)
    fixture.store.resetFormat(for: personID)

    #expect(fixture.store.format(for: personID) == .yearMonthDay)
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

  func key(for personID: UUID) -> String {
    "contactAge.displayFormat.\(personID.uuidString)"
  }
}
