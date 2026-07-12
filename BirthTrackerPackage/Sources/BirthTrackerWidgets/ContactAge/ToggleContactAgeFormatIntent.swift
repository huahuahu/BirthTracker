import AppIntents
import Foundation
import Persistence
import WidgetKit

enum ToggleContactAgeFormatIntentError: LocalizedError {
  case invalidPersonID(String)

  var errorDescription: String? {
    switch self {
    case .invalidPersonID(let value):
      "Invalid person ID for contact age format toggle: \(value)"
    }
  }
}

struct ToggleContactAgeFormatIntent: AppIntent {
  static let title = LocalizedStringResource("Toggle Age Format", table: "Intents", bundle: .main)

  @Parameter(title: LocalizedStringResource("Person ID", table: "Intents", bundle: .main))
  var personID: String

  init() {}

  init(personID: UUID) {
    self.personID = personID.uuidString
  }

  func perform() async throws -> some IntentResult {
    guard let personID = UUID(uuidString: personID) else {
      throw ToggleContactAgeFormatIntentError.invalidPersonID(personID)
    }

    let store = try ContactAgeFormatPreferenceStore.appGroup()
    store.toggleFormat(for: personID)
    WidgetCenter.shared.reloadTimelines(ofKind: BirthTrackerWidgetKind.contactAge)
    return .result()
  }
}
