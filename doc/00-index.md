# 文档索引

`doc/` 是 BirthTracker 唯一的活跃文档根目录，用于维护产品需求、当前架构、技术决策、AI 协作上下文和可追溯的历史资料。

## 先读这里

- `../AGENTS.md` - 代码代理需要遵守的仓库规则。
- `ai-context.md` - 给 AI 使用的项目速览。
- `architecture/current-architecture.md` - 当前 App 架构事实。
- `requirements/README.md` - 需求索引和维护流程。

## 产品需求

- `requirements/backlog.md` - 还没成型的小想法和未来需求碎片。
- `requirements/REQ-0001-settings.md` - 设置页需求。
- `requirements/REQ-0002-people-and-timeline.md` - 联系人与生日时间线需求。
- `requirements/REQ-0003-birthday-widgets.md` - 即将生日与联系人年龄 Widgets 需求。
- `requirements/TEMPLATE.md` - 新需求文档模板。

## 架构

- `architecture/current-architecture.md` - 当前架构、模块、持久化、Widget 和检查命令。

## 历史资料

- `history/README.md` - 历史设计、实施计划和视觉参考的索引及可信边界。
- `history/designs/` - 当时讨论或采用过的设计规格，可能只实现了一部分。
- `history/plans/` - 当时的实施步骤，路径、命令和工具要求可能已经失效。

历史资料不替代正式需求或当前架构。遇到冲突时，应以对应 `REQ-*`、当前架构和实际源码为准，并修正文档差异。

## 历史草稿

- `requirement.md` - 原始通用 iOS 模板需求。
- `settings.md` - 原始设置页草稿，已由 `requirements/REQ-0001-settings.md` 正式承接。
