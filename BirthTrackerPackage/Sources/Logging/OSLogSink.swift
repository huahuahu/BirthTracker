import OSLog

public struct OSLogSink: LogSink {
  public static let shared = OSLogSink()

  private let subsystem: String

  public init(subsystem: String = "BirthTracker") {
    self.subsystem = subsystem
  }

  public func write(_ record: LogRecord) {
    let logger = Logger(subsystem: subsystem, category: record.primaryTag.rawValue)
    let level = record.level.osLogType

    if record.privateMessage.isEmpty {
      logger.log(level: level, "\(record.publicMessage, privacy: .public)")
    } else {
      logger.log(level: level, "\(record.publicMessage, privacy: .public) \(record.privateMessage, privacy: .private)")
    }
  }
}

extension LogLevel {
  fileprivate var osLogType: OSLogType {
    switch self {
    case .debug:
      .debug
    case .info:
      .info
    case .notice, .warning:
      .default
    case .error:
      .error
    case .fault:
      .fault
    }
  }
}
