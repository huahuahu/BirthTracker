# Logging Swift Package Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 `BirthTrackerPackage` 中新增统一 Logging 模块，支持多日志类型、默认 private 动态值、可测试 sink，并迁移现有 OSLog 调用点。

**Architecture:** `Logging` 是一个独立 SwiftPM target/product，只依赖 `Foundation` 和 `OSLog`。业务代码通过 `BirthLogger` facade 写日志，`LogRecord` 保存结构化日志数据，默认 `OSLogSink` 写入 Apple OSLog，测试通过注入 `LogSink` 捕获记录。

**Tech Stack:** Swift 6.3.2、SwiftPM、OSLog、Swift Testing、XcodeGen、SwiftUI、WidgetKit。

## Global Constraints

- 修改代码前遵守 `AGENTS.md`：代码变更后运行 `make check`。
- 不提交 `Config/Project.xcconfig`；只提交模板文件。
- `BirthTracker.xcodeproj` 是生成产物；修改 `project.yml` 后运行 `xcodegen generate`，不要提交生成的 `.xcodeproj`。
- SwiftPM package 单元测试使用计划中给出的 `swift test --package-path BirthTrackerPackage --filter LoggingTests`；Xcode target build/test 使用 xcodebuildmcp，首次 xcodebuildmcp build/test 前调用 `xcodebuildmcp-session_show_defaults`，必要时从 `.xcodebuildmcp/config.yaml` 设置 defaults。
- SwiftPM 或 Xcode 命令如果触发网络依赖解析，使用本机 1082 代理；如果遇到 SwiftPM bare repository 安全限制，用一次性 `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all` 前缀。
- 新增单元测试使用 Swift Testing，不使用 XCTest。
- 业务代码迁移后不直接创建 `OSLog.Logger`；只有 `Logging` target 内部可以 `import OSLog`。
- 一条日志可以携带多个 `LogTag`，但默认只写一条 OSLog 记录。
- 动态日志值默认 private，只有显式 `.public(...)` 才公开。

---

## File Structure

- Create `BirthTrackerPackage/Sources/Logging/LogTag.swift`: 日志类型值对象，含内置 tag 与自定义 tag 规范化。
- Create `BirthTrackerPackage/Sources/Logging/LogLevel.swift`: 日志级别枚举。
- Create `BirthTrackerPackage/Sources/Logging/LogPrivacy.swift`: 动态值隐私枚举。
- Create `BirthTrackerPackage/Sources/Logging/LogValue.swift`: 带隐私的动态值 wrapper。
- Create `BirthTrackerPackage/Sources/Logging/LogRecord.swift`: 一条结构化日志记录，负责 tag 去重、消息分层和 timestamp。
- Create `BirthTrackerPackage/Sources/Logging/LogSink.swift`: 可替换写入协议。
- Create `BirthTrackerPackage/Sources/Logging/OSLogSink.swift`: 默认 OSLog 写入实现。
- Create `BirthTrackerPackage/Sources/Logging/BirthLogger.swift`: 业务 facade 和便捷 logger。
- Create `BirthTrackerPackage/Tests/BirthTrackerTests/LoggingTests.swift`: Logging 模块 Swift Testing 覆盖。
- Modify `BirthTrackerPackage/Package.swift`: 暴露 `Logging` product，添加 target/test dependencies。
- Modify `project.yml`: Widget extension 和 Xcode test target 依赖 `Logging` product。
- Modify `BirthTrackerPackage/Sources/Features/Timeline/PeopleTimelineView.swift`: 迁移 Widget snapshot 日志。
- Modify `Sources/BirthTrackerWidget/PersonSelectionIntent.swift`: 迁移 Widget entity query 日志。
- Modify `Sources/BirthTrackerWidget/UpcomingBirthdaysWidget.swift`: 迁移 Widget provider 日志并补充失败日志。
- Modify `doc/architecture/current-architecture.md`: 记录 `Logging` 模块。
- Modify `doc/ai-context.md`: 更新源码布局说明。

---

### Task 1: Core Logging Value Types

**Files:**
- Create: `BirthTrackerPackage/Sources/Logging/LogTag.swift`
- Create: `BirthTrackerPackage/Sources/Logging/LogLevel.swift`
- Create: `BirthTrackerPackage/Sources/Logging/LogPrivacy.swift`
- Create: `BirthTrackerPackage/Sources/Logging/LogValue.swift`
- Create: `BirthTrackerPackage/Sources/Logging/LogRecord.swift`
- Create: `BirthTrackerPackage/Tests/BirthTrackerTests/LoggingTests.swift`
- Modify: `BirthTrackerPackage/Package.swift`

**Interfaces:**
- Produces: `LogTag`, `LogLevel`, `LogPrivacy`, `LogValue`, `LogRecord`
- Later tasks consume: `LogRecord(level:primaryTag:tags:message:values:timestamp:)`, `LogTag.data`, `LogTag.widget`, `LogValue.public(_:)`, `LogValue.private(_:)`

- [ ] **Step 1: Write the failing core tests**

Create `BirthTrackerPackage/Tests/BirthTrackerTests/LoggingTests.swift` with this content:

```swift
import Foundation
@testable import Logging
import Testing

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
    #expect(record.privateMessage == "")
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
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run:

```bash
HTTP_PROXY=http://127.0.0.1:1082 HTTPS_PROXY=http://127.0.0.1:1082 ALL_PROXY=http://127.0.0.1:1082 http_proxy=http://127.0.0.1:1082 https_proxy=http://127.0.0.1:1082 all_proxy=http://127.0.0.1:1082 NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter LoggingTests
```

Expected: FAIL because module `Logging` and its types do not exist.

- [ ] **Step 3: Add `Logging` to `BirthTrackerPackage/Package.swift`**

Modify `BirthTrackerPackage/Package.swift` so the products and targets include `Logging`.

In `products`, add `Logging` after `Localization`:

```swift
    .library(name: "Localization", targets: ["Localization"]),
    .library(name: "Logging", targets: ["Logging"]),
    .library(name: "Models", targets: ["Models"]),
```

In `targets`, add the target after `Localization`:

```swift
    .target(
      name: "Localization",
      path: "Sources/Localization",
      resources: [.process("Resources")]
    ),
    .target(
      name: "Logging",
      path: "Sources/Logging"
    ),
    .target(
      name: "Models",
      path: "Sources/Models"
    ),
```

Update the test target dependencies:

```swift
    .testTarget(
      name: "BirthTrackerPackageTests",
      dependencies: ["Features", "Logging", "Models", "Persistence", "TestingSupport"],
      path: "Tests/BirthTrackerTests"
    ),
```

- [ ] **Step 4: Implement `LogTag`**

Create `BirthTrackerPackage/Sources/Logging/LogTag.swift`:

```swift
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
```

- [ ] **Step 5: Implement `LogLevel`**

Create `BirthTrackerPackage/Sources/Logging/LogLevel.swift`:

```swift
public enum LogLevel: String, CaseIterable, Equatable, Sendable {
  case debug
  case info
  case notice
  case warning
  case error
  case fault
}
```

- [ ] **Step 6: Implement `LogPrivacy`**

Create `BirthTrackerPackage/Sources/Logging/LogPrivacy.swift`:

```swift
public enum LogPrivacy: Equatable, Sendable {
  case `private`
  case `public`
}
```

- [ ] **Step 7: Implement `LogValue`**

Create `BirthTrackerPackage/Sources/Logging/LogValue.swift`:

```swift
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
```

- [ ] **Step 8: Implement `LogRecord`**

Create `BirthTrackerPackage/Sources/Logging/LogRecord.swift`:

```swift
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
    let publicValues = values
      .filter { $0.privacy == .public }
      .map(\.description)

    guard publicValues.isEmpty == false else {
      return taggedMessage
    }

    return "\(taggedMessage) public=\(publicValues.joined(separator: " "))"
  }

  public var privateMessage: String {
    let privateValues = values
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
```

- [ ] **Step 9: Run the focused test to verify it passes**

Run:

```bash
HTTP_PROXY=http://127.0.0.1:1082 HTTPS_PROXY=http://127.0.0.1:1082 ALL_PROXY=http://127.0.0.1:1082 http_proxy=http://127.0.0.1:1082 https_proxy=http://127.0.0.1:1082 all_proxy=http://127.0.0.1:1082 NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter LoggingTests
```

Expected: PASS for the current `LoggingTests`.

- [ ] **Step 10: Commit Task 1**

Run:

```bash
git add BirthTrackerPackage/Package.swift BirthTrackerPackage/Sources/Logging BirthTrackerPackage/Tests/BirthTrackerTests/LoggingTests.swift
git commit -m "Add logging core types

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 2: Logger Facade and Sink

**Files:**
- Create: `BirthTrackerPackage/Sources/Logging/LogSink.swift`
- Create: `BirthTrackerPackage/Sources/Logging/OSLogSink.swift`
- Create: `BirthTrackerPackage/Sources/Logging/BirthLogger.swift`
- Modify: `BirthTrackerPackage/Tests/BirthTrackerTests/LoggingTests.swift`

**Interfaces:**
- Consumes: `LogRecord`, `LogLevel`, `LogTag`, `LogValue`
- Produces: `LogSink.write(_:)`, `OSLogSink.shared`, `BirthLogger(primaryTag:sink:)`, `BirthLogger.widget`, `BirthLogger.log(_:_:primaryTag:tags:values:timestamp:sink:)`

- [ ] **Step 1: Add failing tests for injected sink and logger facade**

Append this code inside `LoggingTests` before its closing `}`:

```swift
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
```

Add this helper after the `LoggingTests` closing `}`:

```swift
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
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run:

```bash
HTTP_PROXY=http://127.0.0.1:1082 HTTPS_PROXY=http://127.0.0.1:1082 ALL_PROXY=http://127.0.0.1:1082 http_proxy=http://127.0.0.1:1082 https_proxy=http://127.0.0.1:1082 all_proxy=http://127.0.0.1:1082 NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter LoggingTests
```

Expected: FAIL because `BirthLogger`, `LogSink`, and `OSLogSink` do not exist.

- [ ] **Step 3: Implement `LogSink`**

Create `BirthTrackerPackage/Sources/Logging/LogSink.swift`:

```swift
public protocol LogSink: Sendable {
  func write(_ record: LogRecord)
}
```

- [ ] **Step 4: Implement `OSLogSink`**

Create `BirthTrackerPackage/Sources/Logging/OSLogSink.swift`:

```swift
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

private extension LogLevel {
  var osLogType: OSLogType {
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
```

- [ ] **Step 5: Implement `BirthLogger`**

Create `BirthTrackerPackage/Sources/Logging/BirthLogger.swift`:

```swift
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
```

- [ ] **Step 6: Run the focused test to verify it passes**

Run:

```bash
HTTP_PROXY=http://127.0.0.1:1082 HTTPS_PROXY=http://127.0.0.1:1082 ALL_PROXY=http://127.0.0.1:1082 http_proxy=http://127.0.0.1:1082 https_proxy=http://127.0.0.1:1082 all_proxy=http://127.0.0.1:1082 NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter LoggingTests
```

Expected: PASS for all `LoggingTests`.

- [ ] **Step 7: Commit Task 2**

Run:

```bash
git add BirthTrackerPackage/Sources/Logging BirthTrackerPackage/Tests/BirthTrackerTests/LoggingTests.swift
git commit -m "Add logging facade and sink

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 3: Migrate Existing OSLog Call Sites

**Files:**
- Modify: `BirthTrackerPackage/Package.swift`
- Modify: `project.yml`
- Modify: `BirthTrackerPackage/Sources/Features/Timeline/PeopleTimelineView.swift`
- Modify: `Sources/BirthTrackerWidget/PersonSelectionIntent.swift`
- Modify: `Sources/BirthTrackerWidget/UpcomingBirthdaysWidget.swift`

**Interfaces:**
- Consumes: `BirthLogger.widget`, `LogTag.data`, `LogTag.persistence`, `LogValue.private(_:)`, `LogValue.public(_:)`
- Produces: App/Widget call sites using `Logging` instead of direct `OSLog.Logger`

- [ ] **Step 1: Update package dependency for `Features`**

In `BirthTrackerPackage/Package.swift`, update the `Features` target dependencies to include `Logging`:

```swift
    .target(
      name: "Features",
      dependencies: ["DesignSystem", "Localization", "Logging", "Models", "Persistence", "SFSafeSymbols"],
      path: "Sources/Features",
      swiftSettings: [.defaultIsolation(MainActor.self)]
    ),
```

- [ ] **Step 2: Update XcodeGen dependencies**

In `project.yml`, add `Logging` to the Widget extension dependencies after `Localization`:

```yaml
      - package: BirthTrackerPackage
        product: Localization
      - package: BirthTrackerPackage
        product: Logging
      - package: SFSafeSymbols
        product: SFSafeSymbols
```

In `project.yml`, add `Logging` to the `BirthTrackerTests` dependencies after `Features`:

```yaml
      - package: BirthTrackerPackage
        product: Features
      - package: BirthTrackerPackage
        product: Logging
      - package: BirthTrackerPackage
        product: Models
```

- [ ] **Step 3: Migrate `PeopleTimelineView` logging**

In `BirthTrackerPackage/Sources/Features/Timeline/PeopleTimelineView.swift`, replace:

```swift
import OSLog
```

with:

```swift
import Logging
```

Delete this file-level logger:

```swift
private let widgetSnapshotLogger = Logger(subsystem: "BirthTracker", category: "WidgetSnapshot")
```

Replace the `catch` block in `persistWidgetSnapshots(for:)` with:

```swift
    } catch {
      if (error as? WidgetSnapshotStoreError) == .appGroupUnavailable {
        BirthLogger.widget.error(
          "Skipping widget snapshot persistence because App Group is unavailable.",
          tags: [.persistence])
      } else {
        BirthLogger.widget.error(
          "Unable to persist widget snapshots.",
          tags: [.persistence],
          values: [.private(String(describing: error))])
        assertionFailure("Unable to persist widget snapshots: \(error)")
      }
    }
```

- [ ] **Step 4: Migrate `PersonSelectionIntent` logging**

In `Sources/BirthTrackerWidget/PersonSelectionIntent.swift`, replace:

```swift
import OSLog
```

with:

```swift
import Logging
```

Delete this file-level logger:

```swift
let logger = Logger(subsystem: "birthTracc11", category: "widget")
```

Replace:

```swift
    logger.info("entities for \(identifiers), result is \(result)")
```

with:

```swift
    BirthLogger.widget.info(
      "Resolved widget person entities.",
      tags: [.data],
      values: [
        .private(identifiers.map(\.uuidString).joined(separator: ",")),
        .public("result-count=\(result.count)"),
      ])
```

Replace:

```swift
    logger.info("suggestedEntities \(result.map(\.id))")
```

with:

```swift
    BirthLogger.widget.info(
      "Loaded suggested widget person entities.",
      tags: [.data],
      values: [
        .private(result.map(\.id.uuidString).joined(separator: ",")),
        .public("result-count=\(result.count)"),
      ])
```

- [ ] **Step 5: Migrate `UpcomingBirthdaysWidget` logging**

In `Sources/BirthTrackerWidget/UpcomingBirthdaysWidget.swift`, replace:

```swift
import OSLog
```

with:

```swift
import Logging
```

Replace:

```swift
      logger.info("load Entry for \(selectedPersonID?.uuidString ?? "nil")")
```

with:

```swift
      BirthLogger.widget.info(
        "Loading widget entry.",
        tags: [.data],
        values: [.private(selectedPersonID?.uuidString ?? "nil")])
```

Replace the `catch` block at the end of `loadEntry(for:)` with:

```swift
    } catch {
      BirthLogger.widget.error(
        "Failed to load widget entry.",
        tags: [.data, .persistence],
        values: [.private(String(describing: error))])
      return UpcomingBirthdaysEntry(date: .now, birthdays: [], selectedPersonUnavailable: false)
    }
```

- [ ] **Step 6: Verify direct OSLog usage is isolated to Logging**

Run:

```bash
rg "\b(import OSLog|Logger\(subsystem:)" BirthTrackerPackage/Sources Sources --glob "*.swift"
```

Expected: only `BirthTrackerPackage/Sources/Logging/OSLogSink.swift` matches.

- [ ] **Step 7: Regenerate Xcode project**

Run:

```bash
xcodegen generate
```

Expected: `BirthTracker.xcodeproj` is regenerated locally and remains untracked/ignored.

- [ ] **Step 8: Run the package logging tests**

Run:

```bash
HTTP_PROXY=http://127.0.0.1:1082 HTTPS_PROXY=http://127.0.0.1:1082 ALL_PROXY=http://127.0.0.1:1082 http_proxy=http://127.0.0.1:1082 https_proxy=http://127.0.0.1:1082 all_proxy=http://127.0.0.1:1082 NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter LoggingTests
```

Expected: PASS.

- [ ] **Step 9: Run the Xcode test target with xcodebuildmcp**

Tool sequence:

```text
xcodebuildmcp-session_show_defaults({})
```

Expected: defaults show `projectPath` as `BirthTracker.xcodeproj`, `scheme` as `BirthTracker`, and simulator `birth tracker 17 pro` or simulator ID `F4B82181-8A72-4AC3-9C95-454DE83A0C62`.

If defaults are missing or relative path resolution is wrong, call:

```text
xcodebuildmcp-session_set_defaults({
  "projectPath": "/Users/tigerguo/git/copilot-worktrees/BirthTracker/huahuahu-crispy-tribble/BirthTracker.xcodeproj",
  "scheme": "BirthTracker",
  "simulatorName": "birth tracker 17 pro",
  "simulatorId": "F4B82181-8A72-4AC3-9C95-454DE83A0C62"
})
```

Then run:

```text
xcodebuildmcp-test_sim({"progress": true})
```

Expected: build succeeds and `BirthTrackerTests` pass.

- [ ] **Step 10: Commit Task 3**

Run:

```bash
git add BirthTrackerPackage/Package.swift project.yml BirthTrackerPackage/Sources/Features/Timeline/PeopleTimelineView.swift Sources/BirthTrackerWidget/PersonSelectionIntent.swift Sources/BirthTrackerWidget/UpcomingBirthdaysWidget.swift
git commit -m "Migrate call sites to logging module

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 4: Documentation and Final Validation

**Files:**
- Modify: `doc/architecture/current-architecture.md`
- Modify: `doc/ai-context.md`

**Interfaces:**
- Consumes: completed `Logging` module and migrated call sites
- Produces: updated architecture/source-layout documentation and final validation

- [ ] **Step 1: Update `doc/architecture/current-architecture.md`**

In the `## Package 模块` list, add `Logging` after `Localization` if the list is expanded, or insert this bullet near the other package modules:

```markdown
- `Logging` 负责统一日志 facade、日志类型、动态值隐私、OSLog 写入和测试替换接口。
```

If the existing list is the current compact line-based list, the final package module section should include:

```markdown
- `App` 负责 root view 和 App 依赖装配。
- `Features` 负责 SwiftUI 页面，例如时间线、人物编辑和设置页。
- `Models` 负责领域模型，包括生日、被记录的人、关系事实、纯 Swift 关系称谓 resolver、联系人生日摘要 display model、Widget 快照记录和生日计算。
- `Persistence` 负责 SwiftData 容器、App Group 访问、Widget 专用 SwiftData store 和 Widget 持久化常量。
- `DesignSystem` 负责共享的 UI 相邻设置，例如外观模式和已选日历类型。
- `Localization` 负责本地化资源和类型安全访问入口。
- `Logging` 负责统一日志 facade、日志类型、动态值隐私、OSLog 写入和测试替换接口。
- `TestingSupport` 负责测试 fixture、内存持久化辅助逻辑和 debug 数据。
```

- [ ] **Step 2: Update `doc/ai-context.md`**

In `## 源码布局`, add this bullet after the `Localization` or package source bullets:

```markdown
- `BirthTrackerPackage/Sources/Logging` 放统一日志 facade、日志类型、动态值隐私、OSLog sink 和测试替换接口。
```

- [ ] **Step 3: Run final direct OSLog usage check**

Run:

```bash
rg "\b(import OSLog|Logger\(subsystem:)" BirthTrackerPackage/Sources Sources --glob "*.swift"
```

Expected: only `BirthTrackerPackage/Sources/Logging/OSLogSink.swift` matches.

- [ ] **Step 4: Run package tests**

Run:

```bash
HTTP_PROXY=http://127.0.0.1:1082 HTTPS_PROXY=http://127.0.0.1:1082 ALL_PROXY=http://127.0.0.1:1082 http_proxy=http://127.0.0.1:1082 https_proxy=http://127.0.0.1:1082 all_proxy=http://127.0.0.1:1082 NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter LoggingTests
```

Expected: PASS.

- [ ] **Step 5: Run repository check**

Run:

```bash
make check
```

Expected: all script tests, swift-format lint, and SwiftLint pass.

- [ ] **Step 6: Inspect git status**

Run:

```bash
git --no-pager status --short
```

Expected: only intended documentation changes are unstaged before commit; `BirthTracker.xcodeproj` and local config files are not listed for commit.

- [ ] **Step 7: Commit Task 4**

Run:

```bash
git add doc/architecture/current-architecture.md doc/ai-context.md
git commit -m "Document logging module architecture

Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

- [ ] **Step 8: Confirm final branch state**

Run:

```bash
git --no-pager log --oneline -5
git --no-pager status --short
```

Expected: recent commits include the design spec commit and the four implementation commits; working tree is clean.
