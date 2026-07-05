import Foundation
import SwiftData

public enum WidgetSnapshotSchema {
  public static let currentVersion = 1
}

public struct WidgetPersonSnapshot: Equatable, Identifiable, Sendable {
  public var id: UUID { personID }

  /// 对应主数据库人物的业务 ID。
  public var personID: UUID
  /// Widget 中展示的人物名称。
  public var displayName: String
  /// 下一次生日日期。
  public var nextBirthdayDate: Date
  /// 下一次生日时的年龄；未知出生年份时为空。
  public var age: Int?
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
  /// 对应主数据库人物的业务 ID。
  public var personID: UUID = UUID()
  /// Widget 中展示的人物名称。
  public var displayName: String = ""
  /// 下一次生日日期。
  public var nextBirthdayDate: Date = Date()
  /// 下一次生日时的年龄；未知出生年份时为空。
  public var age: Int?
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
    calendarKindRawValue = snapshot.calendarKind.rawValue
    schemaVersion = snapshot.schemaVersion
    generatedAt = snapshot.generatedAt
    sortIndex = snapshot.sortIndex
  }
}
