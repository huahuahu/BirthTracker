# Copilot session 自动生成 xcode-build-server 配置设计

## 背景

`scripts/copilot-session-create.sh` 会在 Copilot worktree session 创建时复制本地 `Config/Project.xcconfig`，然后运行 `xcodegen generate` 生成 `BirthTracker.xcodeproj`。VS Code 的 Swift 跳定义依赖 SourceKit-LSP 能拿到 Xcode target 的构建参数；对 XcodeGen 生成的 iOS 工程，需要在 worktree 根目录生成 `buildServer.json` 并指向当前 session 的 `BirthTracker.xcodeproj` 与 `BirthTracker` scheme。

## 目标

- 新 session 创建完成后，VS Code 中 Swift 符号、属性和类型可以通过 SourceKit-LSP 跳到定义。
- `buildServer.json` 总是针对当前 worktree 生成，不复用主 checkout 或其他 session 的路径。
- 缺少 `xcode-build-server` 或配置生成失败时显式失败，避免静默进入不可跳转状态。
- 继续把 lifecycle 脚本输出写入 `AIOutput/copilot-session-create.log`。

## 非目标

- 不提交生成的 `BirthTracker.xcodeproj`。
- 不提交 session 本地生成的 `buildServer.json`。
- 不新增 VS Code 扩展安装或全局编辑器设置管理。
- 不改变 XcodeGen target、scheme 或签名配置。

## 方案

在 `run_xcodegen` 之后新增 `run_xcode_build_server`：

1. 校验 `xcode-build-server` 命令存在；不存在时输出明确错误并以 `127` 退出。
2. 在 `WORKSPACE_PATH` 下执行：

   ```bash
   xcode-build-server config -project BirthTracker.xcodeproj -scheme BirthTracker
   ```

3. 命令完成后检查 `$WORKSPACE_PATH/buildServer.json` 是否存在；不存在则输出错误并退出。
4. 日志记录开始生成和完成生成，方便用户从 `AIOutput/copilot-session-create.log` 判断 VS Code 跳转环境是否准备好。

`xcode-build-server` 必须在 `xcodegen generate` 之后运行，因为它需要读取刚生成的 Xcode 工程与 scheme。脚本继续在主 checkout 被触发时提前退出，避免修改主 checkout 的本地状态。

## 错误处理

该配置属于用户明确要求的 VS Code 跳定义能力，因此采用严格失败策略：

- 缺少 `xcode-build-server`：失败并提示安装该工具。
- `xcode-build-server config` 返回非零状态：失败并保留命令输出到日志。
- 命令成功但未生成 `buildServer.json`：失败并提示生成结果不完整。

这种策略让配置问题在 session 创建阶段暴露，而不是让 VS Code 后续表现为“点击没反应”。

## 测试

更新 `scripts/test-copilot-session-create.sh`：

- 给测试 PATH 增加 `xcode-build-server` stub。
- stub 验证当前目录是 workspace，并收到 `config -project BirthTracker.xcodeproj -scheme BirthTracker` 参数。
- stub 创建 `buildServer.json`，测试断言该文件存在。
- 测试断言日志包含 xcode-build-server 的开始与完成输出。

代码变更完成后运行 `make check`。
