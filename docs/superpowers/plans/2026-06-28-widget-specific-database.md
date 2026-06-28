# Widget-Specific Database Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the widget JSON snapshot with an App Group SwiftData store that lets each widget instance choose and display a specific person.

**Architecture:** The main app remains the only source of truth and writes a derived widget-only SwiftData store in the App Group container. The widget extension reads that store for both AppIntent configuration options and timeline rendering. The widget store contains flat snapshot records only, does not use CloudKit, and can be rebuilt safely from the main database.

**Tech Stack:** Swift 6.2+, SwiftUI, SwiftData, WidgetKit, AppIntents, Swift Testing, XcodeGen.

## Global Constraints

- Target iOS 26.0 and Swift 6.2 or later; the project currently uses `SWIFT_VERSION: "6.3.2"`.
- Do not introduce third-party frameworks.
- Do not suggest or use Core Data APIs for this feature; use SwiftData.
- Keep the main SwiftData database as the only real data source.
- Store widget data in a separate App Group SwiftData store and disable CloudKit with `cloudKitDatabase: .none`.
- Do not let the widget read the main app database.
- Store only the minimum fields needed for widget rendering and configuration.
- Run `make check` after code changes.
- Use `xcodebuildmcp` for Xcode build or simulator validation.

---

## File Structure

- Create `BirthTrackerPackage/Sources/Models/WidgetPersonSnapshot.swift`: value snapshot, SwiftData record, and schema version constant for widget data.
- Modify `BirthTrackerPackage/Sources/Persistence/AppGroup.swift`: add `widgetStoreFileName` and `widgetStoreURL`.
- Create `BirthTrackerPackage/Sources/Persistence/WidgetSnapshotStore.swift`: create the widget-only ModelContainer, rebuild snapshots, fetch all snapshots, and fetch by person id.
- Create `BirthTrackerPackage/Sources/Persistence/WidgetSnapshotBuilder.swift`: convert `[TrackedPerson]` from the main app into sorted widget snapshot values.
- Modify `BirthTrackerPackage/Sources/Features/Timeline/PeopleTimelineView.swift`: write widget snapshots to the new store instead of JSON.
- Create `Sources/BirthTrackerWidget/PersonSelectionIntent.swift`: AppIntent configuration, AppEntity, and EntityQuery backed by the widget store.
- Modify `Sources/BirthTrackerWidget/UpcomingBirthdaysWidget.swift`: migrate from `StaticConfiguration`/`TimelineProvider` to `AppIntentConfiguration`/`AppIntentTimelineProvider`.
- Modify `BirthTrackerPackage/Sources/Localization/L10n.swift`: expose strings needed by the configurable widget and deleted-person empty state.
- Modify `BirthTrackerPackage/Sources/Localization/Resources/Localizable.xcstrings`: add English and Simplified Chinese localizations for new widget strings.
- Create `BirthTrackerPackage/Tests/BirthTrackerTests/WidgetSnapshotStoreTests.swift`: unit tests for widget store and builder behavior.
- Modify `BirthTrackerPackage/Tests/BirthTrackerTests/BirthdayCalculatorTests.swift`: remove the obsolete JSON snapshot round-trip test.
- Delete `BirthTrackerPackage/Sources/Models/WidgetSnapshot.swift`: remove obsolete JSON snapshot model after widget code no longer uses it.
- Delete `BirthTrackerPackage/Sources/Models/Coding.swift`: remove obsolete JSON encoder/decoder helpers if `rg "birthTracker"` shows no remaining references.
- Modify `doc/architecture/current-architecture.md`: document the widget-only SwiftData store.

---

### Task 1: Add the Widget SwiftData Store

**Files:**
- Create: `BirthTrackerPackage/Sources/Models/WidgetPersonSnapshot.swift`
- Modify: `BirthTrackerPackage/Sources/Persistence/AppGroup.swift`
- Create: `BirthTrackerPackage/Sources/Persistence/WidgetSnapshotStore.swift`
- Create: `BirthTrackerPackage/Tests/BirthTrackerTests/WidgetSnapshotStoreTests.swift`

**Interfaces:**
- Consumes: `AppGroup.identifier`, `BirthdayCalendarKind`, `UpcomingBirthday`
- Produces:
  - `WidgetSnapshotSchema.currentVersion: Int`
  - `WidgetPersonSnapshot`
  - `WidgetPersonSnapshotRecord`
  - `WidgetSnapshotStore.makeContainer(url:allowsSave:) throws -> ModelContainer`
  - `WidgetSnapshotStore.makeInMemoryContainer() throws -> ModelContainer`
  - `WidgetSnapshotStore.rebuild(with:in:) throws`
  - `WidgetSnapshotStore.fetchAll(in:) throws -> [WidgetPersonSnapshot]`
  - `WidgetSnapshotStore.fetchPerson(id:in:) throws -> WidgetPersonSnapshot?`

- [ ] **Step 1: Write failing store tests**

Add this file:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --package-path BirthTrackerPackage --filter WidgetSnapshotStoreTests
```

Expected: FAIL because `WidgetSnapshotStore`, `WidgetPersonSnapshot`, and `WidgetSnapshotSchema` do not exist.

- [ ] **Step 3: Add the widget snapshot model**

Create `BirthTrackerPackage/Sources/Models/WidgetPersonSnapshot.swift`:

```swift
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
```

- [ ] **Step 4: Add the App Group store URL**

Modify `BirthTrackerPackage/Sources/Persistence/AppGroup.swift` to match:

```swift
import Foundation

public enum AppGroup {
  public static let snapshotFileName = "upcoming-birthdays.json"
  public static let widgetStoreFileName = "widget.sqlite"

  public static var identifier: String {
    Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String ?? "group.com.example.BirthTracker"
  }

  public static var snapshotURL: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)?
      .appendingPathComponent(snapshotFileName)
  }

  public static var widgetStoreURL: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)?
      .appendingPathComponent(widgetStoreFileName)
  }
}
```

- [ ] **Step 5: Add the store implementation**

Create `BirthTrackerPackage/Sources/Persistence/WidgetSnapshotStore.swift`:

```swift
import Foundation
import Models
import SwiftData

public enum WidgetSnapshotStoreError: LocalizedError {
  case appGroupUnavailable

  public var errorDescription: String? {
    switch self {
    case .appGroupUnavailable:
      "Unable to access the BirthTracker App Group container."
    }
  }
}

public enum WidgetSnapshotStore {
  public static let schema = Schema([WidgetPersonSnapshotRecord.self])

  public static func makeContainer(
    url: URL? = AppGroup.widgetStoreURL,
    allowsSave: Bool = true
  ) throws -> ModelContainer {
    guard let url else {
      throw WidgetSnapshotStoreError.appGroupUnavailable
    }

    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true)

    let configuration = ModelConfiguration(
      "WidgetSnapshotStore",
      schema: schema,
      url: url,
      allowsSave: allowsSave,
      cloudKitDatabase: .none)
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  public static func makeInMemoryContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  public static func rebuild(
    with snapshots: [WidgetPersonSnapshot],
    in container: ModelContainer? = nil
  ) throws {
    let activeContainer: ModelContainer
    if let container {
      activeContainer = container
    } else {
      activeContainer = try makeContainer(allowsSave: true)
    }

    let context = ModelContext(activeContainer)
    let existing = try context.fetch(FetchDescriptor<WidgetPersonSnapshotRecord>())
    for record in existing {
      context.delete(record)
    }

    for snapshot in snapshots {
      context.insert(WidgetPersonSnapshotRecord(snapshot: snapshot))
    }

    try context.save()
  }

  public static func fetchAll(in container: ModelContainer? = nil) throws -> [WidgetPersonSnapshot] {
    let activeContainer: ModelContainer
    if let container {
      activeContainer = container
    } else {
      activeContainer = try makeContainer(allowsSave: false)
    }

    let context = ModelContext(activeContainer)
    let descriptor = FetchDescriptor<WidgetPersonSnapshotRecord>(
      sortBy: [
        SortDescriptor(\.sortIndex),
        SortDescriptor(\.nextBirthdayDate),
        SortDescriptor(\.displayName),
      ])
    return try context.fetch(descriptor).map(WidgetPersonSnapshot.init(record:))
  }

  public static func fetchPerson(
    id personID: UUID,
    in container: ModelContainer? = nil
  ) throws -> WidgetPersonSnapshot? {
    let activeContainer: ModelContainer
    if let container {
      activeContainer = container
    } else {
      activeContainer = try makeContainer(allowsSave: false)
    }

    let context = ModelContext(activeContainer)
    var descriptor = FetchDescriptor<WidgetPersonSnapshotRecord>(
      predicate: #Predicate { record in
        record.personID == personID
      })
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first.map(WidgetPersonSnapshot.init(record:))
  }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run:

```bash
swift test --package-path BirthTrackerPackage --filter WidgetSnapshotStoreTests
```

Expected: PASS for both `WidgetSnapshotStoreTests`.

- [ ] **Step 7: Commit**

Run:

```bash
git add BirthTrackerPackage/Sources/Models/WidgetPersonSnapshot.swift \
  BirthTrackerPackage/Sources/Persistence/AppGroup.swift \
  BirthTrackerPackage/Sources/Persistence/WidgetSnapshotStore.swift \
  BirthTrackerPackage/Tests/BirthTrackerTests/WidgetSnapshotStoreTests.swift
git commit -m "feat: add widget snapshot store" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 2: Sync Main App Data Into the Widget Store

**Files:**
- Create: `BirthTrackerPackage/Sources/Persistence/WidgetSnapshotBuilder.swift`
- Modify: `BirthTrackerPackage/Sources/Features/Timeline/PeopleTimelineView.swift`
- Modify: `BirthTrackerPackage/Tests/BirthTrackerTests/WidgetSnapshotStoreTests.swift`

**Interfaces:**
- Consumes:
  - `TrackedPerson.upcomingBirthday(after:) -> UpcomingBirthday?`
  - `WidgetSnapshotStore.rebuild(with:in:) throws`
- Produces:
  - `WidgetSnapshotBuilder.makeSnapshots(from:after:) -> [WidgetPersonSnapshot]`
  - `PeopleTimelineView.persistWidgetSnapshots(for:)`

- [ ] **Step 1: Add failing builder tests**

Append these tests inside `WidgetSnapshotStoreTests`:

```swift
  @Test("Widget snapshot builder sorts people by next birthday")
  func widgetSnapshotBuilderSortsPeopleByNextBirthday() throws {
    let calendar = Calendar(identifier: .gregorian)
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
    let laterPersonID = UUID()
    let earlierPersonID = UUID()
    let laterPerson = TrackedPerson(
      id: laterPersonID,
      name: "Later Birthday",
      birthday: Birthday(calendarKind: .gregorian, year: 1990, month: 12, day: 10))
    let earlierPerson = TrackedPerson(
      id: earlierPersonID,
      name: "Earlier Birthday",
      birthday: Birthday(calendarKind: .gregorian, year: 1990, month: 2, day: 1))

    let snapshots = WidgetSnapshotBuilder.makeSnapshots(
      from: [laterPerson, earlierPerson],
      after: referenceDate)

    #expect(snapshots.map(\.personID) == [earlierPersonID, laterPersonID])
    #expect(snapshots.map(\.sortIndex) == [0, 1])
    #expect(snapshots.allSatisfy { $0.generatedAt == referenceDate })
  }
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --package-path BirthTrackerPackage --filter WidgetSnapshotStoreTests/widgetSnapshotBuilderSortsPeopleByNextBirthday
```

Expected: FAIL because `WidgetSnapshotBuilder` does not exist.

- [ ] **Step 3: Add the builder**

Create `BirthTrackerPackage/Sources/Persistence/WidgetSnapshotBuilder.swift`:

```swift
import Foundation
import Models

public enum WidgetSnapshotBuilder {
  public static func makeSnapshots(
    from people: [TrackedPerson],
    after referenceDate: Date = .now
  ) -> [WidgetPersonSnapshot] {
    let birthdays = people
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
```

- [ ] **Step 4: Replace JSON persistence in the timeline view**

In `BirthTrackerPackage/Sources/Features/Timeline/PeopleTimelineView.swift`, rename calls from `persistWidgetSnapshot` to `persistWidgetSnapshots`:

```swift
          persistWidgetSnapshots(for: people + [person])
```

```swift
        persistWidgetSnapshots()
```

```swift
        persistWidgetSnapshots()
```

```swift
    persistWidgetSnapshots(for: remainingPeople)
```

Then replace the old function with:

```swift
  private func persistWidgetSnapshots(for people: [TrackedPerson]? = nil) {
    let snapshots = WidgetSnapshotBuilder.makeSnapshots(from: people ?? self.people)

    do {
      try WidgetSnapshotStore.rebuild(with: snapshots)
      WidgetCenter.shared.reloadTimelines(ofKind: BirthTrackerWidgetKind.upcomingBirthdays)
    } catch {
      assertionFailure("Unable to persist widget snapshots: \(error)")
    }
  }
```

- [ ] **Step 5: Run focused tests**

Run:

```bash
swift test --package-path BirthTrackerPackage --filter WidgetSnapshotStoreTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add BirthTrackerPackage/Sources/Persistence/WidgetSnapshotBuilder.swift \
  BirthTrackerPackage/Sources/Features/Timeline/PeopleTimelineView.swift \
  BirthTrackerPackage/Tests/BirthTrackerTests/WidgetSnapshotStoreTests.swift
git commit -m "feat: sync widget snapshots from app data" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 3: Make the Widget User-Configurable

**Files:**
- Create: `Sources/BirthTrackerWidget/PersonSelectionIntent.swift`
- Modify: `Sources/BirthTrackerWidget/UpcomingBirthdaysWidget.swift`
- Modify: `BirthTrackerPackage/Sources/Localization/L10n.swift`
- Modify: `BirthTrackerPackage/Sources/Localization/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes:
  - `WidgetSnapshotStore.fetchAll(in:) throws -> [WidgetPersonSnapshot]`
  - `WidgetSnapshotStore.fetchPerson(id:in:) throws -> WidgetPersonSnapshot?`
  - `WidgetPersonSnapshot.upcomingBirthday`
- Produces:
  - `SelectPersonIntent: WidgetConfigurationIntent`
  - `WidgetPersonEntity: AppEntity`
  - `WidgetPersonQuery: EntityQuery`
  - `UpcomingBirthdaysProvider: AppIntentTimelineProvider`

- [ ] **Step 1: Add localized string accessors**

Modify `BirthTrackerPackage/Sources/Localization/L10n.swift` inside `public enum Widget`:

```swift
    public static let choosePerson = LocalizedStringResource(
      "Choose Person", bundle: .atURL(Bundle.module.bundleURL))
    public static let choosePersonDescription = LocalizedStringResource(
      "Choose which person's birthday this widget shows.", bundle: .atURL(Bundle.module.bundleURL))
    public static let person = LocalizedStringResource("Person", bundle: .atURL(Bundle.module.bundleURL))
    public static let selectedPersonUnavailable = LocalizedStringResource(
      "Selected person is no longer available.", bundle: .atURL(Bundle.module.bundleURL))
```

- [ ] **Step 2: Add string catalog entries**

Add these entries to the top-level `strings` object in `BirthTrackerPackage/Sources/Localization/Resources/Localizable.xcstrings`:

```json
    "Choose Person": {
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Choose Person"
          }
        },
        "zh-Hans": {
          "stringUnit": {
            "state": "translated",
            "value": "选择联系人"
          }
        }
      },
      "comment": "Widget configuration title for selecting which person to show."
    },
    "Choose which person's birthday this widget shows.": {
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Choose which person's birthday this widget shows."
          }
        },
        "zh-Hans": {
          "stringUnit": {
            "state": "translated",
            "value": "选择这个小组件显示哪位联系人的生日。"
          }
        }
      },
      "comment": "Widget configuration description for selecting a person."
    },
    "Person": {
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Person"
          }
        },
        "zh-Hans": {
          "stringUnit": {
            "state": "translated",
            "value": "联系人"
          }
        }
      },
      "comment": "Widget configuration parameter label for a tracked person."
    },
    "Selected person is no longer available.": {
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Selected person is no longer available."
          }
        },
        "zh-Hans": {
          "stringUnit": {
            "state": "translated",
            "value": "所选联系人已不在列表中。"
          }
        }
      },
      "comment": "Widget empty state shown when a configured person was deleted."
    },
```

- [ ] **Step 3: Add the AppIntent configuration types**

Create `Sources/BirthTrackerWidget/PersonSelectionIntent.swift`:

```swift
import AppIntents
import Foundation
import Localization
import Models
import Persistence

struct SelectPersonIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = L10n.Widget.choosePerson
  static var description = IntentDescription(L10n.Widget.choosePersonDescription)

  @Parameter(title: L10n.Widget.person)
  var person: WidgetPersonEntity?

  init() {}

  init(person: WidgetPersonEntity?) {
    self.person = person
  }
}

struct WidgetPersonEntity: AppEntity {
  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: L10n.Widget.person)
  static var defaultQuery = WidgetPersonQuery()

  let id: UUID

  @Property(title: L10n.Widget.person)
  var name: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(name)")
  }

  init(id: UUID, name: String) {
    self.id = id
    self.name = name
  }
}

struct WidgetPersonQuery: EntityQuery {
  func entities(for identifiers: [UUID]) async throws -> [WidgetPersonEntity] {
    let snapshots = try WidgetSnapshotStore.fetchAll()
    let identifiers = Set(identifiers)
    return snapshots
      .filter { identifiers.contains($0.personID) }
      .map(WidgetPersonEntity.init(snapshot:))
  }

  func suggestedEntities() async throws -> [WidgetPersonEntity] {
    try WidgetSnapshotStore.fetchAll().map(WidgetPersonEntity.init(snapshot:))
  }
}

private extension WidgetPersonEntity {
  init(snapshot: WidgetPersonSnapshot) {
    self.init(id: snapshot.personID, name: snapshot.displayName)
  }
}
```

- [ ] **Step 4: Update the widget provider entry type**

In `Sources/BirthTrackerWidget/UpcomingBirthdaysWidget.swift`, replace the entry struct with:

```swift
struct UpcomingBirthdaysEntry: TimelineEntry {
  let date: Date
  let birthdays: [UpcomingBirthday]
  let selectedPersonUnavailable: Bool
}
```

- [ ] **Step 5: Convert the provider to AppIntentTimelineProvider**

Replace `UpcomingBirthdaysProvider` with:

```swift
struct UpcomingBirthdaysProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> UpcomingBirthdaysEntry {
    UpcomingBirthdaysEntry(
      date: .now,
      birthdays: [
        UpcomingBirthday(
          id: UUID(),
          personName: "Taylor",
          date: .now.addingTimeInterval(86_400),
          age: 30,
          calendarKind: .gregorian)
      ],
      selectedPersonUnavailable: false)
  }

  func snapshot(for configuration: SelectPersonIntent, in context: Context) async -> UpcomingBirthdaysEntry {
    loadEntry(for: configuration.person?.id)
  }

  func timeline(for configuration: SelectPersonIntent, in context: Context) async -> Timeline<UpcomingBirthdaysEntry> {
    let entry = loadEntry(for: configuration.person?.id)
    let refreshDate = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now.addingTimeInterval(21_600)
    return Timeline(entries: [entry], policy: .after(refreshDate))
  }

  private func loadEntry(for selectedPersonID: UUID?) -> UpcomingBirthdaysEntry {
    do {
      if let selectedPersonID {
        guard let snapshot = try WidgetSnapshotStore.fetchPerson(id: selectedPersonID) else {
          return UpcomingBirthdaysEntry(date: .now, birthdays: [], selectedPersonUnavailable: true)
        }

        return UpcomingBirthdaysEntry(
          date: snapshot.generatedAt,
          birthdays: [snapshot.upcomingBirthday],
          selectedPersonUnavailable: false)
      }

      let snapshots = try WidgetSnapshotStore.fetchAll()
      return UpcomingBirthdaysEntry(
        date: snapshots.first?.generatedAt ?? .now,
        birthdays: snapshots.prefix(8).map(\.upcomingBirthday),
        selectedPersonUnavailable: false)
    } catch {
      return UpcomingBirthdaysEntry(date: .now, birthdays: [], selectedPersonUnavailable: false)
    }
  }
}
```

- [ ] **Step 6: Convert widget configuration to AppIntentConfiguration**

Replace the `StaticConfiguration` block in `UpcomingBirthdaysWidget` with:

```swift
    AppIntentConfiguration(
      kind: BirthTrackerWidgetKind.upcomingBirthdays,
      intent: SelectPersonIntent.self,
      provider: UpcomingBirthdaysProvider()
    ) { entry in
      UpcomingBirthdaysWidgetView(entry: entry)
        .containerBackground(.background, for: .widget)
    }
```

Keep the existing `.configurationDisplayName`, `.description`, and `.supportedFamilies` modifiers.

- [ ] **Step 7: Render the deleted-person state**

In `UpcomingBirthdaysWidgetView`, replace the empty-state branch with:

```swift
      if entry.selectedPersonUnavailable {
        Text(L10n.Widget.selectedPersonUnavailable)
          .font(.caption)
          .foregroundStyle(.secondary)
      } else if entry.birthdays.isEmpty {
        Text(L10n.Widget.noUpcomingBirthdays)
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        ForEach(entry.birthdays.prefix(3)) { birthday in
          VStack(alignment: .leading, spacing: 2) {
            Text(birthday.personName)
              .font(.subheadline.weight(.semibold))
              .lineLimit(1)
            Text(birthday.date, format: .dateTime.month(.abbreviated).day())
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
```

- [ ] **Step 8: Run formatting and compile validation**

Run:

```bash
make fix
swift test --package-path BirthTrackerPackage
```

Expected: both commands PASS.

Then validate the Xcode target with xcodebuildmcp:

1. Call `xcodebuildmcp-session_show_defaults`.
2. If defaults are missing, set them from `.xcodebuildmcp/config.yaml`.
3. Call `xcodebuildmcp-build_sim`.

Expected: the app and widget extension build successfully.

- [ ] **Step 9: Commit**

Run:

```bash
git add Sources/BirthTrackerWidget/PersonSelectionIntent.swift \
  Sources/BirthTrackerWidget/UpcomingBirthdaysWidget.swift \
  BirthTrackerPackage/Sources/Localization/L10n.swift \
  BirthTrackerPackage/Sources/Localization/Resources/Localizable.xcstrings
git commit -m "feat: make birthday widget configurable" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 4: Remove JSON Snapshot Code and Update Architecture Docs

**Files:**
- Delete: `BirthTrackerPackage/Sources/Models/WidgetSnapshot.swift`
- Delete: `BirthTrackerPackage/Sources/Models/Coding.swift`
- Modify: `BirthTrackerPackage/Tests/BirthTrackerTests/BirthdayCalculatorTests.swift`
- Modify: `doc/architecture/current-architecture.md`

**Interfaces:**
- Consumes: all new widget store APIs from Tasks 1-3
- Produces: no public API; removes obsolete JSON snapshot code and updates docs

- [ ] **Step 1: Remove obsolete JSON round-trip test**

Delete this test from `BirthTrackerPackage/Tests/BirthTrackerTests/BirthdayCalculatorTests.swift`:

```swift
  @Test("Widget snapshot round trips upcoming birthday data")
  func widgetSnapshotCoding() throws {
    let birthday = UpcomingBirthday(
      id: UUID(),
      personName: "Alex",
      date: Date(timeIntervalSince1970: 1_800_000_000),
      age: 24,
      calendarKind: .gregorian)
    let snapshot = WidgetSnapshot(generatedAt: Date(timeIntervalSince1970: 1_799_999_000), birthdays: [birthday])

    let data = try JSONEncoder.birthTracker.encode(snapshot)
    let decoded = try JSONDecoder.birthTracker.decode(WidgetSnapshot.self, from: data)

    #expect(decoded == snapshot)
  }
```

- [ ] **Step 2: Delete obsolete model files**

Delete:

```bash
rm BirthTrackerPackage/Sources/Models/WidgetSnapshot.swift
rm BirthTrackerPackage/Sources/Models/Coding.swift
```

- [ ] **Step 3: Verify there are no obsolete references**

Run:

```bash
rg "WidgetSnapshot|birthTracker|snapshotURL|snapshotFileName" BirthTrackerPackage Sources
```

Expected: no matches for `WidgetSnapshot` or `birthTracker`. Matches for `snapshotURL` and `snapshotFileName` are acceptable only if Task 4 intentionally keeps backward-compatible constants; otherwise remove `snapshotFileName` and `snapshotURL` from `AppGroup.swift` too.

- [ ] **Step 4: Remove unused JSON constants if no references remain**

If Step 3 shows no `snapshotURL` or `snapshotFileName` usage, modify `BirthTrackerPackage/Sources/Persistence/AppGroup.swift` to:

```swift
import Foundation

public enum AppGroup {
  public static let widgetStoreFileName = "widget.sqlite"

  public static var identifier: String {
    Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String ?? "group.com.example.BirthTracker"
  }

  public static var widgetStoreURL: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)?
      .appendingPathComponent(widgetStoreFileName)
  }
}
```

- [ ] **Step 5: Update architecture docs**

In `doc/architecture/current-architecture.md`, update the package module bullets:

```markdown
- `Models` 负责领域模型，包括生日、被记录的人、日历类型、Widget 快照记录和生日计算。
- `Persistence` 负责 SwiftData 容器、App Group 访问、Widget 专用 SwiftData store 和 Widget 持久化常量。
```

Update the Widgets section to:

```markdown
## Widgets

- Widget 代码位于 `Sources/BirthTrackerWidget`。
- 面向 Widget 共享的模型和持久化常量放在 package 模块里，而不是 App-only 代码里。
- App 和 Widget 配置使用 `Config/Project.xcconfig` 里的占位符，以及已提交的 entitlement 模板。
- App 将主 SwiftData 数据库中的人物转换成扁平快照，并写入 App Group 中独立的 Widget SwiftData store。
- Widget extension 使用 `AppIntentConfiguration` 支持每个小组件实例选择一个联系人。
- Widget store 是派生缓存，不启用 CloudKit，不替代主数据库。
```

- [ ] **Step 6: Run final verification**

Run:

```bash
make check
swift test --package-path BirthTrackerPackage
```

Expected: both commands PASS.

Then validate Xcode build with xcodebuildmcp:

1. Call `xcodebuildmcp-session_show_defaults`.
2. If defaults are missing, set them from `.xcodebuildmcp/config.yaml`.
3. Call `xcodebuildmcp-build_sim`.

Expected: the app and widget extension build successfully.

- [ ] **Step 7: Commit**

Run:

```bash
git add BirthTrackerPackage/Tests/BirthTrackerTests/BirthdayCalculatorTests.swift \
  BirthTrackerPackage/Sources/Persistence/AppGroup.swift \
  doc/architecture/current-architecture.md
git add -u BirthTrackerPackage/Sources/Models/WidgetSnapshot.swift \
  BirthTrackerPackage/Sources/Models/Coding.swift
git commit -m "chore: remove widget JSON snapshot" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Final Acceptance Criteria

- Users can edit each widget instance and choose a specific tracked person.
- Multiple widget instances can show different people.
- The default unconfigured widget still shows the nearest upcoming birthdays.
- Deleted configured people show a stable unavailable state.
- The widget reads only from the widget-specific SwiftData store.
- The widget-specific SwiftData store lives in App Group storage and uses `cloudKitDatabase: .none`.
- The main app remains the only source of truth and can rebuild widget data.
- `make check`, `swift test --package-path BirthTrackerPackage`, and the Xcode simulator build pass.

## Self-Review Notes

- Spec coverage: Tasks 1-3 implement the separate non-CloudKit widget store, AppIntent selection, per-widget timeline rendering, default recent-list behavior, and deleted-person empty state. Task 4 covers JSON removal and architecture documentation.
- Placeholder scan: no `TBD`, no `TODO`, no undefined future work, and every code-changing step includes concrete code.
- Type consistency: `WidgetPersonSnapshot`, `WidgetPersonSnapshotRecord`, `WidgetSnapshotBuilder`, `WidgetSnapshotStore`, `SelectPersonIntent`, `WidgetPersonEntity`, and `WidgetPersonQuery` are defined before later tasks consume them.
