import Foundation
import Models

public enum PersonFormMode: Equatable, Sendable {
  case add
  case edit
}

public enum PersonFormValidationError: LocalizedError, Equatable {
  case emptyName

  public var errorDescription: String? {
    switch self {
    case .emptyName:
      "Name is required."
    }
  }
}

@MainActor
public struct PersonFormState: Equatable {
  public var name: String
  public var notes: String
  public var calendarKind: BirthdayCalendarKind
  public var birthDate: Date
  public var birthYearIsKnown: Bool
  public var relationshipGender: RelationshipGender

  public static func blank(
    defaultCalendarKind: BirthdayCalendarKind,
    fallbackDate: Date = .now
  ) -> PersonFormState {
    PersonFormState(
      name: "",
      notes: "",
      calendarKind: defaultCalendarKind,
      birthDate: fallbackDate,
      birthYearIsKnown: true,
      relationshipGender: .unknown)
  }

  public init(
    name: String,
    notes: String,
    calendarKind: BirthdayCalendarKind,
    birthDate: Date,
    birthYearIsKnown: Bool,
    relationshipGender: RelationshipGender
  ) {
    self.name = name
    self.notes = notes
    self.calendarKind = calendarKind
    self.birthDate = birthDate
    self.birthYearIsKnown = birthYearIsKnown
    self.relationshipGender = relationshipGender
  }

  public init(person: TrackedPerson, fallbackDate: Date = .now) {
    let birthday = person.birthday
    let calendarKind = birthday?.calendarKind ?? person.calendarKind
    self.init(
      name: person.name,
      notes: person.notes,
      calendarKind: calendarKind,
      birthDate: Self.makeDate(from: birthday, calendarKind: calendarKind, fallbackDate: fallbackDate),
      birthYearIsKnown: birthday?.year != nil,
      relationshipGender: person.relationshipGender)
  }

  public var trimmedName: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  public var trimmedNotes: String {
    notes.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  public var canSave: Bool {
    !trimmedName.isEmpty
  }

  public func validate() throws {
    guard canSave else {
      throw PersonFormValidationError.emptyName
    }
  }

  public func makeTrackedPerson(now: Date = Date()) throws -> TrackedPerson {
    try validate()
    let birthday = makeBirthday()
    let person = TrackedPerson(
      name: trimmedName,
      birthday: birthday,
      notes: trimmedNotes,
      relationshipGender: relationshipGender)
    person.createdAt = now
    person.updatedAt = now
    return person
  }

  public func apply(to person: TrackedPerson, updatedAt: Date = Date()) throws {
    try validate()

    person.name = trimmedName
    person.notes = trimmedNotes
    person.relationshipGender = relationshipGender
    if let birthday = person.birthday {
      applyBirthdayFields(to: birthday)
      birthday.person = person
    } else {
      let birthday = makeBirthday()
      birthday.person = person
      person.birthday = birthday
    }
    person.updatedAt = updatedAt
  }

  private func makeBirthday() -> Birthday {
    let birthday = Birthday(date: birthDate, calendarKind: calendarKind)
    applyBirthdayFields(to: birthday)
    return birthday
  }

  private func applyBirthdayFields(to birthday: Birthday) {
    let draft = Birthday(date: birthDate, calendarKind: calendarKind)
    birthday.calendarKind = calendarKind
    birthday.era = draft.era
    birthday.year = birthYearIsKnown ? draft.year : nil
    birthday.month = draft.month
    birthday.day = draft.day
  }

  private static func makeDate(
    from birthday: Birthday?,
    calendarKind: BirthdayCalendarKind,
    fallbackDate: Date
  ) -> Date {
    guard let birthday else { return fallbackDate }

    var calendar = calendarKind.calendar
    calendar.timeZone = .autoupdatingCurrent
    let fallbackComponents = calendar.dateComponents([.era, .year], from: fallbackDate)

    var components = DateComponents()
    components.calendar = calendar
    components.era = birthday.era ?? fallbackComponents.era
    components.year = birthday.year ?? fallbackComponents.year
    components.month = birthday.month
    components.day = birthday.day
    components.hour = 12

    return calendar.date(from: components) ?? fallbackDate
  }
}
