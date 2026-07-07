import Foundation

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

  static func stored(rawValue: String) -> ContactAgeDisplayFormat? {
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
      let format = ContactAgeDisplayFormat.stored(rawValue: rawValue)
    else {
      return .yearMonthDay
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
