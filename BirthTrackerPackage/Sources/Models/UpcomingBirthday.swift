import Foundation

public struct UpcomingBirthday: Codable, Identifiable, Equatable, Sendable {
  /// 对应人物的业务 ID。
  public var id: UUID
  /// 生日列表中展示的人物名称。
  public var personName: String
  /// 下一次生日日期。
  public var date: Date
  /// 下一次生日时的年龄；未知出生年份时为空。
  public var age: Int?
  /// 该生日使用的日历系统。
  public var calendarKind: BirthdayCalendarKind

  public init(id: UUID, personName: String, date: Date, age: Int?, calendarKind: BirthdayCalendarKind) {
    self.id = id
    self.personName = personName
    self.date = date
    self.age = age
    self.calendarKind = calendarKind
  }
}
