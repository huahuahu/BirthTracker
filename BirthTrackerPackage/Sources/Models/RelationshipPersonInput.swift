import Foundation

public enum RelationshipBirthOrder: Equatable, Sendable {
  case older
  case younger
  case sameAge
}

public struct RelationshipBirthday: Equatable, Sendable {
  public let calendarKind: BirthdayCalendarKind
  public let era: Int?
  public let year: Int?
  public let month: Int
  public let day: Int

  public init(calendarKind: BirthdayCalendarKind, era: Int? = nil, year: Int? = nil, month: Int, day: Int) {
    self.calendarKind = calendarKind
    self.era = era
    self.year = year
    self.month = month
    self.day = day
  }

  public init(_ birthday: Birthday) {
    self.init(
      calendarKind: birthday.calendarKind,
      era: birthday.era,
      year: birthday.year,
      month: birthday.month,
      day: birthday.day)
  }

  public func birthOrderCompared(to other: RelationshipBirthday) -> RelationshipBirthOrder? {
    guard calendarKind == other.calendarKind, let year, let otherYear = other.year else { return nil }
    let lhs: [Int]
    let rhs: [Int]
    switch (era, other.era) {
    case (let lhsEra?, let rhsEra?):
      lhs = [lhsEra, year, month, day]
      rhs = [rhsEra, otherYear, other.month, other.day]
    case (nil, nil):
      guard calendarKind.requiresEraForReliableBirthOrder == false else { return nil }
      lhs = [year, month, day]
      rhs = [otherYear, other.month, other.day]
    case (_?, nil), (nil, _?):
      return nil
    }

    if lhs == rhs { return .sameAge }
    return lhs.lexicographicallyPrecedes(rhs) ? .older : .younger
  }
}

extension BirthdayCalendarKind {
  fileprivate var requiresEraForReliableBirthOrder: Bool {
    switch self {
    case .chinese:
      return true
    case .gregorian, .buddhist, .hebrew, .islamicUmmAlQura:
      return false
    }
  }
}

public struct RelationshipPersonInput: Identifiable, Equatable, Sendable {
  public let id: UUID
  public let birthday: RelationshipBirthday?
  public let relationshipGender: RelationshipGender

  public init(id: UUID, birthday: RelationshipBirthday? = nil, relationshipGender: RelationshipGender = .unknown) {
    self.id = id
    self.birthday = birthday
    self.relationshipGender = relationshipGender
  }

  public init(trackedPerson: TrackedPerson) {
    self.init(
      id: trackedPerson.id,
      birthday: trackedPerson.birthday.map(RelationshipBirthday.init),
      relationshipGender: trackedPerson.relationshipGender)
  }
}
