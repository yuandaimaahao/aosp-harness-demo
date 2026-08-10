#!/usr/bin/env bash

# 从逻辑入口（<root>/.claude/...）或物理入口
# （<root>/features/.harness/...）都能解析出工程根目录。
harness_project_root() {
  local script_dir="$1"
  local candidate

  candidate="$(cd "$script_dir/../.." && pwd -L)"
  if [[ -f "$candidate/CURRENT_FEATURE" || -d "$candidate/.repo" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  candidate="$(cd "$script_dir/../../.." && pwd -L)"
  if [[ -f "$candidate/CURRENT_FEATURE" || -d "$candidate/.repo" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  return 1
}

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

# 幂等地把树根 CLAUDE.md 指向 feature 上下文。
#
# 若根入口仍是真实文件，先完成保护性备份，再用临时软链原子替换。备份失败
# 时不碰原文件；建链或替换失败时保留/恢复原文件，并明确报告回滚状态。
sync_feature_link() {
  local root="$1"
  local target="$2"
  local link="$root/CLAUDE.md"
  local current=""
  local backup=""
  local pending="${link}.new.$$"

  FEATURE_LINK_CHANGED=0

  if [[ "$target" == /* || ! -f "$root/$target" ]]; then
    echo "error: 无效的 feature 上下文目标 '$target'。" >&2
    return 1
  fi

  if [[ -L "$link" ]]; then
    current="$(readlink "$link" 2>/dev/null || true)"
    if [[ "$current" == "$target" ]]; then
      return 0
    fi
  elif [[ -e "$link" ]]; then
    backup="${link}.bak.$(date +%s).$$"
    if ! cp -a "$link" "$backup"; then
      echo "error: 备份 $link 失败；原文件未改动。" >&2
      return 1
    fi
  fi

  if ! ln -s "$target" "$pending"; then
    echo "error: 创建 CLAUDE.md 软链失败；原入口保持不变，回滚无需执行。" >&2
    return 1
  fi

  if ! mv -Tf "$pending" "$link"; then
    rm -f "$pending"
    if [[ -n "$backup" && ! -e "$link" ]]; then
      if cp -a "$backup" "$link"; then
        echo "error: 替换 CLAUDE.md 失败，已从备份回滚。" >&2
      else
        echo "error: 替换 CLAUDE.md 失败，且从 $backup 回滚失败；请人工恢复。" >&2
      fi
    else
      echo "error: 替换 CLAUDE.md 失败；原入口仍在，无需回滚。" >&2
    fi
    return 1
  fi

  FEATURE_LINK_CHANGED=1
}
