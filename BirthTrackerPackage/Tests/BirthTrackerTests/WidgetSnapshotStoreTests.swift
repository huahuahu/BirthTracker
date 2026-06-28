import Foundation
import Models
import Persistence
import SwiftData
import Testing

@Suite("Widget snapshot store")
struct WidgetSnapshotStoreTests {
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
    #expect(snapshots[0].upcomingBirthday.personName == "Jamie Lin")
    #expect(snapshots[0].upcomingBirthday.date == jamieBirthday)
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
}
