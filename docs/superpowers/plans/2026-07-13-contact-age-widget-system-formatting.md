# 联系人出生时长系统格式化调整 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 保留联系人出生时长小组件的三种点击切换粒度，同时把实际时间文本交给系统 `DateComponentsFormatter` 生成。

**Architecture:** 保留 provider、App Intent、格式偏好、timeline、底部“出生至今”和状态圆点。`ContactAgeDisplayFormat` 只决定 `DateComponentsFormatter.allowedUnits`；视图显示系统返回的完整字符串，并删除手工时长组件及单位本地化。

**Tech Stack:** Swift 6.2、SwiftUI、WidgetKit、AppIntents、Foundation、Swift Testing、String Catalog

## Global Constraints

- 仅支持 `.systemSmall`。
- 保留点击切换“年月日 → 月与日 → 累计天数”的行为和格式偏好。
- 左下角固定显示“出生至今”，右下角保留三个状态圆点。
- 不显示生日倒计时或生日日期。
- 时间单位、复数和本地化措辞由系统 formatter 决定，不手工拼接。
- 不修改人物选择、格式偏好存储键或 timeline 刷新策略。

---

### Task 1: 为系统格式化入口建立回归测试

**Files:**
- Modify: `BirthTrackerPackage/Tests/BirthTrackerTests/ContactAgeDurationFormatterTests.swift`
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeDurationFormatter.swift`

**Interfaces:**
- Consumes: `ContactAgeSnapshotMetrics`、`ContactAgeDisplayFormat`、`Locale`
- Produces: `ContactAgeDurationFormatter.string(for:displayFormat:locale:) -> String?`

- [ ] **Step 1: 写传入 locale 的失败测试**

新增测试，使用 `en_US` 验证三种粒度分别交给系统生成完整时长文本：

```swift
@Test("System formatter localizes every display granularity")
func systemFormatterLocalizesEveryDisplayGranularity() {
  let formatter = ContactAgeDurationFormatter()
  let locale = Locale(identifier: "en_US")

  #expect(formatter.string(for: metrics, displayFormat: .yearMonthDay, locale: locale) == "38 years, 2 months, 8 days")
  #expect(formatter.string(for: metrics, displayFormat: .monthDay, locale: locale) == "458 months, 8 days")
  #expect(formatter.string(for: metrics, displayFormat: .day, locale: locale) == "13,949 days")
}
```

- [ ] **Step 2: 运行测试确认按预期失败**

Run:

```bash
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter ContactAgeDurationFormatterTests
```

Expected: FAIL，提示缺少带 `locale` 参数的 `string` 重载。

- [ ] **Step 3: 让 DateComponentsFormatter 使用传入 locale**

给公开入口和私有 formatter helper 增加 `locale` 参数，创建带该 locale 的 `Calendar` 并设置到 `DateComponentsFormatter.calendar`，继续使用 `.full` units style。

```swift
func string(
  for metrics: ContactAgeSnapshotMetrics,
  displayFormat: ContactAgeDisplayFormat,
  locale: Locale
) -> String? {
  // 现有 switch 继续选择 DateComponents 和 allowedUnits，
  // 每个分支把 locale 传给私有 helper。
}

private func string(
  from components: DateComponents,
  allowedUnits: NSCalendar.Unit,
  locale: Locale
) -> String? {
  let formatter = DateComponentsFormatter()
  var calendar = Calendar.autoupdatingCurrent
  calendar.locale = locale
  formatter.calendar = calendar
  formatter.allowedUnits = allowedUnits
  formatter.unitsStyle = .full
  return formatter.string(from: components)
}
```

- [ ] **Step 4: 运行测试确认通过**

重复 Step 2 的命令，Expected: 新测试 PASS。

### Task 2: 恢复系统文本 UI 并删除手工组件

**Files:**
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeWidgetView.swift`
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/Shared/WidgetL10n.swift`
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/Resources/Localizable.xcstrings`
- Modify: `BirthTrackerPackage/Tests/BirthTrackerTests/ContactAgeDurationFormatterTests.swift`
- Modify: `scripts/test-widget-person-intent-storage.sh`
- Delete: `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeDurationComponent.swift`
- Delete: `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeDurationView.swift`

**Interfaces:**
- Consumes: `ContactAgeDurationFormatter.string(for:displayFormat:locale:)`
- Produces: 使用系统本地化文本的可点击小号出生时长 UI

- [ ] **Step 1: 在 ContactAgeWidgetView 恢复 ageText 路径**

`ageText(for:)` 调用带当前环境 locale 的 formatter。按钮中使用 `.title3.bold()`、等宽数字、两行上限和缩放兜底显示完整系统字符串；保留 `.id`、Reduce Motion transition、Intent、底部文案和状态点。

```swift
private func ageText(for snapshot: WidgetPersonSnapshot) -> String? {
  guard let metrics = contactAgeMetrics(for: snapshot) else { return nil }
  return durationFormatter.string(
    for: metrics,
    displayFormat: displayFormat,
    locale: locale)
}

Text(ageText)
  .font(.title3.bold())
  .monospacedDigit()
  .lineLimit(2)
  .minimumScaleFactor(0.7)
```

- [ ] **Step 2: 删除不再使用的手工组件与单位资源**

删除 `ContactAgeDurationComponent`、`ContactAgeDurationView`、`WidgetL10n.contactAgeUnit` 以及 year/years/month/months/day/days catalog 条目，只保留 `Since birth`。

- [ ] **Step 3: 同步测试和资源回归脚本**

删除组件顺序与手工单位单复数测试；保留系统 formatter 测试和 `Since birth` 测试。把资源脚本的新 key 集合缩减为 `Since birth`。

- [ ] **Step 4: 格式化并运行聚焦验证**

Run:

```bash
make fix
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift test --package-path BirthTrackerPackage --filter ContactAge
python3 -m json.tool BirthTrackerPackage/Sources/BirthTrackerWidgets/Resources/Localizable.xcstrings >/dev/null
```

Expected: 格式化、SwiftLint、ContactAge 测试和 JSON 校验全部通过。

### Task 3: 完整构建与真实小组件验证

**Files:**
- Verify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/`
- Verify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: 完成后的代码与 `.xcodebuildmcp/config.yaml`
- Produces: 仓库检查、iOS 构建和真实交互证据

- [ ] **Step 1: 运行 `make check` 和完整 Swift 测试**
- [ ] **Step 2: 使用 XcodeBuildMCP 在配置的 Simulator 上构建运行**
- [ ] **Step 3: 在主屏幕点按时间区域，确认三种系统文本和状态点循环**
- [ ] **Step 4: 运行 `git diff --check` 并审查最终状态**
