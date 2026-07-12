import SwiftUI
import WidgetKit

public struct BirthTrackerWidgetsBundle: WidgetBundle {
  public init() {}

  public var body: some Widget {
    UpcomingBirthdaysWidget()
    ContactAgeWidget()
  }
}
