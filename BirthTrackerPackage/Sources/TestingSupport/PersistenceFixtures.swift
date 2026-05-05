import Foundation
import Models
import Persistence
import SwiftData

public enum PersistenceFixtures {
  public static func makeInMemoryContainer() throws -> ModelContainer {
    try BirthTrackerModelContainer.make(storageMode: .memory)
  }

  public static func makePeople() -> [TrackedPerson] {
    [
      TrackedPerson(
        name: "Alex Chen",
        birthday: Birthday(calendarKind: .gregorian, year: 1990, month: 1, day: 12),
        notes: "Sample local contact"
      ),
      TrackedPerson(
        name: "Jamie Lin",
        birthday: Birthday(calendarKind: .gregorian, year: 1988, month: 5, day: 5),
        notes: "Sample coworker"
      ),
      TrackedPerson(
        name: "Morgan Lee",
        birthday: Birthday(calendarKind: .gregorian, year: 2016, month: 11, day: 23),
        notes: "Sample family member"
      ),
    ]
  }
}
