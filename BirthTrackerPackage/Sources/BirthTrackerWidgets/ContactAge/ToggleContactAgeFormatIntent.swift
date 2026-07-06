import AppIntents
import Foundation
import Localization
import Models
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
  static let title: LocalizedStringResource = "Toggle Age Format"

  @Parameter(title: "Person ID")
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
    store.toggleFormat(
      for: personID,
      availableFormats: try availableDisplayFormats(for: personID))
    WidgetCenter.shared.reloadTimelines(ofKind: BirthTrackerWidgetKind.contactAge)
    return .result()
  }

  private func availableDisplayFormats(for personID: UUID) throws -> [ContactAgeDisplayFormat] {
    guard
      let snapshot = try WidgetSnapshotStore.fetchPerson(id: personID),
      let metrics = ContactAgeSnapshotMetrics.make(snapshot: snapshot, referenceDate: .now)
    else {
      return ContactAgeDisplayFormat.allCases
    }

    return metrics.availableDisplayFormats
  }
}
