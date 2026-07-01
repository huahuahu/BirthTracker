#!/usr/bin/env bash
set -euo pipefail

[[ "${COPILOT_SCRIPT_TRIGGER:-}" == "session.archive" ]] || exit 0

with_network_proxy() {
  HTTP_PROXY="${HTTP_PROXY:-http://127.0.0.1:1082}" \
  HTTPS_PROXY="${HTTPS_PROXY:-http://127.0.0.1:1082}" \
  ALL_PROXY="${ALL_PROXY:-http://127.0.0.1:1082}" \
  http_proxy="${http_proxy:-http://127.0.0.1:1082}" \
  https_proxy="${https_proxy:-http://127.0.0.1:1082}" \
  all_proxy="${all_proxy:-http://127.0.0.1:1082}" \
  NO_PROXY="${NO_PROXY:-localhost,127.0.0.1,::1}" \
  no_proxy="${no_proxy:-localhost,127.0.0.1,::1}" \
  "$@"
}

WORKTREE_PATH="$(cd "${COPILOT_WORKSPACE_PATH:?}" && pwd -P)"
MAIN_ROOT="$(cd "${COPILOT_ROOT_PATH:?}" && pwd -P)"
BASE="${COPILOT_DEFAULT_BRANCH:-master}"

if [[ "$WORKTREE_PATH" == "$MAIN_ROOT" ]]; then
  echo "Skip: main checkout"
  exit 0
fi

BRANCH="$(git -C "$WORKTREE_PATH" branch --show-current)"
if [[ -z "$BRANCH" ]]; then
  echo "Stop: detached workspace"
  exit 1
fi

if [[ -n "$(git -C "$WORKTREE_PATH" status --short)" ]]; then
  echo "Stop: worktree has uncommitted changes"
  exit 1
fi

with_network_proxy git -C "$WORKTREE_PATH" fetch --prune origin

MERGED_AT="$(
  cd "$WORKTREE_PATH"
  with_network_proxy gh pr view "$BRANCH" --json mergedAt --jq '.mergedAt // empty' 2>/dev/null || true
)"

if with_network_proxy git -C "$WORKTREE_PATH" ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  REMOTE_BRANCH_EXISTS=1
else
  STATUS=$?
  if [[ "$STATUS" -eq 2 ]]; then
    REMOTE_BRANCH_EXISTS=0
  else
    echo "Stop: cannot check remote branch"
    exit 1
  fi
fi

SAFE_TO_DELETE=0
ALLOW_FORCE_BRANCH_DELETE=0

if [[ -n "$MERGED_AT" ]]; then
  SAFE_TO_DELETE=1
  ALLOW_FORCE_BRANCH_DELETE=1
elif [[ "$REMOTE_BRANCH_EXISTS" == "0" ]] &&
  git -C "$WORKTREE_PATH" merge-base --is-ancestor "$BRANCH" "origin/$BASE"; then
  SAFE_TO_DELETE=1
fi

if [[ "$SAFE_TO_DELETE" != "1" ]]; then
  echo "Stop: cannot prove PR is merged or safely contained in origin/$BASE"
  exit 1
fi

git -C "$WORKTREE_PATH" switch --detach "origin/$BASE"

if ! git -C "$WORKTREE_PATH" branch -d "$BRANCH"; then
  [[ "$ALLOW_FORCE_BRANCH_DELETE" == "1" ]] || exit 1
  git -C "$WORKTREE_PATH" branch -D "$BRANCH"
fi

cd "$MAIN_ROOT"
git worktree remove "$WORKTREE_PATH"
git worktree prune
