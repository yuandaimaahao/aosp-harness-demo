#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT="${HARNESS_ROOT:-$SCRIPT_ROOT}"
FEATURE="${FEATURE_NAME:-dev-sidebar}"
LIST="$ROOT/features/$FEATURE/repos.tsv"
REPOS=()

if [[ ! -f "$LIST" ]]; then
  echo "MISSING $LIST" >&2
  exit 1
fi

while IFS=$'\t' read -r path listed_feature description || [[ -n "${path:-}" ]]; do
  case "${path:-}" in
    ''|'#'*) continue ;;
  esac
  REPOS+=("$path")
done < "$LIST"

if [[ "${#REPOS[@]}" -eq 0 ]]; then
  echo "MISSING repositories in $LIST" >&2
  exit 1
fi

if [[ "${1:-}" == '--demo' ]]; then
  last_index=$((${#REPOS[@]} - 1))
  for index in "${!REPOS[@]}"; do
    repo="${REPOS[$index]}"
    branch="$FEATURE"
    if [[ "$index" -eq "$last_index" ]]; then
      branch="${FEATURE}-demo-drift"
    fi
    if [[ "$branch" == "$FEATURE" ]]; then
      echo "OK      $repo @ $branch"
    else
      echo "DRIFT   $repo @ $branch (应为 $FEATURE)"
    fi
  done
  exit 1
fi

bad=0
for repo in "${REPOS[@]}"; do
  if [[ ! -f "$ROOT/$repo/.git" && ! -d "$ROOT/$repo/.git" ]]; then
    echo "MISSING $repo"
    bad=1
    continue
  fi

  branch="$(git -C "$ROOT/$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [[ "$branch" == "$FEATURE" ]]; then
    echo "OK      $repo @ $branch"
  else
    echo "DRIFT   $repo @ ${branch:-DETACHED} (应为 $FEATURE)"
    bad=1
  fi
done

exit "$bad"
