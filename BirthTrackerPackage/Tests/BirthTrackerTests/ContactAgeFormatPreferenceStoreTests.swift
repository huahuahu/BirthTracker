import Foundation
import Persistence
import Testing

@Suite("Contact age format preference store")
struct ContactAgeFormatPreferenceStoreTests {
  @Test("Store returns duration components by default")
  func storeReturnsDurationComponentsByDefault() throws {
    let fixture = try PreferenceStoreFixture()

    #expect(fixture.store.format(for: UUID()) == .durationComponents)
  }

  @Test("Store persists formats per contact")
  func storePersistsFormatsPerContact() throws {
    let fixture = try PreferenceStoreFixture()
    let firstPersonID = UUID()
    let secondPersonID = UUID()

    fixture.store.setFormat(.totalDays, for: firstPersonID)

    #expect(fixture.store.format(for: firstPersonID) == .totalDays)
    #expect(fixture.store.format(for: secondPersonID) == .durationComponents)
  }

  @Test("Store toggles formats")
  func storeTogglesFormats() throws {
    let fixture = try PreferenceStoreFixture()
    let personID = UUID()

    #expect(fixture.store.toggleFormat(for: personID) == .totalDays)
    #expect(fixture.store.format(for: personID) == .totalDays)
    #expect(fixture.store.toggleFormat(for: personID) == .durationComponents)
    #expect(fixture.store.format(for: personID) == .durationComponents)
  }

  @Test("Store reset returns a contact to the default format")
  func storeResetReturnsAContactToTheDefaultFormat() throws {
    let fixture = try PreferenceStoreFixture()
    let personID = UUID()

    fixture.store.setFormat(.totalDays, for: personID)
    fixture.store.resetFormat(for: personID)

    #expect(fixture.store.format(for: personID) == .durationComponents)
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
