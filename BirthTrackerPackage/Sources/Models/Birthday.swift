import Foundation
import SwiftData

/// 生日模型，保存生日日期，并通过 person 关联到所属人物。
@Model
public final class Birthday: Equatable {
  /// 生日采用的日历系统原始值，持久化时保存 enum rawValue。
  public var calendarKindRawValue: String = BirthdayCalendarKind.gregorian.rawValue
  /// 日历纪元，例如公历 AD；没有该信息时为空。
  public var era: Int?
  /// 出生年份；只记录月日时为空。
  public var year: Int?
  /// 生日月份；Birthday 表示可计算提醒日期的生日，因此月日必须存在。
  public var month: Int = 1
  /// 生日日期；未知生日应由持有方使用可选 Birthday 表示。
  public var day: Int = 1
  /// 拥有这个生日的人；删除生日只会清空人物的 birthday，不会删除人物。
  public var person: TrackedPerson?

  public init(calendarKind: BirthdayCalendarKind, era: Int? = nil, year: Int? = nil, month: Int, day: Int) {
    self.calendarKindRawValue = calendarKind.rawValue
    self.era = era
    self.year = year
    self.month = month
    self.day = day
  }

  public convenience init(date: Date, calendarKind: BirthdayCalendarKind) {
    let calendar = calendarKind.calendar
    let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
    self.init(
      calendarKind: calendarKind,
      era: components.era,
      year: components.year,
      month: components.month ?? 1,
      day: components.day ?? 1
    )
  }

  public static func == (lhs: Birthday, rhs: Birthday) -> Bool {
    lhs.calendarKind == rhs.calendarKind
      && lhs.era == rhs.era
      && lhs.year == rhs.year
      && lhs.month == rhs.month
      && lhs.day == rhs.day
  }
}

extension Birthday {
  public var calendarKind: BirthdayCalendarKind {
    get { BirthdayCalendarKind(rawValue: calendarKindRawValue) ?? .gregorian }
    set { calendarKindRawValue = newValue.rawValue }
  }
}
