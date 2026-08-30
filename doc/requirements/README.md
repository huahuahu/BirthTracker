# 需求索引

这个目录用于维护人和 AI 都能理解、讨论和执行的产品需求。

## 需求状态

- `Draft` - 初步想法，还不适合实现。
- `Proposed` - 已经整理到可以讨论。
- `Accepted` - 已确认，可以实现。
- `In Progress` - 正在实现。
- `Shipped` - 已实现，并已发布或准备发布。
- `Deferred` - 有意延后。
- `Rejected` - 明确不计划做。

## 需求列表

| ID | 标题 | 状态 | 文件 |
| --- | --- | --- | --- |
| REQ-0001 | 设置 | Shipped | `REQ-0001-settings.md` |
| REQ-0002 | 联系人与生日时间线 | Shipped | `REQ-0002-people-and-timeline.md` |
| REQ-0003 | 生日 Widgets | Shipped | `REQ-0003-birthday-widgets.md` |

## Backlog

还没准备好单独成文档的小想法，先放在 `backlog.md`。

## 新增需求

1. 复制 `TEMPLATE.md` 为 `REQ-xxxx-short-name.md`。
1. 每份需求只描述一个清晰的产品能力。
1. 填写目标、非目标、验收标准、依赖和开放问题。
1. 把新文件加入上面的需求列表。

## 给 AI 的说明

- 实现产品功能前先读这个索引。
- `Accepted` 和 `In Progress` 的需求优先级高于 backlog 想法。
- 实现新能力时以 `Accepted` 和 `In Progress` 为输入；修改现有行为前也要阅读对应的 `Shipped` 需求，确认当前产品边界。
- 不要把 `Draft` 或 `Proposed` 状态的需求当作已经确认或实现的行为。
- 如果实现时发现产品语义不清，把问题补到对应需求的 `开放问题` 区域。
- `doc/history/` 中的设计和计划用于追溯，不代表当前需求状态；必须回到本索引和实际实现确认当前行为。
