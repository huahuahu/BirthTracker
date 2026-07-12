# Widget 完整迁移到 Swift Package Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把两个 Widget 的实现、preview 和 UI 本地化完整迁入现有 `BirthTrackerWidgets` SwiftPM target，让 XcodeGen 的 Widget extension target 只管理一个 `@main` 壳和系统要求的三个资源文件。

**Architecture:** 现有 `BirthTrackerPackage` 继续提供 `BirthTrackerWidgets` product；package 内新增真正组合两个 Widget 的公开 `BirthTrackerWidgetsBundle`，extension 壳仅委托其 `body`。Widget UI 字符串由 package resource bundle 管理，只有 AppIntents metadata 和 extension Info.plist 本地化保留在 target main bundle。

**Tech Stack:** Swift 6.3.2、SwiftUI、WidgetKit、AppIntents、SwiftPM、XcodeGen、Swift Testing、XcodeBuildMCP、Bash 结构回归检查。

## Global Constraints

- 使用现有 `BirthTrackerPackage` 和 `BirthTrackerWidgets` target，不创建第二个 package。
- `Sources/BirthTrackerWidget` 最终只能包含 `BirthTrackerWidgetBundle.swift`、`Info.plist`、`InfoPlist.xcstrings`、`Intents.xcstrings`。
- 不改变 Widget 布局、刷新策略、App Group、SwiftData 快照或年龄格式偏好行为。
- `SFSafeSymbols` typed API 保持不变，不引入 raw SF Symbol 字符串。
- AppIntent metadata 必须直接使用 `LocalizedStringResource(..., table: "Intents", bundle: .main)`。
- Widget UI 字符串必须从 `BirthTrackerWidgets` 的 `Bundle.module` 读取。
- 不修改或提交 `Config/Project.xcconfig`。
- 每次代码变更结束前运行 `make check`；Xcode 构建与测试必须使用 XcodeBuildMCP。
- 若 SwiftPM 遇到 `safe.bareRepository is 'explicit'`，只对失败命令添加 `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all`，不得修改全局 Git 配置。

---

## 文件变更总览

**新增：**

- `BirthTrackerPackage/Sources/BirthTrackerWidgets/BirthTrackerWidgetsBundle.swift`：package 对 extension 暴露的唯一 Widget bundle 组合入口。
- `BirthTrackerPackage/Sources/BirthTrackerWidgets/Shared/WidgetL10n.swift`：只访问 package resource bundle 的 Widget UI 本地化入口。
- `BirthTrackerPackage/Sources/BirthTrackerWidgets/Resources/Localizable.xcstrings`：Widget UI、gallery 和提示文本的英文及简体中文资源。
- `Sources/BirthTrackerWidget/Intents.xcstrings`：Widget extension main bundle 的 AppIntents metadata 本地化。

**移动到 package，内容行为保持不变：**

- `Sources/BirthTrackerWidget/ContactAge/ContactAgeEntry.swift` → `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeEntry.swift`
- `Sources/BirthTrackerWidget/ContactAge/ContactAgeProvider.swift` → `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeProvider.swift`
- `Sources/BirthTrackerWidget/ContactAge/ContactAgeWidget.swift` → `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeWidget.swift`
- `Sources/BirthTrackerWidget/ContactAge/ContactAgeWidgetPreviews.swift` → `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeWidgetPreviews.swift`
- `Sources/BirthTrackerWidget/UpcomingBirthdays/UpcomingBirthdaysEntry.swift` → `BirthTrackerPackage/Sources/BirthTrackerWidgets/UpcomingBirthdays/UpcomingBirthdaysEntry.swift`
- `Sources/BirthTrackerWidget/UpcomingBirthdays/UpcomingBirthdaysProvider.swift` → `BirthTrackerPackage/Sources/BirthTrackerWidgets/UpcomingBirthdays/UpcomingBirthdaysProvider.swift`
- `Sources/BirthTrackerWidget/UpcomingBirthdays/UpcomingBirthdaysWidget.swift` → `BirthTrackerPackage/Sources/BirthTrackerWidgets/UpcomingBirthdays/UpcomingBirthdaysWidget.swift`
- `Sources/BirthTrackerWidget/UpcomingBirthdays/UpcomingBirthdaysWidgetPreviews.swift` → `BirthTrackerPackage/Sources/BirthTrackerWidgets/UpcomingBirthdays/UpcomingBirthdaysWidgetPreviews.swift`

**修改：**

- `BirthTrackerPackage/Package.swift`：为 `BirthTrackerWidgets` 处理资源并移除不再使用的 `Localization` 依赖。
- `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeWidgetView.swift`：使用 `WidgetL10n`。
- `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ToggleContactAgeFormatIntent.swift`：AppIntent metadata 使用 `Intents` table 和 main bundle。
- `BirthTrackerPackage/Sources/BirthTrackerWidgets/Shared/PersonSelectionIntent.swift`：AppIntent metadata 使用直接 main-bundle 声明。
- `BirthTrackerPackage/Sources/BirthTrackerWidgets/UpcomingBirthdays/UpcomingBirthdaysWidgetView.swift`：使用 `WidgetL10n`。
- `BirthTrackerPackage/Sources/Localization/L10n.swift`：删除已迁入 Widget target 的 `L10n.Widget`。
- `BirthTrackerPackage/Sources/Localization/Resources/Localizable.xcstrings`：删除只供 Widget 使用的条目，保留 App 仍使用的条目。
- `Sources/BirthTrackerApp/Intents.xcstrings`：补齐四个 AppIntent metadata key。
- `Sources/BirthTrackerWidget/BirthTrackerWidgetBundle.swift`：改成最小委托壳。
- `project.yml`：Widget extension 移除直接 `Logging` 依赖。
- `scripts/test-widget-person-intent-storage.sh`：锁定 package-owned Widget 结构和本地化边界。
- `doc/architecture/current-architecture.md`：记录新的真实架构。

**删除：**

- `Sources/BirthTrackerWidget/Localizable.xcstrings`：空的 target UI catalog 已无职责。

---

### Task 1: 用结构回归检查驱动 Widget 实现迁移

**Files:**

- Create: `BirthTrackerPackage/Sources/BirthTrackerWidgets/BirthTrackerWidgetsBundle.swift`
- Move: `Sources/BirthTrackerWidget/ContactAge/*.swift` 中的 entry、provider、Widget、preview 到 `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/`
- Move: `Sources/BirthTrackerWidget/UpcomingBirthdays/*.swift` 中的 entry、provider、Widget、preview 到 `BirthTrackerPackage/Sources/BirthTrackerWidgets/UpcomingBirthdays/`
- Modify: `Sources/BirthTrackerWidget/BirthTrackerWidgetBundle.swift`
- Modify: `scripts/test-widget-person-intent-storage.sh`

**Interfaces:**

- Consumes: 现有 `UpcomingBirthdaysWidget`、`ContactAgeWidget`、`SelectPersonIntent`、`Models`、`Persistence` 和 `Logging` 行为。
- Produces: `public struct BirthTrackerWidgetsBundle: WidgetBundle`，包含 `public init()` 和 `public var body: some Widget`；extension 壳通过 `BirthTrackerWidgetsBundle().body` 使用它。

- [ ] **Step 1: 先把结构脚本改成目标断言**

先在脚本变量区增加 package bundle 路径：

```bash
PACKAGE_BUNDLE_FILE="$WIDGET_PACKAGE_DIR/BirthTrackerWidgetsBundle.swift"
```

把 `expected_package_files` 扩展为 package 内全部实现文件，并把 extension Swift 文件限制为 bundle 壳：

```bash
expected_package_files=(
  "$PACKAGE_BUNDLE_FILE"
  "$SHARED_DIR/BirthTrackerWidgetsAppIntentsPackage.swift"
  "$SHARED_DIR/PersonSelectionIntent.swift"
  "$CONTACT_AGE_DIR/ContactAgeDurationFormatter.swift"
  "$CONTACT_AGE_DIR/ContactAgeEntry.swift"
  "$CONTACT_AGE_DIR/ContactAgeProvider.swift"
  "$CONTACT_AGE_DIR/ContactAgeWidget.swift"
  "$CONTACT_AGE_DIR/ContactAgeWidgetPreviews.swift"
  "$CONTACT_AGE_DIR/ContactAgeWidgetView.swift"
  "$CONTACT_AGE_DIR/ToggleContactAgeFormatIntent.swift"
  "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysEntry.swift"
  "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysProvider.swift"
  "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysWidget.swift"
  "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysWidgetPreviews.swift"
  "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysWidgetView.swift"
)

expected_extension_files=(
  "$BUNDLE_FILE"
)

grep -q 'BirthTrackerWidgetsBundle().body' "$BUNDLE_FILE" \
  || fail "BirthTrackerWidgetBundle should delegate to the package-owned BirthTrackerWidgetsBundle"
grep -q 'public struct BirthTrackerWidgetsBundle: WidgetBundle' "$PACKAGE_BUNDLE_FILE" \
  || fail "BirthTrackerWidgets should expose a public WidgetBundle"
grep -q 'UpcomingBirthdaysWidget()' "$PACKAGE_BUNDLE_FILE" \
  || fail "BirthTrackerWidgetsBundle should include the upcoming birthdays widget"
grep -q 'ContactAgeWidget()' "$PACKAGE_BUNDLE_FILE" \
  || fail "BirthTrackerWidgetsBundle should include the contact age widget"

while IFS= read -r swift_file; do
  [[ "$swift_file" == "$BUNDLE_FILE" ]] \
    || fail "$(relative_to_root "$swift_file") should not contain Widget implementation code; keep only the extension shell"
done < <(find "$WIDGET_EXTENSION_DIR" -type f -name '*.swift')
```

同时把 provider 的 `configuration.person` 检查路径改为 `"$CONTACT_AGE_DIR" "$UPCOMING_BIRTHDAYS_DIR"`，并把原来要求具体文件位于 extension 的断言改成要求 extension 中不存在这些文件。

- [ ] **Step 2: 运行结构脚本并确认 RED**

Run:

```bash
./scripts/test-widget-person-intent-storage.sh
```

Expected: FAIL，首个失败应指出 `BirthTrackerWidgetsBundle.swift should exist` 或某个 provider/entry 应位于 package，而不是无关的 shell 语法错误。

- [ ] **Step 3: 移动实现文件并清除 self-import**

使用 `apply_patch` 的 move 操作完成文件映射。移动后的 `ContactAgeProvider.swift`、`ContactAgeWidget.swift`、`UpcomingBirthdaysProvider.swift`、`UpcomingBirthdaysWidget.swift` 不再包含：

```swift
import BirthTrackerWidgets
```

其他 import、provider fallback、timeline policy 和 preview 数据保持原样。

- [ ] **Step 4: 新增 package bundle 并缩小 extension 壳**

创建 `BirthTrackerWidgetsBundle.swift`：

```swift
import SwiftUI
import WidgetKit

public struct BirthTrackerWidgetsBundle: WidgetBundle {
  public init() {}

  public var body: some Widget {
    UpcomingBirthdaysWidget()
    ContactAgeWidget()
  }
}
```

把 extension 壳改为：

```swift
import BirthTrackerWidgets
import SwiftUI
import WidgetKit

@main
struct BirthTrackerWidgetBundle: WidgetBundle {
  var body: some Widget {
    BirthTrackerWidgetsBundle().body
  }
}
```

- [ ] **Step 5: 运行结构脚本并确认 GREEN**

Run:

```bash
./scripts/test-widget-person-intent-storage.sh
```

Expected: `widget person intent storage and package structure tests passed`。

- [ ] **Step 6: 提交纯结构迁移**

```bash
git add BirthTrackerPackage/Sources/BirthTrackerWidgets Sources/BirthTrackerWidget scripts/test-widget-person-intent-storage.sh
git commit -m "refactor: move widget implementation into package"
```

### Task 2: 将 Widget UI 与 AppIntents 本地化放入正确 bundle

**Files:**

- Create: `BirthTrackerPackage/Sources/BirthTrackerWidgets/Shared/WidgetL10n.swift`
- Create: `BirthTrackerPackage/Sources/BirthTrackerWidgets/Resources/Localizable.xcstrings`
- Create: `Sources/BirthTrackerWidget/Intents.xcstrings`
- Modify: `BirthTrackerPackage/Package.swift`
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeWidget.swift`
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeWidgetView.swift`
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ToggleContactAgeFormatIntent.swift`
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/Shared/PersonSelectionIntent.swift`
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/UpcomingBirthdays/UpcomingBirthdaysWidget.swift`
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/UpcomingBirthdays/UpcomingBirthdaysWidgetView.swift`
- Modify: `BirthTrackerPackage/Sources/Localization/L10n.swift`
- Modify: `BirthTrackerPackage/Sources/Localization/Resources/Localizable.xcstrings`
- Modify: `Sources/BirthTrackerApp/Intents.xcstrings`
- Delete: `Sources/BirthTrackerWidget/Localizable.xcstrings`
- Modify: `scripts/test-widget-person-intent-storage.sh`

**Interfaces:**

- Consumes: SwiftPM 生成的 `Bundle.module`，AppIntents 要求的 target `.main` bundle，现有英文和简体中文文案。
- Produces: package-internal `WidgetL10n` 静态资源入口；App 与 extension 中内容一致的 `Intents.xcstrings`。

- [ ] **Step 1: 增加本地化边界断言并确认 RED**

先在脚本变量区增加资源路径：

```bash
WIDGET_RESOURCE_FILE="$WIDGET_PACKAGE_DIR/Resources/Localizable.xcstrings"
APP_INTENTS_FILE="$ROOT/Sources/BirthTrackerApp/Intents.xcstrings"
WIDGET_INTENTS_FILE="$WIDGET_EXTENSION_DIR/Intents.xcstrings"
```

在 `expected_package_files` 中加入 `"$WIDGET_RESOURCE_FILE"` 和 `"$SHARED_DIR/WidgetL10n.swift"`，在 extension 必需文件检查中加入 `"$WIDGET_INTENTS_FILE"`，然后增加：

```bash
grep -q 'resources: \[.process("Resources")\]' "$PACKAGE_FILE" \
  || fail "BirthTrackerWidgets should process its own localization resources"
grep -q 'LocalizedStringResource("Choose Person", table: "Intents", bundle: .main)' "$INTENT_FILE" \
  || fail "SelectPersonIntent title should use the main-bundle Intents table"
grep -q 'LocalizedStringResource("Contact", table: "Intents", bundle: .main)' "$INTENT_FILE" \
  || fail "SelectPersonIntent parameter should use the main-bundle Intents table"
grep -q 'LocalizedStringResource("Toggle Age Format", table: "Intents", bundle: .main)' "$CONTACT_AGE_DIR/ToggleContactAgeFormatIntent.swift" \
  || fail "ToggleContactAgeFormatIntent should use the main-bundle Intents table"

if grep -R '^import Localization$' "$WIDGET_PACKAGE_DIR"; then
  fail "Widget UI strings should be owned by BirthTrackerWidgets resources"
fi

for intents_file in "$APP_INTENTS_FILE" "$WIDGET_INTENTS_FILE"; do
  for key in 'Choose Person' 'Choose which person this widget shows.' 'Contact' 'Person ID' 'Toggle Age Format'; do
    grep -Fq "\"$key\"" "$intents_file" \
      || fail "$(relative_to_root "$intents_file") should contain $key"
  done
  grep -q '"zh-Hans"' "$intents_file" \
    || fail "$(relative_to_root "$intents_file") should include Simplified Chinese"
done
```

Run:

```bash
./scripts/test-widget-person-intent-storage.sh
```

Expected: FAIL，提示 package resource、`WidgetL10n.swift` 或 `BirthTrackerWidgets should process its own localization resources` 尚不存在；失败必须来自刚加入的本地化边界断言。

- [ ] **Step 2: 给 package target 声明资源**

把 target 改成：

```swift
.target(
  name: "BirthTrackerWidgets",
  dependencies: ["Logging", "Models", "Persistence", "SFSafeSymbols"],
  path: "Sources/BirthTrackerWidgets",
  resources: [.process("Resources")]
),
```

- [ ] **Step 3: 新增 `WidgetL10n` 并切换所有 Widget UI 调用**

创建以下完整入口：

```swift
import Foundation

enum WidgetL10n {
  static let ageFormatDay = LocalizedStringResource(
    "widget.contact.age.format.total.days",
    bundle: .atURL(Bundle.module.bundleURL))
  static let ageFormatMonthDay = LocalizedStringResource(
    "widget.contact.age.format.month.day",
    bundle: .atURL(Bundle.module.bundleURL))
  static let ageFormatYearMonthDay = LocalizedStringResource(
    "widget.contact.age.format.duration",
    bundle: .atURL(Bundle.module.bundleURL))
  static let contactAge = LocalizedStringResource(
    "Contact Age",
    bundle: .atURL(Bundle.module.bundleURL))
  static let contactAgeChoosePerson = LocalizedStringResource(
    "Choose a person to show their age.",
    bundle: .atURL(Bundle.module.bundleURL))
  static let contactAgeDescription = LocalizedStringResource(
    "Track one person's current age. Tap to switch formats.",
    bundle: .atURL(Bundle.module.bundleURL))
  static let contactAgeNeedsBirthYear = LocalizedStringResource(
    "Add a birth year to show age.",
    bundle: .atURL(Bundle.module.bundleURL))
  static let contactAgeTapToSwitch = LocalizedStringResource(
    "Tap to switch format",
    bundle: .atURL(Bundle.module.bundleURL))
  static let description = LocalizedStringResource(
    "See the next birthdays at a glance.",
    bundle: .atURL(Bundle.module.bundleURL))
  static let noBirthdayRecorded = LocalizedStringResource(
    "No birthday recorded",
    bundle: .atURL(Bundle.module.bundleURL))
  static let noUpcomingBirthdays = LocalizedStringResource(
    "No upcoming birthdays",
    bundle: .atURL(Bundle.module.bundleURL))
  static let selectedPersonUnavailable = LocalizedStringResource(
    "Selected person is no longer available.",
    bundle: .atURL(Bundle.module.bundleURL))
  static let title = LocalizedStringResource(
    "Birthdays",
    bundle: .atURL(Bundle.module.bundleURL))
  static let upcomingBirthdays = LocalizedStringResource(
    "Upcoming Birthdays",
    bundle: .atURL(Bundle.module.bundleURL))

  static func string(_ resource: LocalizedStringResource) -> String {
    String(localized: resource)
  }

  static func birthDuration(_ years: Int, _ months: Int, _ days: Int) -> String {
    let format = string(
      LocalizedStringResource(
        "widget.birth.duration.format",
        bundle: .atURL(Bundle.module.bundleURL)))
    return String.localizedStringWithFormat(format, years, months, days)
  }

  static func daysUntilBirthday(_ days: Int) -> String {
    let format = string(
      LocalizedStringResource(
        "person.detail.days.until.birthday.format",
        bundle: .atURL(Bundle.module.bundleURL)))
    return String.localizedStringWithFormat(format, days)
  }
}
```

在两个 Widget 和两个 View 中删除 `import Localization`，逐项替换：

```swift
L10n.Widget.*                              → WidgetL10n.*
L10n.string(L10n.Widget.*)                → WidgetL10n.string(WidgetL10n.*)
L10n.PersonDetail.daysUntilBirthday(days) → WidgetL10n.daysUntilBirthday(days)
L10n.Widget.birthDuration(y, m, d)         → WidgetL10n.birthDuration(y, m, d)
```

从 `L10n.swift` 删除整个 `public enum Widget`。从共享 `Localizable.xcstrings` 删除只供该 enum 使用的 Widget key；保留仍被 App 使用的 `Birthdays`、`No birthday recorded` 和 person-detail key 时，以 `rg` 的非 Widget 引用结果为准，不能因为名称相同误删 App 文案。

- [ ] **Step 4: 创建 package UI catalog**

新 catalog 必须包含下列精确 key 和翻译：

| Key | English | 简体中文 |
| --- | --- | --- |
| `Add a birth year to show age.` | Add a birth year to show age. | 添加出生年份以显示年龄。 |
| `Birthdays` | Birthdays | 生日 |
| `Choose a person to show their age.` | Choose a person to show their age. | 选择联系人以显示年龄。 |
| `Contact Age` | Contact Age | 联系人年龄 |
| `No birthday recorded` | No birthday recorded | 未记录生日 |
| `No upcoming birthdays` | No upcoming birthdays | 暂无即将到来的生日 |
| `See the next birthdays at a glance.` | See the next birthdays at a glance. | 一眼查看接下来的生日。 |
| `Selected person is no longer available.` | Selected person is no longer available. | 所选联系人已不在列表中。 |
| `Tap to switch format` | Tap to switch format | 点按切换格式 |
| `Track one person's current age. Tap to switch formats.` | Track one person's current age. Tap to switch formats. | 记录一位联系人的当前年龄，点按即可切换格式。 |
| `Upcoming Birthdays` | Upcoming Birthdays | 即将到来的生日 |
| `person.detail.days.until.birthday.format` | `%lld days` | `%lld 天` |
| `widget.birth.duration.format` | `Born %lldy %lldm %lldd` | `出生 %lld 年 %lld 月 %lld 天` |
| `widget.contact.age.format.duration` | `Y/M/D` | `年/月/日` |
| `widget.contact.age.format.month.day` | `M/D` | `月/日` |
| `widget.contact.age.format.total.days` | `D` | `日` |

使用 `apply_patch` 创建以下完整 catalog；格式化空格可以不同，但 key、语言和 value 必须一致：

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "Add a birth year to show age." : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Add a birth year to show age." } }, "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "添加出生年份以显示年龄。" } } } },
    "Birthdays" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Birthdays" } }, "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "生日" } } } },
    "Choose a person to show their age." : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Choose a person to show their age." } }, "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "选择联系人以显示年龄。" } } } },
    "Contact Age" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Contact Age" } }, "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "联系人年龄" } } } },
    "No birthday recorded" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "No birthday recorded" } }, "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "未记录生日" } } } },
    "No upcoming birthdays" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "No upcoming birthdays" } }, "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "暂无即将到来的生日" } } } },
    "See the next birthdays at a glance." : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "See the next birthdays at a glance." } }, "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "一眼查看接下来的生日。" } } } },
    "Selected person is no longer available." : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Selected person is no longer available." } }, "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "所选联系人已不在列表中。" } } } },
    "Tap to switch format" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Tap to switch format" } }, "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "点按切换格式" } } } },
    "Track one person's current age. Tap to switch formats." : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Track one person's current age. Tap to switch formats." } }, "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "记录一位联系人的当前年龄，点按即可切换格式。" } } } },
    "Upcoming Birthdays" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Upcoming Birthdays" } }, "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "即将到来的生日" } } } },
    "person.detail.days.until.birthday.format" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "%lld days" } }, "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "%lld 天" } } } },
    "widget.birth.duration.format" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Born %lldy %lldm %lldd" } }, "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "出生 %lld 年 %lld 月 %lld 天" } } } },
    "widget.contact.age.format.duration" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Y/M/D" } }, "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "年/月/日" } } } },
    "widget.contact.age.format.month.day" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "M/D" } }, "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "月/日" } } } },
    "widget.contact.age.format.total.days" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "D" } }, "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "日" } } } }
  },
  "version" : "1.0"
}
```

- [ ] **Step 5: 把 AppIntent metadata 改为直接 main-bundle 声明**

`SelectPersonIntent` 使用：

```swift
public static let title = LocalizedStringResource("Choose Person", table: "Intents", bundle: .main)
public static let description = IntentDescription(
  LocalizedStringResource("Choose which person this widget shows.", table: "Intents", bundle: .main))

@Parameter(
  title: LocalizedStringResource("Contact", table: "Intents", bundle: .main),
  optionsProvider: WidgetPersonOptionsProvider())
public var personID: String?
```

`ToggleContactAgeFormatIntent` 使用：

```swift
static let title = LocalizedStringResource("Toggle Age Format", table: "Intents", bundle: .main)

@Parameter(title: LocalizedStringResource("Person ID", table: "Intents", bundle: .main))
var personID: String
```

- [ ] **Step 6: 同步 App 与 extension 的 `Intents.xcstrings`**

两个 catalog 均包含同一组 key：

| Key | English | 简体中文 |
| --- | --- | --- |
| `Choose Person` | Choose Person | 选择联系人 |
| `Choose which person this widget shows.` | Choose which person this widget shows. | 选择要展示的联系人 |
| `Contact` | Contact | 联系人 |
| `Person ID` | Person ID | Person ID |
| `Toggle Age Format` | Toggle Age Format | 切换年龄格式 |

两个文件都使用以下完整内容；comments 可以保留现有更详细的说明，但不可改变 key/value：

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "Choose Person" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Choose Person" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "选择联系人" } }
      }
    },
    "Choose which person this widget shows." : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Choose which person this widget shows." } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "选择要展示的联系人" } }
      }
    },
    "Contact" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Contact" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "联系人" } }
      }
    },
    "Person ID" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Person ID" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "Person ID" } }
      }
    },
    "Toggle Age Format" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Toggle Age Format" } },
        "zh-Hans" : { "stringUnit" : { "state" : "translated", "value" : "切换年龄格式" } }
      }
    }
  },
  "version" : "1.2"
}
```

删除 `Sources/BirthTrackerWidget/Localizable.xcstrings`。

- [ ] **Step 7: 验证 JSON、引用边界与结构脚本**

Run:

```bash
python3 -m json.tool BirthTrackerPackage/Sources/BirthTrackerWidgets/Resources/Localizable.xcstrings >/dev/null
python3 -m json.tool Sources/BirthTrackerApp/Intents.xcstrings >/dev/null
python3 -m json.tool Sources/BirthTrackerWidget/Intents.xcstrings >/dev/null
rg -n '^import Localization$|L10n\.Widget' BirthTrackerPackage/Sources/BirthTrackerWidgets
./scripts/test-widget-person-intent-storage.sh
```

Expected: 三个 JSON 命令 exit 0；`rg` 无匹配并返回 1；脚本输出 `widget person intent storage and package structure tests passed`。

- [ ] **Step 8: 提交本地化边界迁移**

```bash
git add BirthTrackerPackage/Package.swift BirthTrackerPackage/Sources/BirthTrackerWidgets BirthTrackerPackage/Sources/Localization Sources/BirthTrackerApp/Intents.xcstrings Sources/BirthTrackerWidget scripts/test-widget-person-intent-storage.sh
git commit -m "refactor: package widget localization resources"
```

### Task 3: 收紧 Xcode target 并同步架构文档

**Files:**

- Modify: `project.yml`
- Modify: `doc/architecture/current-architecture.md`
- Modify: `scripts/test-widget-person-intent-storage.sh`
- Regenerate: `BirthTracker.xcodeproj`（ignored，不提交）

**Interfaces:**

- Consumes: `BirthTrackerWidgets` product 对 `Logging` 等底层模块的封装。
- Produces: 只直接依赖 `BirthTrackerWidgets` 的 extension target；描述真实目录归属的架构文档。

- [ ] **Step 1: 增加 extension 依赖断言并确认 RED**

在脚本中增加：

```bash
widget_target_block="$(awk '/^  BirthTrackerWidget:$/,/^  BirthTrackerTests:$/' "$PROJECT_FILE")"
grep -q 'product: BirthTrackerWidgets' <<<"$widget_target_block" \
  || fail "Widget extension should depend on BirthTrackerWidgets"
if grep -q 'product: Logging' <<<"$widget_target_block"; then
  fail "Widget extension should not directly depend on Logging"
fi
```

Run:

```bash
./scripts/test-widget-person-intent-storage.sh
```

Expected: FAIL with `Widget extension should not directly depend on Logging`。

- [ ] **Step 2: 删除 extension 的直接 Logging 依赖**

`project.yml` 中最终 dependency block 为：

```yaml
dependencies:
  - package: BirthTrackerPackage
    product: BirthTrackerWidgets
```

App target 对 `BirthTrackerWidgets` 的依赖保持不变。

- [ ] **Step 3: 更新当前架构文档**

把 Widgets 开头两条改为：

```markdown
- Widget extension 入口位于 `Sources/BirthTrackerWidget`，该目录只保留 `@main` bundle 壳、Info.plist 和 target 本地化资源；具体 Widget 类型、`AppIntentConfiguration`、timeline provider、entry 和 Widget preview 位于 `BirthTrackerPackage/Sources/BirthTrackerWidgets`。
- 面向 Widget 的 bundle 组合、UI、AppIntent 配置类型、模型和持久化常量放在 package 模块里，而不是 App-only 或 extension-only 代码里。
```

- [ ] **Step 4: 生成工程并运行仓库检查**

Run:

```bash
xcodegen generate
make fix
make check
git diff --check
```

Expected: XcodeGen 输出 `Generated project`；格式化完成；`make check` exit 0；`git diff --check` 无输出。

如果 XcodeGen 或后续 SwiftPM resolution 报 `safe.bareRepository is 'explicit'`，只对失败命令重跑：

```bash
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all xcodegen generate
```

- [ ] **Step 5: 提交工程依赖与文档**

```bash
git add project.yml doc/architecture/current-architecture.md scripts/test-widget-person-intent-storage.sh
git commit -m "refactor: reduce widget extension target surface"
```

### Task 4: 用 XcodeBuildMCP 验证构建、测试和资源产物

**Files:**

- Read: `.xcodebuildmcp/config.yaml`
- Inspect: `AIOutput/DerivedData/Build/Products/Debug-iphonesimulator/BirthTracker.app`
- Modify only if verification exposes a defect: files owned by Tasks 1–3

**Interfaces:**

- Consumes: 生成后的 `BirthTracker.xcodeproj`、`BirthTracker` scheme、配置中的 simulator ID。
- Produces: simulator build/test 结果，以及 App/appex/package bundle 的本地化产物证据。

- [ ] **Step 1: 加载 XcodeBuildMCP 执行规范**

调用 `xcodebuildmcp` skill，并按仓库 `AGENTS.md` 使用 MCP，不以直接 `xcodebuild` 或 `xcrun simctl` 代替。

- [ ] **Step 2: 显示并校准 active defaults**

先调用：

```text
session_show_defaults()
```

期望配置：

```yaml
projectPath: /Users/tigerguo/.codex/worktrees/5bb2/BirthTracker/BirthTracker.xcodeproj
scheme: BirthTracker
simulatorName: birth tracker 17 pro
simulatorId: F4B82181-8A72-4AC3-9C95-454DE83A0C62
```

缺失或不一致时调用：

```text
session_set_defaults(
  projectPath: "/Users/tigerguo/.codex/worktrees/5bb2/BirthTracker/BirthTracker.xcodeproj",
  scheme: "BirthTracker",
  simulatorName: "birth tracker 17 pro",
  simulatorId: "F4B82181-8A72-4AC3-9C95-454DE83A0C62"
)
```

- [ ] **Step 3: 运行 simulator build**

调用：

```text
build_sim(configuration: "Debug")
```

Expected: `BirthTracker` 与嵌入的 `BirthTrackerWidget` 均 build succeeded；AppIntents metadata processor 不报告 main-bundle 或 indirect `LocalizedStringResource` 错误。

- [ ] **Step 4: 运行 simulator test**

调用：

```text
test_sim(configuration: "Debug")
```

Expected: `BirthTrackerTests` 全部通过，失败数为 0。

- [ ] **Step 5: 检查构建产物**

从 XcodeBuildMCP 返回的 derived data 路径定位 `BirthTracker.app`，然后运行本地只读检查：

```bash
APP_PATH="AIOutput/DerivedData/Build/Products/Debug-iphonesimulator/BirthTracker.app"
test -d "$APP_PATH/PlugIns/BirthTrackerWidget.appex"
find "$APP_PATH" -path '*BirthTrackerPackage_BirthTrackerWidgets.bundle*' -print
find "$APP_PATH" -path '*Intents.strings' -print
find "$APP_PATH" -path '*BirthTrackerPackage_BirthTrackerWidgets.bundle*Localizable.strings' -print
```

Expected:

- `BirthTrackerWidget.appex` 存在；
- package bundle 至少出现在 Widget appex 内；
- App 与 Widget appex 均有 `Intents.strings`；
- package bundle 至少有 `en.lproj/Localizable.strings` 和 `zh-Hans.lproj/Localizable.strings`。

若 XcodeBuildMCP 使用其他 derived data 目录，只替换 `APP_PATH` 的前缀，不改变检查目标。

- [ ] **Step 6: 最终回归与工作树检查**

Run:

```bash
make check
git diff --check
git status --short
```

Expected: `make check` exit 0；`git diff --check` 无输出；`git status --short` 只显示实施计划本身（若计划尚未提交），或完全为空。
