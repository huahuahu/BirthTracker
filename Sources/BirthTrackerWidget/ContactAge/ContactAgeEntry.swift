import Foundation
import Models
import Persistence
import WidgetKit

struct ContactAgeEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetPersonSnapshot?
  let displayFormat: ContactAgeDisplayFormat
  let selectedPersonUnavailable: Bool
}
