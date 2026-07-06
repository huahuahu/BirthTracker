# 联系人年龄 Widget 设计

## 背景

BirthTracker 已有 `UpcomingBirthdaysWidget`，它从 App Group 中的 Widget 快照 store 读取联系人生日摘要。App 负责从主 SwiftData 数据库生成扁平快照，Widget extension 只读取快照，不直接访问主数据库。

本设计新增一个独立的“联系人年龄”Widget，用来查看某个联系人当前已经出生多久，并支持在 Widget 内点按切换显示格式。

## 目标

- 新增独立联系人年龄 Widget，不改变现有即将到来的生日 Widget 的定位。
- 每个年龄 Widget 选择一个联系人。
- Widget 默认以年/月/日显示当前年龄，例如“2 年 3 月 4 天”。
- 用户可在 Widget 内点按主数值区域，在年/月/日、月/日和日三种格式之间轮换。
- 格式偏好按联系人保存；同一联系人对应的多个年龄 Widget 会同步切换，不影响其他联系人。
- 联系人缺少出生年份时仍可选择，但 Widget 显示“需要出生年份”，不展示可切换的年龄数字。

## 非目标

- 不做单个 Widget 实例级别的格式偏好，因为 WidgetKit 不提供稳定、简单的当前实例身份用于这种状态写入。
- 不把年龄模式塞进现有即将到来的生日 Widget，避免混淆生日列表和当前年龄两个使用场景。
- 不新增 App 内全局设置页；本次切换入口只在 Widget 内。

## 架构

### Widget

新增 `ContactAgeWidget`，并在 `BirthTrackerWidgetBundle` 中与 `UpcomingBirthdaysWidget` 一起注册。`BirthTrackerWidgetKind` 增加新的 `contactAge` kind，值为 `"ContactAgeWidget"`。

`ContactAgeWidget` 继续使用 `AppIntentConfiguration`。联系人选择复用 `SelectPersonIntent`，配置参数只持久化联系人 UUID 字符串；候选列表由 `WidgetPersonOptionsProvider` 从 Widget 快照动态生成，因此两个 Widget 共用同一套联系人候选来源且不持久化 `AppEntity`。

### 共享模型和快照

`PersonBirthdaySummary` 增加总出生天数字段。该值只有在联系人有完整出生年份时计算；缺出生年份时为 `nil`。

`WidgetPersonSnapshot` 和 `WidgetPersonSnapshotRecord` 增加对应字段，用于把总出生天数写入 Widget 快照 store。`WidgetSnapshotBuilder` 从 `PersonBirthdaySummary` 复制该值。Widget 仍只读取扁平快照，不直接计算或读取 App 主数据库。

### 格式偏好

新增轻量的 Widget 年龄格式偏好存储，使用 `UserDefaults(suiteName: AppGroup.identifier)`。偏好 key 由联系人 ID 组成，值为：

- `yearMonthDay`：年/月/日
- `monthDay`：总月数 + 剩余天数
- `day`：总天数

默认值为 `yearMonthDay`。偏好读取失败时使用默认值；旧 raw value `durationComponents` 和 `totalDays` 会分别映射到 `yearMonthDay` 和 `day`。写入失败应按现有错误处理风格记录或显式暴露，不做静默成功。

### 交互 Intent

新增 `ToggleContactAgeFormatIntent`。Widget 内主数值区域使用交互式 `Button(intent:)` 触发该 intent。Intent 接收联系人 ID，读取该联系人的当前格式，轮换到下一种格式，写回 App Group 偏好，然后通过 WidgetKit 刷新联系人年龄 Widget 时间线。

该交互不会修改 Widget 配置参数，而是修改按联系人保存的显示偏好。因此同一联系人对应的多个年龄 Widget 会一起更新。

## 数据流

1. App 保存或同步联系人数据后，现有 Widget 快照同步流程调用 `WidgetSnapshotBuilder`。
2. Builder 通过 `PersonBirthdaySummary` 计算出生年/月/日、距离下次生日天数、下一次生日年龄和总出生天数。
3. Builder 写入 `WidgetPersonSnapshot`，再由 `WidgetSnapshotStore` 持久化到 App Group 内的 Widget store。
4. `ContactAgeWidget` 的 timeline provider 根据所选联系人读取对应快照。
5. Provider 再读取该联系人对应的格式偏好，生成 entry。
6. Widget view 根据 entry 使用 `DateComponentsFormatter` 本地化显示年/月/日、月/日或日。
7. 用户点按主数值按钮时，`ToggleContactAgeFormatIntent` 切换该联系人格式偏好，并刷新 `ContactAgeWidget`。

## UI 状态

支持 `.systemSmall` 和 `.systemMedium`。

### 小号

- 联系人名。
- 当前年龄主数值。
- 当前格式提示或轻量切换提示。

### 中号

- 联系人名。
- 当前年龄主数值。
- 当前格式提示。
- 可额外显示出生日期或“距离下次生日 X 天”，优先复用已有生日摘要字段。

### 空态和异常态

- 未选择联系人或没有可显示数据：显示引导用户选择联系人或暂无生日数据的短文案。
- 所选联系人已删除：沿用现有“所选联系人已不在列表中”语义。
- 联系人没有生日：显示“未记录生日”。
- 联系人有生日但缺出生年份：显示“需要出生年份”，不展示可切换数字。
- 快照读取失败：显示安全空态，并按现有 Widget 错误处理风格记录错误。

## 本地化

在 `L10n.Widget` 和 `Localizable.xcstrings` 中新增年龄 Widget 需要的文案：

- Widget 展示名和描述。
- 年龄格式名称：年/月/日、月/日、日。
- 缺出生年份提示。
- 未记录生日提示。

年龄数值展示使用 Apple 的 `DateComponentsFormatter`，不在 string catalog 中手写拼接格式。

## 测试

- `PersonBirthdaySummaryTests` 覆盖总出生天数计算、未来生日、生日当天、缺出生年份和无生日。
- `WidgetSnapshotStoreTests` 覆盖新字段从 builder 到 store 的写入、读取和 `upcomingBirthday` 兼容性不被破坏。
- 新增格式偏好 store 单元测试，覆盖默认值、按联系人读写、切换行为和不同联系人互不影响。
- Widget UI 通过 preview 和项目现有检查命令验证构建。

## 实施顺序

1. 给共享生日摘要和 Widget 快照补总出生天数字段及测试。
2. 增加格式偏好 store 和切换 intent。
3. 新增联系人年龄 Widget provider/view/preview，并注册到 Widget bundle。
4. 补本地化文案。
5. 运行现有项目检查。
