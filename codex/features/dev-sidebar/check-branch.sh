#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT="${HARNESS_ROOT:-$SCRIPT_ROOT}"
FEATURE="${FEATURE_NAME:-dev-sidebar}"

valid_feature_name() {
  local feature="$1"
  local LC_ALL=C

  [[ "$feature" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

if ! valid_feature_name "$FEATURE"; then
  echo "INVALID feature: expected [A-Za-z0-9][A-Za-z0-9._-]*" >&2
  exit 1
fi

LIST="$ROOT/features/$FEATURE/repos.tsv"
REPOS=()
LISTED_FEATURES=()
DESCRIPTIONS=()

if [[ ! -f "$LIST" ]]; then
  echo "MISSING $LIST" >&2
  exit 1
fi
if python3 - "$LIST" <<'PY'
import pathlib
import sys

try:
    data = pathlib.Path(sys.argv[1]).read_bytes()
except OSError:
    raise SystemExit(2)
raise SystemExit(1 if b'\0' in data else 0)
PY
then
  :
else
  manifest_bytes_rc=$?
  if [[ "$manifest_bytes_rc" -eq 1 ]]; then
    echo "INVALID manifest $LIST: NUL bytes are not allowed" >&2
  else
    echo "INVALID manifest $LIST: unable to read raw bytes" >&2
  fi
  exit 1
fi

line_number=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line_number=$((line_number + 1))
  case "$line" in
    ''|'#'*) continue ;;
  esac

  if [[ "$line" != *$'\t'* ]]; then
    echo "INVALID manifest $LIST:$line_number: expected exactly three tab-separated fields" >&2
    exit 1
  fi
  path="${line%%$'\t'*}"
  remainder="${line#*$'\t'}"
  if [[ "$remainder" != *$'\t'* ]]; then
    echo "INVALID manifest $LIST:$line_number: expected exactly three tab-separated fields" >&2
    exit 1
  fi
  listed_feature="${remainder%%$'\t'*}"
  description="${remainder#*$'\t'}"
  if [[ -z "$path" || -z "$listed_feature" || -z "$description" || "$description" == *$'\t'* ]]; then
    echo "INVALID manifest $LIST:$line_number: expected three nonempty tab-separated fields" >&2
    exit 1
  fi
  if [[ "$listed_feature" != "$FEATURE" ]]; then
    echo "INVALID manifest $LIST:$line_number: feature '$listed_feature' does not match active feature '$FEATURE'" >&2
    exit 1
  fi

  REPOS+=("$path")
  LISTED_FEATURES+=("$listed_feature")
  DESCRIPTIONS+=("$description")
done < "$LIST"

if [[ "${#REPOS[@]}" -eq 0 ]]; then
  echo "MISSING repositories in $LIST" >&2
  exit 1
fi

if [[ "${1:-}" == '--demo' ]]; then
  last_index=$((${#REPOS[@]} - 1))
  for index in "${!REPOS[@]}"; do
    repo="${REPOS[$index]}"
    expected_feature="${LISTED_FEATURES[$index]}"
    branch="$expected_feature"
    if [[ "$index" -eq "$last_index" ]]; then
      branch="${expected_feature}-demo-drift"
    fi
    if [[ "$branch" == "$expected_feature" ]]; then
      echo "OK      $repo @ $branch"
    else
      echo "DRIFT   $repo @ $branch (应为 $expected_feature)"
    fi
  done
  exit 1
fi

bad=0
for index in "${!REPOS[@]}"; do
  repo="${REPOS[$index]}"
  expected_feature="${LISTED_FEATURES[$index]}"
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
  if [[ "$branch" == "$expected_feature" ]]; then
    echo "OK      $repo @ $branch"
  else
    echo "DRIFT   $repo @ $branch (应为 $expected_feature)"
    bad=1
  fi
done

exit "$bad"
