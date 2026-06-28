# 调试存储切换与测试数据重置设计

## 背景

Settings 的 debug 页面目前直接在 `SettingsDebugSection.swift` 中包含数据库模式 Picker 和仅 memory 模式可见的测试数据生成按钮。Root view 会监听 debug 存储模式变化并立即重建 `ModelContainer`，这会让“切换数据库”表现为热切换。

本次变更要把 debug 数据库存储相关能力独立成 Settings 下的子目录，并让存储模式切换在 App 重启后生效。同时，测试数据操作需要覆盖 memory、local 和 CloudKit 三种存储。

## 推荐方案

采用 `BirthTrackerPackage/Sources/Features/Settings/DebugStorage/` 子目录承载 debug 数据库存储能力：

- `SettingsDebugSection` 只负责组合 debug 页面内容，实际数据库控件移动到 DebugStorage 子目录内的专用 view。
- 存储模式 Picker 继续写入 `AppSettingsKey.storageMode`，但 root view 不再监听并即时替换 `ModelContainer`。
- 当用户选择了不同存储模式时，显示提示，说明新设置需要重启 App 后生效。
- 测试数据按钮始终显示为“重置测试数据”，对当前已启动的 `modelContext` 先删除已有 `TrackedPerson`，再插入简易测试数据。

## 行为设计

### 切换存储模式

Debug 存储模式仍包含 memory、local、cloud 三个选项。选择值会立即持久化到 `UserDefaults`，供下次启动时 `BirthTrackerModelContainer.make()` 读取。

因为 iOS App 不能可靠地自我重启，切换后只提示用户“重启 App 后生效”。当前运行中的 `ModelContainer` 不会被热替换，避免 SwiftData context、导航状态和 UI 刷新在运行时进入不一致状态。

### 重置测试数据

新增“重置测试数据”操作，三种存储模式都可用。它针对当前运行中的存储执行：

1. fetch 当前所有 `TrackedPerson`。
2. 逐个删除。
3. 插入现有的简易测试人物 fixture。
4. 保存 context。

如果任务被取消或保存失败，已插入的新数据会回滚；删除旧数据后的保存失败由 SwiftData 抛出错误并通过现有失败提示展示。CloudKit 模式下删除和插入会按 SwiftData/CloudKit 的同步机制传播。

## 代码结构

新增子目录：

```text
BirthTrackerPackage/Sources/Features/Settings/DebugStorage/
```

该目录放置数据库存储 debug UI 与控制器相关文件，例如：

- `DebugStorageSection.swift`：存储模式 Picker、重启提示、重置测试数据按钮。
- `TestDataGenerationController.swift`：沿用现有 HUD、取消和反馈状态管理，默认执行重置逻辑。
- `TestDataGenerationFeedback.swift`：沿用现有反馈修饰器。

`SettingsDebugSection.swift` 保留在 Settings 根目录，用于组合 debug 表单并引用 `DebugStorageSection()`。

## 本地化

新增或调整文案：

- “重置测试数据”
- “正在重置测试数据…”
- “测试数据已重置”
- “重置失败”
- “存储位置已更新，重启 App 后生效。”

英文和简体中文同时补齐。

## 测试

更新 Swift Testing 覆盖：

- debug 设置页仍通过 Settings 入口进入，并由 debug view 承载 debug section。
- 数据库切换不再触发 root view 热重建 `ModelContainer`。
- 测试数据重置会先删除已有 `TrackedPerson`，再插入 3 条简易 fixture。
- Settings debug 源文件引用 DebugStorage 子目录组件，保证组织结构意图不会回退。

代码变更完成后运行 `make check`。
