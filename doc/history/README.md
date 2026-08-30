# 历史设计与实施资料

本目录保存已经完成、被替代或尚未进入正式需求的设计规格、实施计划和视觉参考。它们用于追溯当时的问题、方案和取舍，**不是当前产品需求、当前架构或可直接执行的工作流**。

## 可信边界

- 当前产品意图以 [`requirements/`](../requirements/README.md) 中对应状态的需求为准；未成型想法以 [`requirements/backlog.md`](../requirements/backlog.md) 为准。
- 当前实现结构以 [`architecture/current-architecture.md`](../architecture/current-architecture.md) 和实际源码为准。
- 当前 AI 协作与文档流转规则以 [`ai-context.md`](../ai-context.md) 和仓库根目录的 [`AGENTS.md`](../../AGENTS.md) 为准。
- `designs/` 记录当时选择或讨论过的设计，可能只实现了一部分，也可能从未实施。
- `plans/` 记录当时准备执行的步骤，其中的文件路径、命令、依赖和代理指令可能已经失效。
- 除置顶的归档警告外，历史文件正文保留原文；其中对 Superpowers skills 的要求只是历史记录，不是当前指令，不应据此执行任务。

阅读历史资料时，应先找到对应的正式需求或当前架构，再用源码、测试和运行结果验证仍然有效的事实。如果历史资料与当前真源冲突，以当前真源和实际实现为准，并修正文档差异。

## 目录

- [`designs/`](designs/)：设计规格与视觉参考。
- [`plans/`](plans/)：实施计划和执行步骤。

## 迁移审计

迁移审计基线：2026-08-30，`master` 提交 `a96ec60`。

下表记录从已经退役的并行文档树迁移的主题及其当前承接位置。它描述的是迁移时点的状态，不把历史方案自动提升为 Accepted 需求。

| 历史主题 | 当前状态 | 当前真源或后续入口 |
| --- | --- | --- |
| 调试存储切换与测试数据重置 | 已实现 | [`REQ-0001`](../requirements/REQ-0001-settings.md) 与[当前架构](../architecture/current-architecture.md) |
| SFSafeSymbols 类型安全图标 | 已实现的开发约束 | [`AGENTS.md`](../../AGENTS.md) 与实际依赖、源码 |
| Widget 专用数据库 | 已实现 | [`REQ-0003`](../requirements/REQ-0003-birthday-widgets.md) 与[当前架构](../architecture/current-architecture.md) |
| 关系视角与生日称谓 | 领域模型、存储和 resolver 已实现；关系管理与视角切换 UI 尚未上线 | [当前架构](../architecture/current-architecture.md)；未来产品能力仍需单独建立需求 |
| xcode-build-server 自动配置 | 已实现的开发工作流 | [当前架构](../architecture/current-architecture.md) 与 `scripts/` 实际脚本 |
| 联系人主页与编辑 | 已实现 | [`REQ-0002`](../requirements/REQ-0002-people-and-timeline.md) 与[当前架构](../architecture/current-architecture.md) |
| 联系人年龄 Widget 及其动画、格式和视觉改版 | 已实现 | [`REQ-0003`](../requirements/REQ-0003-birthday-widgets.md) 与[当前架构](../architecture/current-architecture.md) |
| Logging package | 已实现 | [当前架构](../architecture/current-architecture.md) 与 Logging 模块源码 |
| 单人生日倒计时 Widget | 视觉方向已记录，尚未实施 | [`requirements/backlog.md`](../requirements/backlog.md) |
| Codex worktree 自动初始化 | 已实现的开发工作流 | [当前架构](../architecture/current-architecture.md) 与 `scripts/` 实际脚本 |
| Widget Intents 模块拆分 | 已实现 | [当前架构](../architecture/current-architecture.md) |
| Widget 完整迁移到 Swift Package | 已实现 | [当前架构](../architecture/current-architecture.md) |

## 维护规则

1. 新想法先进入 backlog；稳定的产品能力使用独立 `REQ-*` 文件。
2. 影响系统结构的实现完成后，同步更新当前架构。
3. 重要技术选择可在 `doc/decisions/` 下新增 ADR。
4. 设计稿或实施计划在工作完成后可以归档到这里，但必须从正式需求或当前架构链接到最终事实，而不能让历史文件成为唯一真源。
5. 归档时保留原始日期、上下文和相对资源，不把未实施方案改写成已完成事实。
