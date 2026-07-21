#!/usr/bin/env bash
# 检查 repos.tsv 声明的所有涉及仓是否都在 feature 分支。
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT="${HARNESS_ROOT:-$SCRIPT_ROOT}"
FEATURE="${FEATURE_NAME:-dev-sidebar}"
LIST="$ROOT/features/$FEATURE/repos.tsv"
REPOS=()

[[ -f "$LIST" ]] || {
  echo "MISSING $LIST" >&2
  exit 1
}

while read -r path convention tags rest || [[ -n "${path:-}" ]]; do
  case "${path:-}" in
    ""|'#'*) continue ;;
  esac
  REPOS+=("$path")
done < "$LIST"

[[ ${#REPOS[@]} -gt 0 ]] || {
  echo "MISSING repos in $LIST" >&2
  exit 1
}

if [[ "${1:-}" == "--demo" ]]; then
  bad=0
  for repo in "${REPOS[@]}"; do
    branch="$FEATURE"
    [[ "$repo" == "build/make" ]] && branch="main"
    if [[ "$branch" == "$FEATURE" ]]; then
      echo "OK      $repo @ $branch"
    else
      echo "DRIFT   $repo @ $branch (应为 $FEATURE)"
      bad=1
    fi
  done
  exit "$bad"
fi

bad=0
for repo in "${REPOS[@]}"; do
  if ! git -C "$ROOT/$repo" rev-parse --git-dir >/dev/null 2>&1; then
    echo "MISSING $repo"
    bad=1
    continue
  fi
  branch="$(git -C "$ROOT/$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
  if [[ "$branch" == "$FEATURE" ]]; then
    echo "OK      $repo @ $branch"
  else
    echo "DRIFT   $repo @ $branch (应为 $FEATURE)"
    bad=1
  fi
done

exit "$bad"
