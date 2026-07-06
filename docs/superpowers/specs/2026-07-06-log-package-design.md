# Logging Swift Package 设计

日期：2026-07-06

## 背景

BirthTracker 目前通过 `BirthTrackerPackage` 组织 SwiftPM 模块，并由 `project.yml` 接入 App、Widget extension 和测试 target。现有日志调用分散在 `Features` 与 Widget extension 中，直接依赖 `OSLog.Logger`，并且存在不统一的 subsystem/category 字符串。

需要新增一个专门的 Logging SwiftPM 模块，集中承载日志类型、隐私、写入和测试替换逻辑。日志类型必须支持一条日志同时归属多个类型，例如同一条记录既属于 data 又属于 widget。

## 目标

- 在现有 `BirthTrackerPackage` 中新增 `Logging` target 和 library product。
- 业务模块不直接创建 `OSLog.Logger`，统一通过 Logging facade 写日志。
- 支持内置日志类型和自定义日志类型。
- 支持一条日志携带多个类型，但默认只写入一条 OSLog 记录，避免重复日志。
- 动态日志值默认按 private 处理，并提供显式 public/private API。
- 第一版默认写入 Apple OSLog，同时预留可替换 sink，方便单元测试和后续扩展。
- 迁移当前所有直接 OSLog 调用点，验证 API 在 App 与 Widget extension 中都可用。

## 非目标

- 第一版不实现日志文件落盘、远程上传或复杂异步队列。
- 第一版不做按多个 OSLog category fan-out 的重复写入。
- 第一版不改变业务错误处理语义；日志模块只提高可观察性。

## Package 架构

新增 `BirthTrackerPackage/Sources/Logging`，并在 `BirthTrackerPackage/Package.swift` 中暴露 `Logging` library product。`Logging` 只依赖系统框架 `Foundation` 和 `OSLog`，不依赖 `Models`、`Persistence`、`Features` 或 Widget extension，避免循环依赖。

需要记录日志的模块按需依赖 `Logging`：

- `Features` 用于 UI、Widget snapshot、用户流程日志。
- `Persistence` 后续可用于数据存储、App Group、SwiftData 相关日志。
- `Sources/BirthTrackerWidget` 的 Widget extension 通过 `project.yml` 依赖 `Logging` product。

现有直接 `import OSLog` 的调用点迁移到 `Logging` 后，业务代码只使用统一 facade。Logging 内部统一 subsystem，第一版使用稳定字符串 `BirthTracker`，不再在调用点散落 subsystem 拼写。

## 核心 API

`LogTag` 表示日志类型，提供内置静态值：

- `data`
- `widget`
- `ui`
- `persistence`
- `lifecycle`
- `debug`

同时支持 `LogTag.custom(_:)`。自定义 tag 会规范化为小写 kebab-case 风格，只保留字母、数字和连字符；空白或非法输入映射为安全的 `custom`。

`BirthLogger` 是主要 facade。它提供按主类型创建的便捷 logger，也提供通用入口：

```swift
BirthLogger.widget.info("Loaded widget entry", tags: [.data])
BirthLogger.log(.info, "Loaded widget entry", primaryTag: .widget, tags: [.data])
```

每条日志有一个 `primaryTag` 和一个完整 `tags` 集合。`primaryTag` 用作 OSLog category；完整 `tags` 进入消息前缀，例如 `[widget,data] Loaded widget entry`。当 tags 为空时自动包含 `primaryTag`；当 tags 重复时去重并保持稳定顺序。

日志级别包含：

- `debug`
- `info`
- `notice`
- `warning`
- `error`
- `fault`

这些级别映射到 OSLog 对应写入方法。

## 隐私模型

动态值默认 private。调用方如果要记录动态内容，使用 value wrapper：

```swift
BirthLogger.widget.info(
  "Loaded entry for person",
  values: [.private(personID.uuidString), .public(resultCount)]
)
```

便捷 API 对未显式标注的动态值按 private 处理；只有调用方显式使用 public wrapper 时，值才会公开写入日志。这样可以降低生日、人物姓名、UUID 等敏感信息被误公开的风险。

第一版的消息模板保持简单：静态消息由调用方提供，动态值通过 Logging 统一附加。后续如果需要更完整地复用 OSLog 的编译期插值能力，可以在不改变业务调用点语义的前提下扩展 facade。

## 写入流程

业务代码调用 `BirthLogger` 后，Logging 组装 `LogRecord`：

- `level`
- `primaryTag`
- `tags`
- `message`
- `values`
- `timestamp`

默认 `OSLogSink` 接收 `LogRecord`，按 `primaryTag.rawValue` 创建或复用 `OSLog.Logger`，并写入单条日志。因为 OSLog 常规写入路径不抛错，业务调用不需要处理 logging error。

可替换 sink 主要用于测试。测试可以安装捕获 sink，断言 `LogRecord` 的 level、tag、message 和 privacy，而不依赖 Console 输出。

## 迁移范围

第一版迁移当前所有直接 OSLog 调用点：

- `PeopleTimelineView` 中 Widget snapshot 持久化失败日志。
- `PersonSelectionIntent` 中 Widget entity query 日志。
- `UpcomingBirthdaysWidget` 中 Widget entry load 日志。

Widget provider 当前 catch 后返回空 entry 的行为保持不变，但补充 `error` 级别日志，避免失败完全不可观察。现有错误 subsystem 字符串会随迁移移除。

## 测试策略

在现有 `BirthTrackerPackageTests` 中增加 Logging 测试，不新增独立测试 target。测试覆盖：

- 内置 `LogTag` raw value。
- `LogTag.custom(_:)` 规范化。
- 多 tags 自动包含 primary tag。
- 重复 tags 去重并保持稳定顺序。
- 动态值默认 private。
- 显式 public/private value。
- level 到 OSLog sink 的映射入口。
- 测试 sink 能捕获完整 `LogRecord`。

代码变更完成后运行项目既有 `make check`。

## 验收标准

- `BirthTrackerPackage` 暴露 `Logging` product。
- App 与 Widget extension 可以导入并使用 `Logging`。
- 现有 OSLog 调用点全部迁移，不再在业务代码里直接创建 `OSLog.Logger`。
- 一条日志可以同时携带多个类型，并且默认只写入一条记录。
- 动态值默认 private，显式 public 才公开。
- Logging 行为有单元测试覆盖。
