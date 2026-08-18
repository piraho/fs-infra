#!/usr/bin/env bash
# Fails when a PR changes service behaviour but not its knowledge docs.
#
# Two rules, deliberately different in strictness:
#
#   Rule A (Service Knowledge Standard §3) — behaviour:
#     src/main/** (or app/**, lib/** on the web) changed  =>  <service>.okf and/or <service>.md changed.
#
#   Rule B (Architecture Documentation Standard §4) — SHAPE:
#     an architecturally significant path changed  =>  ARCHITECTURE.md changed.
#     "Significant" = something a diagram in ARCHITECTURE.md draws: a migration (ER diagram),
#     a controller (API surface + component diagram), an outbound client (context diagram),
#     or deployment/gateway wiring (infrastructure diagram). A bug fix inside an existing
#     method is NOT significant and does not trip this rule — the diagrams stay true.
#
# Escape hatch for a pure refactor that changes no facts: [docs-ok] in a commit message.
#
# Usage:  scripts/check-docs-in-sync.sh [BASE_REF]      (BASE_REF defaults to origin/main)
set -euo pipefail

BASE="${1:-origin/main}"
base_sha="$(git merge-base "$BASE" HEAD 2>/dev/null || echo "$BASE")"
changed="$(git diff --name-only "$base_sha"...HEAD)"

if git log --format=%B "$base_sha"..HEAD | grep -qiE '\[docs-ok\]'; then
  echo "docs-in-sync: [docs-ok] opt-out present — skipping."
  exit 0
fi

fail=0

# ---------------------------------------------------------------- Rule A: behaviour -> .okf / .md
if echo "$changed" | grep -qE '^(src/main/|app/|lib/)'; then
  if echo "$changed" | grep -qE '\.okf$' || echo "$changed" | grep -qE '(^|/)[^/]+\.md$'; then
    echo "docs-in-sync: source and knowledge docs both changed — OK."
  else
    echo "::error::Source under src/main|app|lib changed but no .okf/.md was updated."
    echo "  Update <service>.okf and/or <service>.md (Service Knowledge Standard §3),"
    echo "  or add [docs-ok] for a pure refactor."
    fail=1
  fi
else
  echo "docs-in-sync: no behaviour source changed — OK."
fi

# ------------------------------------------------- Rule B: architecture shape -> ARCHITECTURE.md
# Paths whose change alters something a diagram draws.
significant="$(echo "$changed" | grep -E \
  -e '(^|/)db/migration/.*\.sql$' \
  -e '(^|/)[A-Za-z0-9_]*Controller\.java$' \
  -e '(^|/)[A-Za-z0-9_]*Client\.java$' \
  -e '^docker-compose\.ya?ml$' \
  -e '^(deploy|gateway|terraform)/' \
  -e '(^|/)Dockerfile$' \
  || true)"

if [ -n "$significant" ]; then
  if echo "$changed" | grep -qE '^ARCHITECTURE\.md$'; then
    echo "docs-in-sync: architecture-significant change and ARCHITECTURE.md both changed — OK."
  else
    echo "::error::An architecturally significant path changed but ARCHITECTURE.md was not updated."
    echo "  These changed files are drawn by a diagram in ARCHITECTURE.md:"
    echo "$significant" | sed 's/^/    /'
    echo "  Update the affected diagram (ER / component / context / infrastructure) in ARCHITECTURE.md,"
    echo "  or add [docs-ok] if the change genuinely does not alter the drawn shape."
    fail=1
  fi
fi

exit "$fail"
