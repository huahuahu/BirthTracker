import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
  case system
  case light
  case dark

  var id: String { rawValue }

  var title: String {
    switch self {
    case .system: "Follow System"
    case .light: "Light"
    case .dark: "Dark"
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}

enum AppSettingsKey {
  static let appearanceMode = "settings.appearanceMode"
  static let enabledCalendarKinds = "settings.enabledCalendarKinds"
  static let storageMode = "settings.storageMode"
}

extension BirthdayCalendarKind {
  static let defaultSelectionKinds: [BirthdayCalendarKind] = [.gregorian]

  static func selectionKinds(from rawValue: String) -> [BirthdayCalendarKind] {
    let selectedKinds =
      rawValue
      .split(separator: ",")
      .compactMap { BirthdayCalendarKind(rawValue: String($0)) }

    return selectedKinds.isEmpty ? defaultSelectionKinds : selectedKinds
  }

  static func rawSelectionKinds(_ kinds: [BirthdayCalendarKind]) -> String {
    kinds.map(\.rawValue).joined(separator: ",")
  }
}
