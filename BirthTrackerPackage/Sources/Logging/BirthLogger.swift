import Foundation

public struct BirthLogger: Sendable {
  public let primaryTag: LogTag

  private let sink: any LogSink

  public init(primaryTag: LogTag, sink: any LogSink = OSLogSink.shared) {
    self.primaryTag = primaryTag
    self.sink = sink
  }

  public static let data = BirthLogger(primaryTag: .data)
  public static let widget = BirthLogger(primaryTag: .widget)
  public static let ui = BirthLogger(primaryTag: .ui)
  public static let persistence = BirthLogger(primaryTag: .persistence)
  public static let lifecycle = BirthLogger(primaryTag: .lifecycle)
  public static let debug = BirthLogger(primaryTag: .debug)

  public func debug(
    _ message: String,
    tags: [LogTag] = [],
    values: [LogValue] = [],
    timestamp: Date = Date()
  ) {
    log(.debug, message, tags: tags, values: values, timestamp: timestamp)
  }

  public func info(
    _ message: String,
    tags: [LogTag] = [],
    values: [LogValue] = [],
    timestamp: Date = Date()
  ) {
    log(.info, message, tags: tags, values: values, timestamp: timestamp)
  }

  public func notice(
    _ message: String,
    tags: [LogTag] = [],
    values: [LogValue] = [],
    timestamp: Date = Date()
  ) {
    log(.notice, message, tags: tags, values: values, timestamp: timestamp)
  }

  public func warning(
    _ message: String,
    tags: [LogTag] = [],
    values: [LogValue] = [],
    timestamp: Date = Date()
  ) {
    log(.warning, message, tags: tags, values: values, timestamp: timestamp)
  }

  public func error(
    _ message: String,
    tags: [LogTag] = [],
    values: [LogValue] = [],
    timestamp: Date = Date()
  ) {
    log(.error, message, tags: tags, values: values, timestamp: timestamp)
  }

  public func fault(
    _ message: String,
    tags: [LogTag] = [],
    values: [LogValue] = [],
    timestamp: Date = Date()
  ) {
    log(.fault, message, tags: tags, values: values, timestamp: timestamp)
  }

  public func log(
    _ level: LogLevel,
    _ message: String,
    tags: [LogTag] = [],
    values: [LogValue] = [],
    timestamp: Date = Date()
  ) {
    Self.log(
      level,
      message,
      primaryTag: primaryTag,
      tags: tags,
      values: values,
      timestamp: timestamp,
      sink: sink)
  }

  public static func log(
    _ level: LogLevel,
    _ message: String,
    primaryTag: LogTag,
    tags: [LogTag] = [],
    values: [LogValue] = [],
    timestamp: Date = Date(),
    sink: any LogSink = OSLogSink.shared
  ) {
    let record = LogRecord(
      level: level,
      primaryTag: primaryTag,
      tags: tags,
      message: message,
      values: values,
      timestamp: timestamp)
    sink.write(record)
  }
}
