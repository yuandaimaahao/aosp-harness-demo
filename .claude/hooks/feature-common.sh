#!/usr/bin/env bash

detect_feature() {
  local root="$1"
  local repo candidate

  for repo in frameworks/base frameworks/native frameworks/av system/core; do
    [[ -e "$root/$repo/.git" ]] || continue
    candidate="$(git -C "$root/$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if [[ -n "$candidate" && "$candidate" != "HEAD" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if [[ -f "$root/CURRENT_FEATURE" ]]; then
    tr -d '[:space:]' < "$root/CURRENT_FEATURE"
    return 0
  fi
  return 1
}

feature_context_path() {
  local root="$1"
  local feature="$2"
  local target="features/$feature/CLAUDE.md"

  [[ -n "$feature" && -f "$root/$target" ]] || return 1
  printf '%s\n' "$target"
}

sync_feature_link() {
  local root="$1"
  local target="$2"
  local link="$root/CLAUDE.md"
  local current=""

  FEATURE_LINK_CHANGED=0
  if [[ -L "$link" ]]; then
    current="$(readlink "$link" 2>/dev/null || true)"
    if [[ "$current" == "$target" ]]; then
      return 0
    fi
  elif [[ -e "$link" ]]; then
    cp -a "$link" "$link.bak.$(date +%s)"
    rm -f "$link"
  fi

  ln -sfn "$target" "$link"
  FEATURE_LINK_CHANGED=1
}
