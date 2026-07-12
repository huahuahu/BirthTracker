# Widget Intents 独立模块设计

## 背景

当前 `BirthTrackerWidgets` SwiftPM product 同时包含 Widget UI、timeline provider、Widget 配置 Intent 和交互式 Intent。`BirthTracker` App target 为了让系统发现 package 中的 AppIntents，必须直接链接整个 `BirthTrackerWidgets` product，因此 Xcode 的 App target 会显示 `BirthTrackerWidgets`，并把 Widget UI 实现与资源一并带入宿主 App 的依赖图。

本次调整要把 AppIntent 系统集成与 Widget UI 实现拆成两个职责单一的 module，同时保持两个现有 Widget 的配置、显示、数据读取和交互行为不变。

## 目标

- 在现有 `BirthTrackerPackage` 中新增 `BirthTrackerWidgetIntents` library product 和 target。
- `BirthTracker` App target 只链接 `BirthTrackerWidgetIntents`，不再直接链接 `BirthTrackerWidgets`。
- `BirthTrackerWidget` extension target 显式链接 `BirthTrackerWidgetIntents` 与 `BirthTrackerWidgets`。
- `BirthTrackerWidgets` target 依赖 `BirthTrackerWidgetIntents`，继续拥有 Widget UI、provider、entry、preview 和 Widget UI 本地化资源。
- 保持 AppIntents metadata、App/extension main-bundle 本地化、Widget package 资源及 Widget 编辑界面完整。
- 使用结构回归检查、仓库检查、XcodeBuildMCP 构建与测试、构建产物检查和模拟器 Widget 编辑流程完成验证。

## 非目标

- 不创建第二个 Swift package 目录。
- 不改变 `SelectPersonIntent`、`ToggleContactAgeFormatIntent` 的用户行为或文案。
- 不改变 Widget 快照、App Group、SwiftData 或年龄显示偏好的存储方式。
- 不调整 Widget 布局、刷新策略或支持的 family。
- 不把 `Intents.xcstrings` 移入 SwiftPM resource bundle。

## 方案选择

### 采用：同一 package 内拆分独立 Intent product

新增 `BirthTrackerWidgetIntents` target，迁入所有 AppIntent 类型和 `AppIntentsPackage`。`BirthTrackerWidgets` 通过 target dependency 使用这些公开类型；App 与 extension 通过 XcodeGen 对 product 的显式依赖参与 AppIntents metadata 提取。

这个方案与 HHappyDocs 的 `HDiaryWidgetIntents`/`HDiaryWidgetFeature` 边界一致，能让 Xcode 中 App target 的依赖准确表达“只需要 Intent，不需要 Widget UI”。它复用现有 package 和底层模块，改动范围最小且职责清晰。

### 不采用：只删除 App 对 `BirthTrackerWidgets` 的依赖

这会让 Xcode 列表更简洁，但没有为 package 中的 AppIntent 提供新的宿主侧入口，也无法证明 AppIntents metadata 仍然完整。

### 不采用：新建独立 Swift package

独立 package 能提供目录级隔离，但会增加 package 引用和底层模块连接成本；当前只需要 target/module 边界，不需要新的 package 边界。

## 目标模块结构

```text
BirthTrackerPackage/Sources/BirthTrackerWidgetIntents/
├── BirthTrackerWidgetIntentsAppIntentsPackage.swift
├── PersonSelectionIntent.swift
└── ToggleContactAgeFormatIntent.swift

BirthTrackerPackage/Sources/BirthTrackerWidgets/
├── BirthTrackerWidgetsBundle.swift
├── ContactAge/
├── UpcomingBirthdays/
├── Shared/
│   └── WidgetL10n.swift
└── Resources/
    └── Localizable.xcstrings
```

`BirthTrackerWidgetIntents` 依赖：

- `Logging`：联系人选项查询日志。
- `Persistence`：读取 Widget 快照、切换年龄格式偏好并访问 Widget kind。

`BirthTrackerWidgets` 保留现有的 `Logging`、`Models`、`Persistence`、`SFSafeSymbols` 依赖，并新增对 `BirthTrackerWidgetIntents` 的 target dependency。Widget 源文件在引用 Intent 类型的位置显式 `import BirthTrackerWidgetIntents`。

## AppIntents 注册与可见性

`BirthTrackerWidgetIntentsAppIntentsPackage` 是新 module 对外暴露的 framework `AppIntentsPackage`。App 与 Widget extension 各自在宿主 bundle 中声明一个 `AppIntentsPackage`，并通过 `includedPackages` 包含该 framework package；这符合 Apple 对跨 framework 复用 App Intents 的注册方式，也让 metadata extractor 能明确追踪依赖。

跨 module 使用的类型提供最小公开 API：

- `SelectPersonIntent`、`WidgetPersonOptionsProvider` 保持公开。
- `ToggleContactAgeFormatIntent` 改为公开，只暴露 AppIntent conformance、无参初始化和按联系人 UUID 初始化所需成员。
- Intent 内部错误类型继续保持 module 内部可见。

Widget extension 壳继续只组合 package 提供的 `BirthTrackerWidgetsBundle`，并额外承载 extension 宿主的 `AppIntentsPackage` 注册。extension 对 Intent product 的显式依赖用于链接和 metadata 提取；Widget UI module 对 Intent target 的依赖用于编译期类型访问。

## XcodeGen 依赖

`project.yml` 的目标依赖调整为：

```text
BirthTracker app
├── App
├── DesignSystem
├── BirthTrackerWidgetIntents
└── embeds BirthTrackerWidget.appex

BirthTrackerWidget extension
├── BirthTrackerWidgets
└── BirthTrackerWidgetIntents
```

`BirthTrackerWidgets` 不再出现在 App target 的 Frameworks, Libraries, and Embedded Content 中；`BirthTrackerWidgetIntents` 会作为不嵌入的 SwiftPM library product 出现。`BirthTrackerWidget.appex` 仍是唯一嵌入 App 的 extension。

## 本地化与资源

AppIntent metadata 继续直接使用：

```swift
LocalizedStringResource("Source Key", table: "Intents", bundle: .main)
```

因此以下文件都必须保留且内容一致：

- `Sources/BirthTrackerApp/Intents.xcstrings`
- `Sources/BirthTrackerWidget/Intents.xcstrings`

普通 Widget UI 文案继续由 `BirthTrackerWidgets/Resources/Localizable.xcstrings` 和 `WidgetL10n` 的 `Bundle.module` 访问。Intent module 不声明 SwiftPM resources，避免 AppIntents metadata 再次读取错误 bundle。

## 错误处理与行为保持

- `SelectPersonIntent` 继续通过 `WidgetSnapshotStore.fetchAll()` 提供联系人选项，错误原样向 AppIntents 系统传播。
- `ToggleContactAgeFormatIntent` 继续拒绝非法 UUID，切换 App Group 偏好，并刷新联系人年龄 Widget timeline。
- module 移动不引入 fallback、重试或新的运行时分支。
- 任何 metadata 导出、资源打包或 Widget 编辑失败都视为拆分未完成，而不是通过删除本地化或降低检查强度绕过。

## 测试与验证

### TDD 结构回归

先更新 `scripts/test-widget-person-intent-storage.sh`，让它在旧结构上因缺少 `BirthTrackerWidgetIntents` product/target 和错误的 App 依赖而失败。实现后脚本必须验证：

- 新 product/target 存在，Intent 文件只位于新 target。
- `BirthTrackerWidgets` target 依赖新 Intent target。
- App 依赖 Intent product，且不依赖 Widget UI product。
- extension 显式依赖两个 product。
- App 与 Widget extension 各自声明宿主 `AppIntentsPackage`，其 `includedPackages` 包含 `BirthTrackerWidgetIntentsAppIntentsPackage`。
- Widget 源文件从新 module 导入 Intent 类型。
- AppIntent 字符串仍使用 `Intents` table 和 `.main`。
- App 与 extension 的 `Intents.xcstrings` 逐字节一致。

### 仓库检查

- 运行 `xcodegen generate` 更新被忽略的 Xcode 工程。
- 运行 `make fix`，再运行 `make check`。
- 使用 JSON parser 验证三个相关 `.xcstrings` catalog。

### XcodeBuildMCP

首次 build/run/test 前读取 active defaults，并与 `.xcodebuildmcp/config.yaml` 对齐。随后：

- simulator build `BirthTracker` scheme；
- simulator test `BirthTracker` scheme；
- 检查生成 App 与 appex 的 AppIntents metadata；
- 检查 App/appex 的 `Intents.strings` 与 appex 中的 `BirthTrackerPackage_BirthTrackerWidgets.bundle`；
- 安装并运行 App，在模拟器添加 Widget，进入编辑界面，确认联系人配置项可显示并可加载候选联系人。

## 文档更新

更新 `doc/architecture/current-architecture.md`，明确：

- `BirthTrackerWidgetIntents` 管理跨 App/extension 的 AppIntent 类型。
- `BirthTrackerWidgets` 只管理 Widget UI、provider、entry、preview 和 package UI 本地化。
- App 不再直接依赖 Widget UI module。

## 完成标准

- App target 的 Frameworks 列表不再包含 `BirthTrackerWidgets`，而包含 `BirthTrackerWidgetIntents`。
- extension 能构建并包含两个现有 Widget。
- AppIntents metadata 在 App 与 extension 构建产物中均存在，且 Intent 本地化完整。
- Widget 编辑界面能显示联系人参数并加载候选联系人。
- `make check`、XcodeBuildMCP simulator build 和 simulator test 全部通过。
- `/Users/tigerguo/git/BirthTracker` 中现有未提交修改未被更改。
