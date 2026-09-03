#!/usr/bin/env bash
set -u
# 03d session state: remove + aggregator 默认发现矩阵。成功唯一摘要文字为
# RESULT PASS 加两个空格加 session state（此处只写文字）。注意: 注释只写摘要
# 文字，不得逐字包含固定摘要的 printf 调用（探针按该字面量 rindex/index 定位）。
case $#:${1-}:${2-} in
  0:: | 1:all:) ;;
  1:--dependency-absent:) mode=absent ;;
  2:--session-provider-fixture:missing-foundation | 2:--session-provider-fixture:missing-path | 2:--session-provider-fixture:missing-snapshot | 2:--session-provider-fixture:missing-signals | 2:--session-provider-fixture:missing-remove) fixture=$2 ;;
  *) exit 1 ;;
esac
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
repo=$(git -C "$here" rev-parse --show-toplevel)
lib=$repo/common/.harness/lib
aggregator=$lib/session-state.sh
remove=$lib/session-state-remove.sh
inert() {
  printf 'RESULT PASS  session state\n'
  exit 0
}
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
failures=0 checks=0
check_eq() {
  local label=$1 want=$2 got=$3
  checks=$((checks + 1))
  if [[ $got != "$want" ]]; then
    printf 'FAIL %s want=%q got=%q\n' "$label" "$want" "$got" >&2
    failures=$((failures + 1))
  fi
}
bytes() { wc -c <"$1" | xargs; }
inventory() { [[ ! -e $1 ]] || (cd "$1" && find . | LC_ALL=C sort); }
stream_is() {
  printf '%b' "$3" >"$tmp/want"
  cmp -s "$tmp/want" "$2"
  check_eq "$1" 0 "$?"
}
inv_eq() {
  printf '%b' "$2" >"$tmp/want"
  inventory "${3:-$HARNESS_STATE_ROOT}" >"$tmp/got"
  cmp -s "$tmp/want" "$tmp/got"
  check_eq "$1" 0 "$?"
}
run_expect() {
  local label=$1 want_rc=$2 want_err=$3
  shift 3
  "$@" >"$tmp/out" 2>"$tmp/err"
  local rc=$?
  check_eq "$label rc" "$want_rc" "$rc"
  check_eq "$label stdout empty" 0 "$(bytes "$tmp/out")"
  if [[ -z $want_err ]]; then
    check_eq "$label stderr empty" 0 "$(bytes "$tmp/err")"
  else
    stream_is "$label stderr bytes" "$tmp/err" "$want_err"
  fi
}
run_tree() {
  (
    HARNESS_STATE_ROOT=$tmp/$1-state
    # shellcheck source=/dev/null
    source "$tmp/$1/session-state.sh"
    harness_session_state_write project session alpha >/dev/null 2>&1
    harness_session_state_remove project session
  ) >"$tmp/out" 2>"$tmp/err"
}
tree_expect() {
  run_tree "$1"
  local rc=$?
  check_eq "$1 rc" "$2" "$rc"
  check_eq "$1 stdout empty" 0 "$(bytes "$tmp/out")"
  if [[ -z ${3-} ]]; then
    check_eq "$1 stderr empty" 0 "$(bytes "$tmp/err")"
  else
    stream_is "$1 stderr bytes" "$tmp/err" "$3"
  fi
}
run_fixture() {
  local name=$1 tree=$tmp/fixture-$1 rc
  mkdir -p "$tree"
  cp "$lib"/session-state-*.sh "$tree/"
  if [[ $name != aggregator-absent ]]; then
    cp "$aggregator" "$tree/"
    rm -f "$tree/session-state-${name#missing-}.sh"
  fi
  bash -c '
    set -u
    for n in harness_validate_feature_name harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove; do eval "$n() { :; }"; done
    source "$1/session-state.sh" >/dev/null 2>&1
    rc=$?
    [[ $rc != 0 ]] || exit 1
    # 哨兵已占满五个 public API 名, marker 缺席即完整五 API predicate 为 false。
    [[ ${HARNESS_SESSION_STATE_PROVIDER_VERSION-} != 1 ]] || exit 1
  ' _ "$tree" >"$tmp/out" 2>"$tmp/err"
  rc=$?
  check_eq "fixture $name rc" 0 "$rc"
  if [[ $name != aggregator-absent ]]; then
    check_eq "fixture $name streams empty" 0 "$(($(bytes "$tmp/out") + $(bytes "$tmp/err")))"
  fi
}
# fixture 单跑模式: 只跑指定 missing-module fixture 后走统一出口。
if [[ -n ${fixture-} ]]; then
  run_fixture "$fixture"
else
  # 依赖探测: aggregator 在场且隔离 shell source 后 marker 精确为 1。
  [[ -f $aggregator ]] || inert
  bash -c 'source "$1" >/dev/null 2>&1 && [[ $HARNESS_SESSION_STATE_PROVIDER_VERSION == 1 ]]' _ "$aggregator" || inert
  [[ ${mode-} != absent ]] || inert
  export HARNESS_STATE_ROOT=$tmp/state
  # shellcheck source=/dev/null
  source "$aggregator"
  # 结构核对: 双 anchor exact-once、无 rc3 分支、无模块内部逻辑副本、四转接各一行。
  check_eq 'anchor prune exact-once' 1 "$(rg -cF 'pass  # PRUNE_BEFORE_IDENTITY' "$remove")"
  check_eq 'anchor os-error exact-once' 1 "$(rg -cF 'pass  # HARNESS_TEST_MARKER_OS_ERROR' "$remove")"
  leak=absent
  rg -q 'SystemExit\(3\)|return 3' "$remove" && leak=present
  check_eq 'no rc3 branch' absent "$leak"
  leak=absent
  rg -q 'python3|os\.(rmdir|unlink|mkdir)' "$aggregator" && leak=present
  check_eq 'aggregator no module logic copy' absent "$leak"
  check_eq 'four one-line forwarders' 4 "$(rg -c '^harness_session_state_(path|write|read|remove)\(\) \{ _harness_session_[a-z_]+ "\$@"; \}$' "$aggregator")"
  check_eq 'marker' 1 "${HARNESS_SESSION_STATE_PROVIDER_VERSION-}"
  for fn in harness_validate_feature_name harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove; do
    declare -F "$fn" >/dev/null
    check_eq "api $fn" 0 "$?"
  done
  # CLI 非法表: unknown/extra/flag 带值/fixture 缺值/非法值均 rc1 且无 PASS。
  argv_bad() {
    local label=$1
    shift
    bash "$0" "$@" >"$tmp/out" 2>"$tmp/err"
    local rc=$?
    check_eq "argv $label rc+stdout" "1 0" "$rc $(bytes "$tmp/out")"
  }
  argv_bad unknown --bogus
  argv_bad extra all extra
  argv_bad flag-value --dependency-absent=x
  argv_bad fixture-no-value --session-provider-fixture
  argv_bad fixture-bad-value --session-provider-fixture bogus
  printf '%s\n' 'RESULT PASS  session state' >"$tmp/summary"
  bash "$0" --dependency-absent >"$tmp/out" 2>"$tmp/err"
  rc=$?
  check_eq 'flag inert rc' 0 "$rc"
  check_eq 'flag inert stderr empty' 0 "$(bytes "$tmp/err")"
  cmp -s "$tmp/summary" "$tmp/out"
  check_eq 'flag inert summary bytes' 0 "$?"
  # remove 矩阵: feature 存在删除并全层 prune; 缺失幂等仍 prune; rc 表逐字。
  run_expect 'setup write alpha' 0 '' harness_session_state_write project session alpha
  inv_eq 'setup inventory' '.\n./project\n./project/session\n./project/session/feature\n'
  run_expect 'remove feature' 0 '' harness_session_state_remove project session
  inv_eq 'remove prunes all empty layers' ''
  run_expect 'remove absent target idempotent' 0 '' harness_session_state_remove project ghost
  harness_session_state_path project session >"$tmp/out" 2>"$tmp/err"
  rc=$?
  check_eq 'fwd path rc' 0 "$rc"
  stream_is 'fwd path stdout bytes' "$tmp/out" "$HARNESS_STATE_ROOT/project/session\n"
  check_eq 'fwd path stderr empty' 0 "$(bytes "$tmp/err")"
  run_expect 'remove missing feature idempotent' 0 '' harness_session_state_remove project session
  inv_eq 'missing feature still prunes' ''
  run_expect 'unsafe id' 2 'error: unsafe session state\n' harness_session_state_remove '../bad' session
  harness_session_state_path project session >/dev/null 2>&1 && mkdir "$HARNESS_STATE_ROOT/project/session/feature"
  run_expect 'unsafe feature object' 2 'error: unsafe session state\n' harness_session_state_remove project session
  check_eq 'unsafe feature retained' yes "$([[ -d $HARNESS_STATE_ROOT/project/session/feature ]] && echo yes || echo no)"
  rm -rf -- "$HARNESS_STATE_ROOT"
  # 转接透传: write/read 各取一例。
  run_expect 'fwd write' 0 '' harness_session_state_write project session alpha
  harness_session_state_read project session >"$tmp/out" 2>"$tmp/err"
  rc=$?
  check_eq 'fwd read rc' 0 "$rc"
  stream_is 'fwd read stdout bytes' "$tmp/out" 'alpha\n'
  check_eq 'fwd read stderr empty' 0 "$(bytes "$tmp/err")"
  rm -rf -- "$HARNESS_STATE_ROOT"
  # 注入行: 三棵 provider 副本分别注入 EIO / 换入攻击 / 并发非空。
  for tree in eio swap conc; do
    mkdir -p "$tmp/$tree"
    cp "$lib"/session-state-*.sh "$aggregator" "$tmp/$tree/"
  done
  python3 - "$tmp" <<'PY'
import sys
base = sys.argv[1]
def inject(tree, anchor, payload):
    path = f"{base}/{tree}/session-state-remove.sh"
    text = open(path).read()
    assert text.count(anchor) == 1
    open(path, "w").write(text.replace(anchor, anchor + payload))
inject("eio", "        pass  # HARNESS_TEST_MARKER_OS_ERROR", '\n        raise OSError(errno.EIO, "injected EIO")')
inject("swap", "            pass  # PRUNE_BEFORE_IDENTITY", '\n            if name == session:\n                os.rename(name, name + ".held", src_dir_fd=parent_fd, dst_dir_fd=parent_fd)\n                os.mkdir(name, 0o700, dir_fd=parent_fd)')
inject("conc", "            pass  # PRUNE_BEFORE_IDENTITY", '\n            if name == session:\n                os.mkdir("concurrent", 0o700, dir_fd=parent_fd)')
PY
  tree_expect eio 1 'error: session state operation failed\n'
  tree_expect swap 2 'error: unsafe session state\n'
  check_eq 'swap both dirs retained' yes "$([[ -d $tmp/swap-state/project/session && -d $tmp/swap-state/project/session.held ]] && echo yes || echo no)"
  tree_expect conc 0 ''
  inv_eq 'concurrent inventory' '.\n./project\n./project/concurrent\n' "$tmp/conc-state"
  # 六类 inert fixture: 五模块各自缺席 + aggregator 缺席(自愿加严, 不断言双流空)。
  for fixture_name in missing-foundation missing-path missing-snapshot missing-signals missing-remove aggregator-absent; do
    run_fixture "$fixture_name"
  done
fi
if ((failures)); then
  printf 'RESULT FAIL session state checks=%d failures=%d\n' "$checks" "$failures"
  exit 1
fi
printf 'RESULT PASS  session state\n'
