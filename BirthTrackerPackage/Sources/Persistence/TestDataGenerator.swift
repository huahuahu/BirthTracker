import Models
import SwiftData

public enum TestDataGenerator {
  @MainActor
  public static func generateSamplePeople(into modelContext: ModelContext) async throws {
    var insertedPeople: [TrackedPerson] = []

    do {
      for person in makeSamplePeople() {
        try Task.checkCancellation()
        modelContext.insert(person)
        insertedPeople.append(person)
        await Task.yield()
      }

      try Task.checkCancellation()
      try modelContext.save()
    } catch {
      for person in insertedPeople {
        modelContext.delete(person)
      }
      throw error
    }
  }

  private static func makeSamplePeople() -> [TrackedPerson] {
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
