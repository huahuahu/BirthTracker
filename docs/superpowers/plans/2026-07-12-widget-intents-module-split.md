# Widget Intents 独立模块实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 AppIntent 从 `BirthTrackerWidgets` 拆到独立的 `BirthTrackerWidgetIntents` SwiftPM product，使 App 不再链接 Widget UI module，同时保持 metadata、本地化和 Widget 编辑行为完整。

**Architecture:** `BirthTrackerWidgetIntents` 拥有两个 Intent 与 `AppIntentsPackage`，依赖 `Logging` 和 `Persistence`；`BirthTrackerWidgets` 依赖该 target 并只保留 Widget UI、provider、entry、preview 和 package UI 资源。App 与 extension 通过 XcodeGen 显式链接 Intent product，extension 额外链接 Widget UI product。

**Tech Stack:** Swift 6、SwiftPM、AppIntents、WidgetKit、SwiftUI、XcodeGen、Bash 回归脚本、XcodeBuildMCP

## Global Constraints

- 保持 iOS 26 deployment target 与现有 Swift 工具链设置不变。
- AppIntent metadata 字符串必须直接使用 `table: "Intents", bundle: .main`。
- App 与 extension 的 `Intents.xcstrings` 必须逐字节一致。
- Widget UI 字符串继续位于 `BirthTrackerWidgets/Resources/Localizable.xcstrings`，通过 `Bundle.module` 读取。
- 不改变 Widget 行为、布局、持久化、App Group 或刷新策略。
- 不修改 `/Users/tigerguo/git/BirthTracker` 中现有未提交变更。

---

### Task 1: 用结构回归脚本定义新模块边界

**Files:**
- Modify: `scripts/test-widget-person-intent-storage.sh`
- Test: `scripts/test-widget-person-intent-storage.sh`

**Interfaces:**
- Consumes: 当前 `BirthTrackerWidgets` 目录、`Package.swift` 与 `project.yml`。
- Produces: 对 `BirthTrackerWidgetIntents` product/target、文件归属、XcodeGen 依赖和 App 注册入口的可执行结构契约。

- [ ] **Step 1: 写入会在旧结构上失败的断言**

将 Intent 路径变量改成新 target，并增加 App 入口变量：

```bash
WIDGET_PACKAGE_DIR="$ROOT/BirthTrackerPackage/Sources/BirthTrackerWidgets"
WIDGET_INTENTS_PACKAGE_DIR="$ROOT/BirthTrackerPackage/Sources/BirthTrackerWidgetIntents"
WIDGET_EXTENSION_DIR="$ROOT/Sources/BirthTrackerWidget"
INTENT_FILE="$WIDGET_INTENTS_PACKAGE_DIR/PersonSelectionIntent.swift"
TOGGLE_INTENT_FILE="$WIDGET_INTENTS_PACKAGE_DIR/ToggleContactAgeFormatIntent.swift"
INTENTS_PACKAGE_FILE="$WIDGET_INTENTS_PACKAGE_DIR/BirthTrackerWidgetIntentsAppIntentsPackage.swift"
APP_ENTRY_FILE="$ROOT/Sources/BirthTrackerApp/BirthTrackerApp.swift"
```

把三个 Intent 文件加入 `expected_intent_package_files`，从 `expected_package_files` 删除旧位置，并增加以下语义断言：

```bash
grep -q 'library(name: "BirthTrackerWidgetIntents"' "$PACKAGE_FILE" \
  || fail "Package.swift should expose a BirthTrackerWidgetIntents product"
grep -q 'name: "BirthTrackerWidgetIntents"' "$PACKAGE_FILE" \
  || fail "Package.swift should define a BirthTrackerWidgetIntents target"
grep -q 'dependencies: \["BirthTrackerWidgetIntents", "Logging", "Models", "Persistence", "SFSafeSymbols"\]' "$PACKAGE_FILE" \
  || fail "BirthTrackerWidgets should depend on BirthTrackerWidgetIntents"

app_target_block="$(awk '/^  BirthTracker:$/,/^  BirthTrackerWidget:$/' "$PROJECT_FILE")"
grep -q 'product: BirthTrackerWidgetIntents' <<<"$app_target_block" \
  || fail "BirthTracker app should depend on BirthTrackerWidgetIntents"
if grep -q 'product: BirthTrackerWidgets' <<<"$app_target_block"; then
  fail "BirthTracker app should not depend on BirthTrackerWidgets"
fi

widget_target_block="$(awk '/^  BirthTrackerWidget:$/,/^  BirthTrackerTests:$/' "$PROJECT_FILE")"
grep -q 'product: BirthTrackerWidgets' <<<"$widget_target_block" \
  || fail "Widget extension should depend on BirthTrackerWidgets"
grep -q 'product: BirthTrackerWidgetIntents' <<<"$widget_target_block" \
  || fail "Widget extension should depend on BirthTrackerWidgetIntents"

grep -q '^import BirthTrackerWidgetIntents$' "$APP_ENTRY_FILE" \
  || fail "BirthTrackerApp should import BirthTrackerWidgetIntents"
grep -q '^struct BirthTrackerAppIntentsPackage: AppIntentsPackage' "$APP_ENTRY_FILE" \
  || fail "BirthTrackerApp should define a host AppIntentsPackage"
grep -Fq '[BirthTrackerWidgetIntentsAppIntentsPackage.self]' "$APP_ENTRY_FILE" \
  || fail "BirthTrackerApp host package should include BirthTrackerWidgetIntents"
grep -q '^struct BirthTrackerWidgetExtensionAppIntentsPackage: AppIntentsPackage' "$BUNDLE_FILE" \
  || fail "BirthTrackerWidget should define a host AppIntentsPackage"
grep -Fq '[BirthTrackerWidgetIntentsAppIntentsPackage.self]' "$BUNDLE_FILE" \
  || fail "BirthTrackerWidget host package should include BirthTrackerWidgetIntents"
```

检查旧文件位置不存在、使用 Intent 的五个 Widget 文件显式导入新 module，并把 Toggle Intent 的本地化断言改为读取 `$TOGGLE_INTENT_FILE`。

- [ ] **Step 2: 运行结构脚本并确认 RED**

Run:

```bash
bash scripts/test-widget-person-intent-storage.sh
```

Expected: FAIL，首个失败原因为 `BirthTrackerPackage/Sources/BirthTrackerWidgetIntents/PersonSelectionIntent.swift should exist` 或缺少 `BirthTrackerWidgetIntents` product，而不是脚本语法错误。

- [ ] **Step 3: 提交 RED 测试**

```bash
git add scripts/test-widget-person-intent-storage.sh
git commit -m "test: require standalone widget intents module"
```

### Task 2: 创建 `BirthTrackerWidgetIntents` product 并移动 Intent

**Files:**
- Modify: `BirthTrackerPackage/Package.swift`
- Create: `BirthTrackerPackage/Sources/BirthTrackerWidgetIntents/BirthTrackerWidgetIntentsAppIntentsPackage.swift`
- Create: `BirthTrackerPackage/Sources/BirthTrackerWidgetIntents/PersonSelectionIntent.swift`
- Create: `BirthTrackerPackage/Sources/BirthTrackerWidgetIntents/ToggleContactAgeFormatIntent.swift`
- Delete: `BirthTrackerPackage/Sources/BirthTrackerWidgets/Shared/BirthTrackerWidgetsAppIntentsPackage.swift`
- Delete: `BirthTrackerPackage/Sources/BirthTrackerWidgets/Shared/PersonSelectionIntent.swift`
- Delete: `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ToggleContactAgeFormatIntent.swift`
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeWidget.swift`
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeProvider.swift`
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeWidgetView.swift`
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/UpcomingBirthdays/UpcomingBirthdaysWidget.swift`
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/UpcomingBirthdays/UpcomingBirthdaysProvider.swift`

**Interfaces:**
- Consumes: `Logging.BirthLogger`、`Persistence.WidgetSnapshotStore`、`Persistence.ContactAgeFormatPreferenceStore`、`Persistence.BirthTrackerWidgetKind`。
- Produces: `BirthTrackerWidgetIntentsAppIntentsPackage`、`SelectPersonIntent`、`WidgetPersonOptionsProvider`、`ToggleContactAgeFormatIntent`。

- [ ] **Step 1: 在 `Package.swift` 声明 product 与 target**

在 products 中增加：

```swift
.library(name: "BirthTrackerWidgetIntents", targets: ["BirthTrackerWidgetIntents"]),
```

在 `BirthTrackerWidgets` 前增加 target，并更新 Widget target 依赖：

```swift
.target(
  name: "BirthTrackerWidgetIntents",
  dependencies: ["Logging", "Persistence"],
  path: "Sources/BirthTrackerWidgetIntents"
),
.target(
  name: "BirthTrackerWidgets",
  dependencies: ["BirthTrackerWidgetIntents", "Logging", "Models", "Persistence", "SFSafeSymbols"],
  path: "Sources/BirthTrackerWidgets",
  resources: [.process("Resources")]
),
```

- [ ] **Step 2: 移动配置 Intent 与 AppIntents package**

新 package type 为：

```swift
import AppIntents

public struct BirthTrackerWidgetIntentsAppIntentsPackage: AppIntentsPackage {
  public init() {}
}
```

`PersonSelectionIntent.swift` 内容保持不变，只移动到新 target。

- [ ] **Step 3: 移动并公开交互式 Intent**

`ToggleContactAgeFormatIntent.swift` 保持原错误处理与 `perform()` 逻辑，跨 module API 改为：

```swift
public struct ToggleContactAgeFormatIntent: AppIntent {
  public static let title = LocalizedStringResource("Toggle Age Format", table: "Intents", bundle: .main)

  @Parameter(title: LocalizedStringResource("Person ID", table: "Intents", bundle: .main))
  public var personID: String

  public init() {}

  public init(personID: UUID) {
    self.personID = personID.uuidString
  }

  public func perform() async throws -> some IntentResult {
    // 保留现有 UUID 校验、偏好切换、timeline reload 与 .result()
  }
}
```

- [ ] **Step 4: 更新 Widget UI module 的显式 imports**

在以下文件的 imports 中增加 `import BirthTrackerWidgetIntents`：

```text
ContactAge/ContactAgeWidget.swift
ContactAge/ContactAgeProvider.swift
ContactAge/ContactAgeWidgetView.swift
UpcomingBirthdays/UpcomingBirthdaysWidget.swift
UpcomingBirthdays/UpcomingBirthdaysProvider.swift
```

- [ ] **Step 5: 运行 SwiftPM 编译检查**

Run:

```bash
swift test --package-path BirthTrackerPackage
```

Expected: package 构建与测试通过；若外部依赖需要网络，不修改全局 Git config，按仓库代理与 one-shot `safe.bareRepository` 规则重试。

### Task 3: 切换 App/extension 的 XcodeGen 依赖并让结构测试转绿

**Files:**
- Modify: `project.yml`
- Modify: `Sources/BirthTrackerApp/BirthTrackerApp.swift`
- Test: `scripts/test-widget-person-intent-storage.sh`

**Interfaces:**
- Consumes: `BirthTrackerWidgetIntentsAppIntentsPackage`。
- Produces: App 只链接 Intent product；extension 显式链接 Intent 与 Widget UI products；App 对 metadata-only module 有源码级保留引用。

- [ ] **Step 1: 更新 `project.yml`**

App dependencies 改为：

```yaml
      - package: BirthTrackerPackage
        product: App
      - package: BirthTrackerPackage
        product: DesignSystem
      - package: BirthTrackerPackage
        product: BirthTrackerWidgetIntents
      - target: BirthTrackerWidget
        embed: true
```

Widget extension dependencies 改为：

```yaml
      - package: BirthTrackerPackage
        product: BirthTrackerWidgets
      - package: BirthTrackerPackage
        product: BirthTrackerWidgetIntents
```

- [ ] **Step 2: 在 App 与 Widget extension 注册 AppIntents package**

修改 `BirthTrackerApp.swift`：

```swift
import App
import AppIntents
import BirthTrackerWidgetIntents
import DesignSystem
import SwiftUI

struct BirthTrackerAppIntentsPackage: AppIntentsPackage {
  static var includedPackages: [any AppIntentsPackage.Type] {
    [BirthTrackerWidgetIntentsAppIntentsPackage.self]
  }
}

@main
struct BirthTrackerApp: App {
  @AppStorage(AppSettingsKey.appearanceMode)
  private var appearanceMode = AppearanceMode.system.rawValue

  var body: some Scene {
    WindowGroup {
      BirthTrackerRootView()
        .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
    }
  }
}
```

同时在 `BirthTrackerWidgetBundle.swift` 声明 `BirthTrackerWidgetExtensionAppIntentsPackage`，其 `includedPackages` 同样返回 `[BirthTrackerWidgetIntentsAppIntentsPackage.self]`。

- [ ] **Step 3: 运行结构脚本并确认 GREEN**

Run:

```bash
bash scripts/test-widget-person-intent-storage.sh
```

Expected: `widget person intent storage and package structure tests passed`。

- [ ] **Step 4: 提交 module 与 XcodeGen 变更**

```bash
git add BirthTrackerPackage/Package.swift \
  BirthTrackerPackage/Sources/BirthTrackerWidgetIntents \
  BirthTrackerPackage/Sources/BirthTrackerWidgets \
  Sources/BirthTrackerApp/BirthTrackerApp.swift \
  project.yml
git commit -m "refactor: split widget intents module"
```

### Task 4: 更新真实架构文档并运行仓库检查

**Files:**
- Modify: `doc/architecture/current-architecture.md`
- Generated, ignored: `BirthTracker.xcodeproj`

**Interfaces:**
- Consumes: 已实现的 target/module 边界。
- Produces: 与源码一致的架构说明和重新生成的 Xcode 工程。

- [ ] **Step 1: 更新 Widgets 架构段落**

明确记录：

```markdown
- 跨 App 与 Widget extension 使用的 `WidgetConfigurationIntent`、交互式 `AppIntent` 和 `AppIntentsPackage` 位于 `BirthTrackerPackage/Sources/BirthTrackerWidgetIntents`。
- `BirthTrackerWidgets` 只负责 Widget bundle、UI、provider、entry、preview 和 package UI 本地化，并依赖 `BirthTrackerWidgetIntents`。
- App target 只直接依赖 `BirthTrackerWidgetIntents`；Widget extension 同时依赖 `BirthTrackerWidgets` 与 `BirthTrackerWidgetIntents`。
- App 与 Widget extension 各自声明宿主 `AppIntentsPackage`，并通过 `includedPackages` 注册 `BirthTrackerWidgetIntentsAppIntentsPackage`。
```

- [ ] **Step 2: 重新生成 Xcode 工程**

Run:

```bash
xcodegen generate
```

Expected: `Generated project at .../BirthTracker.xcodeproj`。

- [ ] **Step 3: 验证 string catalogs**

```bash
python3 -m json.tool Sources/BirthTrackerApp/Intents.xcstrings >/dev/null
python3 -m json.tool Sources/BirthTrackerWidget/Intents.xcstrings >/dev/null
python3 -m json.tool BirthTrackerPackage/Sources/BirthTrackerWidgets/Resources/Localizable.xcstrings >/dev/null
cmp Sources/BirthTrackerApp/Intents.xcstrings Sources/BirthTrackerWidget/Intents.xcstrings
```

Expected: 全部退出码为 0。

- [ ] **Step 4: 格式化并运行完整仓库检查**

```bash
make fix
make check
```

Expected: 所有脚本与 SwiftLint 通过，无 warnings/errors。

- [ ] **Step 5: 提交文档更新**

```bash
git add doc/architecture/current-architecture.md
git commit -m "docs: document widget intents boundary"
```

### Task 5: 用 XcodeBuildMCP 验证 metadata、资源与 Widget 编辑界面

**Files:**
- Read: `.xcodebuildmcp/config.yaml`
- Inspect: `AIOutput/DerivedData/Build/Products/Debug-iphonesimulator/BirthTracker.app`

**Interfaces:**
- Consumes: 生成后的 `BirthTracker.xcodeproj`、`BirthTracker` scheme 与配置的 simulator。
- Produces: build/test 结果、App/appex metadata 与资源证据、Widget 编辑 UI 证据。

- [ ] **Step 1: 建立 XcodeBuildMCP session context**

先调用 `session_show_defaults`。若 CLI 不提供该 action，则读取 `.xcodebuildmcp/config.yaml` 并在每条 CLI 调用显式传入：

```text
projectPath: /Users/tigerguo/.codex/worktrees/d6bc/BirthTracker/BirthTracker.xcodeproj
scheme: BirthTracker
simulatorId: F4B82181-8A72-4AC3-9C95-454DE83A0C62
```

- [ ] **Step 2: simulator build 与 test**

通过 XcodeBuildMCP 对 `BirthTracker` scheme 执行 simulator build，再执行 simulator test，DerivedData 使用：

```text
/Users/tigerguo/.codex/worktrees/d6bc/BirthTracker/AIOutput/DerivedData
```

Expected: build/test 均成功且 AppIntents metadata processor 无错误。

- [ ] **Step 3: 检查构建产物**

验证：

```text
BirthTracker.app/PlugIns/BirthTrackerWidget.appex
BirthTracker.app/PlugIns/BirthTrackerWidget.appex/BirthTrackerPackage_BirthTrackerWidgets.bundle
BirthTracker.app/en.lproj/Intents.strings
BirthTracker.app/zh-Hans.lproj/Intents.strings
BirthTracker.app/PlugIns/BirthTrackerWidget.appex/en.lproj/Intents.strings
BirthTracker.app/PlugIns/BirthTrackerWidget.appex/zh-Hans.lproj/Intents.strings
```

并确认 App target 的生成工程 Frameworks phase 包含 `BirthTrackerWidgetIntents`、不包含 `BirthTrackerWidgets`。

- [ ] **Step 4: 验证 Widget 编辑界面**

用 XcodeBuildMCP build-and-run 安装 App；通过已启用的 UI automation 打开主屏幕 Widget gallery，添加 BirthTracker Widget，长按进入编辑，确认 `Contact` 参数可见并能加载联系人候选项。保存一张 UI screenshot 到 `AIOutput/` 作为本地证据；该目录不提交。

- [ ] **Step 5: 最终差异与外部 checkout 审计**

```bash
git status --short
git diff HEAD~3 --check
git -C /Users/tigerguo/git/BirthTracker status --short
```

Expected: 当前 branch 只包含计划内改动；`/Users/tigerguo/git/BirthTracker` 仍保留原有三处用户修改，没有新增变化。
