# SFSafeSymbols Integration Implementation Plan

> [!WARNING]
> 本文档是归档实施计划，不是当前执行指令。其中的路径、命令和 Superpowers skills 可能已经失效；使用前请先阅读[历史资料说明](../README.md)。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 BirthTracker 中接入 `SFSafeSymbols/SFSafeSymbols`，并把现有 SF Symbol 字符串调用迁移为 typed symbol 引用。

**Architecture:** 依赖通过 Swift Package Manager 引入：package 内 SwiftUI 页面由 `BirthTrackerPackage/Package.swift` 的 `Features` target 获得依赖，Widget target 由 `project.yml` 的 XcodeGen remote package 获得依赖。源码中优先使用 `SFSymbol.<name>.rawValue` 传给现有 `LocalizedStringResource` 友好的 SwiftUI initializer，`Image` 则直接使用 `Image(systemSymbol:)`。

**Tech Stack:** Swift 6.3.2, SwiftUI, WidgetKit, Swift Package Manager, XcodeGen, SFSafeSymbols 7.0.0.

## Global Constraints

- `project.yml` 中的 iOS deployment target 保持 `"26.0"` 不变。
- `BirthTrackerPackage/Package.swift` 中的 platforms 保持 `.iOS(.v26)` 和 `.macOS(.v26)` 不变。
- 不新增本地 SF Symbol wrapper。
- 不改变现有 UI、布局、文案、交互、签名配置或 target 结构。
- `Config/Project.xcconfig` 是本地文件，不读取或提交其内容；如果缺失，仅从 `Config/Project.xcconfig.example` 复制占位文件。
- 修改 `project.yml` 后运行 `xcodegen generate`。
- 代码变更后运行 `make check`。
- Xcode build/test 使用 xcodebuildmcp；第一次 build/test 前先调用 `session_show_defaults`。

---

### Task 1: 接入 SPM 依赖配置

**Files:**
- Modify: `BirthTrackerPackage/Package.swift`
- Modify: `project.yml`

**Interfaces:**
- Consumes: 现有 `BirthTrackerPackage` target 布局，以及 XcodeGen `packages` / target `dependencies` 配置。
- Produces: `SFSafeSymbols` package dependency；`Features` target 和 `BirthTrackerWidget` target 可 import `SFSafeSymbols`。

- [ ] **Step 1: 运行配置守卫，确认当前还没有依赖**

```bash
rg 'SFSafeSymbols|SFSafeSymbols/SFSafeSymbols' BirthTrackerPackage/Package.swift project.yml
```

Expected: exit code 1，表示当前配置里还没有 `SFSafeSymbols`。

- [ ] **Step 2: 修改 `BirthTrackerPackage/Package.swift`**

Apply this patch:

```diff
diff --git a/BirthTrackerPackage/Package.swift b/BirthTrackerPackage/Package.swift
--- a/BirthTrackerPackage/Package.swift
+++ b/BirthTrackerPackage/Package.swift
@@
   products: [
     .library(name: "App", targets: ["App"]),
     .library(name: "DesignSystem", targets: ["DesignSystem"]),
     .library(name: "Features", targets: ["Features"]),
     .library(name: "Localization", targets: ["Localization"]),
     .library(name: "Models", targets: ["Models"]),
     .library(name: "Persistence", targets: ["Persistence"]),
     .library(name: "TestingSupport", targets: ["TestingSupport"]),
   ],
+  dependencies: [
+    .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols.git", .upToNextMajor(from: "7.0.0")),
+  ],
   targets: [
@@
     .target(
       name: "Features",
-      dependencies: ["DesignSystem", "Localization", "Models", "Persistence"],
+      dependencies: ["DesignSystem", "Localization", "Models", "Persistence", "SFSafeSymbols"],
       path: "Sources/Features"
     ),
```

- [ ] **Step 3: 修改 `project.yml`**

Apply this patch:

```diff
diff --git a/project.yml b/project.yml
--- a/project.yml
+++ b/project.yml
@@
 packages:
   BirthTrackerPackage:
     path: BirthTrackerPackage
+  SFSafeSymbols:
+    url: https://github.com/SFSafeSymbols/SFSafeSymbols.git
+    from: 7.0.0
@@
       - package: BirthTrackerPackage
         product: Localization
+      - package: SFSafeSymbols
+        product: SFSafeSymbols
     settings:
```

- [ ] **Step 4: 解析 Swift package，验证 package 配置可用**

```bash
cd BirthTrackerPackage && HTTP_PROXY=http://127.0.0.1:1082 HTTPS_PROXY=http://127.0.0.1:1082 ALL_PROXY=http://127.0.0.1:1082 http_proxy=http://127.0.0.1:1082 https_proxy=http://127.0.0.1:1082 all_proxy=http://127.0.0.1:1082 NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 swift package describe --type json | grep -q '"SFSafeSymbols"'
```

Expected: exit code 0。

- [ ] **Step 5: Commit dependency configuration**

```bash
git add BirthTrackerPackage/Package.swift project.yml
git commit -m "build: add SFSafeSymbols dependency

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Expected: commit succeeds with exactly those two tracked files.

---

### Task 2: 迁移现有 SF Symbol 调用

**Files:**
- Modify: `BirthTrackerPackage/Sources/Features/Timeline/PeopleTimelineView.swift`
- Modify: `BirthTrackerPackage/Sources/Features/Settings/SettingsDebugSection.swift`
- Modify: `Sources/BirthTrackerWidget/UpcomingBirthdaysWidget.swift`

**Interfaces:**
- Consumes: Task 1 produced `SFSafeSymbols` dependency for `Features` and `BirthTrackerWidget`。
- Produces: 当前 6 处 SF Symbol 调用均通过 `SFSymbol` typed reference 表达：`.calendarBadgePlus`、`.plus`、`.gearshape`、`.gift`、`.sparkles`。

- [ ] **Step 1: 运行源码守卫，确认当前仍有 raw SF Symbol 字符串**

```bash
rg '(Image\(systemName:|UIImage\(systemName:|systemImage: "[^"]+")' BirthTrackerPackage/Sources Sources/BirthTrackerWidget --glob '*.swift'
```

Expected: exit code 0，并列出 `PeopleTimelineView.swift`、`SettingsDebugSection.swift`、`UpcomingBirthdaysWidget.swift` 中的匹配。

- [ ] **Step 2: 修改 `PeopleTimelineView.swift`**

Apply this patch:

```diff
diff --git a/BirthTrackerPackage/Sources/Features/Timeline/PeopleTimelineView.swift b/BirthTrackerPackage/Sources/Features/Timeline/PeopleTimelineView.swift
--- a/BirthTrackerPackage/Sources/Features/Timeline/PeopleTimelineView.swift
+++ b/BirthTrackerPackage/Sources/Features/Timeline/PeopleTimelineView.swift
@@
 import Localization
 import Models
 import Persistence
+import SFSafeSymbols
 import SwiftData
 import SwiftUI
 import WidgetKit
@@
           ContentUnavailableView(
             L10n.Timeline.noBirthdays,
-            systemImage: "calendar.badge.plus",
+            systemImage: SFSymbol.calendarBadgePlus.rawValue,
             description: Text(L10n.Timeline.emptyDescription)
           )
@@
         ToolbarItem(placement: .primaryAction) {
-          Button(L10n.Timeline.addPerson, systemImage: "plus") {
+          Button(L10n.Timeline.addPerson, systemImage: SFSymbol.plus.rawValue) {
             isAddingPerson = true
           }
         }
@@
           } label: {
-            Label(L10n.Common.settings, systemImage: "gearshape")
+            Label(L10n.Common.settings, systemImage: SFSymbol.gearshape.rawValue)
           }
         }
@@
-      Image(systemName: "gift")
+      Image(systemSymbol: .gift)
         .font(.title2)
```

- [ ] **Step 3: 修改 `SettingsDebugSection.swift`**

Apply this patch:

```diff
diff --git a/BirthTrackerPackage/Sources/Features/Settings/SettingsDebugSection.swift b/BirthTrackerPackage/Sources/Features/Settings/SettingsDebugSection.swift
--- a/BirthTrackerPackage/Sources/Features/Settings/SettingsDebugSection.swift
+++ b/BirthTrackerPackage/Sources/Features/Settings/SettingsDebugSection.swift
@@
 import DesignSystem
 import Localization
 import Persistence
+import SFSafeSymbols
 import SwiftData
 import SwiftUI
@@
         }
 
         if storageMode == DebugStorageMode.memory.rawValue {
-          Button(L10n.Settings.generateTestData, systemImage: "sparkles") {
+          Button(L10n.Settings.generateTestData, systemImage: SFSymbol.sparkles.rawValue) {
             testDataGeneration.start(modelContext: modelContext)
           }
```

- [ ] **Step 4: 修改 `UpcomingBirthdaysWidget.swift`**

Apply this patch:

```diff
diff --git a/Sources/BirthTrackerWidget/UpcomingBirthdaysWidget.swift b/Sources/BirthTrackerWidget/UpcomingBirthdaysWidget.swift
--- a/Sources/BirthTrackerWidget/UpcomingBirthdaysWidget.swift
+++ b/Sources/BirthTrackerWidget/UpcomingBirthdaysWidget.swift
@@
 import Localization
 import Models
 import Persistence
+import SFSafeSymbols
 import SwiftUI
 import WidgetKit
@@
     var body: some View {
       VStack(alignment: .leading, spacing: 8) {
-      Label(L10n.Widget.title, systemImage: "gift")
+      Label(L10n.Widget.title, systemImage: SFSymbol.gift.rawValue)
         .font(.headline)
```

- [ ] **Step 5: 运行源码守卫，确认 raw SF Symbol 字符串已迁移**

```bash
rg '(Image\(systemName:|UIImage\(systemName:|systemImage: "[^"]+")' BirthTrackerPackage/Sources Sources/BirthTrackerWidget --glob '*.swift'
```

Expected: exit code 1。

- [ ] **Step 6: Commit symbol migration**

```bash
git add BirthTrackerPackage/Sources/Features/Timeline/PeopleTimelineView.swift BirthTrackerPackage/Sources/Features/Settings/SettingsDebugSection.swift Sources/BirthTrackerWidget/UpcomingBirthdaysWidget.swift
git commit -m "refactor: use typed SF symbols

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Expected: commit succeeds with exactly those three tracked files.

---

### Task 3: 生成工程并验证

**Files:**
- Modify if generated locally: `BirthTracker.xcodeproj` ignored by git
- Modify if missing locally: `Config/Project.xcconfig` ignored by git

**Interfaces:**
- Consumes: Task 1 dependency configuration and Task 2 typed symbol source migration。
- Produces: Generated Xcode project can resolve `SFSafeSymbols` and the repository checks pass。

- [ ] **Step 1: 准备本地 Xcode config 占位文件**

```bash
test -f Config/Project.xcconfig || cp Config/Project.xcconfig.example Config/Project.xcconfig
```

Expected: exit code 0。`Config/Project.xcconfig` remains ignored by git。

- [ ] **Step 2: 重新生成 Xcode project**

```bash
xcodegen generate
```

Expected: exit code 0，`BirthTracker.xcodeproj` regenerated and ignored by git。

- [ ] **Step 3: 检查 xcodebuildmcp 默认配置**

Tool call:

```text
xcodebuildmcp-session_show_defaults
```

Expected: active defaults include `projectPath: BirthTracker.xcodeproj`, `scheme: BirthTracker`, and an iOS Simulator target. If defaults are missing, call:

```text
xcodebuildmcp-session_set_defaults(projectPath: "<repo-root>/BirthTracker.xcodeproj", scheme: "BirthTracker", simulatorName: "configured simulator", simulatorId: "configured simulator id")
```

- [ ] **Step 4: 运行 lint 和格式检查**

```bash
make check
```

Expected: exit code 0。

- [ ] **Step 5: 运行 iOS simulator tests**

Tool call:

```text
xcodebuildmcp-test_sim(progress: true)
```

Expected: test action succeeds for scheme `BirthTracker`。

- [ ] **Step 6: 检查最终 git 状态**

```bash
git --no-pager status --short
```

Expected: no tracked source/config changes remain uncommitted. Ignored files such as `BirthTracker.xcodeproj`, `Package.resolved`, `.build`, and `Config/Project.xcconfig` do not need to be committed。
