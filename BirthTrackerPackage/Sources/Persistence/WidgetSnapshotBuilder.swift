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
      .filter { $0.nextBirthdayDate != nil }
      .sorted { lhs, rhs in
        guard let lhsDate = lhs.nextBirthdayDate, let rhsDate = rhs.nextBirthdayDate else {
          return lhs.personName.localizedStandardCompare(rhs.personName) == .orderedAscending
        }
        if lhsDate == rhsDate {
          return lhs.personName.localizedStandardCompare(rhs.personName) == .orderedAscending
        }
        return lhsDate < rhsDate
      }

    return summaries.enumerated().compactMap { index, summary in
      guard let nextBirthdayDate = summary.nextBirthdayDate else { return nil }
      return WidgetPersonSnapshot(
        personID: summary.personID,
        displayName: summary.personName,
        nextBirthdayDate: nextBirthdayDate,
        age: summary.nextAge,
        birthDuration: summary.birthDuration,
        daysUntilNextBirthday: summary.daysUntilNextBirthday,
        calendarKind: summary.calendarKind,
        generatedAt: referenceDate,
        sortIndex: index)
    }
  }
}
