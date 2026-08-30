# 接入 SFSafeSymbols 设计

## 背景

BirthTracker 当前在 SwiftUI 页面和 Widget 中直接用字符串引用 SF Symbols，例如 `Image(systemName:)`、`Label(systemImage:)` 和 `Button(systemImage:)`。字符串写法容易出现拼写错误，也无法在编译期提示 symbol 的系统版本可用性。

本次接入 `SFSafeSymbols/SFSafeSymbols`，把现有 SF Symbol 调用迁移为 typed symbol API，让编译器参与校验。

## 目标

- 使用 Swift Package Manager 引入 `SFSafeSymbols/SFSafeSymbols`。
- 迁移当前仓库内已经发现的 SF Symbol 字符串调用。
- 保持现有 UI、布局、文案和交互不变。
- 不增加本地 wrapper 或额外抽象，避免为少量 symbol 引入不必要复杂度。

## 非目标

- 不替换非 SF Symbol 图标资源。
- 不重构 SwiftUI 视图结构。
- 不改变最低系统版本、签名配置或 App/Widget target 结构。

## 方案

采用直接依赖并直接使用 `SFSafeSymbols` API 的方案。

1. 在 `BirthTrackerPackage/Package.swift` 增加远程 package dependency。
2. 让 `Features` target 依赖 `SFSafeSymbols`，覆盖 package 内的 SwiftUI 页面。
3. 在 `project.yml` 增加同一个远程 package，并让 `BirthTrackerWidget` target 依赖该 product，覆盖 Widget target 内的 SwiftUI 代码。
4. 迁移当前发现的 6 处 SF Symbol 调用，涉及 5 个 symbol 名称：
   - `calendar.badge.plus`
   - `plus`
   - `gearshape`
   - `gift`
   - `sparkles`

## 取舍

- 只添加依赖但不迁移调用，风险最低，但不能满足“用到 SF Symbol 的地方保证版本正确”的目标。
- 新增本地 wrapper 可以统一项目 API，但当前 symbol 数量很少，会让实现和维护成本高于收益。
- 直接使用 `SFSafeSymbols` 能以最小改动获得 typed symbol 和可用性提示，是当前最合适的方案。

## 验证

实现后执行：

1. `xcodegen generate`
2. `make check`

如果依赖解析或 Xcode 工程生成失败，优先检查 `project.yml` 与 `Package.swift` 的 package URL、product 名称和 target dependency 写法是否一致。
