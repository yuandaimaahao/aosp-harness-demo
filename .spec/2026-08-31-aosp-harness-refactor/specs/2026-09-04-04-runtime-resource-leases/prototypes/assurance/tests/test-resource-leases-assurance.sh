#!/usr/bin/env bash
# shellcheck disable=SC1090
set -u
export LC_ALL=C
summary='RESULT PASS  resource lease assurance'
dependency_absent=false
case ${1-} in
  '' | all) ;;
  --dependency-absent) dependency_absent=true ;;
  *) exit 1 ;;
esac
[[ $# -le 1 ]] || exit 1
if [[ ${HARNESS_ASSURANCE_CLI_PROBE-} == 1 ]]; then
  printf 'cli-ok\n'
  exit 0
fi
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
provider=${HARNESS_ASSURANCE_PROVIDER:-$here/../../common/.harness/lib/resource-leases.sh}
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export TMPDIR=$tmp
fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}
pass() {
  printf '%s\n' "$summary"
  exit 0
}
provider_state() {
  local candidate=$1
  [[ -e $candidate || -L $candidate ]] || return 3
  [[ -f $candidate && ! -L $candidate ]] || return 1
  bash -n "$candidate" 2>/dev/null || return 1
  [[ $(grep -cF '# HARNESS_RESOURCE_LEASE_TEST_SEAM' "$candidate") == 1 ]] || return 1
  bash -c 'source "$1" && declare -F harness_lease_acquire harness_lease_release >/dev/null' _ "$candidate" \
    >"$tmp/provider.out" 2>"$tmp/provider.err" || return 1
  [[ ! -s $tmp/provider.out && ! -s $tmp/provider.err ]]
}
cli_probe() {
  local label=$1 want=$2
  shift 2
  HARNESS_ASSURANCE_CLI_PROBE=1 bash "$0" "$@" >"$tmp/cli.out" 2>"$tmp/cli.err"
  local rc=$?
  [[ $rc == "$want" && ! -s $tmp/cli.err ]] || fail "CLI $label rc/err"
  if [[ $want == 0 ]]; then
    cmp -s "$tmp/cli.out" <(printf 'cli-ok\n') || fail "CLI $label stdout"
  else
    [[ ! -s $tmp/cli.out ]] || fail "CLI $label stdout"
  fi
}
cli_probe noarg 0
cli_probe all 0 all
cli_probe dependency-absent 0 --dependency-absent
cli_probe unknown 1 unknown
cli_probe extra 1 all extra
$dependency_absent && pass
if [[ -z ${HARNESS_ASSURANCE_SURFACE_CHILD-} ]]; then
  surface=$tmp/surface
  mkdir -p "$surface/assurance/tests"
  cp "$0" "$surface/assurance/tests/test-resource-leases-assurance.sh"
  HARNESS_ASSURANCE_SURFACE_CHILD=1 bash "$surface/assurance/tests/test-resource-leases-assurance.sh" \
    >"$tmp/absent.out" 2>"$tmp/absent.err" || fail 'absent provider execution'
  cmp -s "$tmp/absent.out" <(printf '%s\n' "$summary") || fail 'absent provider summary'
  [[ ! -s $tmp/absent.err ]] || fail 'absent provider stderr'
  mkdir -p "$surface/common/.harness/lib"
  printf 'not bash\n' >"$surface/common/.harness/lib/resource-leases.sh"
  HARNESS_ASSURANCE_SURFACE_CHILD=1 bash "$surface/assurance/tests/test-resource-leases-assurance.sh" \
    >"$tmp/damaged.out" 2>"$tmp/damaged.err"
  [[ $? == 1 && ! -s $tmp/damaged.out ]] || fail 'damaged provider execution'
fi
provider_state "$tmp/absent"
[[ $? == 3 ]] || fail 'absent provider classification'
provider_state "$provider"
case $? in
  0) ;;
  3) pass ;;
  *) fail 'provider validation' ;;
esac
printf 'not bash\n' >"$tmp/broken.sh"
provider_state "$tmp/broken.sh"
[[ $? == 1 ]] || fail 'broken provider fail closed'
grep -vF '# HARNESS_RESOURCE_LEASE_TEST_SEAM' "$provider" >"$tmp/no-seam.sh"
provider_state "$tmp/no-seam.sh"
[[ $? == 1 ]] || fail 'missing seam fail closed'
ln -s "$provider" "$tmp/provider-link.sh"
provider_state "$tmp/provider-link.sh"
[[ $? == 1 ]] || fail 'linked provider fail closed'
source "$provider"
declare -F harness_lease_acquire harness_lease_release >/dev/null || fail 'public functions'
! declare -F harness_session_path harness_session_write harness_session_read harness_session_remove >/dev/null \
  || fail 'foreign public functions'
[[ -z ${HARNESS_SESSION_STATE_PROVIDER_VERSION+x} ]] || fail 'foreign marker'
printf 'error: resource lease operation failed\n' >"$tmp/error2"
printf 'error: resource lease unavailable\n' >"$tmp/error3"
LAST_TOKEN=
invoke() {
  local label=$1 want=$2 shape=$3
  shift 3
  "$@" >"$tmp/out" 2>"$tmp/err"
  local rc=$?
  [[ $rc == "$want" ]] || fail "$label rc=$rc"
  case $shape in
    token)
      [[ ! -s $tmp/err ]] || fail "$label token stderr"
      [[ $(wc -c <"$tmp/out") == 33 ]] || fail "$label token bytes=$(wc -c <"$tmp/out")"
      LAST_TOKEN=$(tr -d '\n' <"$tmp/out")
      [[ $LAST_TOKEN =~ ^[0-9a-f]{32}$ ]] || fail "$label token syntax"
      cmp -s "$tmp/out" <(printf '%s\n' "$LAST_TOKEN") || fail "$label token framing"
      ;;
    empty) [[ ! -s $tmp/out && ! -s $tmp/err ]] || fail "$label streams" ;;
    error2)
      if [[ -s $tmp/out ]] || ! cmp -s "$tmp/err" "$tmp/error2"; then fail "$label error2"; fi
      ;;
    error3)
      if [[ -s $tmp/out ]] || ! cmp -s "$tmp/err" "$tmp/error3"; then fail "$label error3"; fi
      ;;
    *) fail "$label internal shape" ;;
  esac
}
state=$tmp/state
reset_state() {
  rm -rf -- "$state"
  mkdir -m 700 "$state"
  export HARNESS_RESOURCE_LEASE_ROOT=$state
}
inventory_empty() {
  local files
  files=$(find "$state" -mindepth 1 -maxdepth 1 -printf '%f\n' | LC_ALL=C sort)
  [[ -z $files || $files == .lock ]]
}
mkdir -m 700 "$tmp/ws" "$tmp/ws2" "$tmp/ws3"
printf 'workspace\t%s\tsource\nandroid\tunit\tdevice\n' "$tmp/ws" >"$tmp/ab.tsv"
printf 'android\tunit\tdevice\nworkspace\t%s\tsource\n' "$tmp/ws" >"$tmp/ba.tsv"
printf 'workspace\t%s\tsource\n' "$tmp/ws" >"$tmp/a.tsv"
printf 'workspace\t%s\tbuild\n' "$tmp/ws" >"$tmp/a-mode.tsv"
printf 'workspace\t%s\tbuild\n' "$tmp/ws2" >"$tmp/b.tsv"
printf 'workspace\t%s\tbuild\n' "$tmp/ws3" >"$tmp/c.tsv"
printf 'android\tunit\tdevice\nandroid\tother\tdevice\n' >"$tmp/partial.tsv"
printf 'workspace\t%s\tsource\nworkspace\t%s\tbuild\nandroid\tunit\tdevice\n' "$tmp/ws" "$tmp/ws3" >"$tmp/super.tsv"
printf 'android\tunit\tcvd\n' >"$tmp/instance-mode.tsv"
reset_state
invoke 'bundle acquire' 0 token harness_lease_acquire owner 0 "$tmp/ab.tsv"
bundle=$LAST_TOKEN
invoke 'reverse idempotent' 0 token harness_lease_acquire owner 0 "$tmp/ba.tsv"
[[ $LAST_TOKEN == "$bundle" ]] || fail 'reverse token identity'
invoke 'same owner changed session' 2 error2 harness_lease_acquire changed 0 "$tmp/ab.tsv"
invoke 'same owner subset' 2 error2 harness_lease_acquire owner 0 "$tmp/a.tsv"
invoke 'same owner superset' 2 error2 harness_lease_acquire owner 0 "$tmp/super.tsv"
invoke 'same owner partial overlap' 2 error2 harness_lease_acquire owner 0 "$tmp/partial.tsv"
invoke 'disjoint acquire' 0 token harness_lease_acquire side 0 "$tmp/b.tsv"
side=$LAST_TOKEN
invoke 'disjoint release' 0 empty harness_lease_release "$side"
invoke 'bundle release' 0 empty harness_lease_release "$bundle"
inventory_empty || fail 'normal inventory'
for item in empty no-lf blank cr columns pair duplicate unsafe missing; do
  request=$tmp/bad-$item.tsv
  case $item in
    empty) : >"$request" ;;
    no-lf) printf 'android\tbad\tdevice' >"$request" ;;
    blank) printf 'android\tbad\tdevice\n\n' >"$request" ;;
    cr) printf 'android\tbad\tdevice\r\n' >"$request" ;;
    columns) printf 'android\tbad\n' >"$request" ;;
    pair) printf 'workspace\t%s\tdevice\n' "$tmp/ws" >"$request" ;;
    duplicate) printf 'android\tbad\tdevice\nandroid\tbad\tcvd\n' >"$request" ;;
    unsafe) printf 'android\t../bad\tdevice\n' >"$request" ;;
    missing) printf 'workspace\t%s\tsource\n' "$tmp/not-there" >"$request" ;;
  esac
  invoke "request $item" 2 error2 harness_lease_acquire bad 0 "$request"
done
for byte in $'\t' $'\n' $'\r' $'\037'; do
  control_target=$tmp/control$byte
  mkdir "$control_target" && ln -s "$control_target" "$tmp/control-link"
  printf 'workspace\t%s\tsource\n' "$tmp/control-link" >"$tmp/control.tsv"
  invoke 'request realpath control' 2 error2 harness_lease_acquire bad 0 "$tmp/control.tsv"
  rm "$tmp/control-link"
done
printf 'android\tbad\tdevice\0\n' >"$tmp/nul.tsv"
invoke 'request NUL' 2 error2 harness_lease_acquire bad 0 "$tmp/nul.tsv"
ln -s "$tmp/ws" "$tmp/alias-a" && ln -s "$tmp/ws" "$tmp/alias-b"
printf 'workspace\t%s\tsource\nworkspace\t%s\tbuild\n' "$tmp/alias-a" "$tmp/alias-b" >"$tmp/alias.tsv"
invoke 'request canonical alias' 2 error2 harness_lease_acquire bad 0 "$tmp/alias.tsv"
invoke 'request nonregular' 2 error2 harness_lease_acquire bad 0 "$tmp/ws"
reset_state
HARNESS_RESOURCE_LEASE_ROOT=relative invoke 'relative root' 2 error2 harness_lease_acquire root 0 "$tmp/a.tsv"
printf x >"$tmp/root-file"
HARNESS_RESOURCE_LEASE_ROOT=$tmp/root-file invoke 'file root' 2 error2 harness_lease_acquire root 0 "$tmp/a.tsv"
ln -s "$state" "$tmp/root-link"
HARNESS_RESOURCE_LEASE_ROOT=$tmp/root-link invoke 'link root' 2 error2 harness_lease_acquire root 0 "$tmp/a.tsv"
mkdir -m 755 "$tmp/root-mode"
HARNESS_RESOURCE_LEASE_ROOT=$tmp/root-mode invoke 'mode root' 2 error2 harness_lease_acquire root 0 "$tmp/a.tsv"
mkdir -m 700 "$tmp/xdg"
unset HARNESS_RESOURCE_LEASE_ROOT
XDG_RUNTIME_DIR=$tmp/xdg invoke 'default root acquire' 0 token harness_lease_acquire root 0 "$tmp/a.tsv"
default_token=$LAST_TOKEN
XDG_RUNTIME_DIR=$tmp/xdg invoke 'default root release' 0 empty harness_lease_release "$default_token"
[[ -d $tmp/xdg/aosp-harness-resource-leases-$(id -u) ]] || fail 'default root path'
reset_state
holder_ready=$tmp/holder-ready
holder_go=$tmp/holder-go
adapter_log=$tmp/adapter.log
: >"$holder_go"
HARNESS_RESOURCE_LEASE_ROOT=$state bash -c '
  source "$1" || exit; harness_lease_acquire holder 0 "$2" >"$3" || exit
  printf "%s\t%s\n" "$6" "$7" >>"$8"; : >"$4"; while [[ -e $5 ]]; do sleep .01; done
  harness_lease_release "$(tr -d "\n" <"$3")"
' _ "$provider" "$tmp/ab.tsv" "$tmp/holder-token" "$holder_ready" "$holder_go" serial-A cvd-A "$adapter_log" >"$tmp/holder.out" 2>"$tmp/holder.err" &
holder=$!
while [[ ! -e $holder_ready ]]; do kill -0 "$holder" 2>/dev/null || fail 'holder startup'; done
invoke 'different owner same mode' 3 error3 harness_lease_acquire other 0 "$tmp/a.tsv"
invoke 'different owner other mode' 3 error3 harness_lease_acquire other 0 "$tmp/a-mode.tsv"
invoke 'live positive timeout' 3 error3 harness_lease_acquire other 1 "$tmp/a.tsv"
[[ ${HARNESS_ASSURANCE_MUTANT_CHILD-} == adapter ]] && printf 'android\tother\tcvd\n' >"$tmp/instance-mode.tsv"
HARNESS_RESOURCE_LEASE_ROOT=$state bash -c '
  source "$1" || exit
  harness_lease_acquire adapter 0 "$2" >"$3" || exit
  printf "%s\t%s\n" "$4" "$5" >>"$6"
' _ "$provider" "$tmp/instance-mode.tsv" "$tmp/adapter-token" serial-B cvd-B "$adapter_log" \
  >"$tmp/adapter.out" 2>"$tmp/adapter.err"
[[ $? == 3 && $(wc -l <"$adapter_log") == 1 && ! -s $tmp/adapter.out ]] || fail 'adapter command count'
grep -qx $'serial-A\tcvd-A' "$adapter_log" || fail 'adapter argv isolation'
cmp -s "$tmp/adapter.err" "$tmp/error3" || fail 'adapter contention error'
waiter_ready=$tmp/waiter-ready
HARNESS_RESOURCE_LEASE_ROOT=$state bash -c '
  source "$1" || exit; : >"$4"
  harness_lease_acquire waiter 3 "$2" >"$3" || exit
  harness_lease_release "$(tr -d "\n" <"$3")"
' _ "$provider" "$tmp/ba.tsv" "$tmp/waiter-token" "$waiter_ready" >"$tmp/waiter.out" 2>"$tmp/waiter.err" &
waiter=$!
while [[ ! -e $waiter_ready ]]; do kill -0 "$waiter" 2>/dev/null || fail 'waiter startup'; done
sleep .1
kill -0 "$waiter" 2>/dev/null || fail 'waiter did not block'
python3 - "$state" <<'PY' || fail 'barrier exposed partial bundle'
import base64, glob, json, sys; paths = glob.glob(sys.argv[1] + "/active-*")
for path in paths: assert base64.b64decode(json.load(open(path))["request"]).count(b"\n") == 2
PY
rm -- "$holder_go"
wait "$holder" || fail 'holder release'
wait "$waiter" || fail 'positive waiter'
[[ ! -s $tmp/holder.out && ! -s $tmp/holder.err && ! -s $tmp/waiter.out && ! -s $tmp/waiter.err ]] || fail 'wait streams'
[[ $(wc -c <"$tmp/waiter-token") == 33 ]] || fail 'wait token'
inventory_empty || fail 'wait inventory'
mutate_record() {
  ACTIVE=$1 MODE=$2 REQUEST=${3-} python3 - <<'PY'
import base64, hashlib, json, os; p, mode = os.environ["ACTIVE"], os.environ["MODE"]
if mode == "duplicate": text = open(p, encoding="ascii").read(); open(p, "w", encoding="ascii").write(text.replace('{"hash":', '{"hash":"x","hash":', 1)); raise SystemExit
d = json.load(open(p, encoding="ascii"))
if mode == "pid-reuse": d["owner"][2] = str(int(d["owner"][2]) + 1)
else: raw = open(os.environ["REQUEST"], "rb").read(); d["request"] = base64.b64encode(raw).decode("ascii"); d["hash"] = hashlib.sha256(raw).hexdigest()
binding = json.dumps([d["owner"], d["session"], d["hash"], d["nonce"]], separators=(",", ":")).encode(); d["token"] = hashlib.sha256(binding).hexdigest()[:32]
target = os.path.join(os.path.dirname(p), "active-" + d["token"]); json.dump(d, open(target, "w", encoding="ascii"), sort_keys=True, separators=(",", ":")); os.chmod(target, 0o600); target != p and os.unlink(p)
PY
}
for damage in duplicate invalid noncanonical overlap; do
  reset_state
  invoke "$damage seed A" 0 token harness_lease_acquire seed 0 "$tmp/a.tsv"
  first=$LAST_TOKEN
  active=$state/active-$first
  if [[ $damage == overlap ]]; then
    invoke "$damage seed B" 0 token harness_lease_acquire seed 0 "$tmp/b.tsv"
    active=$state/active-$LAST_TOKEN
    mutate_record "$active" overlap "$tmp/a.tsv"
  elif [[ $damage == invalid ]]; then
    printf 'android\tbad\tbogus\n' >"$tmp/stored-invalid.tsv"
    mutate_record "$active" invalid "$tmp/stored-invalid.tsv"
  elif [[ $damage == noncanonical ]]; then
    printf 'workspace\t%s/../ws\tsource\n' "$tmp/ws" >"$tmp/stored-noncanonical.tsv"
    mutate_record "$active" noncanonical "$tmp/stored-noncanonical.tsv"
  else
    mutate_record "$active" duplicate
  fi
  invoke "stored $damage" 2 error2 harness_lease_acquire next 0 "$tmp/c.tsv"
done
reset_state
invoke 'nonregular record seed' 0 token harness_lease_acquire seed 0 "$tmp/a.tsv"
rm "$state/active-$LAST_TOKEN" && ln -s /dev/null "$state/active-$LAST_TOKEN"
invoke 'stored nonregular record' 2 error2 harness_lease_acquire next 0 "$tmp/c.tsv"
for field in version token nonce owner session hash request missing extra filename; do
  reset_state
  invoke "$field seed" 0 token harness_lease_acquire seed 0 "$tmp/a.tsv"
  active=$state/active-$LAST_TOKEN
  FIELD=$field ACTIVE=$active python3 - <<'PY'
import json, os; p, field = os.environ["ACTIVE"], os.environ["FIELD"]; d = json.load(open(p)); bad = {"version": 2, "token": "0" * 32, "nonce": "x" * 32, "owner": [0], "session": "../x", "hash": "0" * 64, "request": "!"}
if field == "missing": del d["version"]
elif field == "extra": d["extra"] = 1
elif field != "filename": d[field] = bad[field]
json.dump(d, open(p, "w"), sort_keys=True, separators=(",", ":")); os.chmod(p, 0o600); field == "filename" and os.rename(p, os.path.dirname(p) + "/active-" + "0" * 32)
PY
  invoke "stored field $field" 2 error2 harness_lease_acquire next 0 "$tmp/c.tsv"
done
reset_state
invoke 'pid reuse seed' 0 token harness_lease_acquire old 0 "$tmp/a.tsv"
old=$LAST_TOKEN
mutate_record "$state/active-$old" pid-reuse
invoke 'pid reuse stale reclaim' 0 token harness_lease_acquire fresh 0 "$tmp/a.tsv"
[[ $LAST_TOKEN != "$old" ]] || fail 'pid reuse token'
invoke 'pid reuse release' 0 empty harness_lease_release "$LAST_TOKEN"
inventory_empty || fail 'pid reuse inventory'
mkdir "$tmp/bin"
printf '#!/bin/sh\ncase $1 in -c) exit 0;; *) printf evil; printf bad >&2; exit 17;; esac\n' >"$tmp/bin/python3"
chmod +x "$tmp/bin/python3"
reset_state
PATH=$tmp/bin:$PATH invoke 'fake python' 2 error2 harness_lease_acquire tool 0 "$tmp/a.tsv"
inventory_empty || fail 'fake python inventory'
for helper in mktemp rm; do
  helper_dir=$tmp/helper-$helper && mkdir "$helper_dir"
  [[ $helper == mktemp ]] && helper_rc=1 || helper_rc=0
  printf '#!/bin/sh\nprintf evil; printf bad >&2; exit %s\n' "$helper_rc" >"$helper_dir/$helper"
  chmod +x "$helper_dir/$helper" && reset_state
  PATH=$helper_dir:$PATH invoke "fake $helper" 2 error2 harness_lease_acquire tool 0 "$tmp/a.tsv"
  inventory_empty || fail "fake $helper inventory"
done
mkdir -m 700 "$tmp/victim" && printf 'sentinel\n' >"$tmp/victim/out"
printf '#!/bin/sh\nprintf "%s\\n" "$1"\n' "$tmp/victim" >"$tmp/helper-mktemp/mktemp"
chmod +x "$tmp/helper-mktemp/mktemp" && reset_state
PATH=$tmp/helper-mktemp:$PATH invoke 'fake mktemp success' 2 error2 harness_lease_acquire tool 0 "$tmp/a.tsv"
cmp -s "$tmp/victim/out" <(printf 'sentinel\n') && inventory_empty || fail 'fake mktemp success isolation'
printf '#!/bin/sh\ncase $1 in -c) exit 0;; *) p=$(readlink /proc/$$/fd/1); rm -- "$p"; exit 0;; esac\n' >"$tmp/bin/python3"
chmod +x "$tmp/bin/python3" && reset_state
PATH=$tmp/bin:$PATH invoke 'capture disappear' 2 error2 harness_lease_acquire tool 0 "$tmp/a.tsv"
inventory_empty || fail 'capture disappear inventory'
reset_state
bash -c 'source "$1"; exec 1>&-; harness_lease_acquire closed 0 "$2"' _ "$provider" "$tmp/a.tsv" \
  >"$tmp/closed.out" 2>"$tmp/closed.err"
[[ $? == 2 && ! -s $tmp/closed.out ]] || fail 'closed stdout rc/out'
cmp -s "$tmp/closed.err" "$tmp/error2" || fail 'closed stdout error'
inventory_empty || fail 'closed stdout inventory'
copy=$tmp/provider-faults.sh
python3 - "$provider" "$copy" <<'PY'
import sys; text = open(sys.argv[1], encoding="utf-8").read(); anchor = '# HARNESS_RESOURCE_LEASE_TEST_SEAM\ndef test_seam(_point, value=None): return value'
injected = '''# HARNESS_RESOURCE_LEASE_TEST_SEAM
_seam_counts = {}
def test_seam(point, value=None):
    _seam_counts[point] = _seam_counts.get(point, 0) + 1
    if os.environ.get("ASSURANCE_SEAM_LOG"): open(os.environ["ASSURANCE_SEAM_LOG"], "a").write(point + "\\n")
    if os.environ.get("ASSURANCE_FAULT") == point: raise OSError(5, "injected")
    if os.environ.get("ASSURANCE_MUTATE") == point: changed = list(value); changed[4] += 1; return os.stat_result(changed)
    if point == "monotonic" and os.environ.get("ASSURANCE_CLOCK"): return 0 if _seam_counts[point] < 3 else 1
    return value'''
assert text.count(anchor) == 1; open(sys.argv[2], "w", encoding="utf-8").write(text.replace(anchor, injected))
PY
source "$copy"
for fault in flock open write fsync replace; do
  reset_state
  ASSURANCE_FAULT=$fault invoke "I/O $fault" 2 error2 harness_lease_acquire io 0 "$tmp/a.tsv"
  inventory_empty || fail "I/O $fault inventory"
done
reset_state
ASSURANCE_MUTATE=root-owner invoke 'root wrong owner' 2 error2 harness_lease_acquire io 0 "$tmp/a.tsv"
inventory_empty || fail 'root wrong owner inventory'
reset_state
ASSURANCE_MUTATE=lock-owner invoke 'lock wrong owner' 2 error2 harness_lease_acquire io 0 "$tmp/a.tsv"
inventory_empty || fail 'lock wrong owner inventory'
reset_state
clock_go=$tmp/clock-go
: >"$clock_go"
HARNESS_RESOURCE_LEASE_ROOT=$state bash -c 'source "$1"; t=$(harness_lease_acquire hold 0 "$2") || exit; : >"$3"; while [[ -e $4 ]]; do sleep .01; done; harness_lease_release "$t"' _ "$provider" "$tmp/a.tsv" "$tmp/clock-ready" "$clock_go" &
clock_holder=$!
while [[ ! -e $tmp/clock-ready ]]; do kill -0 "$clock_holder" 2>/dev/null || fail 'clock holder'; done
ASSURANCE_CLOCK=1 ASSURANCE_SEAM_LOG=$tmp/seam.log invoke 'monotonic final attempt' 3 error3 harness_lease_acquire clock 1 "$tmp/a.tsv"
[[ $(grep -c '^flock$' "$tmp/seam.log") == 2 ]] || fail 'monotonic attempt count'
rm "$clock_go" && wait "$clock_holder" || fail 'clock holder release'
inventory_empty || fail 'clock inventory'
reset_state
invoke 'unpublish seed' 0 token harness_lease_acquire io 0 "$tmp/a.tsv"
unpublish_token=$LAST_TOKEN
ASSURANCE_FAULT=unpublish invoke 'I/O unpublish' 2 error2 harness_lease_release "$unpublish_token"
[[ -f $state/active-$unpublish_token ]] || fail 'unpublish failure retained active'
source "$provider"
invoke 'unpublish cleanup' 0 empty harness_lease_release "$unpublish_token"
inventory_empty || fail 'unpublish inventory'
reset_state
source "$copy"
invoke 'unlink seed' 0 token harness_lease_acquire io 0 "$tmp/a.tsv"
unlink_token=$LAST_TOKEN
ASSURANCE_FAULT='unlink' invoke 'I/O unlink' 2 error2 harness_lease_release "$unlink_token"
[[ -f $state/.trash-$unlink_token && ! -e $state/active-$unlink_token ]] || fail 'unlink tombstone'
source "$provider"
invoke 'tombstone recovery acquire' 0 token harness_lease_acquire recovery 0 "$tmp/b.tsv"
recovery=$LAST_TOKEN
[[ ! -e $state/.trash-$unlink_token ]] || fail 'tombstone recovery cleanup'
invoke 'tombstone recovery release' 0 empty harness_lease_release "$recovery"
inventory_empty || fail 'final inventory'
if [[ -z ${HARNESS_ASSURANCE_MUTANT_CHILD-} ]]; then
  for kind in overlap unpublish bundle adapter; do
    mutant=$tmp/provider-mutant-$kind.sh
    case $kind in
      overlap) sed 's/if occupied & keys:/if False:/' "$provider" >"$mutant" ;;
      unpublish) sed 's/test_seam("unpublish"); //' "$provider" >"$mutant" ;;
      bundle) sed '/canonical, digest, wanted = normalize(request_path, pwd)/a\    canonical, digest, wanted = normalize_bytes(canonical.splitlines(True)[0], "", stored=True)' "$provider" >"$mutant" ;;
      adapter) cp "$provider" "$mutant" ;;
    esac
    HARNESS_ASSURANCE_MUTANT_CHILD=$kind HARNESS_ASSURANCE_SURFACE_CHILD=1 HARNESS_ASSURANCE_PROVIDER=$mutant \
      bash "$0" >"$tmp/mutant.out" 2>"$tmp/mutant.err" && fail "$kind mutant survived"
    grep -q '^FAIL ' "$tmp/mutant.err" || fail "$kind mutant oracle"
  done
fi
pass
