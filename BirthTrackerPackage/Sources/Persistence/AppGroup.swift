import Foundation

public enum AppGroup {
  public static let widgetStoreFileName = "widget.sqlite"

  public static var identifier: String {
    Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String ?? "group.com.example.BirthTracker"
  }

  public static var widgetStoreURL: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)?
      .appendingPathComponent(widgetStoreFileName)
  }
}
