#!/usr/bin/env bash
# 一次性把版本化公共 Harness 暴露为树根标准入口：
#   .claude -> features/.harness
set -euo pipefail

FEATURES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -L)"
ROOT="${HARNESS_ROOT:-$(cd "$FEATURES_DIR/.." && pwd -L)}"
SOURCE_REL="features/.harness"
SOURCE="$ROOT/$SOURCE_REL"
LINK="$ROOT/.claude"

if [[ ! -d "$SOURCE" ]]; then
  echo "error: 公共 Harness 不存在：$SOURCE" >&2
  exit 1
fi

if [[ -L "$LINK" ]]; then
  current="$(readlink "$LINK" 2>/dev/null || true)"
  if [[ "$current" == "$SOURCE_REL" && -d "$LINK" ]]; then
    echo "[install-harness] 已安装：.claude -> $SOURCE_REL"
    exit 0
  fi
  echo "error: $LINK 已是指向 '$current' 的软链；拒绝重指，请人工确认。" >&2
  exit 1
fi

if [[ -e "$LINK" ]]; then
  echo "error: $LINK 已存在且不是软链；拒绝覆盖，请先人工迁移。" >&2
  exit 1
fi

if ! ln -s "$SOURCE_REL" "$LINK"; then
  echo "error: 创建 $LINK -> $SOURCE_REL 失败。" >&2
  exit 1
fi

echo "[install-harness] 已安装：.claude -> $SOURCE_REL"
