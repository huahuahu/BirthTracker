.PHONY: check fix test-scripts

check:
	./scripts/test-copilot-session-create.sh
	./scripts/test-cleanup-merged-pr-worktree-on-archive.sh
	./scripts/lint.sh

test-scripts:
	./scripts/test-copilot-session-create.sh
	./scripts/test-cleanup-merged-pr-worktree-on-archive.sh

fix:
	./scripts/format.sh
	swiftlint lint --config .swiftlint.yml --fix --quiet
	./scripts/format.sh
	./scripts/lint.sh
