import BirthTrackerWidgets
import SwiftUI
import WidgetKit

@main
struct BirthTrackerWidgetBundle: WidgetBundle {
  var body: some Widget {
    UpcomingBirthdaysWidget()
    ContactAgeWidget()
  }
}
