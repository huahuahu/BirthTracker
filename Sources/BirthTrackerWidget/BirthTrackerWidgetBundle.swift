import AppIntents
import BirthTrackerWidgetIntents
import BirthTrackerWidgets
import SwiftUI
import WidgetKit

struct BirthTrackerWidgetExtensionAppIntentsPackage: AppIntentsPackage {
  static var includedPackages: [any AppIntentsPackage.Type] {
    [BirthTrackerWidgetIntentsAppIntentsPackage.self]
  }
}

@main
struct BirthTrackerWidgetBundle: WidgetBundle {
  var body: some Widget {
    BirthTrackerWidgetsBundle().body
  }
}
