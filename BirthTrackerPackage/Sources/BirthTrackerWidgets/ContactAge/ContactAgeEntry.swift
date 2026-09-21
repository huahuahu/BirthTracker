import Foundation
import Models
import WidgetKit

struct ContactAgeEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetPersonSnapshot?
  let displayCalendarKind: BirthdayCalendarKind?
  let stateID: String?
  let configuredDisplayFormat: ContactAgeDisplayFormat
  let displayFormat: ContactAgeDisplayFormat
  let selectedPersonUnavailable: Bool
}
