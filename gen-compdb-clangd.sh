#!/bin/bash
# ① 代码智能层：生成/刷新 clangd 的 compile_commands.json —— 两段式精简
#
#   1) SOONG_GEN_COMPDB=1 m nothing → 全树去重库（~11万条/约2GB，仅作过滤源）
#   2) 按 feature 涉及仓前缀过滤 → compdb-feature/（clangd 实际用这份）
#
# 用法：
#   ./gen-compdb-clangd.sh [仓前缀 ...]      # 真实模式（需 AOSP 树）
#   ./gen-compdb-clangd.sh --demo            # DEMO 模式：无需 AOSP 树，造样本数据演示两段式过滤
#   不带仓前缀 = 按当前分支自动读 features/<分支>/repos.tsv 中标签含 compdb 的仓（单一事实源，切 feature 自动跟随；
#              demo 无 repo 树，分支取自 CURRENT_FEATURE）；传前缀则临时覆盖，清单缺失回退兜底并告警。
#
# 何时重跑：repo sync 后 / 改了 Android.bp、Android.mk / 新增 .c|.cpp 加进模块后。
# 只改函数体不用跑（clangd 实时读源文件）。见 .claude/rules/compdb-freshness.md
set -e
cd "$(dirname "$0")"

# feature 涉及仓的来源：命令行参数 > 当前 feature 的 repos.tsv（单一事实源，取标签含 compdb 的仓）> 脚本内兜底。
# 清单缺失时的兜底（应与 features/dev-sidebar/repos.tsv 中标 compdb 的仓一致；仅在读不到清单时启用）
FALLBACK_REPOS=("frameworks/base" "frameworks/native" "packages/apps/SidebarApp")

# 当前 feature = 锚定仓链的 git 分支；demo 无 repo 树，回退读 CURRENT_FEATURE（与 load-feature.sh 对齐）
detect_feature() {
  local repo b
  for repo in frameworks/base frameworks/native system/core; do
    [ -e "$repo/.git" ] || continue                 # 只认有独立 .git 的仓（demo 占位目录无 .git → 跳过，回退 CURRENT_FEATURE）
    if b=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null); then
      printf '%s' "$b"; return 0
    fi
  done
  [ -f CURRENT_FEATURE ] && tr -d '[:space:]' < CURRENT_FEATURE
}

# 从 features/<feature>/repos.tsv 读仓清单，取「标签含 compdb」的仓（列：路径 约定 标签 说明；# 注释、空行忽略）
load_repos() {
  local list="features/$1/repos.tsv" path conv tags _
  [ -f "$list" ] || return 1
  REPOS=()
  while read -r path conv tags _ || [ -n "$path" ]; do
    case "$path" in ''|'#'*) continue;; esac
    case ",$tags," in *,compdb,*) REPOS+=("$path");; esac
  done < "$list"
  [ ${#REPOS[@]} -gt 0 ]
}

# 定出 REPOS（$@ = 剩余的仓前缀参数，已 shift 掉 --demo）
resolve_repos() {
  if [ $# -gt 0 ]; then
    REPOS=("$@"); echo "仓集来源：命令行参数 → ${REPOS[*]}"; return
  fi
  local feature; feature=$(detect_feature || true)
  if [ -n "$feature" ] && load_repos "$feature"; then
    echo "仓集来源：features/$feature/repos.tsv（标 compdb）→ ${REPOS[*]}"
  else
    REPOS=("${FALLBACK_REPOS[@]}")
    echo "WARN: 未读到 features/${feature:-?}/repos.tsv，回退兜底仓集：${REPOS[*]}" >&2
  fi
}

# ---------------- DEMO 模式 ----------------
if [ "$1" == "--demo" ]; then
  shift
  resolve_repos "$@"
  full="demo-out/compdb-full.json"
  featdir="demo-out/compdb-feature"
  mkdir -p demo-out "$featdir"

  # 造一份"全树 compdb"样本：混入 feature 内仓 + 一堆无关仓，模拟全树体量
  cat > "$full" <<'JSON'
[
  {"directory":"/aosp","file":"frameworks/base/services/core/java/com/android/server/sidebar/SidebarService.cpp","command":"clang++ -c SidebarService.cpp"},
  {"directory":"/aosp","file":"frameworks/native/services/sidebarflinger/SidebarFlinger.cpp","command":"clang++ -c SidebarFlinger.cpp"},
  {"directory":"/aosp","file":"packages/apps/SidebarApp/jni/sidebar_jni.cpp","command":"clang++ -c sidebar_jni.cpp"},
  {"directory":"/aosp","file":"external/skia/src/core/SkCanvas.cpp","command":"clang++ -c SkCanvas.cpp"},
  {"directory":"/aosp","file":"external/boringssl/src/crypto/cipher.cpp","command":"clang++ -c cipher.cpp"},
  {"directory":"/aosp","file":"hardware/interfaces/audio/Audio.cpp","command":"clang++ -c Audio.cpp"},
  {"directory":"/aosp","file":"bionic/libc/bionic/malloc.cpp","command":"clang++ -c malloc.cpp"},
  {"directory":"/aosp","file":"out/soong/.intermediates/frameworks/base/ISidebar.cpp","command":"clang++ -c ISidebar.cpp"}
]
JSON

  REPOS_STR="${REPOS[*]}" python3 - "$full" "$featdir/compile_commands.json" <<'EOF'
import json, os, sys
full, out = sys.argv[1], sys.argv[2]
repos = os.environ["REPOS_STR"].split()
# 每个仓前缀同时保留其 out/.intermediates 生成源（aidl/proto 生成的 .cpp 也可导航）
prefixes = tuple(r.rstrip("/") + "/" for r in repos) + tuple(
    f"out/soong/.intermediates/{r.rstrip('/')}/" for r in repos)
db = json.load(open(full))
kept = [e for e in db if e.get("file", "").startswith(prefixes)]
json.dump(kept, open(out, "w"), indent=2)
print(f"[demo] 全树 {len(db)} 条 → feature({', '.join(repos)}) {len(kept)} 条")
print(f"[demo] 精简库写入 {out}")
print("[demo] 真实工程里这两个数量级是 ~113,000 条 / 1.97GB → ~12,000 条 / 282MB")
EOF
  exit 0
fi

# ---------------- 真实模式（需 AOSP 树） ----------------
resolve_repos "$@"
export SOONG_GEN_COMPDB=1
# envsetup 必须 bash 且不接 pipe；别开 _DEBUG（会带缩进变巨大）
source build/envsetup.sh >/dev/null 2>&1
lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1
m nothing

full=out/soong/development/ide/compdb/compile_commands.json
if [ ! -s "$full" ]; then
  echo "FAIL: $full 不存在或为空（soong 分析未产出；检查是否命中上游空数组坑）" >&2
  exit 1
fi

featdir=out/soong/development/ide/compdb-feature
mkdir -p "$featdir"
REPOS_STR="${REPOS[*]}" python3 - "$full" "$featdir/compile_commands.json" <<'EOF'
import json, os, sys
full, out = sys.argv[1], sys.argv[2]
repos = os.environ["REPOS_STR"].split()
prefixes = tuple(r.rstrip("/") + "/" for r in repos) + tuple(
    f"out/soong/.intermediates/{r.rstrip('/')}/" for r in repos)
db = json.load(open(full))
kept = []
for e in db:
    f = e.get("file", "")
    if os.path.isabs(f):
        f = os.path.relpath(f, e.get("directory", "/"))
    if f.startswith(prefixes):
        kept.append(e)
json.dump(kept, open(out, "w"))
print(f"全树 {len(db)} 条 → feature({', '.join(repos)}) {len(kept)} 条")
EOF
echo "OK: $featdir/compile_commands.json（clangd 自动检测更新并增量重建索引）"
