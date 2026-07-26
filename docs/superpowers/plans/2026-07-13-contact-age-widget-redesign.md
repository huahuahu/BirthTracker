# 联系人出生时长小组件重设计 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `ContactAgeWidget` 重设计为只支持小号、突出出生时长、底部固定显示“出生至今”，并保留点按切换三种时间格式的交互。

**Architecture:** 保留现有 provider、App Intent、格式偏好和 timeline 数据流。新增可测试的出生时长数值组件，把年月日数值和单位交给 SwiftUI 分层渲染；视图只负责小号布局、切换动画、状态圆点和无障碍语义。

**Tech Stack:** Swift 6.2、SwiftUI、WidgetKit、AppIntents、Swift Testing、String Catalog、SFSafeSymbols

## Global Constraints

- 仅支持 `.systemSmall`。
- 左下角固定显示“出生至今”，中间时间区域可点按切换三种格式。
- 不显示生日倒计时或生日日期。
- 使用 SFSafeSymbols typed API，不使用原始 SF Symbol 字符串。
- 不修改格式偏好存储键、人物选择或 timeline 刷新策略。
- 所有规格与计划文档使用中文。

---

### Task 1: 为分层时间展示建立可测试的组件模型

**Files:**
- Modify: `BirthTrackerPackage/Package.swift`
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeDurationFormatter.swift`
- Create: `BirthTrackerPackage/Tests/BirthTrackerTests/ContactAgeDurationFormatterTests.swift`

**Interfaces:**
- Consumes: `ContactAgeSnapshotMetrics`、`ContactAgeDisplayFormat`
- Produces: `ContactAgeDurationComponent`、`ContactAgeDurationFormatter.components(for:displayFormat:)`

- [ ] **Step 1: 让测试 target 依赖 Widget 模块并写失败测试**

在 `Package.swift` 的 `BirthTrackerPackageTests` dependencies 中加入 `BirthTrackerWidgets`。新增测试，明确三种格式需要的数值和单位顺序：

```swift
import Models
import Persistence
import Testing
@testable import BirthTrackerWidgets

@Suite("Contact age duration formatter")
struct ContactAgeDurationFormatterTests {
  private let metrics = ContactAgeSnapshotMetrics(
    birthDuration: .init(years: 38, months: 2, days: 8),
    totalBirthDays: 13_949)

  @Test("Year month day format exposes three ordered components")
  func yearMonthDayComponents() {
    #expect(
      ContactAgeDurationFormatter().components(for: metrics, displayFormat: .yearMonthDay) == [
        .init(value: 38, unit: .year),
        .init(value: 2, unit: .month),
        .init(value: 8, unit: .day),
      ])
  }

  @Test("Month day format folds years into months")
  func monthDayComponents() {
    #expect(
      ContactAgeDurationFormatter().components(for: metrics, displayFormat: .monthDay) == [
        .init(value: 458, unit: .month),
        .init(value: 8, unit: .day),
      ])
  }

  @Test("Day format exposes one total day component")
  func dayComponents() {
    #expect(
      ContactAgeDurationFormatter().components(for: metrics, displayFormat: .day) == [
        .init(value: 13_949, unit: .day)
      ])
  }
}
```

- [ ] **Step 2: 运行测试确认按预期失败**

Run:

```bash
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter ContactAgeDurationFormatterTests
```

Expected: FAIL，提示 `ContactAgeDurationFormatter` 没有 `components`，且 `ContactAgeDurationComponent` 不存在。

- [ ] **Step 3: 实现最小组件模型**

在 `ContactAgeDurationFormatter.swift` 中增加：

```swift
struct ContactAgeDurationComponent: Equatable, Sendable {
  enum Unit: Equatable, Sendable {
    case year
    case month
    case day
  }

  let value: Int
  let unit: Unit
}

struct ContactAgeDurationFormatter {
  func components(
    for metrics: ContactAgeSnapshotMetrics,
    displayFormat: ContactAgeDisplayFormat
  ) -> [ContactAgeDurationComponent] {
    switch displayFormat {
    case .yearMonthDay:
      return [
        .init(value: metrics.birthDuration.years, unit: .year),
        .init(value: metrics.birthDuration.months, unit: .month),
        .init(value: metrics.birthDuration.days, unit: .day),
      ]
    case .monthDay:
      let monthDay = metrics.totalBirthMonthsAndDays
      return [
        .init(value: monthDay.months, unit: .month),
        .init(value: monthDay.days, unit: .day),
      ]
    case .day:
      return [.init(value: metrics.totalBirthDays, unit: .day)]
    }
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run:

```bash
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter ContactAgeDurationFormatterTests
```

Expected: `ContactAgeDurationFormatterTests` 的 3 个测试全部 PASS。

### Task 2: 本地化固定说明和完整时间单位

**Files:**
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/Shared/WidgetL10n.swift`
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/Resources/Localizable.xcstrings`
- Modify: `BirthTrackerPackage/Tests/BirthTrackerTests/ContactAgeDurationFormatterTests.swift`

**Interfaces:**
- Consumes: `ContactAgeDurationComponent.Unit`
- Produces: `WidgetL10n.contactAgeSinceBirth(locale:)`、`WidgetL10n.contactAgeUnit(_:value:locale:)`

- [ ] **Step 1: 写单位单复数的失败测试**

在 formatter 测试中新增：

```swift
@Test("English units use singular and plural forms")
func englishUnitsUseSingularAndPluralForms() {
  #expect(WidgetL10n.contactAgeSinceBirth(locale: Locale(identifier: "en")) == "Since birth")
  #expect(WidgetL10n.contactAgeUnit(.year, value: 1, locale: Locale(identifier: "en")) == "year")
  #expect(WidgetL10n.contactAgeUnit(.year, value: 2, locale: Locale(identifier: "en")) == "years")
  #expect(WidgetL10n.contactAgeUnit(.month, value: 1, locale: Locale(identifier: "en")) == "month")
  #expect(WidgetL10n.contactAgeUnit(.month, value: 2, locale: Locale(identifier: "en")) == "months")
  #expect(WidgetL10n.contactAgeUnit(.day, value: 1, locale: Locale(identifier: "en")) == "day")
  #expect(WidgetL10n.contactAgeUnit(.day, value: 2, locale: Locale(identifier: "en")) == "days")
}
```

- [ ] **Step 2: 运行测试确认按预期失败**

Run:

```bash
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter ContactAgeDurationFormatterTests
```

Expected: FAIL，提示 `WidgetL10n.contactAgeUnit` 不存在。

- [ ] **Step 3: 增加本地化 API 与 string catalog 条目**

在 `WidgetL10n` 中新增 `contactAgeSinceBirth`，并按 `value == 1` 选择 year/years、month/months、day/days。`Localizable.xcstrings` 新增以下英中翻译：

```text
Since birth -> 出生至今
year / years -> 年
month / months -> 月
day / days -> 天
```

`contactAgeUnit(_:value:locale:)` 使用传入 locale 从 `Bundle.module` 读取对应资源；视图调用时使用当前环境 locale。macOS `swift test` 会把 `.xcstrings` 原样复制到 SwiftPM resource bundle，而不会像 Xcode iOS 构建一样编译成各语言 `.lproj`，因此 Swift 单元测试只验证 source language 和单复数选择；简体中文条目由 JSON 校验与 iOS 构建产物验证。

- [ ] **Step 4: 运行测试并校验 string catalog**

Run:

```bash
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter ContactAgeDurationFormatterTests
python3 -m json.tool BirthTrackerPackage/Sources/BirthTrackerWidgets/Resources/Localizable.xcstrings >/dev/null
```

Expected: formatter 测试全部 PASS，JSON 校验退出码为 0。

### Task 3: 实现小号交互式 UI

**Files:**
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeWidgetView.swift`
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeWidget.swift`
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeWidgetPreviews.swift`

**Interfaces:**
- Consumes: `ContactAgeDurationFormatter.components(for:displayFormat:)`、`WidgetL10n.contactAgeSinceBirth`、`ToggleContactAgeFormatIntent`
- Produces: 只支持 `.systemSmall` 的联系人出生时长小组件

- [ ] **Step 1: 把 Widget family 收窄为小号并更新 previews**

把配置改为：

```swift
.supportedFamilies([.systemSmall])
```

把年月日、月与日、累计天数以及缺失出生年份 preview 全部改为 `.systemSmall`。

- [ ] **Step 2: 重写有数据状态的视图层级**

视图使用以下结构：

```swift
VStack(alignment: .leading, spacing: 10) {
  Label(snapshot.displayName, systemImage: SFSymbol.clock.rawValue)
    .font(.headline)
    .lineLimit(1)

  Button(intent: ToggleContactAgeFormatIntent(personID: snapshot.personID)) {
    durationContent(components)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      .id(displayFormat.rawValue)
      .transition(.push(from: .bottom))
  }
  .buttonStyle(.plain)
  .accessibilityHint(WidgetL10n.contactAgeTapToSwitch)

  HStack {
    Text(WidgetL10n.contactAgeSinceBirth)
      .font(.caption)
      .foregroundStyle(.secondary)
    Spacer()
    formatIndicator
  }
}
```

`durationContent` 对一个、两个、三个 component 使用等宽 `HStack`，数字采用粗体等宽数字，单位采用 caption 和 secondary 样式。`formatIndicator` 使用三个圆点，当前格式为 primary，其余为 tertiary。开启 Reduce Motion 时使用 `.identity` transition 且不添加 `.smooth` animation。

- [ ] **Step 3: 保留空状态并移除生日倒计时**

未选择人物、人物不可用、缺少出生年份的消息继续使用现有 `message(_:)`。删除 `daysUntilNextBirthday` 和可见的 “Tap to switch format” 文本；空状态不显示底部圆点。

- [ ] **Step 4: 格式化并运行聚焦测试**

Run:

```bash
make fix
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter ContactAge
```

Expected: Swift format/lint autocorrection完成，所有 ContactAge 测试 PASS。

### Task 4: 全量验证和 Simulator UI 检查

**Files:**
- Verify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/`
- Verify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: 完成后的代码和项目 `.xcodebuildmcp/config.yaml`
- Produces: 构建、测试、真实小组件交互证据

- [ ] **Step 1: 运行仓库全量检查**

Run:

```bash
make check
```

Expected: formatting、SwiftLint 和测试全部通过。

- [ ] **Step 2: 使用 XcodeBuildMCP 构建并运行指定 Simulator**

先调用 `session_show_defaults`，确认 project、scheme、simulator 与 `.xcodebuildmcp/config.yaml` 一致，再调用 simulator build/run 工作流。若出现 SwiftPM bare repository 错误，对该次命令使用：

```bash
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all
```

Expected: `BirthTracker` scheme 在 `F4B82181-8A72-4AC3-9C95-454DE83A0C62` 上成功构建和启动。

- [ ] **Step 3: 验证小组件真实 UI**

在 Simulator 主屏幕确认联系人出生时长小组件只提供小号布局，左下角显示“出生至今”，不出现生日倒计时。点按中间时间三次，确认显示按“年月日 → 月与日 → 累计天数 → 年月日”循环，右下状态圆点同步变化。

- [ ] **Step 4: 检查最终差异**

Run:

```bash
git diff --check
git status --short
```

Expected: 无空白错误；差异只包含本设计、计划、测试、联系人年龄小组件 UI、本地化和 test target 依赖。
