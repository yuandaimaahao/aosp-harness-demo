#!/bin/bash
# PostToolUse hook · compdb 时效"补漏"——补 path-scoped rule compdb-freshness.md 够不着的盲区。
# DEMO：与真实树 <AOSP_ROOT>/.claude/hooks/compdb-stale-nudge.sh 逐字一致（此 hook 与 feature 无关、
#       不含分支名/树路径，两处同构）。
#
# 背景：compdb-freshness.md 的 `paths:` glob 只在 agent **读到** Android.bp/.mk 时注入提醒；
#   而下面三类会让 compile_commands.json 过期的动作**不读构建文件**，rule 触发不了，靠本 hook 在
#   动作发生**后**回注一句提醒（hookSpecificOutput.additionalContext）补上：
#     1) Bash 跑了 repo sync              —— 仓结构可能全树变化
#     2) Write 了新 .c/.cc/.cpp/.cxx      —— srcs 用 glob 的模块不改 bp，新 TU 拿不到编译参数
#     3) Write 了新 Android.bp/.mk        —— 新模块，可能还在 features/<分支>/repos.tsv 之外
#
# 只提醒、不拦、不报错：任何情况都 exit 0；命中才往 stdout 吐一段 JSON，没命中则零输出（静默）。
# 无 jq 时静默降级退出。改函数体/逻辑不触发（那是"读已存在的文件"，rule 那条腿管，且本不需刷新）。
set -u
input=$(cat 2>/dev/null || true)
command -v jq >/dev/null 2>&1 || exit 0

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)

# 命中时吐 additionalContext（Claude 下一轮读到），随即 exit 0
emit() {
  jq -n --arg ctx "$1" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
  exit 0
}

case "$tool" in
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
    case "$cmd" in
      *"repo sync"*)
        emit "compdb 时效提醒：刚跑了 repo sync，仓结构可能已全树变化，out/soong 的 compile_commands.json 会对新结构失准。若接下来要用 clangd 做 C++ 符号导航，先在树根后台跑一次 ./gen-compdb-clangd.sh 刷新（几分钟，只跑 soong 分析不编译）；只读代码、不动构建结构可忽略本条。"
        ;;
    esac
    ;;
  Write)
    fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    base=$(basename -- "$fp" 2>/dev/null)
    case "$base" in
      Android.bp|Android.mk)
        emit "compdb 时效提醒：新建了构建文件 $fp（疑似新模块）。compile_commands.json 尚不含它；若该仓不在 features/<分支>/repos.tsv 里，先给它补一行并标 compdb（否则新仓文件静默拿不到精确编译参数），再在树根后台跑 ./gen-compdb-clangd.sh 刷新。"
        ;;
      *.c|*.cc|*.cpp|*.cxx)
        emit "compdb 时效提醒：新增了源文件 $fp。若它属于某 C++ 模块且该模块 srcs 用 glob（即你没改 Android.bp），clangd 的 compile_commands.json 不会自动收录它、符号导航会缺这档。需要精确编译参数时，在树根后台跑 ./gen-compdb-clangd.sh 刷新（改了 Android.bp 显式列 srcs 则 rule 已提醒过，忽略本条）。"
        ;;
    esac
    ;;
esac
exit 0
