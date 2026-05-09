import DesignSystem
import Foundation
import Localization
import Models
import Persistence

extension AppearanceMode {
  var localizedTitle: LocalizedStringResource {
    switch self {
    case .system: L10n.Appearance.system
    case .light: L10n.Appearance.light
    case .dark: L10n.Appearance.dark
    }
  }
}

extension BirthdayCalendarKind {
  var localizedTitle: LocalizedStringResource {
    switch self {
    case .gregorian: L10n.CalendarKind.gregorian
    case .buddhist: L10n.CalendarKind.buddhist
    case .chinese: L10n.CalendarKind.chinese
    case .hebrew: L10n.CalendarKind.hebrew
    case .islamicUmmAlQura: L10n.CalendarKind.islamic
    }
  }
}

extension DebugStorageMode {
  var localizedTitle: LocalizedStringResource {
    switch self {
    case .memory: L10n.DebugStorage.memory
    case .local: L10n.DebugStorage.local
    case .cloud: L10n.DebugStorage.cloud
    }
  }
}
