import App
import DesignSystem
import SwiftUI

@main
struct BirthTrackerApp: App {
  @AppStorage(AppSettingsKey.appearanceMode) private var appearanceMode = AppearanceMode.system.rawValue

  var body: some Scene {
    WindowGroup {
      BirthTrackerRootView()
        .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
    }
  }
}
