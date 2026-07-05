import Foundation
import Models

public enum WidgetSnapshotBuilder {
  public static func makeSnapshots(
    from people: [TrackedPerson],
    after referenceDate: Date = .now
  ) -> [WidgetPersonSnapshot] {
    let summaries =
      people
      .map { PersonBirthdaySummary.make(for: $0, referenceDate: referenceDate) }
      .sorted { lhs, rhs in
        switch (lhs.nextBirthdayDate, rhs.nextBirthdayDate) {
        case (let lhsDate?, let rhsDate?):
          if lhsDate == rhsDate {
            return lhs.personName.localizedStandardCompare(rhs.personName) == .orderedAscending
          }
          return lhsDate < rhsDate
        case (.some, nil):
          return true
        case (nil, .some):
          return false
        case (nil, nil):
          return lhs.personName.localizedStandardCompare(rhs.personName) == .orderedAscending
        }
      }

    return summaries.enumerated().map { index, summary in
      WidgetPersonSnapshot(
        personID: summary.personID,
        displayName: summary.personName,
        nextBirthdayDate: summary.nextBirthdayDate,
        age: summary.nextAge,
        birthDate: summary.birthDate,
        birthDuration: summary.birthDuration,
        daysUntilNextBirthday: summary.daysUntilNextBirthday,
        totalBirthDays: summary.totalBirthDays,
        calendarKind: summary.calendarKind,
        generatedAt: referenceDate,
        sortIndex: index)
    }
  }
}
