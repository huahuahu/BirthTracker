import Models
import SwiftUI

public enum AppearanceMode: String, CaseIterable, Identifiable {
  case system
  case light
  case dark

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .system: "Follow System"
    case .light: "Light"
    case .dark: "Dark"
    }
  }

  public var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}

public enum AppSettingsKey {
  public static let appearanceMode = "settings.appearanceMode"
  public static let enabledCalendarKinds = "settings.enabledCalendarKinds"
  public static let storageMode = "settings.storageMode"
}

extension BirthdayCalendarKind {
  public static let defaultSelectionKinds: [BirthdayCalendarKind] = [.gregorian]

  public static func selectionKinds(from rawValue: String) -> [BirthdayCalendarKind] {
    let selectedKinds =
      rawValue
      .split(separator: ",")
      .compactMap { BirthdayCalendarKind(rawValue: String($0)) }

    return selectedKinds.isEmpty ? defaultSelectionKinds : selectedKinds
  }

  public static func rawSelectionKinds(_ kinds: [BirthdayCalendarKind]) -> String {
    kinds.map(\.rawValue).joined(separator: ",")
  }
}
