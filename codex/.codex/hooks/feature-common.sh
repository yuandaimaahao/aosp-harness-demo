#!/usr/bin/env bash

detect_feature() {
  local root="$1"
  local repo candidate

  for repo in frameworks/base frameworks/native frameworks/av system/core; do
    if [[ ! -f "$root/$repo/.git" && ! -d "$root/$repo/.git" ]]; then
      continue
    fi
    candidate="$(git -C "$root/$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    if [[ -n "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  [[ -f "$root/CURRENT_FEATURE" ]] || return 1
  tr -d '[:space:]' < "$root/CURRENT_FEATURE"
}

feature_context_path() {
  local root="$1"
  local feature="$2"
  local target="features/$feature/AGENTS.md"

  [[ -n "$feature" && -f "$root/$target" ]] || return 1
  printf '%s\n' "$target"
}

sync_feature_link() {
  local root="$1"
  local target="$2"
  local link="$root/AGENTS.md"
  local temporary_link

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
  if ! mv -Tf "$temporary_link" "$link"; then
    rm -f "$temporary_link"
    printf 'error: 无法安全更新 %s。\n' "$link" >&2
    return 1
  fi
}
