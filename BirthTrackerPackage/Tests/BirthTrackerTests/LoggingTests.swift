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
}
