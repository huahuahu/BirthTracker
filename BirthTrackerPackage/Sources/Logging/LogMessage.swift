public struct LogMessage: Equatable, Sendable, ExpressibleByStringInterpolation, ExpressibleByStringLiteral {
  public let publicDescription: String
  public let privateValues: [String]

  public init(_ message: String) {
    publicDescription = message
    privateValues = []
  }

  public init(stringLiteral value: String) {
    self.init(value)
  }

  public init(stringInterpolation: StringInterpolation) {
    publicDescription = stringInterpolation.publicDescription
    privateValues = stringInterpolation.privateValues
  }

  public struct StringInterpolation: StringInterpolationProtocol {
    public var publicDescription: String
    public var privateValues: [String]

    public init(literalCapacity: Int, interpolationCount: Int) {
      publicDescription = ""
      publicDescription.reserveCapacity(literalCapacity)
      privateValues = []
      privateValues.reserveCapacity(interpolationCount)
    }

    public mutating func appendLiteral(_ literal: String) {
      publicDescription += literal
    }

    public mutating func appendInterpolation(_ value: LogValue) {
      append(value.description, privacy: value.privacy)
    }

    public mutating func appendInterpolation(_ value: some CustomStringConvertible, privacy: LogPrivacy = .private) {
      append(value.description, privacy: privacy)
    }

    private mutating func append(_ value: String, privacy: LogPrivacy) {
      switch privacy {
      case .private:
        publicDescription += "<private>"
        privateValues.append(value)
      case .public:
        publicDescription += value
      }
    }
  }
}
