# 需求 Backlog

还没准备好单独成为 `REQ-xxxx` 文件的小想法、碎片和未来需求，先放在这里。

## 产品想法

- 改进生日统计和时间线摘要。
- 扩展 Widget 配置和展示选项。
- 将 `UpcomingBirthdaysWidget` 改为以单人生日倒计时为主角，同时保留 `ContactAgeWidget` 展示已经出生多久的现有职责；已确认的“小缺口圆环”方向见 [单人生日倒计时 Widget 设计](../../docs/superpowers/specs/2026-07-12-birthday-countdown-widget-design.md)。
- 等核心模型稳定后加入数据导出。
- 发布前审查 App Store 元数据和本地化需求。

## 后续再确认的问题

- App 是否需要支持多人管理同一个生日列表？
- 生产环境里的 iCloud 同步应该可选，还是默认始终启用？
- 哪些导入来源最重要：通讯录、CSV、手动录入，还是其他 App？
