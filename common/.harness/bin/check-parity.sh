#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${HARNESS_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/shared-harness-parity.XXXXXX")"
trap 'rm -rf -- "$TMP_DIR"' EXIT

HARNESS_ROOT="$ROOT" "$ROOT/.claude/bin/claude-feature" --dry-run --contract \
  > "$TMP_DIR/claude"
HARNESS_ROOT="$ROOT" "$ROOT/.codex/bin/codex-feature" --dry-run --contract \
  > "$TMP_DIR/codex"

sed 's/^client=.*/client=CLIENT/' "$TMP_DIR/claude" > "$TMP_DIR/claude.normalized"
sed 's/^client=.*/client=CLIENT/' "$TMP_DIR/codex" > "$TMP_DIR/codex.normalized"

if ! diff -u "$TMP_DIR/claude.normalized" "$TMP_DIR/codex.normalized"; then
  echo 'PARITY FAIL  Claude/Codex 公共契约不一致' >&2
  exit 1
fi

if ! grep -Fq '.harness/common.md' "$ROOT/CLAUDE.md" ||
   ! grep -Fq '.harness/common.md' "$ROOT/AGENTS.md"; then
  echo 'PARITY FAIL  两个上下文文件都必须引用 .harness/common.md' >&2
  exit 1
fi

if [[ -e "$ROOT/.claude/repos.tsv" || -e "$ROOT/.codex/repos.tsv" ]]; then
  echo 'PARITY FAIL  manifest 不得复制到客户端目录' >&2
  exit 1
fi

echo 'PARITY PASS  Claude/Codex 共享同一公共契约'
