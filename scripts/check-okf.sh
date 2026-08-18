#!/usr/bin/env bash
# Validates this repo's .okf against the Service Knowledge Standard: it must parse as YAML,
# declare schema okf/1, name its service, and carry well-formed api entries.
#
# Shares the provisioning cache with check-mermaid.sh (default ~/.cache/fs-mermaid-lint,
# override with MERMAID_LINT_HOME). The linter is copied there so Node's ESM resolver finds
# js-yaml.
#
# Usage: scripts/check-okf.sh [file.okf ...]   (default: every *.okf in the repo root)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
cache="${MERMAID_LINT_HOME:-$HOME/.cache/fs-mermaid-lint}"

if ! command -v node >/dev/null 2>&1; then
  echo "::error::node is required to validate .okf files"; exit 1
fi

if [ ! -d "$cache/node_modules/js-yaml" ]; then
  echo "okf-lint: provisioning js-yaml into $cache (one time)…"
  mkdir -p "$cache"
  [ -f "$cache/package.json" ] || echo '{"name":"fs-okf-lint","private":true,"type":"module"}' > "$cache/package.json"
  ( cd "$cache" && npm install --no-audit --no-fund --silent js-yaml@^4 )
fi

cp "$here/lint-okf.mjs" "$cache/lint-okf.mjs"

if [ "$#" -gt 0 ]; then
  files=("$@")
else
  files=()
  while IFS= read -r f; do files+=("$f"); done < <(find "$repo" -maxdepth 1 -name '*.okf' | sort)
  if [ "${#files[@]}" -eq 0 ]; then
    echo "okf-lint: no .okf in this repo — nothing to check."; exit 0
  fi
fi

node "$cache/lint-okf.mjs" "${files[@]}"
