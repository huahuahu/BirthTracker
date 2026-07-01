# 小组件 UI 提升设计

## 背景

BirthTracker 现有小组件已经能读取 App Group 中的 widget-only SwiftData store，并展示即将到来的生日。但当前 UI 仍偏基础：标题、最多 3 条生日文本和简单空状态，视觉层次较弱，也没有充分利用 `age`、日期和下一个生日之间的紧迫感。

本设计聚焦提升现有 `UpcomingBirthdaysWidget` 的呈现质量。用户确认的方向是“强视觉徽章布局 + 暖色生日氛围”：用醒目的倒计时徽章突出下一个生日，同时保持生日卡片的温暖、庆祝感。

## 目标

- 保留现有 `.systemSmall` 和 `.systemMedium` 支持范围。
- 让 small 小组件一眼看出下一个生日是谁、还有多久、日期和年龄信息。
- 让 medium 小组件在保持主生日视觉焦点的同时，展示更多即将到来的生日。
- 用同一套暖色视觉语言覆盖正常、空列表和选中人物不可用状态。
- 只改小组件 UI 层，不改变持久化模型、AppIntent 配置或数据同步流程。
- 沿用 `SFSafeSymbols` typed symbol API，不新增 raw SF Symbol 字符串。

## 非目标

- 不新增 `.systemLarge`、`.accessory*` 或其他 widget family。
- 不新增小组件配置项。
- 不改变 `WidgetPersonSnapshot`、`UpcomingBirthday` 或 widget store schema。
- 不调整主 App 页面 UI。
- 不引入新的设计系统模块或第三方 UI 依赖。

## 方案

采用聚焦重绘现有小组件的方案。`UpcomingBirthdaysWidget.swift` 继续作为 Widget target 专属 UI 文件，内部拆出少量私有子视图和格式化 helper，避免为一次局部 UI 提升扩散到共享模块。

备选方案的取舍如下：

- 只重绘现有小组件：改动集中、风险最低，能最快获得明显视觉提升，是本次推荐方案。
- 组件化重构：更利于后续扩展，但会扩大本次范围；如果后续有多个 widget 或 large family，再抽取更合适。
- 扩展 widget family：视觉空间更大，但会引入新的布局、preview 和验证负担，不符合本次“提升现有小组件 UI”的核心目标。

## UI 结构

small 小组件以“下一个生日”为唯一焦点：

1. 顶部显示 BirthTracker 标识和礼物图标。
2. 中部显示醒目的倒计时徽章，例如 `Tomorrow`、`In 8 days` 或 `Today`。
3. 主体显示人物姓名，使用更高字重和更大字号。
4. 底部显示生日日期；如果 `age` 存在，追加即将到来的年龄。

medium 小组件使用同一套暖色背景和圆角卡片语言：

1. 左侧展示主生日 Hero，保持与 small 一致的倒计时、姓名和日期信息。
2. 右侧展示后续 2-3 个生日的精简列表，列表行包含日期、姓名和倒计时。
3. 当只有一个生日时，右侧显示轻量辅助文案，避免空白区域显得未完成。

空状态和选中人物不可用状态不再只显示纯文字。它们使用同一张暖色卡片，保留图标、标题和说明文案，让小组件在无数据时仍然完整、友好。

## 数据流

数据流保持不变：

1. `UpcomingBirthdaysProvider` 读取 `WidgetSnapshotStore`。
2. Provider 将快照转换为 `UpcomingBirthdaysEntry`。
3. `UpcomingBirthdaysWidgetView` 根据 `entry.birthdays` 和 `entry.selectedPersonUnavailable` 渲染不同状态。
4. UI 层根据 `entry.date` 与 `UpcomingBirthday.date` 计算展示用倒计时文案。

倒计时只用于展示，不写回 store，也不改变 timeline 刷新策略。`entry.date` 代表 Widget 当前刷新/展示时间；快照的 `generatedAt` 只描述缓存生成时间，不参与倒计时计算。

## 错误处理

Widget 读取失败时继续走现有空状态路径，不崩溃、不改变数据层错误处理策略。UI 不增加会吞掉异常的 catch，也不新增成功形态的 fallback 数据。

选中人物不可用时显示明确状态，避免用户误以为生日列表为空。普通无生日数据时显示鼓励式空状态，提示回到 App 添加生日。

## 可访问性和本地化

使用系统动态字体层级，例如 headline、title、caption 等，避免固定字号过多导致可读性下降。颜色对比以白色主体文字配合深暖色渐变为主，次要文字使用较高透明度而不是过低对比。

新增展示文案应进入现有 `L10n.Widget` 命名空间，避免在 UI 中散落硬编码字符串。日期继续使用系统 `Date.FormatStyle`，尊重用户区域格式。

## 验证

实现后需要覆盖以下验证点：

- `UpcomingBirthdaysWidgetView` 能在 small family 展示主生日 Hero。
- `UpcomingBirthdaysWidgetView` 能在 medium family 展示主生日 Hero 和后续生日列表。
- `selectedPersonUnavailable` 为 true 时显示人物不可用状态。
- `birthdays` 为空时显示普通空状态。
- `age` 缺失时 UI 不显示多余占位符。
- 现有检查命令 `make check` 通过。
