public protocol LogSink: Sendable {
  func write(_ record: LogRecord)
}
