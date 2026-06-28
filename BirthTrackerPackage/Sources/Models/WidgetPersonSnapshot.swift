import Foundation
import SwiftData

public enum WidgetSnapshotSchema {
  public static let currentVersion = 1
}

public struct WidgetPersonSnapshot: Equatable, Identifiable, Sendable {
  public var id: UUID { personID }

  public var personID: UUID
  public var displayName: String
  public var nextBirthdayDate: Date
  public var age: Int?
  public var calendarKind: BirthdayCalendarKind
  public var schemaVersion: Int
  public var generatedAt: Date
  public var sortIndex: Int

  public init(
    personID: UUID,
    displayName: String,
    nextBirthdayDate: Date,
    age: Int?,
    calendarKind: BirthdayCalendarKind,
    schemaVersion: Int = WidgetSnapshotSchema.currentVersion,
    generatedAt: Date,
    sortIndex: Int
  ) {
    self.personID = personID
    self.displayName = displayName
    self.nextBirthdayDate = nextBirthdayDate
    self.age = age
    self.calendarKind = calendarKind
    self.schemaVersion = schemaVersion
    self.generatedAt = generatedAt
    self.sortIndex = sortIndex
  }

  public init(record: WidgetPersonSnapshotRecord) {
    self.init(
      personID: record.personID,
      displayName: record.displayName,
      nextBirthdayDate: record.nextBirthdayDate,
      age: record.age,
      calendarKind: BirthdayCalendarKind(rawValue: record.calendarKindRawValue) ?? .gregorian,
      schemaVersion: record.schemaVersion,
      generatedAt: record.generatedAt,
      sortIndex: record.sortIndex)
  }

  public var upcomingBirthday: UpcomingBirthday {
    UpcomingBirthday(
      id: personID,
      personName: displayName,
      date: nextBirthdayDate,
      age: age,
      calendarKind: calendarKind)
  }
}

@Model
public final class WidgetPersonSnapshotRecord {
  public var personID: UUID = UUID()
  public var displayName: String = ""
  public var nextBirthdayDate: Date = Date()
  public var age: Int?
  public var calendarKindRawValue: String = BirthdayCalendarKind.gregorian.rawValue
  public var schemaVersion: Int = WidgetSnapshotSchema.currentVersion
  public var generatedAt: Date = Date()
  public var sortIndex: Int = 0

  public init(snapshot: WidgetPersonSnapshot) {
    personID = snapshot.personID
    displayName = snapshot.displayName
    nextBirthdayDate = snapshot.nextBirthdayDate
    age = snapshot.age
    calendarKindRawValue = snapshot.calendarKind.rawValue
    schemaVersion = snapshot.schemaVersion
    generatedAt = snapshot.generatedAt
    sortIndex = snapshot.sortIndex
  }
}
