#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

root = Path(sys.argv[1])
errors: list[str] = []


def fail(message: str) -> None:
    errors.append(message)


legacy_docs = root / "docs"
if legacy_docs.exists():
    fail("top-level docs/ should not exist; current documentation belongs under doc/")

archive_plans = root / "doc" / "history" / "plans"
archive_designs = root / "doc" / "history" / "designs"
active_markdown = [root / "README.md", root / "AGENTS.md"]
active_markdown.extend(
    path
    for path in sorted((root / "doc").rglob("*.md"))
    if archive_plans not in path.parents and archive_designs not in path.parents
)

for path in active_markdown:
    text = path.read_text(encoding="utf-8")
    lowered = text.lower()
    for forbidden in ("docs/superpowers", "superpowers:"):
        if forbidden in lowered:
            fail(f"{path.relative_to(root)} should not reference retired {forbidden}")

warning = "> [!WARNING]"
for path in sorted(archive_plans.glob("*.md")):
    if warning not in "\n".join(path.read_text(encoding="utf-8").splitlines()[:10]):
        fail(f"{path.relative_to(root)} should begin with an archive warning")

requirements_index = root / "doc" / "requirements" / "README.md"
requirements_index_text = requirements_index.read_text(encoding="utf-8")
for path in sorted((root / "doc" / "requirements").glob("REQ-[0-9]*.md")):
    if path.name not in requirements_index_text:
        fail(f"{path.relative_to(root)} should appear in doc/requirements/README.md")

inline_link = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
reference_link = re.compile(r"^\s*\[[^\]]+\]:\s*(\S+)", re.MULTILINE)
markdown_files = [root / "README.md", *sorted((root / "doc").rglob("*.md"))]


def link_path(raw_target: str) -> str | None:
    target = raw_target.strip()
    if target.startswith("<") and ">" in target:
        target = target[1 : target.index(">")]
    else:
        target = target.split(maxsplit=1)[0]

    if not target or target.startswith(("#", "/")):
        return None

    parsed = urlsplit(target)
    if parsed.scheme or parsed.netloc:
        return None
    return unquote(parsed.path)


for path in markdown_files:
    text = path.read_text(encoding="utf-8")
    targets = [*inline_link.findall(text), *reference_link.findall(text)]
    for raw_target in targets:
        relative_path = link_path(raw_target)
        if relative_path is None:
            continue
        resolved = path.parent / relative_path
        if not resolved.exists():
            fail(
                f"{path.relative_to(root)} contains a broken relative link: "
                f"{raw_target.strip()}"
            )

if errors:
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    raise SystemExit(1)

print("PASS: documentation layout, archive warnings, requirements index, and links")
PY
