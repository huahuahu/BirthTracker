import Foundation
import Testing

@testable import Logging

@Suite("Logging")
struct LoggingTests {
  @Test("Built-in tags keep stable raw values")
  func builtInTagsKeepStableRawValues() {
    #expect(LogTag.data.rawValue == "data")
    #expect(LogTag.widget.rawValue == "widget")
    #expect(LogTag.ui.rawValue == "ui")
    #expect(LogTag.persistence.rawValue == "persistence")
    #expect(LogTag.lifecycle.rawValue == "lifecycle")
    #expect(LogTag.debug.rawValue == "debug")
  }

  @Test("Custom tags normalize to safe category values")
  func customTagsNormalizeToSafeCategoryValues() {
    #expect(LogTag.custom("Widget Snapshot").rawValue == "widget-snapshot")
    #expect(LogTag.custom("  DATA_sync  ").rawValue == "data-sync")
    #expect(LogTag.custom("UI+Flow").rawValue == "ui-flow")
    #expect(LogTag.custom("!!!").rawValue == "custom")
  }

  @Test("Log records include primary tag and remove duplicate tags")
  func logRecordsIncludePrimaryTagAndRemoveDuplicateTags() {
    let timestamp = Date(timeIntervalSince1970: 1_799_999_000)
    let record = LogRecord(
      level: .info,
      primaryTag: .widget,
      tags: [.data, .widget, .data],
      message: "Loaded widget entry",
      timestamp: timestamp)

    #expect(record.level == .info)
    #expect(record.primaryTag == .widget)
    #expect(record.tags.map(\.rawValue) == ["widget", "data"])
    #expect(record.message == "Loaded widget entry")
    #expect(record.timestamp == timestamp)
    #expect(record.publicMessage == "[widget,data] Loaded widget entry")
    #expect(record.privateMessage.isEmpty)
  }

  @Test("Log values default to private and can be explicitly public")
  func logValuesDefaultToPrivateAndCanBeExplicitlyPublic() {
    let privateValue = LogValue("person-id-123")
    let explicitPrivateValue = LogValue.private("birthday-1990-06-10")
    let publicValue = LogValue.public(3)

    #expect(privateValue.description == "person-id-123")
    #expect(privateValue.privacy == .private)
    #expect(explicitPrivateValue.privacy == .private)
    #expect(publicValue.description == "3")
    #expect(publicValue.privacy == .public)
  }

  @Test("Log records split public and private dynamic values")
  func logRecordsSplitPublicAndPrivateDynamicValues() {
    let record = LogRecord(
      level: .error,
      primaryTag: .widget,
      tags: [.data],
      message: "Failed to load widget entry",
      values: [
        .private("person-id-123"),
        .public("snapshot-count=0"),
      ],
      timestamp: Date(timeIntervalSince1970: 1_799_999_000))

    #expect(record.tags.map(\.rawValue) == ["widget", "data"])
    #expect(record.publicMessage == "[widget,data] Failed to load widget entry public=snapshot-count=0")
    #expect(record.privateMessage == "private=person-id-123")
  }

  @Test("BirthLogger writes records through an injected sink")
  func birthLoggerWritesRecordsThroughInjectedSink() throws {
    let sink = RecordingLogSink()
    let timestamp = Date(timeIntervalSince1970: 1_799_999_100)
    let logger = BirthLogger(primaryTag: .widget, sink: sink)

    logger.info(
      "Loaded widget entry",
      tags: [.data],
      values: [.private("person-id-123"), .public("snapshot-count=1")],
      timestamp: timestamp)

    let record = try #require(sink.records.first)
    #expect(record.level == .info)
    #expect(record.primaryTag == .widget)
    #expect(record.tags.map(\.rawValue) == ["widget", "data"])
    #expect(record.message == "Loaded widget entry")
    #expect(record.values == [.private("person-id-123"), .public("snapshot-count=1")])
    #expect(record.timestamp == timestamp)
  }

  @Test("Static BirthLogger entry point writes records through a provided sink")
  func staticBirthLoggerEntryPointWritesRecordsThroughProvidedSink() throws {
    let sink = RecordingLogSink()
    let timestamp = Date(timeIntervalSince1970: 1_799_999_200)

    BirthLogger.log(
      .error,
      "Failed to rebuild widget snapshots",
      primaryTag: .widget,
      tags: [.persistence],
      values: [.private("App Group unavailable")],
      timestamp: timestamp,
      sink: sink)

    let record = try #require(sink.records.first)
    #expect(record.level == .error)
    #expect(record.primaryTag == .widget)
    #expect(record.tags.map(\.rawValue) == ["widget", "persistence"])
    #expect(record.privateMessage == "private=App Group unavailable")
  }

  @Test("BirthLogger preserves every supported level", arguments: LogLevel.allCases)
  func birthLoggerPreservesEverySupportedLevel(level: LogLevel) throws {
    let sink = RecordingLogSink()
    let logger = BirthLogger(primaryTag: .debug, sink: sink)

    logger.log(level, "Message for \(level.rawValue)", timestamp: Date(timeIntervalSince1970: 1))

    let record = try #require(sink.records.first)
    #expect(record.level == level)
    #expect(record.primaryTag == .debug)
  }

  @Test("OSLogSink dispatches every supported level to the matching writer", arguments: LogLevel.allCases)
  func osLogSinkDispatchesEverySupportedLevelToMatchingWriter(level: LogLevel) throws {
    let writer = RecordingOSLogWriter()
    let sink = OSLogSink(writerFactory: { category in
      writer.recordCategory(category)
      return writer
    })
    let record = LogRecord(
      level: level,
      primaryTag: .widget,
      tags: [.data],
      message: "Message for \(level.rawValue)",
      values: [.public("visible"), .private("secret")],
      timestamp: Date(timeIntervalSince1970: 1_799_999_300))

    sink.write(record)

    let call = try #require(writer.calls.first)
    #expect(writer.categories == [LogTag.widget.rawValue])
    #expect(writer.calls.count == 1)
    #expect(call.level == level)
    #expect(call.publicMessage == record.publicMessage)
    #expect(call.privateMessage == record.privateMessage)
  }
}

private final class RecordingLogSink: LogSink, @unchecked Sendable {
  private let lock = NSLock()
  private var capturedRecords: [LogRecord] = []

  var records: [LogRecord] {
    lock.lock()
    defer { lock.unlock() }
    return capturedRecords
  }

  func write(_ record: LogRecord) {
    lock.lock()
    defer { lock.unlock() }
    capturedRecords.append(record)
  }
}

private final class RecordingOSLogWriter: OSLogWriting, @unchecked Sendable {
  struct Call: Equatable {
    let level: LogLevel
    let publicMessage: String
    let privateMessage: String
  }

  private let lock = NSLock()
  private var capturedCategories: [String] = []
  private var capturedCalls: [Call] = []

  var categories: [String] {
    lock.lock()
    defer { lock.unlock() }
    return capturedCategories
  }

  var calls: [Call] {
    lock.lock()
    defer { lock.unlock() }
    return capturedCalls
  }

  func recordCategory(_ category: String) {
    lock.lock()
    defer { lock.unlock() }
    capturedCategories.append(category)
  }

  func debug(publicMessage: String, privateMessage: String) {
    record(.debug, publicMessage: publicMessage, privateMessage: privateMessage)
  }

  func info(publicMessage: String, privateMessage: String) {
    record(.info, publicMessage: publicMessage, privateMessage: privateMessage)
  }

  func notice(publicMessage: String, privateMessage: String) {
    record(.notice, publicMessage: publicMessage, privateMessage: privateMessage)
  }

  func warning(publicMessage: String, privateMessage: String) {
    record(.warning, publicMessage: publicMessage, privateMessage: privateMessage)
  }

  func error(publicMessage: String, privateMessage: String) {
    record(.error, publicMessage: publicMessage, privateMessage: privateMessage)
  }

  func fault(publicMessage: String, privateMessage: String) {
    record(.fault, publicMessage: publicMessage, privateMessage: privateMessage)
  }

  private func record(_ level: LogLevel, publicMessage: String, privateMessage: String) {
    lock.lock()
    defer { lock.unlock() }
    capturedCalls.append(Call(level: level, publicMessage: publicMessage, privateMessage: privateMessage))
  }
}
