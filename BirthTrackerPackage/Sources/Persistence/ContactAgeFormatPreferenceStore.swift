import Foundation
import Models

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

  private struct StoredPreference: Codable {
    let configuredFormat: ContactAgeDisplayFormat
    let selectedFormat: ContactAgeDisplayFormat
  }

  private let userDefaults: UserDefaults
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  public init(userDefaults: UserDefaults) {
    self.userDefaults = userDefaults
  }

  public static func appGroup() throws -> ContactAgeFormatPreferenceStore {
    guard let userDefaults = UserDefaults(suiteName: AppGroup.identifier) else {
      throw StoreError.appGroupUserDefaultsUnavailable(AppGroup.identifier)
    }

    return ContactAgeFormatPreferenceStore(userDefaults: userDefaults)
  }

  public func format(
    for stateID: String,
    configuredFormat: ContactAgeDisplayFormat
  ) -> ContactAgeDisplayFormat {
    guard
      let data = userDefaults.data(forKey: key(for: stateID)),
      let preference = try? decoder.decode(StoredPreference.self, from: data)
    else {
      return configuredFormat
    }

    // Age format is no longer editable configuration. A saved tap selection is
    // authoritative even if WidgetKit drops the old hidden initial-format value.
    return preference.selectedFormat
  }

  @discardableResult
  public func toggleFormat(
    for stateID: String,
    configuredFormat: ContactAgeDisplayFormat
  ) throws -> ContactAgeDisplayFormat {
    let selectedFormat = format(
      for: stateID,
      configuredFormat: configuredFormat
    ).toggled
    let preference = StoredPreference(
      configuredFormat: configuredFormat,
      selectedFormat: selectedFormat)
    userDefaults.set(try encoder.encode(preference), forKey: key(for: stateID))
    return selectedFormat
  }

  public func resetFormat(for stateID: String) {
    userDefaults.removeObject(forKey: key(for: stateID))
  }

  private func key(for stateID: String) -> String {
    "contactAge.displayFormat.v2.\(stateID)"
  }
}
