# REQ-0003: 生日 Widgets

## 状态

Shipped

## 问题

用户需要在主屏幕快速查看即将到来的生日或某位联系人的出生时长，并能够为 Widget 选择联系人。Widget 必须在主 App 不运行时使用稳定的共享快照，同时清楚处理未配置、联系人被删除和生日信息不足等状态。

## 目标

- 提供即将生日 Widget，在未选择联系人时展示最近生日列表，选择联系人后只展示该人物的下一次生日。
- 提供联系人年龄 Widget，展示所选联系人已经出生的时长。
- Widget 配置允许从主 App 已保存的人物中选择联系人，包括暂时没有可计算生日的人物。
- 联系人年龄支持“年/月/日”“总月数/日”和“总天数”三种格式；配置界面只保留联系人、显示日历，格式通过点按内容区域（包括年龄文字、三状态指示和内容内空白）循环切换。
- 每个联系人年龄 Widget 实例独立保存点按后的显示格式，即使多个实例选择同一联系人也不会联动。
- Widget 使用 App Group 中的派生快照，不直接打开主数据库，也不启用 CloudKit。

## 非目标

- 本需求不包含尚未实施的单人生日倒计时圆环设计。
- 联系人年龄 Widget 当前不支持中号或大号尺寸。
- Widget 不负责编辑联系人或修复缺失的生日信息。
- Widget 快照不是主数据真源，也不替代主数据库同步。

## 用户故事

- 作为用户，我可以添加一个小号或中号 Widget 查看最近的生日。
- 作为用户，我可以把即将生日 Widget 配置为只关注一个联系人。
- 作为用户，我可以添加一个小号联系人年龄 Widget，在“编辑小组件”中选择联系人和日历，并直接点按内容区域切换格式。
- 作为用户，我可以让选择同一联系人的两个年龄 Widget 分别停留在不同的显示格式。
- 作为用户，当已选择的联系人被删除时，我会看到明确的不可用状态，而不是悄悄切换到其他人。

## 验收标准

- 即将生日 Widget 支持 `systemSmall` 和 `systemMedium`；小号最多展示两人，中号最多展示三人。
- 即将生日 Widget 未选择联系人时按快照顺序展示最近生日；选择联系人时只展示该人物。
- 联系人年龄 Widget 仅支持 `systemSmall`，且必须选择联系人后才能展示出生时长。
- 联系人没有可计算的生日时显示“未记录生日”状态；出生年份未知时显示需要出生年份的状态。
- 所选联系人不存在时显示明确的不可用状态，不自动改选其他联系人。
- 配置不显示年龄格式；新 Widget 默认使用“年/月/日”，旧 Widget 保留已存的格式和点按状态。
- 点按内容区域按“年/月/日 → 总月数/日 → 总天数 → 年/月/日”循环，并只刷新被点按的 Widget 实例。
- 选择同一联系人的多个 Widget 实例分别保存点按状态，改变日历不重置已有实例 token 对应的显示格式。
- Widget 显示可见的三状态指示，当前位置与该实例当前生效的年龄格式一致。
- “出生至今”和当前实际采用的日历以紧凑页脚显示；“跟随联系人”要解析为具体历法名，不能只显示“跟随联系人”。日历文字不能挤压或遮挡两行年龄及三状态指示。
- 主 App 成功新增、编辑或删除联系人后尝试重建 Widget 快照；只有重建成功时才请求相关 timelines 刷新，重建失败不回滚主数据库修改。
- Widget 快照存储在 App Group 的独立 SwiftData store 中，配置明确使用 `cloudKitDatabase: .none`。

## 依赖

- `BirthTrackerPackage/Sources/BirthTrackerWidgets`
- `BirthTrackerPackage/Sources/BirthTrackerWidgetIntents`
- `BirthTrackerPackage/Sources/Models/WidgetPersonSnapshot.swift`
- `BirthTrackerPackage/Sources/Persistence/WidgetSnapshotStore.swift`
- `BirthTrackerPackage/Sources/Models/ContactAgeDisplayFormat.swift`
- `BirthTrackerPackage/Sources/Persistence/ContactAgeFormatPreferenceStore.swift`
- `Sources/BirthTrackerWidget/BirthTrackerWidgetBundle.swift`

## 开放问题

- 单人生日倒计时设计何时从 backlog 提升为正式需求？
- 即将生日 Widget 是否继续保留“未选择联系人时显示列表”的默认模式？
- 联系人年龄 Widget 是否需要中号布局？

## 备注

- 本需求承接已实现的 Widget 专用数据库、联系人年龄 Widget 和视觉改版；历史生日倒计时设计仍属于未实施方案。
