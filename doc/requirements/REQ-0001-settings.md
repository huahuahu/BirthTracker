# REQ-0001: 设置

## 状态

Accepted

## 问题

用户需要一个稳定、可预期的位置来控制 App 外观和生日录入时可用的日历类型。开发者也需要 debug-only 的控制项，用于本地测试时切换持久化模式和生成示例数据。

## 目标

- 用户可以选择外观模式：跟随系统、浅色或深色。
- 用户可以选择录入生日时可用的日历系统。
- 默认日历选择为 Gregorian。
- 至少保留一个已选日历系统。
- Debug 构建提供 memory、local、iCloud/cloud 数据库模式控制。
- Debug 构建提供 memory、local、iCloud/cloud 三种存储的测试数据重置能力。
- Debug 存储模式切换后需要提示用户重启 App，新的存储位置在下次启动后生效。

## 非目标

- Release 构建不暴露数据库模式控制。
- 本需求不包含账号、订阅、导出或通知设置。
- 本需求不要求所有日历系统在完成前都已经完整本地化。

## 用户故事

- 作为用户，我可以让 App 跟随系统外观，也可以强制使用浅色或深色模式。
- 作为用户，我可以选择录入生日时想使用的日历系统。
- 作为开发者，我可以不改代码就切换 debug 数据库模式。
- 作为开发者，我可以在当前 debug 存储中重置简易测试数据。

## 验收标准

- 设置页包含外观区域，并提供跟随系统、浅色和深色选项。
- 已选外观模式在 App 重启后仍然保留。
- 设置页包含日历区域，并提供可选择的日历系统。
- 首次启动或已存选择为空时，默认选择 Gregorian。
- UI 会避免已选日历列表变为空。
- Debug 构建包含 memory、local、cloud/iCloud 的数据库模式选择器。
- Release 构建不显示 debug 数据库控制项。
- Debug 构建中，memory、local、cloud/iCloud 三种数据库模式都显示测试数据重置操作。
- 测试数据重置会先删除已有生日记录，再插入简易测试数据。
- Debug 数据库模式切换后显示重启提示，并且不在当前运行中热切换 SwiftData `ModelContainer`。

## 依赖

- `BirthTrackerPackage/Sources/Features/Settings/SettingsView.swift`
- `BirthTrackerPackage/Sources/DesignSystem/AppSettings.swift`
- `BirthTrackerPackage/Sources/Models/BirthdayCalendarKind.swift`
- `BirthTrackerPackage/Sources/Persistence/BirthTrackerModelContainer.swift`

## 开放问题

- 发布前日历名称是否需要本地化？
- 修改已选日历类型应该影响已有生日，还是只影响未来录入选择？
- 后续简易测试数据需要覆盖哪些生日类型、日历类型和边界日期？

## 备注

- 本需求正式承接 `doc/settings.md` 中的原始草稿。
