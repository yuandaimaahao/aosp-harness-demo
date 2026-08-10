#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -L)"
source "$SCRIPT_DIR/../hooks/feature-common.sh"
ROOT="$(harness_project_root "$SCRIPT_DIR")"
INSTALLER="$ROOT/features/install-harness.sh"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

fail() {
  echo "FAIL  $1" >&2
  exit 1
}

mkdir -p "$FIXTURE/ok/features/.harness"
HARNESS_ROOT="$FIXTURE/ok" "$INSTALLER" >/dev/null
[[ -L "$FIXTURE/ok/.claude" ]] || fail "安装器未创建根 .claude 软链"
[[ "$(readlink "$FIXTURE/ok/.claude")" == "features/.harness" ]] \
  || fail "安装器创建了错误的软链目标"
HARNESS_ROOT="$FIXTURE/ok" "$INSTALLER" >/dev/null \
  || fail "安装器重复执行不幂等"

mkdir -p "$FIXTURE/real-dir/features/.harness" "$FIXTURE/real-dir/.claude"
if HARNESS_ROOT="$FIXTURE/real-dir" "$INSTALLER" >/dev/null 2>&1; then
  fail "安装器覆盖了已有真实 .claude 目录"
fi
[[ -d "$FIXTURE/real-dir/.claude" && ! -L "$FIXTURE/real-dir/.claude" ]] \
  || fail "安装失败后已有真实目录被改动"

mkdir -p "$FIXTURE/wrong-link/features/.harness" "$FIXTURE/wrong-link/elsewhere"
ln -s elsewhere "$FIXTURE/wrong-link/.claude"
if HARNESS_ROOT="$FIXTURE/wrong-link" "$INSTALLER" >/dev/null 2>&1; then
  fail "安装器重指了已有无关软链"
fi
[[ "$(readlink "$FIXTURE/wrong-link/.claude")" == "elsewhere" ]] \
  || fail "安装失败后无关软链被改动"

mkdir -p "$FIXTURE/missing/features"
if HARNESS_ROOT="$FIXTURE/missing" "$INSTALLER" >/dev/null 2>&1; then
  fail "公共 Harness 缺失时安装器仍返回成功"
fi
[[ ! -e "$FIXTURE/missing/.claude" ]] \
  || fail "公共 Harness 缺失时仍创建了入口"

echo "PASS  harness installer is idempotent and fail-safe"
