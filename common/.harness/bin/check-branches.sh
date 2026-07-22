#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${HARNESS_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

contract="$(HARNESS_ROOT="$ROOT" \
  "$ROOT/.harness/bin/resolve-feature.sh" --client claude --contract)"
target_branch="$(awk -F= '$1 == "target_branch" { print substr($0, index($0, "=") + 1) }' \
  <<<"$contract")"
repositories="$(awk -F= '$1 == "repositories" { print substr($0, index($0, "=") + 1) }' \
  <<<"$contract")"

[[ -n "$target_branch" && -n "$repositories" ]] || {
  echo 'error: public contract is missing target_branch or repositories' >&2
  exit 1
}

IFS=',' read -r -a repo_list <<<"$repositories"
bad=0
for repo in "${repo_list[@]}"; do
  repo_root="$ROOT/$repo"
  if [[ ! -e "$repo_root/.git" && ! -L "$repo_root/.git" ]]; then
    echo "MISSING $repo"
    bad=1
    continue
  fi
  if ! git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
    echo "INVALID $repo"
    bad=1
    continue
  fi
  if branch="$(git -C "$repo_root" symbolic-ref --quiet --short HEAD 2>/dev/null)"; then
    :
  elif git -C "$repo_root" rev-parse --verify 'HEAD^{object}' >/dev/null 2>&1; then
    branch='DETACHED'
  else
    echo "INVALID $repo"
    bad=1
    continue
  fi
  if [[ "$branch" == "$target_branch" ]]; then
    echo "OK      $repo @ $branch"
  else
    echo "DRIFT   $repo @ $branch (expected $target_branch)"
    bad=1
  fi
done

exit "$bad"
