# 当前架构

本文档记录 App 当前真实的工作方式。这里应该写已经验证的事实，不写未来计划。

## 平台

- 原生 iOS App，由 `project.yml` 通过 XcodeGen 生成工程。
- 主要技术选择是 Swift 6.2 和 SwiftUI。
- 生成的 `BirthTracker.xcodeproj` 属于派生产物。

## Targets

- `BirthTracker` 是 iOS 应用 target。
- `BirthTrackerWidget` 是 WidgetKit 扩展 target。
- `BirthTrackerTests` 是 `project.yml` 中配置的单元测试 target。

## Package 模块

- `App` 负责 root view 和 App 依赖装配。
- `Features` 负责 SwiftUI 页面，例如时间线、人物编辑和设置页。
- `Models` 负责领域模型，包括生日、被记录的人、关系事实、纯 Swift 关系称谓 resolver、联系人生日摘要 display model、Widget 快照记录和生日计算。
- `Persistence` 负责 SwiftData 容器、App Group 访问、Widget 专用 SwiftData store 和 Widget 持久化常量。
- `DesignSystem` 负责共享的 UI 相邻设置，例如外观模式和已选日历类型。
- `Localization` 负责本地化资源和类型安全访问入口。
- `Logging` 负责统一日志 facade、日志类型、动态值隐私、OSLog 写入和测试替换接口。
- `TestingSupport` 负责测试 fixture、内存持久化辅助逻辑和 debug 数据。
- `BirthTrackerWidgetIntents` 负责 App 与 Widget extension 共同使用的 Widget 配置 Intent、交互式 Intent 和 `AppIntentsPackage`。
- `BirthTrackerWidgets` 负责 Widget bundle、UI、timeline provider、entry、preview 和 package 内的 Widget UI 本地化。

## 持久化

- SwiftData 是主要持久化层。
- Release 构建预期使用私有 CloudKit 同步。
- Debug 构建可以通过 `BIRTHTRACKER_STORAGE_MODE` 和 debug 设置使用 memory、local 或 cloud 存储。
- 测试和 preview 优先使用内存存储。

## Widgets

- Widget extension 入口位于 `Sources/BirthTrackerWidget`，该目录只保留 `@main` bundle 壳、Info.plist 和 target 本地化资源；具体 Widget 类型、`AppIntentConfiguration`、timeline provider、entry 和 Widget preview 位于 `BirthTrackerPackage/Sources/BirthTrackerWidgets`。
- 跨 App 与 Widget extension 使用的 `WidgetConfigurationIntent`、交互式 `AppIntent` 和 `AppIntentsPackage` 位于 `BirthTrackerPackage/Sources/BirthTrackerWidgetIntents`。
- `BirthTrackerWidgets` 依赖 `BirthTrackerWidgetIntents`；App target 只直接依赖 Intent module，Widget extension 同时直接依赖 Intent 与 Widget UI module。
- 面向 Widget 的 bundle 组合、UI、模型和持久化常量放在 package 模块里，而不是 App-only 或 extension-only 代码里。
- App 和 Widget 配置使用 `Config/Project.xcconfig` 里的占位符，以及已提交的 entitlement 模板。
- App 将主 SwiftData 数据库中的人物转换成扁平快照，并写入 App Group 中独立的 Widget SwiftData store；该快照包含有生日和无生日联系人，生日列表 Widget 会过滤没有下一次生日的快照。
- App 和 Widget 通过 `PersonBirthdaySummary` 共享“已经出生多久”“已经出生总天数”“距离下次生日”等生日摘要语义；Widget 仍只读取扁平快照字段，不复用 App 的 SwiftUI 详情页。
- Widget extension 使用 `AppIntentConfiguration` 支持每个小组件实例选择一个联系人。
- 联系人年龄 Widget 使用交互式 AppIntent 在年/月/日、月/日、日三种显示格式间轮换，格式偏好按联系人 ID 保存在 App Group `UserDefaults` 中；同一联系人对应的多个年龄 Widget 会共享该格式。
- Widget store 是派生缓存，不启用 CloudKit，不替代主数据库。

## 检查命令

```bash
make check
make fix
```

代码变更后运行 `make check`。需要格式化和 SwiftLint 自动修复时运行 `make fix`。

## 待确认架构问题

- 当 SwiftData 模型演进变复杂后，长期迁移说明应该放在哪里？
- 后续重要产品或技术决策是否需要记录为 `doc/decisions/` 下的 ADR？
- 除了当前 package 和单元测试覆盖外，哪些 App 流程需要 UI 测试？
