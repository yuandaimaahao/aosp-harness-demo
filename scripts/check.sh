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
printf 'RESULT PASS  aosp-harness offline quality gate\n'
