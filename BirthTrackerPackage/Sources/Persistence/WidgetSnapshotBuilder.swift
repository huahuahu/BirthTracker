import Foundation
import Models

public enum WidgetSnapshotBuilder {
  public static func makeSnapshots(
    from people: [TrackedPerson],
    after referenceDate: Date = .now
  ) -> [WidgetPersonSnapshot] {
    let birthdays =
      people
      .compactMap { $0.upcomingBirthday(after: referenceDate) }
      .sorted { lhs, rhs in
        if lhs.date == rhs.date {
          lhs.personName.localizedStandardCompare(rhs.personName) == .orderedAscending
        } else {
          lhs.date < rhs.date
        }
      }

    return birthdays.enumerated().map { index, birthday in
      WidgetPersonSnapshot(
        personID: birthday.id,
        displayName: birthday.personName,
        nextBirthdayDate: birthday.date,
        age: birthday.age,
        calendarKind: birthday.calendarKind,
        generatedAt: referenceDate,
        sortIndex: index)
    }
  }
}
