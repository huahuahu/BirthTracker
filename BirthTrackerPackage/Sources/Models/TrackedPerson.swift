import Foundation
import SwiftData

@Model
public final class TrackedPerson {
  /// 人物的稳定业务标识，用于跨模块引用同一个人。
  public private(set) var id: UUID = UUID()
  /// 人物显示名称。
  public var name: String = ""
  /// 用户记录的备注内容。
  public var notes: String = ""
  /// 人物生日；这是 SwiftData relationship，可以从 Birthday.person 反查所属人物。
  /// 删除人物会级联删除生日；删除生日只会清空这里，不会删除人物。
  @Relationship(deleteRule: .cascade, inverse: \Birthday.person)
  public var birthday: Birthday?
  /// 记录创建时间。
  public var createdAt: Date = Date()
  /// 记录最后更新时间，需要由写入逻辑显式维护。
  public var updatedAt: Date = Date()

  public init(id: UUID = UUID(), name: String, birthday: Birthday? = nil, notes: String = "") {
    self.id = id
    self.name = name
    self.notes = notes
    self.birthday = birthday
    birthday?.person = self
  }
}

extension TrackedPerson {
  public var calendarKind: BirthdayCalendarKind {
    birthday?.calendarKind ?? .gregorian
  }

  public func upcomingBirthday(after referenceDate: Date = .now) -> UpcomingBirthday? {
    guard let birthday, let nextDate = BirthdayCalculator.nextOccurrence(for: birthday, after: referenceDate) else {
      return nil
    }

    return UpcomingBirthday(
      id: id,
      personName: name,
      date: nextDate,
      age: BirthdayCalculator.age(on: nextDate, for: birthday),
      calendarKind: calendarKind
    )
  }
}
