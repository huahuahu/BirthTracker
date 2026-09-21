import AppIntents
import Foundation
import Logging
import Models
import Persistence

enum ToggleContactAgeFormatIntentError: LocalizedError {
  case invalidConfiguredFormat(String)

  var errorDescription: String? {
    switch self {
    case .invalidConfiguredFormat(let value):
      "Invalid configured contact age format: \(value)"
    }
  }
}

public struct ToggleContactAgeFormatIntent: AppIntent {
  public static let title = LocalizedStringResource(
    "Toggle Age Format",
    table: "Intents")
  public static let isDiscoverable = false

  @Parameter(title: LocalizedStringResource("Widget ID", table: "Intents"))
  public var stateID: String

  @Parameter(title: LocalizedStringResource("Age Format", table: "Intents"))
  public var configuredFormat: String

  public init() {}

  public init(
    stateID: String,
    configuredFormat: ContactAgeDisplayFormat
  ) {
    self.stateID = stateID
    self.configuredFormat = configuredFormat.rawValue
  }

  public func perform() async throws -> some IntentResult {
    let rawConfiguredFormat = configuredFormat
    guard let configuredFormat = ContactAgeDisplayFormat(rawValue: rawConfiguredFormat) else {
      throw ToggleContactAgeFormatIntentError.invalidConfiguredFormat(rawConfiguredFormat)
    }

    let store = try ContactAgeFormatPreferenceStore.appGroup()
    let selectedFormat = try store.toggleFormat(
      for: stateID,
      configuredFormat: configuredFormat)
    BirthLogger.widget.info(
      "Toggled contact age format.",
      tags: [.persistence],
      values: [
        .private(stateID),
        .public("configured-format=\(configuredFormat.rawValue)"),
        .public("selected-format=\(selectedFormat.rawValue)"),
      ])
    return .result()
  }
}
