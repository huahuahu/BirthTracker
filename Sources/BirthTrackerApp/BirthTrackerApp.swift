import App
import BirthTrackerWidgetIntents
import DesignSystem
import SwiftUI

@main
struct BirthTrackerApp: App {
  @AppStorage(AppSettingsKey.appearanceMode)
  private var appearanceMode = AppearanceMode.system.rawValue

  init() {
    _ = BirthTrackerWidgetIntentsAppIntentsPackage.self
    _ = SelectPersonIntent.self
    _ = SelectUpcomingBirthdaysIntent.self
  }

  var body: some Scene {
    WindowGroup {
      BirthTrackerRootView()
        .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
    }
  }
}
