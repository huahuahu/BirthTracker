# Contact Age Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增一个联系人年龄 Widget，显示所选联系人当前年龄，并允许用户在 Widget 内点按切换“年/月/日”和“总天数”格式。

**Architecture:** App 继续生成 App Group 内的 Widget 快照；Widget extension 只读取快照和 App Group 格式偏好。年龄格式偏好按联系人 ID 存储在 `UserDefaults(suiteName: AppGroup.identifier)`，交互式 AppIntent 切换偏好并刷新联系人年龄 Widget。

**Tech Stack:** Swift 6.3.2, SwiftUI, WidgetKit, AppIntents, SwiftData, Swift Testing, XcodeGen, SFSafeSymbols.

## Global Constraints

- iOS deployment target is `26.0`.
- Swift language version is `6.3.2`.
- `BirthTracker.xcodeproj` is generated from `project.yml` and ignored; regenerate with `xcodegen generate` before Xcode builds when the project file is missing.
- Do not commit `Config/Project.xcconfig`.
- Keep app/widget shared logic in `BirthTrackerPackage/Sources`.
- Use SFSafeSymbols typed APIs or existing `SFSymbol.*.rawValue` patterns instead of raw SF Symbol strings.
- Run `make check` after code changes.
- Before the first `xcodebuildmcp` build/test call in an implementation session, call `xcodebuildmcp-session_show_defaults`; if defaults are missing, set `projectPath` to the repo-root absolute path for `BirthTracker.xcodeproj`, `scheme` to `BirthTracker`, and use the simulator defaults from `.xcodebuildmcp/config.yaml`.
- When implementing the Widget UI, preview the Widget and capture evidence with xcodebuildmcp. Prefer a simulator/home-screen preview with screenshot; if WidgetKit home-screen insertion is not available in the active tooling, build the Widget previews and capture the best available simulator screenshot, then report the limitation explicitly.
- If SwiftPM/Xcode fails with `safe.bareRepository is 'explicit'`, rerun that command with `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all`.
- Network fetch/install commands must use the local proxy environment required by the repository instructions.

---

## File Structure

- Modify `BirthTrackerPackage/Sources/Models/PersonBirthdaySummary.swift`: add `totalBirthDays` to the shared birthday summary and compute it from full birth dates.
- Modify `BirthTrackerPackage/Tests/BirthTrackerTests/PersonBirthdaySummaryTests.swift`: cover total-day age calculations, missing year, no birthday, and future birth dates.
- Modify `BirthTrackerPackage/Sources/Models/WidgetPersonSnapshot.swift`: persist `totalBirthDays`, allow `nextBirthdayDate` to be optional so no-birthday contacts can still appear in age-widget selection, and make `upcomingBirthday` optional.
- Modify `BirthTrackerPackage/Sources/Persistence/WidgetSnapshotBuilder.swift`: include all tracked people in snapshots, sort dated birthdays first, and carry `totalBirthDays`.
- Modify `BirthTrackerPackage/Sources/Persistence/WidgetSnapshotStore.swift`: keep fetch ordering based on `sortIndex` after `nextBirthdayDate` becomes optional.
- Modify `BirthTrackerPackage/Tests/BirthTrackerTests/WidgetSnapshotStoreTests.swift`: cover snapshot round-trip, builder sorting, no-birthday snapshots, and optional `upcomingBirthday`.
- Create `BirthTrackerPackage/Sources/Persistence/ContactAgeFormatPreferenceStore.swift`: define `ContactAgeDisplayFormat` and per-contact App Group preference read/write/toggle behavior.
- Create `BirthTrackerPackage/Tests/BirthTrackerTests/ContactAgeFormatPreferenceStoreTests.swift`: cover default format, per-contact persistence, toggling, and reset.
- Modify `BirthTrackerPackage/Sources/Persistence/BirthTrackerWidgetKind.swift`: add `contactAge = "ContactAgeWidget"`.
- Modify `BirthTrackerPackage/Sources/Localization/L10n.swift`: add Widget strings and format helpers for contact age.
- Modify `BirthTrackerPackage/Sources/Localization/Resources/Localizable.xcstrings`: add English and Simplified Chinese localizations for the new Widget strings.
- Create `Sources/BirthTrackerWidget/ToggleContactAgeFormatIntent.swift`: implement AppIntent that toggles a contact's display format and reloads contact-age timelines.
- Create `Sources/BirthTrackerWidget/ContactAgeWidget.swift`: implement provider, entry, view, empty states, tap-to-toggle button, and previews.
- Modify `Sources/BirthTrackerWidget/UpcomingBirthdaysWidget.swift`: adapt to optional `upcomingBirthday` and keep birthday-list behavior unchanged by filtering out snapshots with no next birthday.
- Modify `Sources/BirthTrackerWidget/BirthTrackerWidgetBundle.swift`: register `ContactAgeWidget()`.
- Modify `doc/architecture/current-architecture.md`: record the new age Widget and per-contact App Group display-format preference.

---

### Task 1: Shared Current-Age Day Count

**Files:**
- Modify: `BirthTrackerPackage/Sources/Models/PersonBirthdaySummary.swift`
- Modify: `BirthTrackerPackage/Tests/BirthTrackerTests/PersonBirthdaySummaryTests.swift`

**Interfaces:**
- Produces: `PersonBirthdaySummary.totalBirthDays: Int?`
- Produces: `PersonBirthdaySummary.init(..., daysUntilNextBirthday: Int?, totalBirthDays: Int?, nextAge: Int?)`
- Later tasks consume: `summary.totalBirthDays`

- [ ] **Step 1: Write failing tests for total-day age**

Add the `totalBirthDays` expectations and future-date test below to `BirthTrackerPackage/Tests/BirthTrackerTests/PersonBirthdaySummaryTests.swift`.

```swift
@Test("Summary includes duration and next birthday for full birth date")
func summaryIncludesDurationAndNextBirthdayForFullBirthDate() throws {
  let calendar = Calendar(identifier: .gregorian)
  let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: 10)))
  let person = TrackedPerson(
    name: "An An",
    birthday: Birthday(calendarKind: .gregorian, year: 2024, month: 7, day: 5))

  let summary = PersonBirthdaySummary.make(for: person, referenceDate: referenceDate)

  #expect(summary.personName == "An An")
  #expect(summary.calendarKind == .gregorian)
  #expect(summary.birthDuration == PersonBirthdaySummary.BirthDuration(years: 2, months: 0, days: 0))
  #expect(summary.daysUntilNextBirthday == 0)
  #expect(summary.totalBirthDays == 730)
  #expect(summary.nextAge == 2)
  #expect(summary.nextBirthdayDate != nil)
}

@Test("Summary calculates days until the next birthday")
func summaryCalculatesDaysUntilTheNextBirthday() throws {
  let calendar = Calendar(identifier: .gregorian)
  let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 10)))
  let person = TrackedPerson(
    name: "Future Birthday",
    birthday: Birthday(calendarKind: .gregorian, year: 2024, month: 7, day: 5))

  let summary = PersonBirthdaySummary.make(for: person, referenceDate: referenceDate)

  #expect(summary.birthDuration == PersonBirthdaySummary.BirthDuration(years: 1, months: 9, days: 26))
  #expect(summary.daysUntilNextBirthday == 65)
  #expect(summary.totalBirthDays == 665)
  #expect(summary.nextAge == 2)
}

@Test("Summary omits age dependent values when birth year is unknown")
func summaryOmitsAgeDependentValuesWhenBirthYearIsUnknown() throws {
  let calendar = Calendar(identifier: .gregorian)
  let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 10)))
  let person = TrackedPerson(
    name: "Unknown Year",
    birthday: Birthday(calendarKind: .gregorian, year: nil, month: 7, day: 5))

  let summary = PersonBirthdaySummary.make(for: person, referenceDate: referenceDate)

  #expect(summary.birthDate == nil)
  #expect(summary.birthDuration == nil)
  #expect(summary.totalBirthDays == nil)
  #expect(summary.nextAge == nil)
  #expect(summary.daysUntilNextBirthday == 65)
  #expect(summary.nextBirthdayDate != nil)
}

@Test("Summary handles people without birthdays")
func summaryHandlesPeopleWithoutBirthdays() {
  let person = TrackedPerson(name: "No Birthday")

  let summary = PersonBirthdaySummary.make(for: person)

  #expect(summary.personName == "No Birthday")
  #expect(summary.birthDate == nil)
  #expect(summary.birthDuration == nil)
  #expect(summary.totalBirthDays == nil)
  #expect(summary.nextBirthdayDate == nil)
  #expect(summary.daysUntilNextBirthday == nil)
  #expect(summary.nextAge == nil)
}

@Test("Summary clamps total birth days for future birth dates")
func summaryClampsTotalBirthDaysForFutureBirthDates() throws {
  let calendar = Calendar(identifier: .gregorian)
  let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 10)))
  let person = TrackedPerson(
    name: "Future Birth",
    birthday: Birthday(calendarKind: .gregorian, year: 2027, month: 1, day: 1))

  let summary = PersonBirthdaySummary.make(for: person, referenceDate: referenceDate)

  #expect(summary.birthDuration == PersonBirthdaySummary.BirthDuration(years: 0, months: 0, days: 0))
  #expect(summary.totalBirthDays == 0)
}
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run:

```bash
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter PersonBirthdaySummaryTests
```

Expected: FAIL with compile errors referencing missing member `totalBirthDays`.

- [ ] **Step 3: Add total-day age to `PersonBirthdaySummary`**

Update `BirthTrackerPackage/Sources/Models/PersonBirthdaySummary.swift` with the code below.

```swift
public struct PersonBirthdaySummary: Equatable, Sendable {
  public struct BirthDuration: Codable, Equatable, Sendable {
    public var years: Int
    public var months: Int
    public var days: Int

    public init(years: Int, months: Int, days: Int) {
      self.years = years
      self.months = months
      self.days = days
    }
  }

  public var personID: UUID
  public var personName: String
  public var calendarKind: BirthdayCalendarKind
  public var birthDate: Date?
  public var birthDuration: BirthDuration?
  public var nextBirthdayDate: Date?
  public var daysUntilNextBirthday: Int?
  public var totalBirthDays: Int?
  public var nextAge: Int?

  public init(
    personID: UUID,
    personName: String,
    calendarKind: BirthdayCalendarKind,
    birthDate: Date?,
    birthDuration: BirthDuration?,
    nextBirthdayDate: Date?,
    daysUntilNextBirthday: Int?,
    totalBirthDays: Int?,
    nextAge: Int?
  ) {
    self.personID = personID
    self.personName = personName
    self.calendarKind = calendarKind
    self.birthDate = birthDate
    self.birthDuration = birthDuration
    self.nextBirthdayDate = nextBirthdayDate
    self.daysUntilNextBirthday = daysUntilNextBirthday
    self.totalBirthDays = totalBirthDays
    self.nextAge = nextAge
  }

  public static func make(
    for person: TrackedPerson,
    referenceDate: Date = .now
  ) -> PersonBirthdaySummary {
    guard let birthday = person.birthday else {
      return PersonBirthdaySummary(
        personID: person.id,
        personName: person.name,
        calendarKind: person.calendarKind,
        birthDate: nil,
        birthDuration: nil,
        nextBirthdayDate: nil,
        daysUntilNextBirthday: nil,
        totalBirthDays: nil,
        nextAge: nil)
    }

    var calendar = birthday.calendarKind.calendar
    calendar.timeZone = .autoupdatingCurrent
    let birthDate = makeBirthDate(for: birthday, calendar: calendar)
    let nextBirthdayDate = BirthdayCalculator.nextOccurrence(for: birthday, after: referenceDate)

    return PersonBirthdaySummary(
      personID: person.id,
      personName: person.name,
      calendarKind: birthday.calendarKind,
      birthDate: birthDate,
      birthDuration: birthDate.map { birthDuration(from: $0, to: referenceDate, calendar: calendar) },
      nextBirthdayDate: nextBirthdayDate,
      daysUntilNextBirthday: nextBirthdayDate.map { daysUntil($0, from: referenceDate, calendar: calendar) },
      totalBirthDays: birthDate.map { totalBirthDays(from: $0, to: referenceDate, calendar: calendar) },
      nextAge: nextBirthdayDate.flatMap { BirthdayCalculator.age(on: $0, for: birthday) })
  }

  private static func makeBirthDate(for birthday: Birthday, calendar: Calendar) -> Date? {
    guard let year = birthday.year else { return nil }

    var components = DateComponents()
    components.calendar = calendar
    components.era = birthday.era
    components.year = year
    components.month = birthday.month
    components.day = birthday.day
    components.hour = 12
    return calendar.date(from: components)
  }

  private static func birthDuration(
    from birthDate: Date,
    to referenceDate: Date,
    calendar: Calendar
  ) -> BirthDuration {
    let birthStart = calendar.startOfDay(for: birthDate)
    let referenceStart = calendar.startOfDay(for: referenceDate)
    guard birthStart <= referenceStart else {
      return BirthDuration(years: 0, months: 0, days: 0)
    }

    let components = calendar.dateComponents([.year, .month, .day], from: birthStart, to: referenceStart)
    return BirthDuration(
      years: max(0, components.year ?? 0),
      months: max(0, components.month ?? 0),
      days: max(0, components.day ?? 0))
  }

  private static func totalBirthDays(
    from birthDate: Date,
    to referenceDate: Date,
    calendar: Calendar
  ) -> Int {
    let birthStart = calendar.startOfDay(for: birthDate)
    let referenceStart = calendar.startOfDay(for: referenceDate)
    guard birthStart <= referenceStart else { return 0 }

    return max(0, calendar.dateComponents([.day], from: birthStart, to: referenceStart).day ?? 0)
  }

  private static func daysUntil(
    _ nextBirthdayDate: Date,
    from referenceDate: Date,
    calendar: Calendar
  ) -> Int {
    let referenceStart = calendar.startOfDay(for: referenceDate)
    let nextStart = calendar.startOfDay(for: nextBirthdayDate)
    return max(0, calendar.dateComponents([.day], from: referenceStart, to: nextStart).day ?? 0)
  }
}
```

- [ ] **Step 4: Run the focused test to verify it passes**

Run:

```bash
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter PersonBirthdaySummaryTests
```

Expected: PASS for `PersonBirthdaySummaryTests`.

- [ ] **Step 5: Commit Task 1**

```bash
git add BirthTrackerPackage/Sources/Models/PersonBirthdaySummary.swift BirthTrackerPackage/Tests/BirthTrackerTests/PersonBirthdaySummaryTests.swift
git commit -m "Add total birth days to birthday summaries" -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 2: Widget Snapshot Support for Age Widgets

**Files:**
- Modify: `BirthTrackerPackage/Sources/Models/WidgetPersonSnapshot.swift`
- Modify: `BirthTrackerPackage/Sources/Persistence/WidgetSnapshotBuilder.swift`
- Modify: `BirthTrackerPackage/Sources/Persistence/WidgetSnapshotStore.swift`
- Modify: `BirthTrackerPackage/Tests/BirthTrackerTests/WidgetSnapshotStoreTests.swift`
- Modify: `Sources/BirthTrackerWidget/UpcomingBirthdaysWidget.swift`

**Interfaces:**
- Consumes: `PersonBirthdaySummary.totalBirthDays: Int?`
- Produces: `WidgetPersonSnapshot.nextBirthdayDate: Date?`
- Produces: `WidgetPersonSnapshot.totalBirthDays: Int?`
- Produces: `WidgetPersonSnapshot.upcomingBirthday: UpcomingBirthday?`
- Later tasks consume: `snapshot.totalBirthDays`, `snapshot.birthDuration`, `snapshot.nextBirthdayDate`

- [ ] **Step 1: Write failing snapshot tests**

Update `BirthTrackerPackage/Tests/BirthTrackerTests/WidgetSnapshotStoreTests.swift` with these changed and new expectations.

```swift
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
```

- [ ] **Step 2: Run the focused tests to verify they fail**

Run:

```bash
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter WidgetSnapshotStoreTests
```

Expected: FAIL with compile errors for `totalBirthDays` and optional `upcomingBirthday` expectations.

- [ ] **Step 3: Update the snapshot model**

Replace the relevant declarations in `BirthTrackerPackage/Sources/Models/WidgetPersonSnapshot.swift` with the code below.

```swift
public enum WidgetSnapshotSchema {
  public static let currentVersion = 3
}

public struct WidgetPersonSnapshot: Equatable, Identifiable, Sendable {
  public var id: UUID { personID }

  /// 对应主数据库人物的业务 ID。
  public var personID: UUID
  /// Widget 中展示的人物名称。
  public var displayName: String
  /// 下一次生日日期；未记录生日时为空。
  public var nextBirthdayDate: Date?
  /// 下一次生日时的年龄；未知出生年份时为空。
  public var age: Int?
  /// 已经出生的年/月/日；未知出生年份时为空。
  public var birthDuration: PersonBirthdaySummary.BirthDuration?
  /// 距离下一次生日的天数。
  public var daysUntilNextBirthday: Int?
  /// 已经出生的总天数；未知出生年份时为空。
  public var totalBirthDays: Int?
  /// 该生日使用的日历系统。
  public var calendarKind: BirthdayCalendarKind
  /// 快照数据结构版本，用于后续兼容升级。
  public var schemaVersion: Int
  /// 快照生成时间。
  public var generatedAt: Date
  /// Widget 展示排序序号。
  public var sortIndex: Int

  public init(
    personID: UUID,
    displayName: String,
    nextBirthdayDate: Date?,
    age: Int?,
    birthDuration: PersonBirthdaySummary.BirthDuration? = nil,
    daysUntilNextBirthday: Int? = nil,
    totalBirthDays: Int? = nil,
    calendarKind: BirthdayCalendarKind,
    schemaVersion: Int = WidgetSnapshotSchema.currentVersion,
    generatedAt: Date,
    sortIndex: Int
  ) {
    self.personID = personID
    self.displayName = displayName
    self.nextBirthdayDate = nextBirthdayDate
    self.age = age
    self.birthDuration = birthDuration
    self.daysUntilNextBirthday = daysUntilNextBirthday
    self.totalBirthDays = totalBirthDays
    self.calendarKind = calendarKind
    self.schemaVersion = schemaVersion
    self.generatedAt = generatedAt
    self.sortIndex = sortIndex
  }

  public init(record: WidgetPersonSnapshotRecord) {
    let birthDuration: PersonBirthdaySummary.BirthDuration?
    switch (record.birthDurationYears, record.birthDurationMonths, record.birthDurationDays) {
    case (let years?, let months?, let days?):
      birthDuration = PersonBirthdaySummary.BirthDuration(years: years, months: months, days: days)
    default:
      birthDuration = nil
    }

    self.init(
      personID: record.personID,
      displayName: record.displayName,
      nextBirthdayDate: record.nextBirthdayDate,
      age: record.age,
      birthDuration: birthDuration,
      daysUntilNextBirthday: record.daysUntilNextBirthday,
      totalBirthDays: record.totalBirthDays,
      calendarKind: BirthdayCalendarKind(rawValue: record.calendarKindRawValue) ?? .gregorian,
      schemaVersion: record.schemaVersion,
      generatedAt: record.generatedAt,
      sortIndex: record.sortIndex)
  }

  public var upcomingBirthday: UpcomingBirthday? {
    guard let nextBirthdayDate else { return nil }

    return UpcomingBirthday(
      id: personID,
      personName: displayName,
      date: nextBirthdayDate,
      age: age,
      calendarKind: calendarKind,
      birthDuration: birthDuration,
      daysUntilNextBirthday: daysUntilNextBirthday)
  }
}
```

Update the record class in the same file.

```swift
@Model
public final class WidgetPersonSnapshotRecord {
  /// 对应主数据库人物的业务 ID。
  public var personID: UUID = UUID()
  /// Widget 中展示的人物名称。
  public var displayName: String = ""
  /// 下一次生日日期；未记录生日时为空。
  public var nextBirthdayDate: Date?
  /// 下一次生日时的年龄；未知出生年份时为空。
  public var age: Int?
  /// 已经出生的年份数；未知出生年份时为空。
  public var birthDurationYears: Int?
  /// 已经出生的月份余数；未知出生年份时为空。
  public var birthDurationMonths: Int?
  /// 已经出生的天数余数；未知出生年份时为空。
  public var birthDurationDays: Int?
  /// 距离下一次生日的天数。
  public var daysUntilNextBirthday: Int?
  /// 已经出生的总天数；未知出生年份时为空。
  public var totalBirthDays: Int?
  /// 生日日历类型原始值，持久化时保存 enum rawValue。
  public var calendarKindRawValue: String = BirthdayCalendarKind.gregorian.rawValue
  /// 快照数据结构版本，用于后续兼容升级。
  public var schemaVersion: Int = WidgetSnapshotSchema.currentVersion
  /// 快照生成时间。
  public var generatedAt: Date = Date()
  /// Widget 展示排序序号。
  public var sortIndex: Int = 0

  public init(snapshot: WidgetPersonSnapshot) {
    personID = snapshot.personID
    displayName = snapshot.displayName
    nextBirthdayDate = snapshot.nextBirthdayDate
    age = snapshot.age
    birthDurationYears = snapshot.birthDuration?.years
    birthDurationMonths = snapshot.birthDuration?.months
    birthDurationDays = snapshot.birthDuration?.days
    daysUntilNextBirthday = snapshot.daysUntilNextBirthday
    totalBirthDays = snapshot.totalBirthDays
    calendarKindRawValue = snapshot.calendarKind.rawValue
    schemaVersion = snapshot.schemaVersion
    generatedAt = snapshot.generatedAt
    sortIndex = snapshot.sortIndex
  }
}
```

- [ ] **Step 4: Update the snapshot builder**

Replace `makeSnapshots` in `BirthTrackerPackage/Sources/Persistence/WidgetSnapshotBuilder.swift` with this implementation.

```swift
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
        birthDuration: summary.birthDuration,
        daysUntilNextBirthday: summary.daysUntilNextBirthday,
        totalBirthDays: summary.totalBirthDays,
        calendarKind: summary.calendarKind,
        generatedAt: referenceDate,
        sortIndex: index)
    }
  }
}
```

- [ ] **Step 5: Update snapshot fetch ordering**

Update `fetchAll` in `BirthTrackerPackage/Sources/Persistence/WidgetSnapshotStore.swift` so it does not sort directly on optional `nextBirthdayDate`.

```swift
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
      SortDescriptor(\.displayName),
    ])
  return try context.fetch(descriptor).map(WidgetPersonSnapshot.init(record:))
}
```

- [ ] **Step 6: Keep the existing upcoming-birthdays Widget focused on birthdays**

Update `Sources/BirthTrackerWidget/UpcomingBirthdaysWidget.swift` so optional `upcomingBirthday` snapshots are filtered out.

```swift
private func loadEntry(for selectedPersonID: UUID?) -> UpcomingBirthdaysEntry {
  do {
    logger.info("load Entry for \(selectedPersonID?.uuidString ?? "nil")")
    if let selectedPersonID {
      guard let snapshot = try WidgetSnapshotStore.fetchPerson(id: selectedPersonID) else {
        return UpcomingBirthdaysEntry(date: .now, birthdays: [], selectedPersonUnavailable: true)
      }

      return UpcomingBirthdaysEntry(
        date: snapshot.generatedAt,
        birthdays: snapshot.upcomingBirthday.map { [$0] } ?? [],
        selectedPersonUnavailable: false)
    }

    let snapshots = try WidgetSnapshotStore.fetchAll()
    return UpcomingBirthdaysEntry(
      date: snapshots.first?.generatedAt ?? .now,
      birthdays: Array(snapshots.compactMap(\.upcomingBirthday).prefix(8)),
      selectedPersonUnavailable: false)
  } catch {
    logger.error("Unable to load upcoming birthdays entry: \(error.localizedDescription)")
    return UpcomingBirthdaysEntry(date: .now, birthdays: [], selectedPersonUnavailable: false)
  }
}
```

- [ ] **Step 7: Run focused tests**

Run:

```bash
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter WidgetSnapshotStoreTests
```

Expected: PASS for `WidgetSnapshotStoreTests`.

- [ ] **Step 8: Commit Task 2**

```bash
git add BirthTrackerPackage/Sources/Models/WidgetPersonSnapshot.swift BirthTrackerPackage/Sources/Persistence/WidgetSnapshotBuilder.swift BirthTrackerPackage/Sources/Persistence/WidgetSnapshotStore.swift BirthTrackerPackage/Tests/BirthTrackerTests/WidgetSnapshotStoreTests.swift Sources/BirthTrackerWidget/UpcomingBirthdaysWidget.swift
git commit -m "Expand widget snapshots for contact age" -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 3: Per-Contact Age Format Preferences

**Files:**
- Create: `BirthTrackerPackage/Sources/Persistence/ContactAgeFormatPreferenceStore.swift`
- Create: `BirthTrackerPackage/Tests/BirthTrackerTests/ContactAgeFormatPreferenceStoreTests.swift`

**Interfaces:**
- Produces: `public enum ContactAgeDisplayFormat: String, CaseIterable, Codable, Sendable`
- Produces: `public struct ContactAgeFormatPreferenceStore`
- Produces: `ContactAgeFormatPreferenceStore.appGroup() throws -> ContactAgeFormatPreferenceStore`
- Produces: `format(for:)`, `setFormat(_:for:)`, `toggleFormat(for:)`, `resetFormat(for:)`
- Later tasks consume: `ContactAgeFormatPreferenceStore.appGroup()`, `ContactAgeDisplayFormat.durationComponents`, `ContactAgeDisplayFormat.totalDays`

- [ ] **Step 1: Write failing preference-store tests**

Create `BirthTrackerPackage/Tests/BirthTrackerTests/ContactAgeFormatPreferenceStoreTests.swift`.

```swift
import Foundation
import Persistence
import Testing

@Suite("Contact age format preference store")
struct ContactAgeFormatPreferenceStoreTests {
  @Test("Store returns duration components by default")
  func storeReturnsDurationComponentsByDefault() throws {
    let fixture = try PreferenceStoreFixture()

    #expect(fixture.store.format(for: UUID()) == .durationComponents)
  }

  @Test("Store persists formats per contact")
  func storePersistsFormatsPerContact() throws {
    let fixture = try PreferenceStoreFixture()
    let firstPersonID = UUID()
    let secondPersonID = UUID()

    fixture.store.setFormat(.totalDays, for: firstPersonID)

    #expect(fixture.store.format(for: firstPersonID) == .totalDays)
    #expect(fixture.store.format(for: secondPersonID) == .durationComponents)
  }

  @Test("Store toggles formats")
  func storeTogglesFormats() throws {
    let fixture = try PreferenceStoreFixture()
    let personID = UUID()

    #expect(fixture.store.toggleFormat(for: personID) == .totalDays)
    #expect(fixture.store.format(for: personID) == .totalDays)
    #expect(fixture.store.toggleFormat(for: personID) == .durationComponents)
    #expect(fixture.store.format(for: personID) == .durationComponents)
  }

  @Test("Store reset returns a contact to the default format")
  func storeResetReturnsAContactToTheDefaultFormat() throws {
    let fixture = try PreferenceStoreFixture()
    let personID = UUID()

    fixture.store.setFormat(.totalDays, for: personID)
    fixture.store.resetFormat(for: personID)

    #expect(fixture.store.format(for: personID) == .durationComponents)
  }
}

private struct PreferenceStoreFixture {
  let suiteName: String
  let defaults: UserDefaults
  let store: ContactAgeFormatPreferenceStore

  init() throws {
    suiteName = "ContactAgeFormatPreferenceStoreTests.\(UUID().uuidString)"
    defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    store = ContactAgeFormatPreferenceStore(userDefaults: defaults)
  }
}
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run:

```bash
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter ContactAgeFormatPreferenceStoreTests
```

Expected: FAIL with compile errors for missing `ContactAgeFormatPreferenceStore` and `ContactAgeDisplayFormat`.

- [ ] **Step 3: Implement the preference store**

Create `BirthTrackerPackage/Sources/Persistence/ContactAgeFormatPreferenceStore.swift`.

```swift
import Foundation

public enum ContactAgeDisplayFormat: String, CaseIterable, Codable, Sendable {
  case durationComponents
  case totalDays

  public var toggled: ContactAgeDisplayFormat {
    switch self {
    case .durationComponents:
      .totalDays
    case .totalDays:
      .durationComponents
    }
  }
}

public struct ContactAgeFormatPreferenceStore {
  public enum StoreError: LocalizedError, Equatable {
    case appGroupUserDefaultsUnavailable(String)

    public var errorDescription: String? {
      switch self {
      case .appGroupUserDefaultsUnavailable(let identifier):
        "Unable to access UserDefaults suite for App Group \(identifier)."
      }
    }
  }

  private let userDefaults: UserDefaults

  public init(userDefaults: UserDefaults) {
    self.userDefaults = userDefaults
  }

  public static func appGroup() throws -> ContactAgeFormatPreferenceStore {
    guard let userDefaults = UserDefaults(suiteName: AppGroup.identifier) else {
      throw StoreError.appGroupUserDefaultsUnavailable(AppGroup.identifier)
    }

    return ContactAgeFormatPreferenceStore(userDefaults: userDefaults)
  }

  public func format(for personID: UUID) -> ContactAgeDisplayFormat {
    guard
      let rawValue = userDefaults.string(forKey: key(for: personID)),
      let format = ContactAgeDisplayFormat(rawValue: rawValue)
    else {
      return .durationComponents
    }

    return format
  }

  public func setFormat(_ format: ContactAgeDisplayFormat, for personID: UUID) {
    userDefaults.set(format.rawValue, forKey: key(for: personID))
  }

  @discardableResult
  public func toggleFormat(for personID: UUID) -> ContactAgeDisplayFormat {
    let newFormat = format(for: personID).toggled
    setFormat(newFormat, for: personID)
    return newFormat
  }

  public func resetFormat(for personID: UUID) {
    userDefaults.removeObject(forKey: key(for: personID))
  }

  private func key(for personID: UUID) -> String {
    "contactAge.displayFormat.\(personID.uuidString)"
  }
}
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter ContactAgeFormatPreferenceStoreTests
```

Expected: PASS for `ContactAgeFormatPreferenceStoreTests`.

- [ ] **Step 5: Commit Task 3**

```bash
git add BirthTrackerPackage/Sources/Persistence/ContactAgeFormatPreferenceStore.swift BirthTrackerPackage/Tests/BirthTrackerTests/ContactAgeFormatPreferenceStoreTests.swift
git commit -m "Add contact age format preferences" -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 4: Contact Age Localization and Widget Kind

**Files:**
- Modify: `BirthTrackerPackage/Sources/Persistence/BirthTrackerWidgetKind.swift`
- Modify: `BirthTrackerPackage/Sources/Localization/L10n.swift`
- Modify: `BirthTrackerPackage/Sources/Localization/Resources/Localizable.xcstrings`

**Interfaces:**
- Produces: `BirthTrackerWidgetKind.contactAge`
- Produces: `L10n.Widget.contactAge`
- Produces: `L10n.Widget.contactAgeDescription`
- Produces: `L10n.Widget.contactAgeChoosePerson`
- Produces: `L10n.Widget.contactAgeNeedsBirthYear`
- Produces: `L10n.Widget.contactAgeTapToSwitch`
- Produces: `L10n.Widget.ageFormatDuration`
- Produces: `L10n.Widget.ageFormatTotalDays`
- Produces: `L10n.Widget.toggleAgeFormat`
- Produces: `L10n.Widget.contactAgeDuration(_:_:_:)`
- Produces: `L10n.Widget.contactAgeTotalDays(_:)`
- Later tasks consume all symbols above in Widget provider/view/intent code.

- [ ] **Step 1: Write a compile-checking expectation by referencing the planned APIs**

Temporarily add the following private function to the bottom of `BirthTrackerPackage/Sources/Localization/L10n.swift`. It intentionally references symbols that do not exist yet.

```swift
private func contactAgeLocalizationCompileCheck() {
  _ = L10n.Widget.contactAge
  _ = L10n.Widget.contactAgeDescription
  _ = L10n.Widget.contactAgeChoosePerson
  _ = L10n.Widget.contactAgeNeedsBirthYear
  _ = L10n.Widget.contactAgeTapToSwitch
  _ = L10n.Widget.ageFormatDuration
  _ = L10n.Widget.ageFormatTotalDays
  _ = L10n.Widget.toggleAgeFormat
  _ = L10n.Widget.contactAgeDuration(1, 2, 3)
  _ = L10n.Widget.contactAgeTotalDays(456)
}
```

Also temporarily add this line inside `BirthTrackerPackage/Sources/Persistence/BirthTrackerWidgetKind.swift` after `upcomingBirthdays` is referenced by existing code:

```swift
private let contactAgeWidgetKindCompileCheck = BirthTrackerWidgetKind.contactAge
```

- [ ] **Step 2: Run package tests to verify the planned APIs are missing**

Run:

```bash
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter ContactAgeFormatPreferenceStoreTests
```

Expected: FAIL with compile errors for missing `L10n.Widget.*` contact-age symbols and `BirthTrackerWidgetKind.contactAge`.

- [ ] **Step 3: Implement Widget kind and L10n APIs, then remove compile-check helpers**

Update `BirthTrackerPackage/Sources/Persistence/BirthTrackerWidgetKind.swift`.

```swift
import Foundation

public enum BirthTrackerWidgetKind {
  public static let upcomingBirthdays = "UpcomingBirthdaysWidget"
  public static let contactAge = "ContactAgeWidget"
}
```

Add these declarations inside `public enum L10n.Widget` in `BirthTrackerPackage/Sources/Localization/L10n.swift`.

```swift
public static let ageFormatDuration = LocalizedStringResource(
  "widget.contact.age.format.duration", bundle: .atURL(Bundle.module.bundleURL))
public static let ageFormatTotalDays = LocalizedStringResource(
  "widget.contact.age.format.total.days", bundle: .atURL(Bundle.module.bundleURL))
public static let contactAge = LocalizedStringResource("Contact Age", bundle: .atURL(Bundle.module.bundleURL))
public static let contactAgeChoosePerson = LocalizedStringResource(
  "Choose a person to show their age.", bundle: .atURL(Bundle.module.bundleURL))
public static let contactAgeDescription = LocalizedStringResource(
  "Track one person's current age. Tap to switch formats.", bundle: .atURL(Bundle.module.bundleURL))
public static let contactAgeNeedsBirthYear = LocalizedStringResource(
  "Add a birth year to show age.", bundle: .atURL(Bundle.module.bundleURL))
public static let contactAgeTapToSwitch = LocalizedStringResource(
  "Tap to switch format", bundle: .atURL(Bundle.module.bundleURL))
public static let noBirthdayRecorded = LocalizedStringResource(
  "No birthday recorded", bundle: .atURL(Bundle.module.bundleURL))
public static let toggleAgeFormat = LocalizedStringResource(
  "Toggle Age Format", bundle: .atURL(Bundle.module.bundleURL))

public static func contactAgeDuration(_ years: Int, _ months: Int, _ days: Int) -> String {
  let format = L10n.string(
    LocalizedStringResource("widget.contact.age.duration.format", bundle: .atURL(Bundle.module.bundleURL)))
  return String.localizedStringWithFormat(format, years, months, days)
}

public static func contactAgeTotalDays(_ days: Int) -> String {
  let format = L10n.string(
    LocalizedStringResource("widget.contact.age.total.days.format", bundle: .atURL(Bundle.module.bundleURL)))
  return String.localizedStringWithFormat(format, days)
}
```

Remove `contactAgeLocalizationCompileCheck` and `contactAgeWidgetKindCompileCheck` after the real declarations exist.

- [ ] **Step 4: Add localized strings**

Add these entries to `BirthTrackerPackage/Sources/Localization/Resources/Localizable.xcstrings` inside the top-level `"strings"` object. Keep valid JSON punctuation around neighboring entries.

```json
"Add a birth year to show age." : {
  "comment" : "Widget empty state when a selected person has a birthday month/day but no birth year, so current age cannot be calculated.",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Add a birth year to show age."
      }
    },
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "添加出生年份以显示年龄。"
      }
    }
  }
},
"Choose a person to show their age." : {
  "comment" : "Contact age Widget empty state before a person is selected.",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Choose a person to show their age."
      }
    },
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "选择联系人以显示年龄。"
      }
    }
  }
},
"Contact Age" : {
  "comment" : "Widget display name and header for showing one person's current age.",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Contact Age"
      }
    },
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "联系人年龄"
      }
    }
  }
},
"Tap to switch format" : {
  "comment" : "Hint shown in the contact age Widget under the tappable age value.",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Tap to switch format"
      }
    },
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "点按切换格式"
      }
    }
  }
},
"Toggle Age Format" : {
  "comment" : "AppIntent title for toggling a contact age Widget between duration and total-days formats.",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Toggle Age Format"
      }
    },
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "切换年龄格式"
      }
    }
  }
},
"Track one person's current age. Tap to switch formats." : {
  "comment" : "Widget gallery description for the contact age Widget.",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Track one person's current age. Tap to switch formats."
      }
    },
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "记录一位联系人的当前年龄，点按即可切换格式。"
      }
    }
  }
},
"widget.contact.age.duration.format" : {
  "comment" : "Contact age Widget duration format. Arguments are years, months, days.",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "%lldy %lldm %lldd"
      }
    },
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "%lld 年 %lld 月 %lld 天"
      }
    }
  }
},
"widget.contact.age.format.duration" : {
  "comment" : "Short label for the year/month/day contact age format.",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Y/M/D"
      }
    },
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "年/月/日"
      }
    }
  }
},
"widget.contact.age.format.total.days" : {
  "comment" : "Short label for the total-days contact age format.",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Days"
      }
    },
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "总天数"
      }
    }
  }
},
"widget.contact.age.total.days.format" : {
  "comment" : "Contact age Widget total-days format. Argument is total day count since birth.",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "%lld days old"
      }
    },
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "出生 %lld 天"
      }
    }
  }
}
```

- [ ] **Step 5: Run focused tests**

Run:

```bash
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter ContactAgeFormatPreferenceStoreTests
```

Expected: PASS for `ContactAgeFormatPreferenceStoreTests` and no package compile errors.

- [ ] **Step 6: Commit Task 4**

```bash
git add BirthTrackerPackage/Sources/Persistence/BirthTrackerWidgetKind.swift BirthTrackerPackage/Sources/Localization/L10n.swift BirthTrackerPackage/Sources/Localization/Resources/Localizable.xcstrings
git commit -m "Add contact age widget localization" -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 5: Contact Age Widget and Tap-to-Toggle Intent

**Files:**
- Create: `Sources/BirthTrackerWidget/ToggleContactAgeFormatIntent.swift`
- Create: `Sources/BirthTrackerWidget/ContactAgeWidget.swift`
- Modify: `Sources/BirthTrackerWidget/BirthTrackerWidgetBundle.swift`

**Interfaces:**
- Consumes: `BirthTrackerWidgetKind.contactAge`
- Consumes: `ContactAgeFormatPreferenceStore.appGroup()`
- Consumes: `ContactAgeDisplayFormat`
- Consumes: `WidgetPersonSnapshot.totalBirthDays`
- Produces: `ToggleContactAgeFormatIntent`
- Produces: `ContactAgeWidget`

- [ ] **Step 1: Create the failing Widget/intent references**

Modify `Sources/BirthTrackerWidget/BirthTrackerWidgetBundle.swift` to register the new Widget before it exists.

```swift
import SwiftUI
import WidgetKit

@main
struct BirthTrackerWidgetBundle: WidgetBundle {
  var body: some Widget {
    UpcomingBirthdaysWidget()
    ContactAgeWidget()
  }
}
```

- [ ] **Step 2: Build the Widget target to verify it fails**

If `BirthTracker.xcodeproj` is missing, run:

```bash
xcodegen generate
```

Use xcodebuildmcp:

```text
1. xcodebuildmcp-session_show_defaults
2. If defaults are missing, call xcodebuildmcp-session_set_defaults with:
   projectPath: /Users/tigerguo/git/copilot-worktrees/BirthTracker/huahuahu-ubiquitous-meme/BirthTracker.xcodeproj
   scheme: BirthTracker
   simulatorName: birth tracker 17 pro
   simulatorId: F4B82181-8A72-4AC3-9C95-454DE83A0C62
3. xcodebuildmcp-build_sim with extraArgs: []
```

Expected: FAIL with a compile error for missing `ContactAgeWidget`.

- [ ] **Step 3: Implement the toggle AppIntent**

Create `Sources/BirthTrackerWidget/ToggleContactAgeFormatIntent.swift`.

```swift
import AppIntents
import Foundation
import Localization
import Persistence
import WidgetKit

enum ToggleContactAgeFormatIntentError: LocalizedError {
  case invalidPersonID(String)

  var errorDescription: String? {
    switch self {
    case .invalidPersonID(let value):
      "Invalid person ID for contact age format toggle: \(value)"
    }
  }
}

struct ToggleContactAgeFormatIntent: AppIntent {
  static let title = L10n.Widget.toggleAgeFormat

  @Parameter(title: "Person ID")
  var personID: String

  init() {}

  init(personID: UUID) {
    self.personID = personID.uuidString
  }

  func perform() async throws -> some IntentResult {
    guard let personID = UUID(uuidString: personID) else {
      throw ToggleContactAgeFormatIntentError.invalidPersonID(personID)
    }

    let store = try ContactAgeFormatPreferenceStore.appGroup()
    store.toggleFormat(for: personID)
    WidgetCenter.shared.reloadTimelines(ofKind: BirthTrackerWidgetKind.contactAge)
    return .result()
  }
}
```

- [ ] **Step 4: Implement the contact age Widget**

Create `Sources/BirthTrackerWidget/ContactAgeWidget.swift`.

```swift
import AppIntents
import Foundation
import Localization
import Models
import Persistence
import SFSafeSymbols
import SwiftUI
import WidgetKit

struct ContactAgeEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetPersonSnapshot?
  let displayFormat: ContactAgeDisplayFormat
  let selectedPersonUnavailable: Bool
}

struct ContactAgeProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> ContactAgeEntry {
    ContactAgeEntry(
      date: .now,
      snapshot: WidgetPersonSnapshot(
        personID: UUID(),
        displayName: "Taylor",
        nextBirthdayDate: .now.addingTimeInterval(86_400),
        age: 3,
        birthDuration: PersonBirthdaySummary.BirthDuration(years: 2, months: 3, days: 4),
        daysUntilNextBirthday: 120,
        totalBirthDays: 825,
        calendarKind: .gregorian,
        generatedAt: .now,
        sortIndex: 0),
      displayFormat: .durationComponents,
      selectedPersonUnavailable: false)
  }

  func snapshot(for configuration: SelectPersonIntent, in context: Context) async -> ContactAgeEntry {
    loadEntry(for: configuration.person?.id)
  }

  func timeline(for configuration: SelectPersonIntent, in context: Context) async -> Timeline<ContactAgeEntry> {
    let entry = loadEntry(for: configuration.person?.id)
    let refreshDate = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now.addingTimeInterval(21_600)
    return Timeline(entries: [entry], policy: .after(refreshDate))
  }

  private func loadEntry(for selectedPersonID: UUID?) -> ContactAgeEntry {
    guard let selectedPersonID else {
      return ContactAgeEntry(
        date: .now,
        snapshot: nil,
        displayFormat: .durationComponents,
        selectedPersonUnavailable: false)
    }

    do {
      guard let snapshot = try WidgetSnapshotStore.fetchPerson(id: selectedPersonID) else {
        return ContactAgeEntry(
          date: .now,
          snapshot: nil,
          displayFormat: .durationComponents,
          selectedPersonUnavailable: true)
      }

      let formatStore = try ContactAgeFormatPreferenceStore.appGroup()
      return ContactAgeEntry(
        date: snapshot.generatedAt,
        snapshot: snapshot,
        displayFormat: formatStore.format(for: selectedPersonID),
        selectedPersonUnavailable: false)
    } catch {
      logger.error("Unable to load contact age entry: \(error.localizedDescription)")
      return ContactAgeEntry(
        date: .now,
        snapshot: nil,
        displayFormat: .durationComponents,
        selectedPersonUnavailable: false)
    }
  }
}

struct ContactAgeWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: BirthTrackerWidgetKind.contactAge,
      intent: SelectPersonIntent.self,
      provider: ContactAgeProvider()
    ) { entry in
      ContactAgeWidgetView(entry: entry)
        .containerBackground(.background, for: .widget)
    }
    .configurationDisplayName(L10n.Widget.contactAge)
    .description(L10n.Widget.contactAgeDescription)
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

private struct ContactAgeWidgetView: View {
  @Environment(\.widgetFamily)
  private var family

  let entry: ContactAgeEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(L10n.Widget.contactAge, systemImage: SFSymbol.clock.rawValue)
        .font(.headline)

      if entry.selectedPersonUnavailable {
        message(L10n.string(L10n.Widget.selectedPersonUnavailable))
      } else if let snapshot = entry.snapshot {
        snapshotContent(snapshot)
      } else {
        message(L10n.string(L10n.Widget.contactAgeChoosePerson))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  @ViewBuilder
  private func snapshotContent(_ snapshot: WidgetPersonSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(snapshot.displayName)
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)

      if snapshot.nextBirthdayDate == nil {
        message(L10n.string(L10n.Widget.noBirthdayRecorded))
      } else if let ageText = ageText(for: snapshot) {
        Button(intent: ToggleContactAgeFormatIntent(personID: snapshot.personID)) {
          VStack(alignment: .leading, spacing: 4) {
            Text(ageText)
              .font(family == .systemSmall ? .title3.bold() : .title.bold())
              .monospacedDigit()
              .lineLimit(2)
              .minimumScaleFactor(0.7)
            Text(formatLabel)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)

        if family == .systemMedium {
          if let days = snapshot.daysUntilNextBirthday {
            Text(L10n.PersonDetail.daysUntilBirthday(days))
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Text(L10n.Widget.contactAgeTapToSwitch)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      } else {
        message(L10n.string(L10n.Widget.contactAgeNeedsBirthYear))
      }
    }
  }

  private func ageText(for snapshot: WidgetPersonSnapshot) -> String? {
    switch entry.displayFormat {
    case .durationComponents:
      guard let duration = snapshot.birthDuration else { return nil }
      return L10n.Widget.contactAgeDuration(duration.years, duration.months, duration.days)
    case .totalDays:
      guard let totalBirthDays = snapshot.totalBirthDays else { return nil }
      return L10n.Widget.contactAgeTotalDays(totalBirthDays)
    }
  }

  private var formatLabel: LocalizedStringResource {
    switch entry.displayFormat {
    case .durationComponents:
      L10n.Widget.ageFormatDuration
    case .totalDays:
      L10n.Widget.ageFormatTotalDays
    }
  }

  private func message(_ text: String) -> some View {
    Text(text)
      .font(.caption)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
  }
}

#Preview("duration small", as: .systemSmall) {
  ContactAgeWidget()
} timeline: {
  ContactAgeEntry(
    date: .now,
    snapshot: WidgetPersonSnapshot(
      personID: UUID(),
      displayName: "Taylor",
      nextBirthdayDate: .now.addingTimeInterval(86_400),
      age: 3,
      birthDuration: PersonBirthdaySummary.BirthDuration(years: 2, months: 3, days: 4),
      daysUntilNextBirthday: 120,
      totalBirthDays: 825,
      calendarKind: .gregorian,
      generatedAt: .now,
      sortIndex: 0),
    displayFormat: .durationComponents,
    selectedPersonUnavailable: false)
}

#Preview("days medium", as: .systemMedium) {
  ContactAgeWidget()
} timeline: {
  ContactAgeEntry(
    date: .now,
    snapshot: WidgetPersonSnapshot(
      personID: UUID(),
      displayName: "Taylor",
      nextBirthdayDate: .now.addingTimeInterval(86_400),
      age: 3,
      birthDuration: PersonBirthdaySummary.BirthDuration(years: 2, months: 3, days: 4),
      daysUntilNextBirthday: 120,
      totalBirthDays: 825,
      calendarKind: .gregorian,
      generatedAt: .now,
      sortIndex: 0),
    displayFormat: .totalDays,
    selectedPersonUnavailable: false)
}

#Preview("missing year", as: .systemSmall) {
  ContactAgeWidget()
} timeline: {
  ContactAgeEntry(
    date: .now,
    snapshot: WidgetPersonSnapshot(
      personID: UUID(),
      displayName: "Jordan",
      nextBirthdayDate: .now.addingTimeInterval(86_400),
      age: nil,
      calendarKind: .gregorian,
      generatedAt: .now,
      sortIndex: 0),
    displayFormat: .durationComponents,
    selectedPersonUnavailable: false)
}
```

- [ ] **Step 5: Build the app target**

If `BirthTracker.xcodeproj` is missing, run:

```bash
xcodegen generate
```

Use xcodebuildmcp:

```text
1. xcodebuildmcp-session_show_defaults
2. If defaults are missing, call xcodebuildmcp-session_set_defaults with:
   projectPath: /Users/tigerguo/git/copilot-worktrees/BirthTracker/huahuahu-ubiquitous-meme/BirthTracker.xcodeproj
   scheme: BirthTracker
   simulatorName: birth tracker 17 pro
   simulatorId: F4B82181-8A72-4AC3-9C95-454DE83A0C62
3. xcodebuildmcp-build_sim with extraArgs: []
```

Expected: Build succeeds for `BirthTracker` and embedded `BirthTrackerWidget`.

- [ ] **Step 6: Preview the contact age Widget**

Use xcodebuildmcp to preview the Widget visually after the build succeeds.

```text
1. xcodebuildmcp-open_sim
2. xcodebuildmcp-screenshot with returnFormat: path
3. If the active tooling can add or focus the Widget on the simulator home screen, show `ContactAgeWidget` in both `durationComponents` and `totalDays` states and capture screenshots.
4. If the active tooling cannot insert a Widget into the home screen, use the Widget SwiftUI previews as the visual source of truth, keep the Xcode build evidence from Step 5, capture the best available simulator screenshot, and write the limitation in the Task 5 report.
```

Expected: The Task 5 report includes screenshot path(s) or a clear limitation explaining why a real home-screen Widget preview could not be captured with available tooling.

- [ ] **Step 7: Commit Task 5**

```bash
git add Sources/BirthTrackerWidget/ToggleContactAgeFormatIntent.swift Sources/BirthTrackerWidget/ContactAgeWidget.swift Sources/BirthTrackerWidget/BirthTrackerWidgetBundle.swift
git commit -m "Add contact age widget" -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 6: Architecture Documentation and Full Verification

**Files:**
- Modify: `doc/architecture/current-architecture.md`

**Interfaces:**
- Consumes all prior tasks.
- Produces updated architecture facts for Widget data flow and contact-age display-format preferences.

- [ ] **Step 1: Update architecture documentation**

In `doc/architecture/current-architecture.md`, update the Widgets section to include these facts.

```markdown
- App 将主 SwiftData 数据库中的人物转换成扁平快照，并写入 App Group 中独立的 Widget SwiftData store；该快照包含有生日和无生日联系人，生日列表 Widget 会过滤没有下一次生日的快照。
- App 和 Widget 通过 `PersonBirthdaySummary` 共享“已经出生多久”“已经出生总天数”“距离下次生日”等生日摘要语义；Widget 仍只读取扁平快照字段，不复用 App 的 SwiftUI 详情页。
- Widget extension 使用 `AppIntentConfiguration` 支持每个小组件实例选择一个联系人。
- 联系人年龄 Widget 使用交互式 AppIntent 切换显示格式，格式偏好按联系人 ID 保存在 App Group `UserDefaults` 中；同一联系人对应的多个年龄 Widget 会共享该格式。
- Widget store 是派生缓存，不启用 CloudKit，不替代主数据库。
```

- [ ] **Step 2: Run the full Swift package tests**

Run:

```bash
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage
```

Expected: PASS for all Swift package tests.

- [ ] **Step 3: Run repository checks**

Run:

```bash
make check
```

Expected: all scripts and linters complete successfully.

- [ ] **Step 4: Run final Xcode build**

If `BirthTracker.xcodeproj` is missing, run:

```bash
xcodegen generate
```

Use xcodebuildmcp:

```text
1. xcodebuildmcp-session_show_defaults
2. If defaults are missing, call xcodebuildmcp-session_set_defaults with:
   projectPath: /Users/tigerguo/git/copilot-worktrees/BirthTracker/huahuahu-ubiquitous-meme/BirthTracker.xcodeproj
   scheme: BirthTracker
   simulatorName: birth tracker 17 pro
   simulatorId: F4B82181-8A72-4AC3-9C95-454DE83A0C62
3. xcodebuildmcp-build_sim with extraArgs: []
```

Expected: Build succeeds for the app and Widget extension.

- [ ] **Step 5: Inspect git status**

Run:

```bash
git --no-pager status --short
```

Expected: only `doc/architecture/current-architecture.md` is modified before the final commit, plus any generated ignored files not shown by git.

- [ ] **Step 6: Commit Task 6**

```bash
git add doc/architecture/current-architecture.md
git commit -m "Document contact age widget architecture" -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```
