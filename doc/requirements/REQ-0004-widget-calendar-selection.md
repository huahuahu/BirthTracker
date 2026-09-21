# REQ-0004: Widget 显示日历选择

## 状态

Shipped

## 问题

“即将生日”和“联系人年龄”Widget 原本只能选择联系人，无法为单个 Widget 实例指定日期展示或出生时长计算所用的日历。显示日历属于 Widget 实例配置，不能修改联系人保存的原始生日历法，也不能改变生日实际发生日期的含义。

## 目标

- 两个 Widget 都在联系人之后提供“显示日历”配置。
- 支持跟随联系人、公历、农历、佛历、希伯来历和伊斯兰历。
- 配置按 Widget 实例保存，并默认使用“跟随联系人”。
- 联系人年龄按所选日历计算年、月、日；总天数仍表示绝对日期之间经过的天数。
- 即将生日仍按联系人原始历法确定下一次生日，只使用所选日历格式化该绝对日期。
- 配置项和选项提供英文与简体中文本地化。
- 联系人年龄 Widget 本体用简短日历名标明出生时长采用的实际历法，并保留“出生至今”的含义。

## 非目标

- 不为联系人保存多条不同历法的生日。
- 不把 Widget 显示日历写回主数据库、设置页或 Widget 快照。
- 不使用显示日历重新解释生日月日、重新计算下一次生日或改变列表排序。
- 不增加 Widget 类型或尺寸；日历标识放入联系人年龄 Widget 的紧凑页脚，不扩展成说明段落。

## 用户故事

- 作为用户，我可以让不同 Widget 实例为同一个联系人使用不同的显示日历。
- 作为用户，我可以让多人生日列表中的每个人继续按自己的原始生日历法显示。
- 作为已有 Widget 的用户，升级后无需重新配置，行为仍默认跟随联系人。

## 验收标准

- 两个 Widget 的配置界面都按“联系人”“显示日历”的顺序显示参数。
- 新实例和缺少新增字段的既有实例默认使用“跟随联系人”。
- 六个选项的英文和简体中文名称正确，并能由 App Intents metadata 导出。
- 联系人年龄的年、月、日按所选日历计算；总天数不随显示日历改变。
- 联系人年龄 Widget 始终显示计算所用的具体日历；“跟随联系人”显示解析后的公历、农历等名称。英文和简体中文在小号尺寸下不遮挡年龄或状态圆点。
- 即将生日的绝对日期和人物顺序不因显示日历改变。
- 多人列表在“跟随联系人”时逐人使用原始生日历法，显式选择时统一使用所选日历格式化日期。
- 修改 Widget 配置不修改联系人生日、设置页日历选择、快照或其他 Widget 实例。
- 出生年份未知、未记录生日、联系人已删除等现有状态保持不变。
- App 与 Widget extension 都包含新增 App Intents metadata 的英文和简体中文资源。
- 在 Simulator 或真机的 Widget 编辑界面验证配置可见、可选择并可持久化，两个 Widget 的输出符合上述语义。

## 依赖

- `REQ-0003-birthday-widgets.md`
- `BirthTrackerPackage/Sources/BirthTrackerWidgetIntents`
- `BirthTrackerPackage/Sources/BirthTrackerWidgets`
- `BirthTrackerPackage/Sources/Models/ContactAgeSnapshotMetrics.swift`
- `Sources/BirthTrackerApp/Intents.xcstrings`
- `Sources/BirthTrackerWidget/Intents.xcstrings`

## 开放问题

- 即将生日的多人列表是否也需要逐行标注各自的日历名称？
- 如果未来支持一个联系人保存多条生日记录，配置是否应改为直接选择某条生日记录？

## 备注

- 对应 GitHub Issue #43。
- 系统配置通过稳定的日历 raw ID 传给 Widget provider，再解析为 `WidgetDisplayCalendar`；缺失或未知 ID 回退为“跟随联系人”。
