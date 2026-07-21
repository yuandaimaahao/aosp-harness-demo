#!/usr/bin/env bash

valid_feature_name() {
  local feature="$1"
  local LC_ALL=C

  [[ "$feature" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

detect_feature() {
  local root="$1"
  local repo candidate

  for repo in frameworks/base frameworks/native frameworks/av system/core; do
    if [[ ! -f "$root/$repo/.git" && ! -d "$root/$repo/.git" ]]; then
      continue
    fi
    if ! git -C "$root/$repo" rev-parse --git-dir >/dev/null 2>&1; then
      continue
    fi
    candidate="$(git -C "$root/$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    if [[ -n "$candidate" ]]; then
      printf '%s\n' "$candidate"
      valid_feature_name "$candidate" || return 2
      return 0
    fi
  done

  [[ -f "$root/CURRENT_FEATURE" ]] || return 1
  if ! candidate="$(python3 - "$root/CURRENT_FEATURE" <<'PY'
import re
import sys

try:
    data = open(sys.argv[1], 'rb').read()
except OSError:
    raise SystemExit(1)
match = re.fullmatch(rb'([A-Za-z0-9][A-Za-z0-9._-]*)(?:\n)?', data)
if match is None:
    raise SystemExit(1)
sys.stdout.buffer.write(match.group(1))
PY
)"; then
    return 2
  fi
  printf '%s\n' "$candidate"
  valid_feature_name "$candidate" || return 2
}

feature_context_path() {
  local root="$1"
  local feature="$2"
  local target="features/$feature/AGENTS.md"

  valid_feature_name "$feature" || return 1
  [[ -f "$root/$target" ]] || return 1
  printf '%s\n' "$target"
}

sync_feature_link() {
  local root="$1"
  local target="$2"
  local link="$root/AGENTS.md"
  local temporary_link replace_rc

  if [[ ! -L "$link" && -e "$link" ]]; then
    printf 'error: %s 是普通文件，拒绝覆盖。\n' "$link" >&2
    return 1
  fi
  if [[ -L "$link" && "$(readlink "$link")" == "$target" ]]; then
    return 0
  fi

  temporary_link="$root/.AGENTS.md.tmp.$$.$RANDOM"
  if ! ln -s "$target" "$temporary_link"; then
    printf 'error: 无法创建临时 feature 上下文软链 %s。\n' "$temporary_link" >&2
    return 1
  fi

  if [[ ! -L "$link" && -e "$link" ]]; then
    rm -f "$temporary_link"
    printf 'error: %s 是普通文件，拒绝覆盖。\n' "$link" >&2
    return 1
  fi
  if python3 - "$temporary_link" "$link" <<'PY'
import os
import sys

source, destination = sys.argv[1:]
if os.path.lexists(destination) and not os.path.islink(destination):
    raise SystemExit(2)
try:
    os.replace(source, destination)
except OSError:
    raise SystemExit(1)
PY
  then
    return 0
  else
    replace_rc=$?
  fi

  rm -f "$temporary_link"
  if [[ "$replace_rc" -eq 2 ]]; then
    printf 'error: %s 是普通文件，拒绝覆盖。\n' "$link" >&2
  else
    printf 'error: 无法安全更新 %s。\n' "$link" >&2
  fi
  return 1
}
