public struct LogValue: Equatable, Sendable {
  public let description: String
  public let privacy: LogPrivacy

  public init(_ value: some CustomStringConvertible, privacy: LogPrivacy = .private) {
    description = value.description
    self.privacy = privacy
  }

  public static func `private`(_ value: some CustomStringConvertible) -> Self {
    Self(value, privacy: .private)
  }

  public static func `public`(_ value: some CustomStringConvertible) -> Self {
    Self(value, privacy: .public)
  }
}
