import App
import AppIntents
import BirthTrackerWidgetIntents
import DesignSystem
import SwiftUI

struct BirthTrackerAppIntentsPackage: AppIntentsPackage {
  static var includedPackages: [any AppIntentsPackage.Type] {
    [BirthTrackerWidgetIntentsAppIntentsPackage.self]
  }
}

@main
struct BirthTrackerApp: App {
  @AppStorage(AppSettingsKey.appearanceMode)
  private var appearanceMode = AppearanceMode.system.rawValue

  var body: some Scene {
    WindowGroup {
      BirthTrackerRootView()
        .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
    }
  }
}
