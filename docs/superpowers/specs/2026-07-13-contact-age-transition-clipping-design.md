# 联系人年龄 Widget 切换动画裁剪设计

## 背景

联系人年龄 Widget 当前把显示格式作为视图身份，并对整个年龄内容块应用 `.push(from: .bottom)`。格式更新时，新内容从下方进入，旧内容向上退出。SwiftUI 会在过渡期间同时保留两份内容；由于动画内容没有独立的裁剪边界，旧内容向上离开时会绘制到联系人姓名区域，连续点击时尤其明显。

## 目标

- 保留现有从下往上的 `push` 动画方向。
- 保留旧内容向上退出、新内容从下方进入的视觉关系。
- 年龄内容到达自身区域边界后立即被裁剪，不能覆盖联系人姓名或其他相邻内容。
- 普通点击和快速连续点击都不能在年龄区域之外留下重影。

## 非目标

- 不修改三种年龄格式及其轮换顺序。
- 不修改 `ToggleContactAgeFormatIntent`、格式偏好存储或 Widget timeline 刷新流程。
- 不使用固定高度约束年龄内容，避免本地化文本、不同 Widget family 或字号变化造成截断。
- 不进行无关的 Widget 布局重构。

## 设计

在 `ContactAgeWidgetView` 的交互式年龄按钮内部，为年龄数值和格式标签增加一个独立、左上对齐的 `ZStack` 可视区域：

1. 保留年龄内容块现有的 `.id(displayFormat.rawValue)`，使格式变化继续触发视图替换。
2. 保留 `.transition(.push(from: .bottom))`，因此旧内容仍向上退出，新内容仍从下方进入。
3. 由外层 `ZStack` 承担布局边界，并在该容器上应用 `.clipped()`。
4. 将动画绑定保留在这个局部区域，使格式变化只影响年龄内容，不影响姓名和 Widget 标题。

裁剪容器不设置固定高度。过渡期间可以在年龄区域内同时看到正在交接的新旧内容，这是 `push` 动画本身的效果；一旦旧内容越过该区域顶部，它就不可见，因此不会与姓名发生冲突。

## 数据流和错误处理

数据流保持不变：按钮触发 `ToggleContactAgeFormatIntent`，Intent 写入新的格式偏好并刷新 Widget timeline，新的 entry 驱动 `displayFormat` 变化。此次修改只约束 SwiftUI 的绘制范围，不引入新状态，也不增加新的失败路径。

## 验证

- 运行现有格式检查、SwiftLint 和 Widget 结构测试。
- 使用 XcodeBuildMCP 构建 BirthTracker，并在 `birth tracker 17 pro` Simulator 上验证。
- 分别检查 `.systemSmall` 和 `.systemMedium` 联系人年龄 Widget。
- 正常点击轮换三种格式，确认旧内容向上退出、新内容从下进入。
- 快速连续点击至少三次并在动画中截图，确认文字只在年龄区域内出现，不覆盖联系人姓名或其他相邻内容。
- 确认联系人选择、格式持久化以及另一个生日 Widget 的显示不受影响。
