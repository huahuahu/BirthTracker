import Features
import Foundation
import Models
import Testing

@Suite("Person form state")
struct PersonFormStateTests {
  @Test("Blank draft creates a new tracked person")
  @MainActor
  func blankDraftCreatesANewTrackedPerson() throws {
    let calendar = Calendar(identifier: .gregorian)
    let birthDate = try #require(calendar.date(from: DateComponents(year: 2024, month: 7, day: 5, hour: 12)))
    let timestamp = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: 12)))
    var state = PersonFormState.blank(defaultCalendarKind: .gregorian, fallbackDate: birthDate)
    state.name = "  An An  "
    state.notes = "  Likes strawberries.  "
    state.birthDate = birthDate
    state.relationshipGender = .female

    let person = try state.makeTrackedPerson(now: timestamp)

    #expect(person.name == "An An")
    #expect(person.notes == "Likes strawberries.")
    #expect(person.relationshipGender == .female)
    #expect(person.createdAt == timestamp)
    #expect(person.updatedAt == timestamp)
    #expect(person.birthday?.year == 2024)
    #expect(person.birthday?.month == 7)
    #expect(person.birthday?.day == 5)
  }

  @Test("Edit draft applies values to an existing person")
  @MainActor
  func editDraftAppliesValuesToAnExistingPerson() throws {
    let calendar = Calendar(identifier: .gregorian)
    let originalDate = try #require(calendar.date(from: DateComponents(year: 2024, month: 7, day: 5, hour: 12)))
    let editedDate = try #require(calendar.date(from: DateComponents(year: 2025, month: 8, day: 6, hour: 12)))
    let timestamp = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: 12)))
    let person = TrackedPerson(
      name: "Original",
      birthday: Birthday(date: originalDate, calendarKind: .gregorian),
      notes: "Old",
      relationshipGender: .unknown)
    var state = PersonFormState(person: person, fallbackDate: originalDate)
    state.name = "  Edited  "
    state.notes = "  New note  "
    state.birthDate = editedDate
    state.relationshipGender = .male

    try state.apply(to: person, updatedAt: timestamp)

    #expect(person.name == "Edited")
    #expect(person.notes == "New note")
    #expect(person.relationshipGender == .male)
    #expect(person.updatedAt == timestamp)
    #expect(person.birthday?.year == 2025)
    #expect(person.birthday?.month == 8)
    #expect(person.birthday?.day == 6)
  }

  @Test("Draft preserves unknown birth year")
  @MainActor
  func draftPreservesUnknownBirthYear() throws {
    let calendar = Calendar(identifier: .gregorian)
    let fallbackDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12)))
    let person = TrackedPerson(
      name: "Month Day Only",
      birthday: Birthday(calendarKind: .gregorian, year: nil, month: 7, day: 5))
    let state = PersonFormState(person: person, fallbackDate: fallbackDate)

    #expect(state.birthYearIsKnown == false)
    try state.apply(to: person, updatedAt: fallbackDate)

    #expect(person.birthday?.year == nil)
    #expect(person.birthday?.month == 7)
    #expect(person.birthday?.day == 5)
  }

  @Test("Empty name is rejected")
  @MainActor
  func emptyNameIsRejected() throws {
    var state = PersonFormState.blank(defaultCalendarKind: .gregorian)
    state.name = "   "

    do {
      _ = try state.makeTrackedPerson()
      Issue.record("Expected empty name validation to fail.")
    } catch let error as PersonFormValidationError {
      #expect(error == .emptyName)
    } catch {
      Issue.record("Expected PersonFormValidationError.emptyName, got \(error).")
    }
  }
}
