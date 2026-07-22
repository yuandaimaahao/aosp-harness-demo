#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOT="${HARNESS_ROOT:-$DEFAULT_ROOT}"
CLIENT=''

usage() {
  printf '%s\n' 'Usage: resolve-feature.sh --client claude|codex [--contract]'
}

while (($# > 0)); do
  case "$1" in
    --client)
      (($# >= 2)) || { usage >&2; exit 2; }
      CLIENT="$2"
      shift 2
      ;;
    --contract)
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

case "$CLIENT" in
  claude|codex) ;;
  *)
    echo 'error: client 必须是 claude 或 codex' >&2
    exit 1
    ;;
esac

current_file="$ROOT/CURRENT_FEATURE"
if [[ ! -f "$current_file" ]]; then
  echo "error: 缺少 $current_file" >&2
  exit 1
fi

feature="$(cat "$current_file")"
if [[ "$feature" != "${feature//$'\n'/}" ||
      "$feature" != "${feature//$'\r'/}" ||
      ! "$feature" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "error: INVALID feature '$feature'" >&2
  exit 1
fi

manifest_rel=".harness/features/$feature/repos.tsv"
verifier_rel=".harness/features/$feature/verify-sidebar.sh"
manifest="$ROOT/$manifest_rel"
verifier="$ROOT/$verifier_rel"
common="$ROOT/.harness/common.md"

[[ -f "$manifest" ]] || { echo "error: 缺少 $manifest_rel" >&2; exit 1; }
[[ -x "$verifier" ]] || { echo "error: 缺少可执行 verifier $verifier_rel" >&2; exit 1; }
[[ -f "$common" ]] || { echo 'error: 缺少 .harness/common.md' >&2; exit 1; }

repo_paths=''
line_number=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line_number=$((line_number + 1))
  case "$line" in
    ''|'#'*) continue ;;
  esac
  IFS=$'\t' read -r path convention tags description extra <<<"$line"
  if [[ -n "${extra:-}" || -z "$path" || -z "$convention" || -z "$tags" ||
        -z "$description" ]]; then
    echo "error: $manifest_rel:$line_number 必须有四个非空 tab 字段" >&2
    exit 1
  fi
  if [[ -n "$repo_paths" ]]; then
    repo_paths+=","
  fi
  repo_paths+="$path"
done < "$manifest"

[[ -n "$repo_paths" ]] || { echo "error: $manifest_rel 没有涉及仓" >&2; exit 1; }

hash_files=("$ROOT/CURRENT_FEATURE" "$common" "$manifest" "$verifier")
if command -v sha256sum >/dev/null 2>&1; then
  contract_sha256="$(cat "${hash_files[@]}" | sha256sum | awk '{print $1}')"
else
  contract_sha256="$(cat "${hash_files[@]}" | shasum -a 256 | awk '{print $1}')"
fi

printf 'client=%s\n' "$CLIENT"
printf 'feature=%s\n' "$feature"
printf 'manifest=%s\n' "$manifest_rel"
printf 'verifier=%s\n' "$verifier_rel"
printf 'repositories=%s\n' "$repo_paths"
printf 'contract_sha256=%s\n' "$contract_sha256"
