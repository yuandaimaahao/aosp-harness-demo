#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

section() {
  printf '\n============================================================\n'
  printf '%s\n' "$1"
  printf '============================================================\n'
}

section '1. Claude adapter'
./.claude/bin/claude-feature --dry-run --contract

section '2. Codex adapter'
./.codex/bin/codex-feature --dry-run --contract

section '3. Shared parity'
./.harness/bin/check-parity.sh

section '4. Strict verifier'
./.harness/features/dev-sidebar/verify-sidebar.sh --demo

section '5. Exploration-only skip'
set +e
skip_output="$(DEMO_SKIP=1 ./.harness/features/dev-sidebar/verify-sidebar.sh --demo 2>&1)"
skip_rc=$?
set -e
if [[ "$skip_rc" -eq 0 || "$skip_output" != *'RESULT INCOMPLETE'* ]]; then
  echo 'error: strict skip demo did not fail with RESULT INCOMPLETE' >&2
  exit 1
fi
printf '%s\n' "$skip_output"
DEMO_SKIP=1 ./.harness/features/dev-sidebar/verify-sidebar.sh --demo --allow-skip

section '6. Regression'
./tests/test-harness.sh

echo 'Claude Code + Codex 共用 Harness 演示完毕'
