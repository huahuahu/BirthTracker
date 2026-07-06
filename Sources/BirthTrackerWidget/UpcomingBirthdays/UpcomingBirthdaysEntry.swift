import Foundation
import Models
import WidgetKit

struct UpcomingBirthdaysEntry: TimelineEntry {
  let date: Date
  let birthdays: [UpcomingBirthday]
  let selectedPersonUnavailable: Bool
}
