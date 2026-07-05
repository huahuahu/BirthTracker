import Foundation
import Models
import Persistence
import SwiftData
import Testing

@Suite("Widget snapshot store")
struct WidgetSnapshotStoreTests {
  private enum TestSaveError: Error, Equatable {
    case failed
  }

  @Test("Widget store round trips snapshots in sort order")
  func widgetStoreRoundTripsSnapshots() throws {
    let container = try WidgetSnapshotStore.makeInMemoryContainer()
    let alexID = UUID()
    let jamieID = UUID()
    let generatedAt = Date(timeIntervalSince1970: 1_799_999_000)
    let alexBirthday = Date(timeIntervalSince1970: 1_800_000_000)
    let jamieBirthday = Date(timeIntervalSince1970: 1_799_999_500)
    let alex = WidgetPersonSnapshot(
      personID: alexID,
      displayName: "Alex Chen",
      nextBirthdayDate: alexBirthday,
      age: 36,
      birthDuration: PersonBirthdaySummary.BirthDuration(years: 35, months: 11, days: 20),
      daysUntilNextBirthday: 12,
      totalBirthDays: 13_140,
      calendarKind: .gregorian,
      generatedAt: generatedAt,
      sortIndex: 1)
    let jamie = WidgetPersonSnapshot(
      personID: jamieID,
      displayName: "Jamie Lin",
      nextBirthdayDate: jamieBirthday,
      age: 38,
      calendarKind: .gregorian,
      generatedAt: generatedAt,
      sortIndex: 0)

    try WidgetSnapshotStore.rebuild(with: [alex, jamie], in: container)
    let snapshots = try WidgetSnapshotStore.fetchAll(in: container)

    #expect(snapshots.map(\.personID) == [jamieID, alexID])
    #expect(snapshots[0].displayName == "Jamie Lin")
    #expect(snapshots[0].schemaVersion == WidgetSnapshotSchema.currentVersion)
    #expect(snapshots[0].upcomingBirthday?.personName == "Jamie Lin")
    #expect(snapshots[0].upcomingBirthday?.date == jamieBirthday)
    #expect(snapshots[1].birthDuration == PersonBirthdaySummary.BirthDuration(years: 35, months: 11, days: 20))
    #expect(snapshots[1].daysUntilNextBirthday == 12)
    #expect(snapshots[1].totalBirthDays == 13_140)
    #expect(snapshots[1].upcomingBirthday?.birthDuration == snapshots[1].birthDuration)
  }

  @Test("Widget store rebuild removes stale people")
  func widgetStoreRebuildRemovesStalePeople() throws {
    let container = try WidgetSnapshotStore.makeInMemoryContainer()
    let removedID = UUID()
    let keptID = UUID()
    let generatedAt = Date(timeIntervalSince1970: 1_799_999_000)
    let removed = WidgetPersonSnapshot(
      personID: removedID,
      displayName: "Removed Person",
      nextBirthdayDate: Date(timeIntervalSince1970: 1_800_000_000),
      age: nil,
      calendarKind: .gregorian,
      generatedAt: generatedAt,
      sortIndex: 0)
    let kept = WidgetPersonSnapshot(
      personID: keptID,
      displayName: "Kept Person",
      nextBirthdayDate: Date(timeIntervalSince1970: 1_800_010_000),
      age: 12,
      calendarKind: .gregorian,
      generatedAt: generatedAt,
      sortIndex: 0)

    try WidgetSnapshotStore.rebuild(with: [removed], in: container)
    try WidgetSnapshotStore.rebuild(with: [kept], in: container)

    #expect(try WidgetSnapshotStore.fetchPerson(id: removedID, in: container) == nil)
    #expect(try WidgetSnapshotStore.fetchPerson(id: keptID, in: container)?.displayName == "Kept Person")
  }

  @Test("Widget snapshot builder sorts dated birthdays before undated people")
  func widgetSnapshotBuilderSortsDatedBirthdaysBeforeUndatedPeople() throws {
    let calendar = Calendar(identifier: .gregorian)
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
    let laterPersonID = UUID()
    let earlierPersonID = UUID()
    let noBirthdayPersonID = UUID()
    let laterPerson = TrackedPerson(
      id: laterPersonID,
      name: "Later Birthday",
      birthday: Birthday(calendarKind: .gregorian, year: 1990, month: 12, day: 10))
    let earlierPerson = TrackedPerson(
      id: earlierPersonID,
      name: "Earlier Birthday",
      birthday: Birthday(calendarKind: .gregorian, year: 1990, month: 2, day: 1))
    let noBirthdayPerson = TrackedPerson(id: noBirthdayPersonID, name: "No Birthday")

    let snapshots = WidgetSnapshotBuilder.makeSnapshots(
      from: [noBirthdayPerson, laterPerson, earlierPerson],
      after: referenceDate)

    #expect(snapshots.map(\.personID) == [earlierPersonID, laterPersonID, noBirthdayPersonID])
    #expect(snapshots.map(\.sortIndex) == [0, 1, 2])
    #expect(snapshots.allSatisfy { $0.generatedAt == referenceDate })
  }

  @Test("Widget snapshot builder carries birthday summary fields")
  func widgetSnapshotBuilderCarriesBirthdaySummaryFields() throws {
    let calendar = Calendar(identifier: .gregorian)
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 10)))
    let personID = UUID()
    let person = TrackedPerson(
      id: personID,
      name: "Summary Person",
      birthday: Birthday(calendarKind: .gregorian, year: 2024, month: 7, day: 5))

    let snapshot = try #require(
      WidgetSnapshotBuilder.makeSnapshots(from: [person], after: referenceDate).first)

    #expect(snapshot.personID == personID)
    #expect(snapshot.age == 2)
    #expect(snapshot.birthDuration == PersonBirthdaySummary.BirthDuration(years: 1, months: 9, days: 26))
    #expect(snapshot.daysUntilNextBirthday == 65)
    #expect(snapshot.totalBirthDays == 665)
    #expect(snapshot.upcomingBirthday?.birthDuration == snapshot.birthDuration)
    #expect(snapshot.upcomingBirthday?.daysUntilNextBirthday == 65)
  }

  @Test("Widget snapshot builder carries people without birthdays")
  func widgetSnapshotBuilderCarriesPeopleWithoutBirthdays() throws {
    let calendar = Calendar(identifier: .gregorian)
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 10)))
    let personID = UUID()
    let person = TrackedPerson(id: personID, name: "No Birthday")

    let snapshot = try #require(
      WidgetSnapshotBuilder.makeSnapshots(from: [person], after: referenceDate).first)

    #expect(snapshot.personID == personID)
    #expect(snapshot.nextBirthdayDate == nil)
    #expect(snapshot.birthDuration == nil)
    #expect(snapshot.totalBirthDays == nil)
    #expect(snapshot.upcomingBirthday == nil)
  }

  @Test("Widget snapshot sync is skipped when save fails")
  func widgetSnapshotSyncIsSkippedWhenSaveFails() {
    var syncCalled = false
    var reportedError: TestSaveError?

    WidgetSnapshotSyncGate.runAfterSuccessfulSave(
      save: {
        throw TestSaveError.failed
      },
      sync: {
        syncCalled = true
      },
      reportFailure: { error in
        reportedError = error as? TestSaveError
      })

    #expect(syncCalled == false)
    #expect(reportedError == .failed)
  }

  @Test("Widget snapshot sync runs after successful save")
  func widgetSnapshotSyncRunsAfterSuccessfulSave() {
    var saveCalled = false
    var syncCalled = false
    var reportCalled = false

    WidgetSnapshotSyncGate.runAfterSuccessfulSave(
      save: {
        saveCalled = true
      },
      sync: {
        syncCalled = true
      },
      reportFailure: { _ in
        reportCalled = true
      })

    #expect(saveCalled)
    #expect(syncCalled)
    #expect(reportCalled == false)
  }

  @Test("Widget snapshot sync is skipped with pending changes")
  func widgetSnapshotSyncIsSkippedWithPendingChanges() {
    var syncCalled = false
    var reportCalled = false

    WidgetSnapshotSyncGate.runWhenNoPendingChanges(
      hasPendingChanges: true,
      sync: {
        syncCalled = true
      },
      reportPendingChanges: {
        reportCalled = true
      })

    #expect(syncCalled == false)
    #expect(reportCalled)
  }

  @Test("Widget snapshot sync runs without pending changes")
  func widgetSnapshotSyncRunsWithoutPendingChanges() {
    var syncCalled = false
    var reportCalled = false

    WidgetSnapshotSyncGate.runWhenNoPendingChanges(
      hasPendingChanges: false,
      sync: {
        syncCalled = true
      },
      reportPendingChanges: {
        reportCalled = true
      })

    #expect(syncCalled)
    #expect(reportCalled == false)
  }
}
