# review 包 a8d03d1d..5b2e66b3

## commit 列表

```
5b2e66b test(claude): add session lifecycle matrix
```

## diff --stat

```
 tests/test-claude-session-lifecycle.sh | 176 +++++++++++++++++++++++++++++++++
 1 file changed, 176 insertions(+)
```

## diff

```diff
diff --git a/tests/test-claude-session-lifecycle.sh b/tests/test-claude-session-lifecycle.sh
new file mode 100644
index 0000000..da811ed
--- /dev/null
+++ b/tests/test-claude-session-lifecycle.sh
@@ -0,0 +1,176 @@
+#!/usr/bin/env bash
+set -u
+# 03e claude session lifecycle 默认发现入口: v1 生命周期矩阵、七类 fixture、
+# legacy/absent surface、结构核对与 demo 收敛。成功唯一摘要文字为 RESULT PASS
+# 加两个空格加 claude session lifecycle（注释只写文字: 探针按摘要 printf 字面量
+# rindex/index 定位, 故注释不得逐字包含它）。
+case $#:${1-}:${2-} in
+  0:: | 1:all:) ;;
+  1:--dependency-absent:) mode=absent ;;
+  2:--session-provider-fixture:missing-foundation | 2:--session-provider-fixture:missing-path | 2:--session-provider-fixture:missing-snapshot | 2:--session-provider-fixture:missing-signals | 2:--session-provider-fixture:missing-remove | 2:--session-provider-fixture:absent) fixture=$2 ;;
+  *) exit 1 ;;
+esac
+here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
+repo=$(git -C "$here" rev-parse --show-toplevel)
+lib=$repo/common/.harness/lib aggregator=$repo/common/.harness/lib/session-state.sh
+hooks=$repo/claude-code/features/.harness/hooks demo=$repo/claude-code/run-demo.sh
+settings=$repo/claude-code/features/.harness/settings.json snap_name=.aosp-harness-demo.feature-snapshot
+tmp=$(mktemp -d)
+trap 'rm -rf -- "$tmp"' EXIT
+failures=0 checks=0 tree='' state='' pid=''
+check_eq() {
+  checks=$((checks + 1))
+  [[ $3 == "$2" ]] && return 0
+  printf 'FAIL %s want=%q got=%q\n' "$1" "$2" "$3" >&2
+  failures=$((failures + 1))
+}
+bytes() { wc -c <"$1" | xargs; }
+exists() { [[ -e $1 ]] && echo present || echo absent; }
+occurrences() { rg -oF -- "$1" "$2" | wc -l | xargs; }
+stream_is() {
+  printf '%b' "$3" >"$tmp/want" && cmp -s "$tmp/want" "$2"
+  check_eq "$1" 0 "$?"
+}
+ss() { printf '{"hook_event_name":"SessionStart","session_id":"%s","source":"%s"}' "$1" "$2"; }
+ups() { printf '{"hook_event_name":"UserPromptSubmit","session_id":"%s"}' "$1"; }
+se() { printf '{"hook_event_name":"%s","session_id":"%s","reason":"%s"}' "$1" "$2" "$3"; }
+# 依赖探测: aggregator 在场且隔离 shell source 后 marker 精确为 1 且五 API 在场。
+dependency_present() {
+  [[ -f $aggregator ]] || return 1
+  bash -c 'source "$1" >/dev/null 2>&1 && [[ ${HARNESS_SESSION_STATE_PROVIDER_VERSION-} == 1 ]] && declare -F harness_validate_feature_name harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove >/dev/null' _ "$aggregator"
+}
+run_hook() { printf '%s' "$2" | env CLAUDE_PROJECT_DIR="$tree/claude-code" TMPDIR="$tree/tmp" HARNESS_STATE_ROOT="$state" "$hooks/$1.sh" >"$tmp/out" 2>"$tmp/err"; }
+# $4 期望退出码, $5 期望 stdout 中 compat marker 出现次数, $6 可选双流总字节数。
+hook_expect() {
+  local rc
+  run_hook "$2" "$3"
+  rc=$?
+  check_eq "$1 rc+marker" "$4 $5" "$rc $(occurrences 'compat: session-provider=legacy' "$tmp/out")"
+  [[ -z ${6-} ]] || check_eq "$1 stream bytes" "$6" "$(($(bytes "$tmp/out") + $(bytes "$tmp/err")))"
+}
+# fixture 构建: 私有 tree/claude-code + tree/common/.harness/lib 副本; $2 为空即完整 provider, absent 则 aggregator 整体缺席, 否则删该模块。
+mk_tree() {
+  tree=$tmp/$1 state=$tmp/$1-state
+  mkdir -p "$tree/claude-code/features/dev-sidebar" "$tree/claude-code/features/dev-next" "$tree/tmp"
+  printf '%s\n' dev-sidebar >"$tree/claude-code/CURRENT_FEATURE"
+  for f in dev-sidebar dev-next; do printf '%s\n' "# demo context: $f" >"$tree/claude-code/features/$f/CLAUDE.md"; done
+  [[ ${2-} == absent ]] || { mkdir -p "$tree/common/.harness/lib" && cp "$lib"/session-state*.sh "$tree/common/.harness/lib/"; }
+  [[ -z ${2-} || ${2-} == absent ]] || rm -f -- "$tree/common/.harness/lib/session-state-$2.sh"
+  pid=$(realpath -- "$tree/claude-code" | sha256sum | cut -c1-64)
+}
+# legacy/absent surface: 全部 legacy 行为 case(非零 case inert); 先核 aggregator fail-closed 使完整五 API predicate 为 false, 无 partial capability。
+legacy_surface() {
+  local label=$1 snap=$tree/tmp/$snap_name
+  bash -c 'source "$1" >/dev/null 2>&1 && exit 1
+    [[ ${HARNESS_SESSION_STATE_PROVIDER_VERSION-} != 1 ]] || exit 1
+    for n in harness_validate_feature_name harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove; do ! declare -F "$n" >/dev/null || exit 1; done' _ "$tree/common/.harness/lib/session-state.sh" >/dev/null 2>&1
+  check_eq "$label five-api predicate false" 0 "$?"
+  hook_expect "$label start" load-feature "$(ss lg-1 startup)" 0 1
+  check_eq "$label start snapshot+link" 'dev-sidebar features/dev-sidebar/CLAUDE.md' "$(cat "$snap") $(readlink "$tree/claude-code/CLAUDE.md")"
+  check_eq "$label start message" 1 "$(occurrences 'SessionStart 才把 CLAUDE.md 切到 features/dev-sidebar/CLAUDE.md' "$tmp/out")"
+  hook_expect "$label ups no drift" check-branch-drift "$(ups lg-1)" 0 1
+  stream_is "$label ups no drift stdout" "$tmp/out" 'compat: session-provider=legacy\n'
+  printf '%s\n' dev-next >"$tree/claude-code/CURRENT_FEATURE"
+  hook_expect "$label ups drift" check-branch-drift "$(ups lg-1)" 0 1
+  stream_is "$label ups drift stdout" "$tmp/out" "compat: session-provider=legacy\n⚠️ [分支漂移] 会话注入时在 'dev-sidebar'，现在切到了 'dev-next'。\n   当前会话仍含旧上下文；退出后用 .claude/bin/claude-feature 重启，别拿旧分支约定改新分支。\n"
+  printf '%s\n' dev-sidebar >"$tree/claude-code/CURRENT_FEATURE"
+  hook_expect "$label end" session-end "$(se SessionEnd lg-1 clear)" 0 1
+  check_eq "$label end removed snapshot" absent "$(exists "$snap")"
+  hook_expect "$label end repeat" session-end "$(se SessionEnd lg-1 logout)" 0 1
+  check_eq "$label end idempotent + no v1 state" 'absent absent' "$(exists "$snap") $(exists "$state")"
+}
+fixture_case() {
+  mk_tree "f-$1" "${1#missing-}"
+  legacy_surface "fixture $1"
+}
+if [[ -n ${fixture-} ]]; then
+  fixture_case "$fixture"
+elif [[ ${mode-} == absent ]] || ! dependency_present; then
+  fixture_case absent
+  ((failures)) && exit 1
+  printf 'RESULT PASS  claude session lifecycle\n'
+  exit 0
+else
+  # 七类 fixture 之第一类(完整 provider) —— v1 SessionStart 按 source 分级建/读基线
+  mk_tree v1
+  snap=$tree/tmp/$snap_name saved=$state
+  for src in startup fork clear resume; do
+    hook_expect "start $src" load-feature "$(ss "s-$src" "$src")" 0 0
+    check_eq "start $src baseline+stderr" 'dev-sidebar 0' "$(cat "$state/$pid/s-$src/feature") $(bytes "$tmp/err")"
+  done
+  stream_is 'start steady stdout' "$tmp/out" '[load-feature] 当前 feature=dev-sidebar，CLAUDE.md 已由启动 wrapper 预同步。\n'
+  check_eq 'start link + project-id + no legacy write' 'features/dev-sidebar/CLAUDE.md 64 present absent' "$(readlink "$tree/claude-code/CLAUDE.md") ${#pid} $(exists "$state/$pid") $(exists "$snap")"
+  check_eq 'full provider five-api predicate true' present "$(dependency_present && echo present)"
+  hook_expect 'start same-value idempotent' load-feature "$(ss s-startup startup)" 0 0
+  check_eq 'start same-value stderr+baseline' '0 dev-sidebar' "$(bytes "$tmp/err") $(cat "$state/$pid/s-startup/feature")"
+  hook_expect 'start compact missing' load-feature "$(ss s-compact compact)" 0 0
+  stream_is 'start compact stderr' "$tmp/err" 'error: [load-feature] compact 会话基线缺失，未创建。\n'
+  check_eq 'start compact no baseline' absent "$(exists "$state/$pid/s-compact/feature")"
+  printf '%s\n' dev-next >"$tree/claude-code/CURRENT_FEATURE"
+  hook_expect 'start present baseline no overwrite' load-feature "$(ss s-startup fork)" 0 0
+  check_eq 'start no overwrite baseline' dev-sidebar "$(cat "$state/$pid/s-startup/feature")"
+  cp "$tree/common/.harness/lib/session-state.sh" "$tmp/real-agg.sh" && printf '\nharness_session_state_read() { return 3; }\n' >>"$tree/common/.harness/lib/session-state.sh" && hook_expect 'start write conflict' load-feature "$(ss s-startup fork)" 0 0
+  check_eq 'start conflict kept + logged' 'dev-sidebar 1' "$(cat "$state/$pid/s-startup/feature") $(occurrences '已存在且值不同' "$tmp/err")" && cp "$tmp/real-agg.sh" "$tree/common/.harness/lib/session-state.sh"
+  printf '%s\n' dev-sidebar >"$tree/claude-code/CURRENT_FEATURE"
+  for bad in '{"session_id":"../bad","source":"startup"}' '{"session_id":"s-bad","source":"bogus"}' 'not json'; do
+    rm -f -- "$snap"
+    hook_expect 'start illegal stdin' load-feature "$bad" 0 1
+    check_eq 'start illegal legacy write + no v1 state' 'dev-sidebar absent' "$(cat "$snap") $(exists "$state/$pid/s-bad")"
+  done
+  rm -f -- "$snap"
+  # v1 UserPromptSubmit: 无漂移/漂移 exit 2 两行告警/基线缺席/非法 session_id
+  hook_expect 'ups no drift' check-branch-drift "$(ups s-startup)" 0 0 0
+  printf '%s\n' dev-next >"$tree/claude-code/CURRENT_FEATURE"
+  hook_expect 'ups drift blocks prompt' check-branch-drift "$(ups s-startup)" 2 0
+  stream_is 'ups drift stdout' "$tmp/out" "⚠️ [分支漂移] 会话注入时在 'dev-sidebar'，现在切到了 'dev-next'。\n   当前会话仍含旧上下文；退出后用 .claude/bin/claude-feature 重启，别拿旧分支约定改新分支。\n"
+  check_eq 'ups drift stderr empty' 0 "$(bytes "$tmp/err")"
+  printf '%s\n' dev-sidebar >"$tree/claude-code/CURRENT_FEATURE"
+  hook_expect 'ups baseline absent' check-branch-drift "$(ups s-ghost)" 0 0 0
+  hook_expect 'ups illegal session id' check-branch-drift '{"session_id":"../bad"}' 0 1
+  check_eq 'ups legacy path wrote nothing' absent "$(exists "$snap")"
+  # v1 SessionEnd: 校验后幂等清理; 非法输入零删除; provider 设计外错误码落 legacy
+  hook_expect 'end reason clear' session-end "$(se SessionEnd s-startup clear)" 0 0 0
+  check_eq 'end clear removed state' absent "$(exists "$state/$pid/s-startup")"
+  hook_expect 'end clear repeat idempotent' session-end "$(se SessionEnd s-startup clear)" 0 0 0
+  hook_expect 'end reason resume' session-end "$(se SessionEnd s-resume resume)" 0 0
+  check_eq 'end resume removed state' absent "$(exists "$state/$pid/s-resume/feature")"
+  printf '%s' legacy-snap >"$snap"
+  for bad in "$(se SessionStart s-fork clear)" "$(se SessionEnd ../bad clear)" "$(se SessionEnd s-fork bogus)"; do
+    hook_expect 'end illegal stdin' session-end "$bad" 0 1
+    check_eq 'end illegal zero deletion' 'dev-sidebar legacy-snap' "$(cat "$state/$pid/s-fork/feature") $(cat "$snap")"
+  done
+  state=/
+  hook_expect 'end provider off-contract' session-end "$(se SessionEnd s-fork clear)" 0 1
+  state=$saved
+  check_eq 'end off-contract zero deletion' 'dev-sidebar legacy-snap' "$(cat "$state/$pid/s-fork/feature") $(cat "$snap")"
+  # 七类 fixture 之第二至七类: aggregator 缺席 + 五模块各自缺席, 各走 legacy
+  for name in absent missing-foundation missing-path missing-snapshot missing-signals missing-remove; do
+    fixture_case "$name"
+  done
+  # 结构核对: 三 hook compat 字面量恰一次 + guard 两子句; settings.json 注册
+  for hook in load-feature check-branch-drift session-end; do
+    check_eq "$hook compat literal once" 1 "$(occurrences 'compat: session-provider=legacy' "$hooks/$hook.sh")"
+    check_eq "$hook guard marker+five-api" '1 1' "$(occurrences '"${HARNESS_SESSION_STATE_PROVIDER_VERSION:-}" == 1' "$hooks/$hook.sh") $(occurrences 'declare -F harness_validate_feature_name harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove' "$hooks/$hook.sh")"
+  done
+  python3 -c 'import json, sys; e = json.load(open(sys.argv[1]))["hooks"]["SessionEnd"][0]["hooks"][0]; sys.exit(0 if e["type"] == "command" and e["command"].endswith("/.claude/hooks/session-end.sh") else 1)' "$settings"
+  check_eq 'settings SessionEnd registration' 0 "$?"
+  # CLI 非法表: unknown/extra/flag 带值/fixture 缺值或非法值均 rc1 且无 PASS
+  for spec in --bogus 'all extra' --dependency-absent=x --session-provider-fixture '--session-provider-fixture bogus'; do
+    bash "$0" $spec >"$tmp/out" 2>"$tmp/err"
+    rc=$?
+    check_eq "argv [$spec] rc+stdout" '1 0' "$rc $(bytes "$tmp/out")"
+  done
+  # demo 收敛: 真实 CURRENT_FEATURE 逐字不变、全局快照缺席、mktemp 目录零残留
+  mkdir -p "$tmp/demotmp"
+  before=$(sha256sum "$repo/claude-code/CURRENT_FEATURE")
+  TMPDIR="$tmp/demotmp" bash "$demo" >"$tmp/out" 2>"$tmp/err"
+  rc=$?
+  check_eq 'demo rc + CURRENT_FEATURE unchanged' "0 $before" "$rc $(sha256sum "$repo/claude-code/CURRENT_FEATURE")"
+  check_eq 'demo no snapshot + no leftover mktemp dir' 'absent 0' "$(exists "$tmp/demotmp/$snap_name") $(find "$tmp/demotmp" -maxdepth 1 -name 'claude-harness-demo.*' | wc -l | xargs)"
+  check_eq 'demo single exit trap' '1 1' "$(occurrences "trap 'rm -rf -- \"\$DEMO_TMP_DIR\"' EXIT" "$demo") $(occurrences 'trap ' "$demo")"
+fi
+if ((failures)); then
+  printf 'RESULT FAIL claude session lifecycle checks=%d failures=%d\n' "$checks" "$failures"
+  exit 1
+fi
+printf 'RESULT PASS  claude session lifecycle\n'
```
