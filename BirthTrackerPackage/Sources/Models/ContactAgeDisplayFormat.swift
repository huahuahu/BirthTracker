public enum ContactAgeDisplayFormat: String, CaseIterable, Codable, Sendable {
  case yearMonthDay
  case monthDay
  case day

  public var toggled: ContactAgeDisplayFormat {
    next(in: Self.allCases)
  }

  public func resolved(in availableFormats: [ContactAgeDisplayFormat]) -> ContactAgeDisplayFormat {
    let formats = Self.normalizedAvailableFormats(availableFormats)
    return formats.contains(self) ? self : formats[0]
  }

  public func next(in availableFormats: [ContactAgeDisplayFormat]) -> ContactAgeDisplayFormat {
    let formats = Self.normalizedAvailableFormats(availableFormats)
    let currentFormat = resolved(in: formats)

    guard let currentIndex = formats.firstIndex(of: currentFormat) else {
      return currentFormat
    }

    let nextIndex = formats.index(after: currentIndex)
    return formats[nextIndex == formats.endIndex ? formats.startIndex : nextIndex]
  }

  public static func stored(rawValue: String) -> ContactAgeDisplayFormat? {
    if let format = ContactAgeDisplayFormat(rawValue: rawValue) {
      return format
    }

    switch rawValue {
    case "durationComponents":
      return .yearMonthDay
    case "totalDays":
      return .day
    default:
      return nil
    }
  }

  private static func normalizedAvailableFormats(
    _ availableFormats: [ContactAgeDisplayFormat]
  ) -> [ContactAgeDisplayFormat] {
    availableFormats.isEmpty ? [.day] : availableFormats
  }
}
