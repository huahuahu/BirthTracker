# AI 上下文

BirthTracker 是一个 SwiftUI iOS App，用来记录和查看重要人物的生日。项目使用 SwiftData 作为主要持久化方案，Release 构建预期使用私有 CloudKit 同步，并通过 WidgetKit 展示即将到来的生日快照。

## 仓库规则

- 修改代码前先阅读 `../AGENTS.md`。
- 代码变更保持聚焦，遵循现有 SwiftUI、SwiftData 和 WidgetKit 模式。
- 不要提交 `Config/Project.xcconfig`；只提交模板文件 `Config/Project.xcconfig.example`。
- AI 生成的本地输出放在 `AIOutput/` 下。

## 常用命令

```bash
xcodegen generate
make check
make fix
```

## 源码布局

- `project.yml` 定义由 XcodeGen 生成的 Xcode 工程。
- `BirthTrackerPackage/Sources/App` 放 App 组合和依赖装配。
- `BirthTrackerPackage/Sources/Features` 放 SwiftUI 功能页面和用户流程。
- `BirthTrackerPackage/Sources/Models` 放 SwiftData 模型和共享领域类型。
- `BirthTrackerPackage/Sources/Persistence` 放 SwiftData 容器、App Group 访问和 Widget 持久化常量。
- `BirthTrackerPackage/Sources/DesignSystem` 放可复用的 UI 相邻设置和选择辅助逻辑。
- `BirthTrackerPackage/Sources/Localization` 放本地化资源和类型安全访问入口。
- `BirthTrackerPackage/Sources/Logging` 放统一日志 facade、日志类型、动态值隐私、OSLog sink 和测试替换接口。
- `BirthTrackerPackage/Sources/TestingSupport` 放测试 fixture 和内存持久化辅助逻辑。
- `Sources/BirthTrackerApp` 和 `Sources/BirthTrackerWidget` 放 target 专属入口、资源和 plist 文件。

## 文档工作流

- 一个重要产品能力对应一个 `doc/requirements/REQ-xxxx-name.md` 文件。
- 还没成型的小想法先放进 `doc/requirements/backlog.md`。
- 需求文档描述用户或产品想要什么，不提前写过细的实现方案。
- 如果实现改变了系统结构，同步更新 `doc/architecture/current-architecture.md`。
- 以后遇到重要技术选择时，可在 `doc/decisions/` 下新增 ADR 记录原因。
