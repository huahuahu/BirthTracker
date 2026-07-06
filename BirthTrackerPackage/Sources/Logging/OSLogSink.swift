import OSLog

public struct OSLogSink: LogSink {
  public static let shared = OSLogSink()

  private let writerFactory: @Sendable (String) -> any OSLogWriting

  public init(subsystem: String = "BirthTracker") {
    self.writerFactory = { category in
      SystemOSLogWriter(subsystem: subsystem, category: category)
    }
  }

  init(writerFactory: @escaping @Sendable (String) -> any OSLogWriting) {
    self.writerFactory = writerFactory
  }

  public func write(_ record: LogRecord) {
    let writer = writerFactory(record.primaryTag.rawValue)

    switch record.level {
    case .debug:
      writer.debug(publicMessage: record.publicMessage, privateMessage: record.privateMessage)
    case .info:
      writer.info(publicMessage: record.publicMessage, privateMessage: record.privateMessage)
    case .notice:
      writer.notice(publicMessage: record.publicMessage, privateMessage: record.privateMessage)
    case .warning:
      writer.warning(publicMessage: record.publicMessage, privateMessage: record.privateMessage)
    case .error:
      writer.error(publicMessage: record.publicMessage, privateMessage: record.privateMessage)
    case .fault:
      writer.fault(publicMessage: record.publicMessage, privateMessage: record.privateMessage)
    }
  }
}

protocol OSLogWriting: Sendable {
  func debug(publicMessage: String, privateMessage: String)
  func info(publicMessage: String, privateMessage: String)
  func notice(publicMessage: String, privateMessage: String)
  func warning(publicMessage: String, privateMessage: String)
  func error(publicMessage: String, privateMessage: String)
  func fault(publicMessage: String, privateMessage: String)
}

private struct SystemOSLogWriter: OSLogWriting {
  private let logger: Logger

  init(subsystem: String, category: String) {
    logger = Logger(subsystem: subsystem, category: category)
  }

  func debug(publicMessage: String, privateMessage: String) {
    if privateMessage.isEmpty {
      logger.debug("\(publicMessage, privacy: .public)")
    } else {
      logger.debug("\(publicMessage, privacy: .public) \(privateMessage, privacy: .private)")
    }
  }

  func info(publicMessage: String, privateMessage: String) {
    if privateMessage.isEmpty {
      logger.info("\(publicMessage, privacy: .public)")
    } else {
      logger.info("\(publicMessage, privacy: .public) \(privateMessage, privacy: .private)")
    }
  }

  func notice(publicMessage: String, privateMessage: String) {
    if privateMessage.isEmpty {
      logger.notice("\(publicMessage, privacy: .public)")
    } else {
      logger.notice("\(publicMessage, privacy: .public) \(privateMessage, privacy: .private)")
    }
  }

  func warning(publicMessage: String, privateMessage: String) {
    if privateMessage.isEmpty {
      logger.warning("\(publicMessage, privacy: .public)")
    } else {
      logger.warning("\(publicMessage, privacy: .public) \(privateMessage, privacy: .private)")
    }
  }

  func error(publicMessage: String, privateMessage: String) {
    if privateMessage.isEmpty {
      logger.error("\(publicMessage, privacy: .public)")
    } else {
      logger.error("\(publicMessage, privacy: .public) \(privateMessage, privacy: .private)")
    }
  }

  func fault(publicMessage: String, privateMessage: String) {
    if privateMessage.isEmpty {
      logger.fault("\(publicMessage, privacy: .public)")
    } else {
      logger.fault("\(publicMessage, privacy: .public) \(privateMessage, privacy: .private)")
    }
  }
}
