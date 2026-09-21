public enum ContactAgeDisplayFormat: String, CaseIterable, Codable, Sendable {
  case yearMonthDay
  case monthDay
  case day

  public var toggled: ContactAgeDisplayFormat {
    switch self {
    case .yearMonthDay:
      .monthDay
    case .monthDay:
      .day
    case .day:
      .yearMonthDay
    }
  }
}
