import Foundation
import SwiftData

public enum WidgetSnapshotSchema {
  public static let currentVersion = 4
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
  /// 完整出生日期；未知出生年份时为空。
  public var birthDate: Date?
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
    birthDate: Date? = nil,
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
    self.birthDate = birthDate
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
      birthDate: record.birthDate,
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
  /// 完整出生日期；未知出生年份时为空。
  public var birthDate: Date?
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
    birthDate = snapshot.birthDate
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
