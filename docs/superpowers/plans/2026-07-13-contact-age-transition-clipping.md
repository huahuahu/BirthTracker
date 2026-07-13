# 联系人年龄 Widget 切换动画裁剪实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 保留联系人年龄格式切换时旧内容向上退出、新内容从下进入的动画，同时阻止过渡内容越界覆盖联系人姓名或其他相邻内容。

**Architecture:** 只调整 `ContactAgeWidgetView` 的局部视图层级：让带身份和 `push` transition 的年龄内容成为一个左上对齐 `ZStack` 的子视图，再由稳定的父容器执行裁剪。AppIntent、格式偏好和 Widget timeline 数据流保持不变。

**Tech Stack:** Swift 6、SwiftUI、WidgetKit、AppIntents、XcodeBuildMCP

## Global Constraints

- 保留 `.push(from: .bottom)`，旧内容必须继续向上退出，新内容必须继续从下进入。
- 不使用固定高度，避免本地化文本、Widget family 或字号变化造成截断。
- 不修改 `ToggleContactAgeFormatIntent`、格式偏好存储和 timeline 刷新流程。
- 不修改或暂存 `ContactAgeWidget.swift` 与 `UpcomingBirthdaysWidget.swift` 中花花虎现有的未提交改动。
- 按花花虎此前要求，本修复不采用 TDD；通过现有检查、构建、测试和 Simulator 动画验证覆盖风险。
- 所有 Xcode 构建、测试、Simulator 截图和录屏都使用 XcodeBuildMCP。

---

### Task 1: 在局部可视区域内裁剪 push transition

**Files:**
- Modify: `BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeWidgetView.swift:56-70`
- Test: `scripts/test-widget-person-intent-storage.sh`

**Interfaces:**
- Consumes: `displayFormat.rawValue` 作为视图身份和动画触发值；`ageText` 与 `formatLabel` 作为年龄内容。
- Produces: 一个不设固定高度、左上对齐并裁剪越界绘制的年龄动画区域；不新增公共 API 或状态。

- [ ] **Step 1: 记录并保护现有工作区改动**

Run:

```bash
git status --short --branch
git diff -- BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeWidget.swift BirthTrackerPackage/Sources/BirthTrackerWidgets/UpcomingBirthdays/UpcomingBirthdaysWidget.swift
```

Expected: 只看到上述两个文件的既有未提交修改；后续不得暂存或格式化它们。

- [ ] **Step 2: 用局部 ZStack 包住可切换年龄内容**

Replace the current button label with:

```swift
Button(intent: ToggleContactAgeFormatIntent(personID: snapshot.personID)) {
  ZStack(alignment: .topLeading) {
    VStack(alignment: .leading, spacing: 4) {
      Text(ageText)
        .font(family == .systemSmall ? .title3.bold() : .title.bold())
        .monospacedDigit()
        .lineLimit(2)
        .minimumScaleFactor(0.7)
      Text(formatLabel)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .id(displayFormat.rawValue)
    .transition(.push(from: .bottom))
  }
  .frame(maxWidth: .infinity, alignment: .leading)
  .clipped()
  .animation(.smooth, value: displayFormat.rawValue)
}
.buttonStyle(.plain)
```

Use `apply_patch` and do not change any other view or intent.

- [ ] **Step 3: 只格式化并检查修改文件**

Run:

```bash
swift-format format --in-place --configuration .swift-format BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeWidgetView.swift
swift-format lint --strict --configuration .swift-format BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeWidgetView.swift
swiftlint lint --config .swiftlint.yml --quiet --strict BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeWidgetView.swift
git diff --check -- BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeWidgetView.swift
```

Expected: 四条命令均以状态码 0 结束且没有格式或 lint 错误。

- [ ] **Step 4: 运行 Widget 结构测试和项目检查**

Run:

```bash
scripts/test-widget-person-intent-storage.sh
make check
```

Expected: Widget 结构测试输出 `widget person intent storage and package structure tests passed`。如果 `make check` 仅因为两个受保护文件的既有注释缩进而在 `swift-format` 阶段失败，记录该事实且不要运行 `make fix`；其余脚本必须通过。

- [ ] **Step 5: 使用 XcodeBuildMCP 构建并运行测试**

先调用 XcodeBuildMCP `session_show_defaults`，确认：

```text
projectPath: /Users/tigerguo/.codex/worktrees/71a8/BirthTracker/BirthTracker.xcodeproj
scheme: BirthTracker
simulatorId: F4B82181-8A72-4AC3-9C95-454DE83A0C62
```

Then run:

```bash
xcodebuildmcp simulator build-and-run \
  --project-path /Users/tigerguo/.codex/worktrees/71a8/BirthTracker/BirthTracker.xcodeproj \
  --scheme BirthTracker \
  --simulator-id F4B82181-8A72-4AC3-9C95-454DE83A0C62

xcodebuildmcp simulator test \
  --project-path /Users/tigerguo/.codex/worktrees/71a8/BirthTracker/BirthTracker.xcodeproj \
  --scheme BirthTracker \
  --simulator-id F4B82181-8A72-4AC3-9C95-454DE83A0C62
```

Expected: build-and-run 成功；测试报告 0 failed。

- [ ] **Step 6: 在 Simulator 验证普通点击和快速连续点击**

1. 使用 XcodeBuildMCP Home button 返回主屏幕，并通过 `snapshot_ui` 定位联系人年龄 Widget。
2. 使用 XcodeBuildMCP `record-video` 把验证视频写入 `AIOutput/contact-age-transition-clipping-verification.mp4`。
3. 正常点击轮换三种格式，再快速连续点击至少三次。
4. 停止录屏并检查视频中间帧。

Expected: 旧内容向上退出、新内容从下进入；过渡文字只能出现在年龄区域，不能覆盖联系人姓名、Widget 标题或中号 Widget 的下方说明。

- [ ] **Step 7: 审查并提交实现**

Run:

```bash
git diff -- BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeWidgetView.swift
git diff --check
git add -- BirthTrackerPackage/Sources/BirthTrackerWidgets/ContactAge/ContactAgeWidgetView.swift
git diff --cached --name-status
git commit -m "Clip contact age format transitions"
git status --short --branch
```

Expected: 实现提交只包含 `ContactAgeWidgetView.swift`；两个受保护文件仍保持未暂存。

---

### Task 2: 更新 PR Demo 并完成远端验证

**Files:**
- Generated, ignored: `AIOutput/contact-age-transition-clipping-verification.mp4`
- External update: GitHub PR `huahuahu/BirthTracker#37`

**Interfaces:**
- Consumes: Task 1 生成并在 Simulator 中验证过的 MP4，以及实现提交。
- Produces: 包含最新无越界动画 Demo 的 PR #37，以及通过的远端检查。

- [ ] **Step 1: 验证 Demo 文件**

Run:

```bash
ffprobe -v error -show_entries format=duration,size:stream=codec_name,width,height,r_frame_rate -of default=noprint_wrappers=1 AIOutput/contact-age-transition-clipping-verification.mp4
shasum -a 256 AIOutput/contact-age-transition-clipping-verification.mp4
```

Expected: 视频编码为 H.264、尺寸与 Simulator 录屏一致、时长足以显示至少一次完整切换，并生成稳定 SHA-256。

- [ ] **Step 2: 推送实现提交**

Run:

```bash
HTTP_PROXY=http://127.0.0.1:1082 HTTPS_PROXY=http://127.0.0.1:1082 ALL_PROXY=http://127.0.0.1:1082 http_proxy=http://127.0.0.1:1082 https_proxy=http://127.0.0.1:1082 all_proxy=http://127.0.0.1:1082 NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 git push origin codex/fix-widget-editing-animation
```

Expected: 远端分支更新到最新实现提交。

- [ ] **Step 3: 上传新 Demo 并替换 PR 正文中的旧附件链接**

使用 GitHub `user-attachments` 上传接口上传 MP4，取得新的 `https://github.com/user-attachments/assets/<uuid>`；随后使用带完整 1082 代理环境的 `gh pr edit 37 --repo huahuahu/BirthTracker`，只替换 `## Demo` 下的旧附件 URL，保留其他 PR 正文。

Expected: `gh pr view 37 --repo huahuahu/BirthTracker --json body --jq .body` 显示 `## Demo` 下只有新的附件 URL；匿名请求附件 URL 返回 302 到 `video/mp4` 存储地址。

- [ ] **Step 4: 等待 PR 检查完成**

Run:

```bash
HTTP_PROXY=http://127.0.0.1:1082 HTTPS_PROXY=http://127.0.0.1:1082 ALL_PROXY=http://127.0.0.1:1082 http_proxy=http://127.0.0.1:1082 https_proxy=http://127.0.0.1:1082 all_proxy=http://127.0.0.1:1082 NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1 gh pr checks 37 --repo huahuahu/BirthTracker --watch --interval 10
```

Expected: 0 failing、0 pending，全部检查成功。
