import Foundation

public enum AppGroup {
  public static let snapshotFileName = "upcoming-birthdays.json"

  public static var identifier: String {
    Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String ?? "group.com.example.BirthTracker"
  }

  public static var snapshotURL: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)?
      .appendingPathComponent(snapshotFileName)
  }
}
