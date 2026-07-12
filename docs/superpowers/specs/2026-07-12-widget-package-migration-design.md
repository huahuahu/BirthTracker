# Widget 完整迁移到 Swift Package 设计

## 背景

当前项目已经通过本地 Swift package `BirthTrackerPackage` 暴露 `BirthTrackerWidgets` product，但 Widget 实现仍分散在两个位置：

- `BirthTrackerPackage/Sources/BirthTrackerWidgets` 保存 Widget View、AppIntent 和部分辅助逻辑；
- `Sources/BirthTrackerWidget` 保存具体 Widget、timeline provider、entry、preview 和 `@main` bundle 入口。

参考 `/Users/tigerguo/git/HHappyDocs` 的结构，本次迁移要让 Swift package 拥有完整 Widget 功能，XcodeGen 管理的 Widget extension target 只保留系统入口和无法放入 package 的 target 资源。

## 目标

- 所有 Widget 业务实现归属 `BirthTrackerPackage` 中现有的 `BirthTrackerWidgets` target。
- `Sources/BirthTrackerWidget` 中只保留一个 Swift 文件，即 `@main` extension 壳。
- 减少 `project.yml` 中 Widget extension 的直接依赖，让依赖由 package target 封装。
- 保持现有两个 Widget 的外观、配置、数据读取、刷新和交互行为不变。
- 保证 AppIntents metadata、Widget UI 本地化和 extension 展示名称仍被正确打包。
- 通过结构检查、仓库检查、XcodeBuildMCP 构建与测试以及产物检查完成验收。

## 非目标

- 不新建第二个独立 Swift package 目录。
- 不重构 Widget 的产品行为、布局或持久化模型。
- 不改变 App Group、SwiftData Widget 快照或联系人年龄格式偏好的存储方式。
- 不借迁移扩大无关类型的访问级别或重构 App 代码。

## 方案选择

### 采用方案：扩充现有 `BirthTrackerWidgets` target

继续使用 `BirthTrackerPackage`，把具体 Widget、provider、entry 和 preview 移入现有 `BirthTrackerWidgets` target。新增 package 内部真正拥有实现的 `BirthTrackerWidgetsBundle`，extension 的 `@main` bundle 只委托它的 `body`。

这个方案与 HHappyDocs 的 `HDiaryLibrary/HDiaryWidgetFeature` 模式一致，复用现有 package 依赖关系，也最符合“Xcode 直接管理的文件越少越好”的目标。

### 未采用方案：新建独立 `BirthTrackerWidgetsPackage`

独立 package 会提供更强的目录隔离，但需要重新连接 `Models`、`Persistence`、`Logging`、`Localization` 和 `SFSafeSymbols`，同时增加 Xcode package 引用和维护成本。本次迁移不需要这种额外边界。

### 未采用方案：保留当前混合结构

只保留现有 package View 和 extension provider 的拆分方式改动最少，但 Xcode 仍直接管理大部分 Widget 实现，不能达到本次目标。

## 目标架构

迁移后的主要目录如下：

```text
Sources/BirthTrackerWidget/
├── BirthTrackerWidgetBundle.swift
├── Info.plist
├── InfoPlist.xcstrings
└── Intents.xcstrings

BirthTrackerPackage/Sources/BirthTrackerWidgets/
├── BirthTrackerWidgetsBundle.swift
├── ContactAge/
│   ├── ContactAgeDurationFormatter.swift
│   ├── ContactAgeEntry.swift
│   ├── ContactAgeProvider.swift
│   ├── ContactAgeWidget.swift
│   ├── ContactAgeWidgetPreviews.swift
│   ├── ContactAgeWidgetView.swift
│   └── ToggleContactAgeFormatIntent.swift
├── UpcomingBirthdays/
│   ├── UpcomingBirthdaysEntry.swift
│   ├── UpcomingBirthdaysProvider.swift
│   ├── UpcomingBirthdaysWidget.swift
│   ├── UpcomingBirthdaysWidgetPreviews.swift
│   └── UpcomingBirthdaysWidgetView.swift
├── Shared/
│   ├── BirthTrackerWidgetsAppIntentsPackage.swift
│   ├── PersonSelectionIntent.swift
│   └── WidgetL10n.swift
└── Resources/
    └── Localizable.xcstrings
```

`BirthTrackerWidgetBundle.swift` 是 extension 唯一的 Swift 文件，结构为：

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

package 中的 `BirthTrackerWidgetsBundle` 提供公开初始化方法和公开 `body`，并组合 `UpcomingBirthdaysWidget` 与 `ContactAgeWidget`。具体 Widget 和其他实现类型保持 package 内部可见，不因为跨模块入口而全部改成 `public`。

## 依赖与数据流

数据流保持不变：

1. App 将主数据库中的人物转换成扁平 Widget 快照。
2. App 把快照写入 App Group 中独立的 Widget SwiftData store。
3. package 内的 timeline provider 通过 `Persistence` 读取快照。
4. provider 生成 entry，具体 Widget 将 entry 交给 package 内的 View 渲染。
5. extension 壳只向 WidgetKit 暴露 package 的 `WidgetBundle`。

`BirthTrackerWidgets` target 继续依赖 `Localization`、`Logging`、`Models`、`Persistence` 和 `SFSafeSymbols`。App target 继续依赖 `BirthTrackerWidgets`，以便系统从宿主 App 导出并实例化 Widget configuration intent。Widget extension 在 `project.yml` 中只直接依赖 `BirthTrackerWidgets`，移除对 `Logging` 的直接依赖。

provider 现有的错误捕获、日志记录、空数据 fallback 和刷新策略原样迁移，不增加新的运行时错误分支。

## 本地化与资源边界

SwiftPM 资源和 AppIntents metadata 使用不同 bundle 规则，因此本地化按职责拆分。

### Package 资源

Widget configuration 的展示名称、描述、Widget 正文和提示信息放在 `BirthTrackerWidgets/Resources/Localizable.xcstrings`。`Package.swift` 为 `BirthTrackerWidgets` 声明 `.process("Resources")`，`WidgetL10n` 通过 `Bundle.module` 提供类型明确的 Widget 字符串入口。

这些字符串不再由 Widget extension 的 `Localizable.xcstrings` 管理；迁移完成后删除该空文件。

### Main bundle 资源

AppIntent 的 title、description 和 parameter title 使用直接声明的：

```swift
LocalizedStringResource(
  "Source Key",
  defaultValue: "English Value",
  table: "Intents",
  bundle: .main
)
```

`Intents.xcstrings` 同时存在于 App target 和 Widget extension target，确保两个 target 导出 AppIntents metadata 时都能从自己的 main bundle 找到相同 key。这里不通过间接常量或 `Bundle.module` 构造 AppIntent metadata 字符串。

`InfoPlist.xcstrings` 和 `Info.plist` 继续留在 Widget extension target，因为它们描述并本地化 extension 自身，不属于 package 业务资源。

## 工程配置

- `BirthTrackerPackage/Package.swift` 为 `BirthTrackerWidgets` target 增加 package resources 声明。
- `project.yml` 中 Widget extension 只保留对 `BirthTrackerWidgets` product 的直接依赖。
- App target 保留对 `BirthTrackerWidgets` product 的依赖。
- 迁移文件后运行 `xcodegen generate`，重新生成被忽略的 `BirthTracker.xcodeproj`。
- `doc/architecture/current-architecture.md` 同步记录新的真实结构。

## 验证设计

### 结构回归检查

更新 `scripts/test-widget-person-intent-storage.sh`，至少验证：

- `Sources/BirthTrackerWidget` 只有一个 Swift 文件；
- extension 壳导入 `BirthTrackerWidgets` 并委托 `BirthTrackerWidgetsBundle().body`；
- package 中存在完整的 Widget bundle、Widget、provider、entry 和 preview；
- extension 不再直接依赖 `Logging`；
- App 与 extension 均依赖 `BirthTrackerWidgets`；
- `BirthTrackerWidgets` target 声明并处理 `Resources`；
- AppIntent 使用 `Intents` table 和 `.main` bundle；
- extension 中不再存在 Widget UI 使用的 `Localizable.xcstrings`。

### 仓库检查

- 使用 JSON parser 验证所有新增或修改的 `.xcstrings` 文件；
- 运行 `make fix` 处理格式化和 SwiftLint 自动修复；
- 运行 `make check` 执行仓库完整检查。

### XcodeBuildMCP 验证

首次调用前读取 XcodeBuildMCP active defaults；若缺失或与 `.xcodebuildmcp/config.yaml` 不一致，则按仓库绝对路径设置 defaults。随后：

- 对 `BirthTracker` scheme 执行 simulator build；
- 对 `BirthTracker` scheme 执行 simulator test；
- 以构建产物而不是仅凭源码推断资源是否正确打包。

产物必须包含：

- `BirthTracker.app/PlugIns/BirthTrackerWidget.appex`；
- Widget extension 中的 `BirthTrackerPackage_BirthTrackerWidgets.bundle`；
- App 和 Widget extension 对应语言目录下的 `Intents.strings`；
- package bundle 对应语言目录下的 Widget UI `Localizable.strings`。

## 风险与控制

### AppIntents metadata 无法导出

风险来自间接 `LocalizedStringResource`、错误的 table 或使用 SwiftPM resource bundle。控制方式是保持 AppIntent metadata 字符串直接声明并显式使用 `Intents` table 与 `.main` bundle，再通过 simulator build 验证 metadata processor。

### Package 本地化未随 extension 打包

风险来自遗漏 `Package.swift` 的 resources 声明或继续读取错误 bundle。控制方式是统一通过 `WidgetL10n` 读取 `Bundle.module`，并直接检查生成的 appex 和 package bundle。

### 移动后出现 self-import 或访问级别问题

迁入同一 target 的文件不再导入 `BirthTrackerWidgets`。只有供 extension 壳调用的 `BirthTrackerWidgetsBundle` 暴露必要的 `public` API，其余实现保持内部可见。编译和静态检查共同覆盖该风险。

## 完成标准

- extension 目录中只有一个 Swift 壳文件和三个系统所需资源文件；
- 所有 Widget 业务代码、preview 和 Widget UI 本地化均归属 `BirthTrackerWidgets` target；
- extension 不直接依赖 Widget 的底层模块；
- 两个现有 Widget 的配置、显示、刷新和交互行为未改变；
- 结构脚本、`make check`、XcodeBuildMCP simulator build 与 simulator test 全部通过；
- 构建产物中的 AppIntents 与 package 本地化资源完整。
