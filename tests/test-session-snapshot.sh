#!/usr/bin/env bash
set -u
case ${1-} in
  '' | all) ;;
  --dependency-absent) mode=absent ;;
  *) exit 1 ;;
esac
[[ $# -le 1 ]] || exit 1
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
repo=$(git -C "$here" rev-parse --show-toplevel)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
core=${SNAPSHOT_CORE:-$repo/common/.harness/lib/session-state-snapshot.sh}
surface_rc=0
for setup in none validate path both; do
  SETUP=$setup bash -c 'case $SETUP in validate|both) harness_validate_feature_name(){ :; };; esac; case $SETUP in path|both) _harness_session_path_core(){ :; };; esac; before=$(declare -f harness_validate_feature_name _harness_session_path_core 2>/dev/null || :); before_inventory=$(declare -F | sort); before_exports=$(export -p); source "$1"; source_rc=$?; after=$(declare -f harness_validate_feature_name _harness_session_path_core 2>/dev/null || :); after_inventory=$(declare -F | sed "/declare -f _harness_session_snapshot_\\(worker\\|write_core\\|read_core\\)$/d" | sort); after_exports=$(export -p); [[ $source_rc == 0 && $before == "$after" && $before_inventory == "$after_inventory" && $before_exports == "$after_exports" && ! -v HARNESS_SESSION_STATE_PROVIDER_VERSION ]] || exit 1; for name in _harness_session_snapshot_worker _harness_session_snapshot_write_core _harness_session_snapshot_read_core; do if [[ $SETUP == both ]]; then declare -F "$name" >/dev/null; else ! declare -F "$name" >/dev/null; fi || exit 1; done; for name in harness_session_path harness_session_write harness_session_read harness_session_remove; do ! declare -F "$name" >/dev/null || exit 1; done' _ "$core" || surface_rc=1
done >"$tmp/out" 2>"$tmp/err"
((surface_rc == 0)) && [[ ! -s $tmp/out && ! -s $tmp/err ]] || exit 1
[[ ${mode-} != absent ]] || exec printf 'RESULT PASS  session snapshot safety\n'
export HARNESS_STATE_ROOT=$tmp/state
source "$repo/common/.harness/lib/session-state-foundation.sh" 2>/dev/null || :
source "$repo/common/.harness/lib/session-state-path.sh" 2>/dev/null || :
declare -F harness_validate_feature_name _harness_session_path_core >/dev/null || exec printf 'RESULT PASS  session snapshot safety\n'
probe_core=$tmp/snapshot-core.sh
python3 - "$core" "$probe_core" <<'PY'
import sys; text = open(sys.argv[1]).read()
replacements = {
    "    : # HARNESS_TEST_MARKER_CAPTURE_READY": """    [[ ! -e $path_file && $(stat -Lc '%a:%h' "/proc/$BASHPID/fd/$path_fd") == 600:0 ]] || return 1
    : # HARNESS_TEST_MARKER_CAPTURE_READY""",
    "    pass  # HARNESS_TEST_MARKER_TEMP_BEFORE_PUBLISH": """    barrier = os.environ.get("SNAPSHOT_PID_BARRIER")
    if barrier: open(barrier, "w").close()
    while barrier and os.path.exists(barrier): __import__("time").sleep(.01)
    pass  # HARNESS_TEST_MARKER_TEMP_BEFORE_PUBLISH""",
    "    raise Interrupted": """    caught = os.environ.get("SNAPSHOT_SIGNAL_CAUGHT")
    if caught: open(caught, "w").close(); __import__("time").sleep(.2)
    raise Interrupted""",
}
for old, new in replacements.items():
    assert text.count(old) == 1; text = text.replace(old, new)
open(sys.argv[2], "w").write(text)
PY
core=$probe_core
# shellcheck source=/dev/null
source "$core" && failures=0
check_rc() {
  local want=$1
  shift
  local out=$tmp/out err=$tmp/err rc command=$1
  "$@" >"$out" 2>"$err"
  rc=$?
  if [[ $rc != "$want" || -s $err || ($want != 0 && -s $out) || ($command == *_write_core && -s $out) ]]; then
    printf 'FAIL rc want=%s got=%s command=%q\n' "$want" "$rc" "$*"
    failures=$((failures + 1))
  fi
}
reset() { rm -rf -- "$HARNESS_STATE_ROOT"; }
leaf() { printf '%s/project/session/feature' "$HARNESS_STATE_ROOT"; }
object_state() { find "$1" -maxdepth 0 -printf '%y:%D:%i:%U:%m:%n:%s:%l\n' -type f -exec sha256sum {} \;; }
tree_state() { [[ ! -e $HARNESS_STATE_ROOT ]] || {
  find "$HARNESS_STATE_ROOT" -xdev -printf '%P:%y:%D:%i:%u:%m:%n:%s:%l\n'
  find "$HARNESS_STATE_ROOT" -xdev -type f -exec sha256sum {} +
}; }
temp_count() { find "$tmp" -name '.snapshot-*' | wc -l | xargs; }
check_rc 3 _harness_session_snapshot_read_core project session
[[ ! -e $(leaf) ]] || failures=$((failures + 1))
check_rc 0 _harness_session_snapshot_write_core project session alpha
check_rc 0 _harness_session_snapshot_read_core project session
[[ $(od -An -tx1 "$tmp/out" | tr -d ' \n') == 616c7068610a ]] || failures=$((failures + 1))
before=$(tree_state)
check_rc 0 _harness_session_snapshot_write_core project session alpha
[[ $(tree_state) == "$before" ]] || failures=$((failures + 1))
check_rc 3 _harness_session_snapshot_write_core project session beta
[[ $(tree_state) == "$before" ]] || failures=$((failures + 1))
reset
mkdir -p "$tmp/results"
write_result() {
  _harness_session_snapshot_write_core project session "$1"
  printf '%s\n' "$?" >"$tmp/results/$2"
}
for n in 1 2 3 4 5 6; do (write_result same "$n") & done
wait
[[ $(sort "$tmp/results"/* | uniq -c) == '      6 0' ]] || failures=$((failures + 1))
[[ $(<"$(leaf)") == same ]] || failures=$((failures + 1))
before=$(tree_state)
for n in 1 2 3 4 5 6; do (_harness_session_snapshot_write_core project session same) & done
wait
[[ $(tree_state) == "$before" ]] || failures=$((failures + 1))
reset
rm -f "$tmp/results"/*
for n in 1 2 3 4 5 6; do (write_result "v$n" "$n") & done
wait
[[ $(sort "$tmp/results"/* | uniq -c) == $'      1 0\n      5 3' ]] || failures=$((failures + 1))
[[ $(<"$(leaf)") =~ ^v[1-6]$ ]] || failures=$((failures + 1))
[[ $(find "$HARNESS_STATE_ROOT/project/session" -mindepth 1 -maxdepth 1 | wc -l) == 1 ]] || failures=$((failures + 1))
winner=$(<"$(leaf)") before=$(tree_state)
for n in 1 2 3 4 5 6; do (_harness_session_snapshot_write_core project session "v$n") & done
wait
[[ $(tree_state) == "$before" && $(<"$(leaf)") == "$winner" ]] || failures=$((failures + 1))
attack() {
  local kind=$1
  reset
  _harness_session_path_core project session >/dev/null
  case $kind in
    symlink) ln -s "$tmp/victim" "$(leaf)" ;;
    hardlink) : >"$tmp/victim" && ln "$tmp/victim" "$(leaf)" ;;
    directory) mkdir "$(leaf)" ;;
    mode) printf 'alpha\n' >"$(leaf)" && chmod 0644 "$(leaf)" ;;
    content) printf 'alpha\nextra\n' >"$(leaf)" && chmod 0600 "$(leaf)" ;;
  esac
  before=$(tree_state) victim_before=$(object_state "$tmp/victim")
  check_rc 2 _harness_session_snapshot_read_core project session
  check_rc 2 _harness_session_snapshot_write_core project session alpha
  [[ $(tree_state) == "$before" && $(object_state "$tmp/victim") == "$victim_before" && $(temp_count) == 0 ]] || failures=$((failures + 1))
}
: >"$tmp/victim"
for kind in symlink hardlink directory mode content; do attack "$kind"; done
content_attack() {
  local data=$1
  reset
  _harness_session_path_core project session >/dev/null
  printf '%b' "$data" >"$(leaf)"
  chmod 0600 "$(leaf)"
  before=$(tree_state) victim_before=$(object_state "$tmp/victim")
  check_rc 2 _harness_session_snapshot_read_core project session
  check_rc 2 _harness_session_snapshot_write_core project session alpha
  [[ $(tree_state) == "$before" && $(object_state "$tmp/victim") == "$victim_before" && $(temp_count) == 0 ]] || failures=$((failures + 1))
}
for data in '' "$(printf 'a%.0s' {1..129})\n" '\377\n' alpha 'alpha\nbeta\n' 'alpha\nX' '.bad\n' 'a b\n' 'a/b\n'; do content_attack "$data"; done
real_path=$(declare -f _harness_session_path_core)
managed_attack() {
  local layer=$1 kind=$2 path want=2
  reset
  # shellcheck disable=SC2034
  path=$(_harness_session_path_core project session)
  case $layer in
    root) target=$HARNESS_STATE_ROOT ;;
    project) target=$HARNESS_STATE_ROOT/project ;;
    session) target=$HARNESS_STATE_ROOT/project/session ;;
  esac
  case $kind in
    symlink) rm -rf -- "$target" && ln -s "$tmp/victim-dir" "$target" ;;
    file) rm -rf -- "$target" && : >"$target" ;;
    mode) chmod 0755 "$target" ;;
    missing) rm -rf -- "$target" && want=1 ;;
  esac
  before=$(tree_state) victim_before=$(object_state "$tmp/victim-dir")
  eval '_harness_session_path_core() { printf "%s\\n" "$path"; }'
  check_rc "$want" _harness_session_snapshot_read_core project session
  check_rc "$want" _harness_session_snapshot_write_core project session alpha
  [[ $(tree_state) == "$before" && $(object_state "$tmp/victim-dir") == "$victim_before" && $(temp_count) == 0 ]] || failures=$((failures + 1))
  eval "$real_path"
}
mkdir -m 0700 "$tmp/victim-dir"
for layer in root project session; do
  for kind in symlink file mode missing; do managed_attack "$layer" "$kind"; done
done
for path_rc in 1 2; do
  eval '_harness_session_path_core() { return "$path_rc"; }'
  check_rc "$path_rc" _harness_session_snapshot_read_core project session
  check_rc "$path_rc" _harness_session_snapshot_write_core project session alpha
done
eval '_harness_session_path_core() { printf "%s/wrong/session\n" "$HARNESS_STATE_ROOT"; }'
check_rc 2 _harness_session_snapshot_read_core project session
check_rc 2 _harness_session_snapshot_write_core project session alpha
eval "$real_path"
for marker in CAPTURE_READY SNAPSHOT_MANAGED_BEFORE_OPEN MANAGED_EXPECTED_EUID \
  SNAPSHOT_EXPECTED_EUID SNAPSHOT_BEFORE_OPEN TEMP_BEFORE_PUBLISH PUBLISH_RESULT OS_ERROR; do
  [[ $(rg -c "HARNESS_TEST_MARKER_$marker" "$core") == 1 ]] || failures=$((failures + 1))
done
[[ $(rg -F -c 'path = path_from_fd(int(path_fd))' "$core") == 1 ]] || failures=$((failures + 1))
reset && barrier=$tmp/temp-barrier caught=$tmp/signal-caught
SNAPSHOT_PID_BARRIER=$barrier SNAPSHOT_SIGNAL_CAUGHT=$caught _harness_session_snapshot_worker write project session pidprobe &
worker=$!
while [[ ! -e $barrier ]]; do sleep .01; done
[[ -e $barrier && $(ps -o comm= -p "$worker" | xargs) == python3 ]] || failures=$((failures + 1))
kill -TERM "$worker"
while [[ ! -e $caught ]]; do sleep .01; done
kill -HUP "$worker" 2>/dev/null || true
wait "$worker"
rc=$?
[[ $rc == 143 && ! -e $(leaf) ]] || failures=$((failures + 1))
[[ $(find "$HARNESS_STATE_ROOT/project/session" -mindepth 1 -maxdepth 1 | wc -l) == 0 ]] || failures=$((failures + 1))
reset
worker_call() { (_harness_session_snapshot_worker "$@"); }
check_rc 2 worker_call nope project session
check_rc 2 worker_call write project session
check_rc 2 worker_call read project session extra
[[ ! -e $HARNESS_STATE_ROOT ]] || failures=$((failures + 1))
check_rc 2 _harness_session_snapshot_write_core project session '../bad'
check_rc 2 _harness_session_snapshot_read_core project
((failures == 0)) || exit 1
printf 'RESULT PASS  session snapshot safety\n'
