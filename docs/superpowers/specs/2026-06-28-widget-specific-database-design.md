# 小组件专用数据库设计

## 背景

BirthTracker 当前使用 SwiftData 作为主 App 的真实数据源，并通过 App Group 中的 `upcoming-birthdays.json` 给 WidgetKit 提供即将到来的生日快照。当前 JSON 快照简单可靠，但无法支持“每个小组件实例单独选择某个人”的配置体验，也缺少结构化查询和缓存版本信息。

本设计将小组件数据从单个 JSON 快照迁移为 App Group 中的独立 SwiftData store。这个 store 只服务小组件，不启用 CloudKit，不替代主数据库。

## 目标

- 支持用户在编辑每个小组件时选择要显示的人。
- 让不同小组件实例可以显示不同人物。
- 保持主 App 的 SwiftData 主库作为唯一真实数据源。
- 小组件 store 只保存渲染和配置所需的最小派生数据。
- 小组件 store 不参与 iCloud / CloudKit 同步。
- 缓存损坏或迁移失败时可以安全重建，不影响主数据库。

## 非目标

- 不让 Widget 直接读取主 App 数据库。
- 不把小组件 store 作为用户数据的真实来源。
- 不在小组件 store 中复制完整人物模型或复杂对象关系。
- 不引入第三方数据库或框架。

## 架构

新增一个 App Group 内的 widget-only SwiftData store，例如 `widget.sqlite`。主 App 和 Widget extension 都可以打开这个 store，但职责不同：

- 主 App 负责从主库读取 `TrackedPerson`，生成小组件快照并写入 widget store。
- Widget extension 负责读取 widget store，用于时间线渲染和 AppIntent 配置选项。

widget store 使用独立的轻量模型，例如 `WidgetPersonSnapshot`。模型应保持扁平，避免关系和主库对象引用。

建议字段：

- `personID: UUID`
- `displayName: String`
- `nextBirthdayDate: Date`
- `age: Int?`
- `calendarKindRawValue: String`
- `schemaVersion: Int`
- `generatedAt: Date`
- `sortIndex: Int`

`personID` 对应主库人物 id，用于小组件配置保存选择。`schemaVersion` 和 `generatedAt` 用于调试、兼容判断和未来缓存重建策略。

## 数据流

主 App 在人物新增、删除、修改、设置变化或进入生日列表页面时刷新 widget store：

1. 从主 SwiftData 数据库读取当前人物。
2. 计算每个人的下一次生日、年龄和排序。
3. 将结果转换为 `WidgetPersonSnapshot`。
4. 用一次保存操作重建 widget store 中的快照数据。
5. 调用 `WidgetCenter.shared.reloadTimelines(ofKind:)` 刷新小组件。

Widget 使用 `AppIntentConfiguration` 代替当前的 `StaticConfiguration`：

1. AppIntent 的选项提供器从 widget store 读取可选人物列表。
2. 用户编辑某个小组件实例时选择一个人物。
3. 时间线生成时读取配置中的 `personID`。
4. Provider 从 widget store 查询对应 `WidgetPersonSnapshot` 并渲染。

未配置人物时，Widget 显示最近生日列表作为默认体验。配置中的人物被删除后，Widget 显示明确空状态，例如“这个人已不在列表中”，不自动改选其他人物。

## 错误处理和恢复

widget store 是派生缓存，不是权威数据源。任何缓存层失败都不应影响主 App 的真实数据。

- App Group URL 不可用时，主 App 触发调试断言并跳过 widget store 写入，主库数据不受影响。
- widget store 写入失败时，按现有调试风格触发断言，避免静默掩盖问题。
- Widget 读取失败时显示空状态，不崩溃。
- 迁移失败、模型版本不兼容或缓存损坏时，优先删除并重建 widget store。
- Widget 查询不到选中的 `personID` 时显示删除/不可用状态。

## 隐私和同步

widget store 位于 App Group 容器中，只包含小组件需要显示的最小数据。它不配置 CloudKit，也不依赖主库的 CloudKit 同步。只要 Widget extension 不实现网络请求，小组件读取这个本地 store 不会导致数据外发。

## 验证

需要覆盖以下验证点：

- 主 App 能把 `TrackedPerson` 正确转换为 `WidgetPersonSnapshot`。
- widget store 能保存、读取、排序并按 `personID` 查询快照。
- 删除人物后，旧 `personID` 不再返回有效快照。
- AppIntent 的可选人物列表来自 widget store。
- 时间线 provider 使用配置中的 `personID` 渲染对应人物。
- widget store 不可用或为空时，小组件显示稳定的空状态。

实现完成后运行现有项目检查命令 `make check`。
