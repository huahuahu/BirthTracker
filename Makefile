.PHONY: check fix

check:
	./scripts/lint.sh

fix:
	./scripts/format.sh
	swiftlint lint --config .swiftlint.yml --fix --quiet
	./scripts/format.sh
	./scripts/lint.sh
