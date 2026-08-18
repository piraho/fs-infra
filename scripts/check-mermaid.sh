#!/usr/bin/env bash
# Compiles every mermaid diagram in the repo's Markdown so a broken diagram fails the
# build instead of silently rendering as a grey error box on GitHub.
#
# Provisions mermaid + jsdom once into a cache dir (default ~/.cache/fs-mermaid-lint) and
# runs scripts/lint-mermaid.mjs from there, so Node's ESM resolver finds the packages.
#
# Usage: scripts/check-mermaid.sh [file.md ...]     (default: ARCHITECTURE.md + docs/*.md)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
cache="${MERMAID_LINT_HOME:-$HOME/.cache/fs-mermaid-lint}"

if ! command -v node >/dev/null 2>&1; then
  echo "::error::node is required to compile mermaid diagrams"; exit 1
fi

if [ ! -d "$cache/node_modules/mermaid" ] || [ ! -d "$cache/node_modules/jsdom" ]; then
  echo "mermaid-lint: provisioning parser into $cache (one time)…"
  mkdir -p "$cache"
  ( cd "$cache" \
    && [ -f package.json ] || echo '{"name":"fs-mermaid-lint","private":true,"type":"module"}' > package.json )
  ( cd "$cache" && npm install --no-audit --no-fund --silent mermaid@^11 jsdom@^25 )
fi

# The linter must execute from the cache dir so `import 'mermaid'` resolves.
cp "$here/lint-mermaid.mjs" "$cache/lint-mermaid.mjs"

if [ "$#" -gt 0 ]; then
  files=("$@")
else
  files=()
  [ -f "$repo/ARCHITECTURE.md" ] && files+=("$repo/ARCHITECTURE.md")
  while IFS= read -r f; do files+=("$f"); done < <(find "$repo/docs" -name '*.md' 2>/dev/null | sort)
  if [ "${#files[@]}" -eq 0 ]; then
    echo "::error::no ARCHITECTURE.md and no docs/*.md to check"; exit 1
  fi
fi

node "$cache/lint-mermaid.mjs" "${files[@]}"
