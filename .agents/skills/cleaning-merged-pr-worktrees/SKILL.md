---
name: cleaning-merged-pr-worktrees
description: Use when cleaning up a local git worktree for a pull request that was already merged, closed, or whose remote branch was deleted
---

# 清理已合并 PR 的 Worktree

## 概览

只在确认远端 PR 或远端分支已经不再需要本地 worktree 后，才安全删除本地 PR worktree。

**核心原则：** 先确认远端状态 -> 从功能分支 detached 到主分支 -> 删除本地分支 -> 从外部删除 worktree folder。

## 什么时候使用

当用户说类似下面的话时使用：

- “清理这个已经 merge 的 PR worktree”
- “PR 已经合并了，删除本地 worktree”
- “远端分支没了，把本地 PR worktree 清掉”

不要用于放弃未合并的工作；那种情况应使用分支完成/丢弃工作流。

## 必要安全检查

以下任一检查失败时，停止删除并询问用户：

| 检查 | 命令 | 停止条件 |
| --- | --- | --- |
| worktree 是否干净 | `git status --short` | 有任何输出 |
| 是否有本地分支 | `git branch --show-current` | 为空但需要删分支 |
| 远端状态是否明确 | `gh pr view "$BRANCH"` 和 `git ls-remote --heads origin "$BRANCH"` | 无法证明 PR 已合并，也无法证明远端分支已删除 |
| 远端分支已删但 PR 未确认合并 | `git merge-base --is-ancestor "$BRANCH" "origin/$BASE"` | 本地分支还有未进 base 的提交 |

执行 `gh`、`git fetch` 等网络命令时，遵守当前会话的网络和代理规则。

## 流程

### 1. 记录状态，并确认远端可以安全清理

```bash
WORKTREE_PATH=$(git rev-parse --show-toplevel)
BRANCH=$(git branch --show-current)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
MAIN_ROOT=$(git -C "$GIT_COMMON/.." rev-parse --show-toplevel)
BASE=${BASE:-master}

git status --short
git fetch --prune origin
gh pr view "$BRANCH" --json state,mergedAt,headRefName,baseRefName
git ls-remote --heads origin "$BRANCH"
```

只有在证明以下任一条件成立时继续：

- PR 存在，并且 `mergedAt` 不是 `null`。
- 远端分支已删除，并且 `git merge-base --is-ancestor "$BRANCH" "origin/$BASE"` 成功。

如果 PR 只是关闭但未合并，或者远端分支已删除但本地分支还有未进入 base 的提交，停止并询问用户。

### 2. 从功能分支 detached 到主分支，并删除本地分支

这一步必须在 worktree folder 还存在时执行：

```bash
git -C "$WORKTREE_PATH" switch --detach "origin/$BASE"
git -C "$WORKTREE_PATH" branch -d "$BRANCH"
```

如果 `branch -d` 因为 squash merge 失败，只有在前面已经确认 PR 已合并时，才使用强制删除：

```bash
git -C "$WORKTREE_PATH" branch -D "$BRANCH"
```

### 3. 从 worktree 外部删除 worktree folder

不要在即将删除的 worktree 内执行 `git worktree remove`。

```bash
cd "$MAIN_ROOT"
git worktree remove "$WORKTREE_PATH"
git worktree prune
git worktree list
```

如果 `git worktree remove` 提示该路径不是已注册 worktree，必须先得到用户明确确认，才能使用 `rm -rf`。

## 快速参考

| 情况 | 动作 |
| --- | --- |
| PR 已合并 | detached、删除本地分支、删除 worktree |
| 远端分支已删除，且本地分支是 base 的祖先 | detached、删除本地分支、删除 worktree |
| 远端分支已删除，但本地分支还有独有提交 | 停止并询问 |
| worktree 有未提交改动 | 停止并询问 |
| 当前 shell 在要删除的 worktree 内 | 先 detached，再从 `MAIN_ROOT` 删除 |

## 常见错误

- 还在功能分支上时就删除本地分支。
- 先删除 folder，再删除分支。
- 把“远端分支已删除”当成“PR 已合并”的证明。
- 在要删除的 worktree 内执行 `git worktree remove`。
- 未证明 PR 已合并或分支已进入 base 就使用 `branch -D`。
