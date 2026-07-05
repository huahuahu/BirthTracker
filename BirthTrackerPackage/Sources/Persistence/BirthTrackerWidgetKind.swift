import Foundation

public enum BirthTrackerWidgetKind {
  public static let upcomingBirthdays = "UpcomingBirthdaysWidget"
  public static let contactAge = "ContactAgeWidget"

  public static let snapshotBackedKinds = [
    upcomingBirthdays,
    contactAge,
  ]
}
