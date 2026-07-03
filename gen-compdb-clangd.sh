#!/bin/bash
# ① 代码智能层：生成/刷新 clangd 的 compile_commands.json —— 两段式精简
#
#   1) SOONG_GEN_COMPDB=1 m nothing → 全树去重库（~11万条/约2GB，仅作过滤源）
#   2) 按 feature 涉及仓前缀过滤 → compdb-feature/（clangd 实际用这份）
#
# 用法：
#   ./gen-compdb-clangd.sh [仓前缀 ...]      # 真实模式（需 AOSP 树）
#   ./gen-compdb-clangd.sh --demo            # DEMO 模式：无需 AOSP 树，造样本数据演示两段式过滤
#
# 何时重跑：repo sync 后 / 改了 Android.bp、Android.mk / 新增 .c|.cpp 加进模块后。
# 只改函数体不用跑（clangd 实时读源文件）。见 .claude/rules/compdb-freshness.md
set -e
cd "$(dirname "$0")"

# feature 涉及仓（与 features/<分支>/_index.md 清单对齐；build/make、system/sepolicy 无 C++ 不列）
REPOS=("frameworks/base" "frameworks/native" "packages/apps/SidebarApp")

# ---------------- DEMO 模式 ----------------
if [ "$1" == "--demo" ]; then
  shift
  [ $# -gt 0 ] && REPOS=("$@")
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
[ $# -gt 0 ] && REPOS=("$@")
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
