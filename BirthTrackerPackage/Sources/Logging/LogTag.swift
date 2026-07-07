import Foundation

public struct LogTag: Equatable, Hashable, Sendable, ExpressibleByStringLiteral {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = Self.normalize(rawValue)
  }

  public init(stringLiteral value: String) {
    self.init(value)
  }

  public static let data = Self("data")
  public static let widget = Self("widget")
  public static let ui = Self("ui")
  public static let persistence = Self("persistence")
  public static let lifecycle = Self("lifecycle")
  public static let debug = Self("debug")

  public static func custom(_ rawValue: String) -> Self {
    Self(rawValue)
  }

  private static func normalize(_ rawValue: String) -> String {
    var result = ""
    var previousWasSeparator = false

    for scalar in rawValue.lowercased().unicodeScalars {
      let isASCIIAlpha = (97...122).contains(scalar.value)
      let isASCIIDigit = (48...57).contains(scalar.value)

      if isASCIIAlpha || isASCIIDigit {
        result.unicodeScalars.append(scalar)
        previousWasSeparator = false
      } else if result.isEmpty == false && previousWasSeparator == false {
        result.append("-")
        previousWasSeparator = true
      }
    }

    let normalized = result.trimmingCharacters(in: .init(charactersIn: "-"))
    return normalized.isEmpty ? "custom" : normalized
  }
}
