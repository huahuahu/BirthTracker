import Foundation

public struct LogRecord: Equatable, Sendable {
  public let level: LogLevel
  public let primaryTag: LogTag
  public let tags: [LogTag]
  public let message: String
  public let values: [LogValue]
  public let timestamp: Date

  public init(
    level: LogLevel,
    primaryTag: LogTag,
    tags: [LogTag] = [],
    message: String,
    values: [LogValue] = [],
    timestamp: Date = Date()
  ) {
    self.level = level
    self.primaryTag = primaryTag
    self.tags = Self.normalizedTags(primaryTag: primaryTag, tags: tags)
    self.message = message
    self.values = values
    self.timestamp = timestamp
  }

  public var publicMessage: String {
    let publicValues =
      values
      .filter { $0.privacy == .public }
      .map(\.description)

    guard publicValues.isEmpty == false else {
      return taggedMessage
    }

    return "\(taggedMessage) public=\(publicValues.joined(separator: " "))"
  }

  public var privateMessage: String {
    let privateValues =
      values
      .filter { $0.privacy == .private }
      .map(\.description)

    guard privateValues.isEmpty == false else {
      return ""
    }

    return "private=\(privateValues.joined(separator: " "))"
  }

  public static func normalizedTags(primaryTag: LogTag, tags: [LogTag]) -> [LogTag] {
    var normalizedTags = [primaryTag]

    for tag in tags where normalizedTags.contains(tag) == false {
      normalizedTags.append(tag)
    }

    return normalizedTags
  }

  private var taggedMessage: String {
    "[\(tags.map(\.rawValue).joined(separator: ","))] \(message)"
  }
}
