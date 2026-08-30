# Codex worktree 自动初始化设计

## 背景

Codex Environment 会在新 worktree 创建后、任务开始前，在项目根目录执行 Setup script，并提供主 checkout 路径 `CODEX_SOURCE_TREE_PATH` 和新 worktree 路径 `CODEX_WORKTREE_PATH`。BirthTracker 现有的 `scripts/copilot-session-create.sh` 已经为 Copilot session 完成一整套初始化：复制本地 Xcode 配置、运行 XcodeGen、生成 `buildServer.json`、为 Simulator 执行 `build-for-testing`，并生成 xcode-build-server compile cache。

Codex 需要获得同等能力，但不应依赖 Copilot 专用的触发器和环境变量。两种入口也不应各自维护一份完整初始化逻辑。

## 目标

- 新 Codex worktree 创建后自动完成与 Copilot session 相同的完整初始化流程。
- Codex 入口直接使用 `CODEX_SOURCE_TREE_PATH` 和 `CODEX_WORKTREE_PATH`，不伪造 `COPILOT_*` 环境变量。
- Copilot 与 Codex 共享一份核心初始化实现，避免行为随时间分叉。
- 保留现有 Copilot 入口的触发器、日志路径、日志前缀和失败行为。
- Codex 初始化过程写入独立日志，能够定位路径、工具、工程生成或构建失败。

## 非目标

- 不修改 Codex 应用的全局配置文件或 Environment 数据存储格式。
- 不自动安装 XcodeGen、xcode-build-server 或其他开发工具。
- 不提交 `Config/Project.xcconfig`、`BirthTracker.xcodeproj`、`buildServer.json`、DerivedData 或 xcresult。
- 不改变 Xcode target、scheme、签名配置或 Simulator 默认值。
- 当目标路径就是主 checkout 时，不复制配置、不生成工程，也不执行构建；只保留现有的日志记录后提前退出行为。

## 架构

初始化逻辑拆分为三个脚本：

1. `scripts/copilot-session-create.sh`
   - 保留 `COPILOT_SCRIPT_TRIGGER=session.create` 校验。
   - 校验 `COPILOT_WORKSPACE_PATH` 和 `COPILOT_ROOT_PATH`。
   - 将路径、日志文件名和消息前缀传给共享核心脚本。
2. `scripts/codex-worktree-setup.sh`
   - 校验 `CODEX_WORKTREE_PATH` 和 `CODEX_SOURCE_TREE_PATH`。
   - 将路径、日志文件名和消息前缀传给共享核心脚本。
   - 不引入额外 trigger，因为 Codex Environment 的 Setup script 本身就是触发边界。
3. `scripts/worktree-setup.sh`
   - 作为仓库内部共享入口，只接收两个调用方传入的规范化参数。
   - 承担当前 Copilot 脚本中的全部通用初始化逻辑。
   - 根据调用方参数选择日志文件和消息前缀。

共享核心保持 POSIX `sh` 兼容。两个平台入口都通过脚本自身所在目录定位共享核心，避免依赖调用者当前目录来寻找脚本。

## 执行流程

Codex Environment 中配置以下 Setup script：

```sh
cd "$CODEX_WORKTREE_PATH"
./scripts/codex-worktree-setup.sh
```

Codex 入口依次执行：

1. 确认两个 `CODEX_*` 路径变量非空。
2. 确认 source tree 和 worktree 目录存在，并用 `pwd -P` 规范化路径。
3. 调用共享核心，指定：
   - source tree 为本地配置来源；
   - worktree 为所有生成命令的工作目录；
   - 日志文件为 `AIOutput/codex-worktree-setup.log`；
   - 日志消息前缀为 `codex-worktree-setup`。
4. 共享核心在 worktree 下创建 `AIOutput` 并重定向后续输出到日志。
5. 如果规范化后的 source tree 与 worktree 相同，只记录主 checkout 提示，不复制配置或运行生成与构建命令，然后退出成功。
6. 如果目标 `Config/Project.xcconfig` 不存在，优先复制 source tree 的本地 `Project.xcconfig`，否则复制 source tree 的 example。
7. 在 worktree 中运行 `xcodegen generate`。
8. 运行 `xcode-build-server config`，生成指向当前 worktree 和 `AIOutput/DerivedData` 的 `buildServer.json`。
9. 清理仅限预期路径的旧 DerivedData 和 xcresult，然后根据 `.xcodebuildmcp/config.yaml` 中的 `simulatorId` 选择构建 destination；未配置时使用 generic iOS Simulator。
10. 对 `buildServer.json` 指定的 workspace 和 scheme 执行 Debug `build-for-testing`。
11. 运行 `xcode-build-server parse` 生成 compile cache，并检查结果文件非空。

Copilot 入口走相同流程，但继续使用 `AIOutput/copilot-session-create.log` 和 `copilot-session-create` 消息前缀，因此已有日志消费者和测试无需改变契约。

## 错误处理与安全边界

- 必需环境变量缺失、路径不存在或无法规范化时，在尚未重定向日志前输出到标准错误并以 `2` 退出。
- `xcodegen`、`xcode-build-server`、`xcodebuild`、`plutil` 或 hash 工具缺失时，记录明确错误并以 `127` 退出。
- 配置来源不存在、`buildServer.json` 缺少必需值、生成结果缺失或 compile cache 为空时，以非零状态失败。
- 外部命令的非零退出状态直接导致初始化失败，不吞掉错误。
- 删除 DerivedData 前必须确认 build root 精确等于当前 worktree 的 `AIOutput/DerivedData`，不接受 `buildServer.json` 指向其他路径。
- 目标 `Config/Project.xcconfig` 已存在时不覆盖，避免丢失 worktree 中的本地修改。
- 所有包含路径的 shell 展开都使用双引号，支持路径中的空格。

严格失败是刻意行为：一个只完成部分步骤的 worktree 会产生难以诊断的工程、SourceKit-LSP 或构建问题，应该在 Setup script 阶段直接暴露。

## 测试与验证

保留并运行 `scripts/test-copilot-session-create.sh`，证明重构没有改变 Copilot 的触发器、参数、日志或完整构建流程。

新增 `scripts/test-codex-worktree-setup.sh`，通过临时 source tree、临时 worktree 和 stub 工具验证：

- 缺少 `CODEX_SOURCE_TREE_PATH` 或 `CODEX_WORKTREE_PATH` 时返回 `2`，且不会运行初始化工具。
- Codex 入口使用正确的 source tree 和 worktree，而不是读取 `COPILOT_*` 变量。
- 本地配置复制、XcodeGen、build server 配置、`build-for-testing` 和 compile cache 生成顺序完整执行。
- 构建 destination 优先使用 `.xcodebuildmcp/config.yaml` 中的 `simulatorId`。
- 日志写入 `AIOutput/codex-worktree-setup.log`，并使用 Codex 专属消息前缀。
- source tree 与 worktree 相同时，除日志外不复制配置、不生成工程且不运行构建。
- 目标配置已经存在时保持原内容。

将新的 Codex 测试加入 `make check` 和 `make test-scripts` 当前执行的脚本检查链。代码实现完成后运行 `make check`，并检查 Git diff，确认生成文件和本地配置没有被纳入版本控制。

## 文档更新

README 的 Development 部分新增 Codex Environment 说明，包括：

- 可直接粘贴的 Setup script 两行配置；
- 依赖的两个 Codex 路径变量；
- 完整初始化所包含的步骤；
- 日志位置 `AIOutput/codex-worktree-setup.log`；
- 初始化失败会阻止进入不完整工作环境的行为。
