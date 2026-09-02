#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 2 && $1 == --case && $2 == cli ]] || { printf 'RESULT FAIL seed-contract-runtime\n' >&2; exit 1; }
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
if output=$(cd "$root" && python3 common/tests/test_seed_contract_runtime.py cli 2>&1) && [[ $output == 'PASS cli' ]]; then
  printf 'RESULT PASS seed-contract-runtime\n'
else
  printf '%s\n' "$output" >&2; exit 1
fi
