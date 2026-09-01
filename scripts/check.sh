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
quality_run_static() {
  local baseline_file="$repo_root/scripts/shell-quality-baseline.tsv" baseline_sha=62211b0b05c8ada6e48e408696244a655e1b0cb728c3a5406b601fc0af074a5f path blob; local -a shell_files=(); declare -A approved=()
  [[ "$(sha256sum "$baseline_file" | awk '{print $1}')" == "$baseline_sha" ]] || quality_protocol_error 'baseline canonical digest mismatch'
  LC_ALL=C awk -F '\t' 'NF != 2 || $1 == "" || $2 !~ /^[0-9a-f]{40}$/ || (NR > 1 && $1 <= previous) || paths[$1]++ || blobs[$2]++ {exit 1} {previous=$1} END {if (NR != 30) exit 1}' "$baseline_file" || quality_protocol_error 'baseline canonical format mismatch'
  while IFS=$'\t' read -r path blob; do approved["$path"]="$blob"; done <"$baseline_file"
  while IFS= read -r -d '' path; do shell_files+=("$path"); done < <(quality_list_shell_files)
  for path in "${shell_files[@]}"; do
    [[ "${approved[$path]-}" == "$(git hash-object "$path")" ]] && continue
    shellcheck -x --severity=warning "$path" || return 1
    shfmt -d -i 2 -ci -bn "$path" || return 1
  done
}
if [[ "$mode" == --ci ]]; then
  for tool_spec in shellcheck:0.11.0 shfmt:3.14.0 gitleaks:8.30.1; do
    tool="${tool_spec%%:*}"; expected="${tool_spec#*:}"
    command -v "$tool" >/dev/null 2>&1 || quality_protocol_error "missing $tool $expected"
    case "$tool" in
      shellcheck) [[ "$(shellcheck --version | awk '/^version:/ {print $2}')" == 0.11.0 ]] || quality_protocol_error 'expected shellcheck 0.11.0' ;;
      shfmt) [[ "$(shfmt --version)" == v3.14.0 ]] || quality_protocol_error 'expected shfmt 3.14.0' ;;
      gitleaks) [[ "$(gitleaks version)" == 8.30.1 ]] || quality_protocol_error 'expected gitleaks 8.30.1' ;;
    esac
  done
fi
quality_run_core || exit 1
[[ "$mode" != --ci ]] || quality_run_static || exit 1
printf 'RESULT PASS  aosp-harness offline quality gate\n'
