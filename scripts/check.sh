#!/usr/bin/env bash
set -u
quality_protocol_error() {
  printf 'error: %s\n' "$*" >&2
  exit 2
}
[[ "$#" -eq 1 && ( "$1" == --offline || "$1" == --ci ) ]] ||
  quality_protocol_error 'usage: scripts/check.sh --offline|--ci'
mode="$1"
for command_name in bash git python3 rg find sort awk sed grep sha256sum; do
  command -v "$command_name" >/dev/null 2>&1 ||
    quality_protocol_error "missing required command: $command_name"
done
repo_root="$(cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)"
cd -- "$repo_root"
quality_list_shell_files() {
  find . -path './.git' -prune -o -path './.spec' -prune -o -type f -print0 |
    while IFS= read -r -d '' path; do
      IFS= read -r first <"$path" || first=
      [[ "$path" == *.sh || "$first" == '#!/usr/bin/env bash' || "$first" == '#!/bin/bash' ]] && printf '%s\0' "${path#./}"
    done | LC_ALL=C sort -z
}
quality_run_core() {
  local path; local -a shell_files=() root_tests=()
  while IFS= read -r -d '' path; do shell_files+=("$path"); done < <(quality_list_shell_files)
  for path in "${shell_files[@]}"; do bash -n "$path" || return 1; done
  while IFS= read -r -d '' path; do root_tests+=("${path#./}"); done < <(find ./tests -maxdepth 1 -type f -name 'test-*.sh' -print0 | LC_ALL=C sort -z)
  for path in "${root_tests[@]}"; do QUALITY_GATE_NESTED=1 bash "$path" || return 1; done
}
quality_run_core || exit 1
printf 'RESULT PASS  aosp-harness offline quality gate\n'
