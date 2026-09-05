#!/usr/bin/env bash
set -u
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
lib=$here/../common/.harness/lib/command-runtime.sh
repo=$(git -C "$here" rev-parse --show-toplevel)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
fail() {
  printf 'FAIL %s\n' "$*" >&2
  exit 1
}
run() {
  local want=$1 label=$2
  shift 2
  "$@" >"$tmp/out" 2>"$tmp/err"
  local rc=$?
  [[ $rc == "$want" ]] || fail "$label rc=$rc want=$want"
}

source_out=$tmp/source.out source_err=$tmp/source.err
bash -c 'before=$(declare -F | awk '\''$3~/^harness_/{print $3}'\''); source "$1"; after=$(declare -F | awk '\''$3~/^harness_/{print $3}'\''); comm -13 <(printf "%s\n" "$before"|sort) <(printf "%s\n" "$after"|sort)' _ "$lib" >"$source_out" 2>"$source_err"
[[ ! -s $source_err && $(cat "$source_out") == harness_command_run ]] || fail source
# shellcheck source=/dev/null
source "$lib"
run 2 invalid harness_command_run query 01 ok 0 - -- true
cmp -s "$tmp/err" <(printf 'error: invalid command runtime request\n') || fail invalid-bytes
run 2 empty harness_command_run query 1 ok 0 - -- ''
[[ ! -s $tmp/out ]] || fail empty-stdout

arg=$'a b\n*'
run 0 argv harness_command_run mutate 5 ok 0 - -- bash -c 'printf "%s" "$1"; printf raw >&2' _ "$arg"
cmp -s "$tmp/out" <(printf '%s' "$arg") || fail argv
tail -c 3 "$tmp/err" | cmp -s - <(printf raw) || fail raw-tail
grep -Eq '^runtime: class=mutate attempt=1/1 argc=5 argv0_len=4 argv0_hex=62617368 result=rc:0 elapsed_ms=[0-9]+$' "$tmp/err" || fail diag

for class in query reconnect mutate build cvd; do
  run 0 "$class" env HARNESS_COMMAND_QUERY_ATTEMPTS=1 HARNESS_COMMAND_RECONNECT_ATTEMPTS=1 bash -c 'source "$1"; harness_command_run "$2" 5 ok 0 - -- true' _ "$lib" "$class"
done
for class in query reconnect; do
  counter=$tmp/$class.count
  run 0 "$class-retry" env COUNTER="$counter" HARNESS_COMMAND_QUERY_ATTEMPTS=2 HARNESS_COMMAND_RECONNECT_ATTEMPTS=2 HARNESS_COMMAND_RETRY_DELAY_SECONDS=0 bash -c 'source "$1"; harness_command_run "$2" 5 ok 0 - -- bash -c '\''n=$(cat "$COUNTER" 2>/dev/null||echo 0); n=$((n+1)); echo "$n">"$COUNTER"; ((n==2))'\''' _ "$lib" "$class"
  [[ $(cat "$counter") == 2 && $(grep -c '^runtime:' "$tmp/err") == 2 ]] || fail "$class-retry-count"
done
for class in mutate build cvd; do
  counter=$tmp/$class.fail
  run 9 "$class-once" env COUNTER="$counter" bash -c 'source "$1"; harness_command_run "$2" 5 ok 0 - -- bash -c '\''echo x >>"$COUNTER"; exit 9'\''' _ "$lib" "$class"
  [[ $(wc -l <"$counter") == 1 ]] || fail "$class-once-count"
done

run 124 timeout harness_command_run mutate 1 ok 0 - -- bash -c 'trap "exit 0" TERM; sleep 5'
grep -q 'result=timeout' "$tmp/err" || fail timeout-result

mkdir -m 700 "$tmp/runtime-tmp"
export TMPDIR=$tmp/runtime-tmp
run 0 background env BGFILE="$tmp/bg.pid" bash -c 'source "$1"; harness_command_run mutate 5 ok 0 - -- bash -c '\''sleep 30 & echo $! >"$BGFILE"; exit 0'\''' _ "$lib"
bg=$(cat "$tmp/bg.pid")
kill -0 "$bg" 2>/dev/null && fail background-live
[[ -z $(find "$TMPDIR" -mindepth 1 -print -quit) ]] || fail runtime-temp-leak
unset TMPDIR

request=$tmp/request.tsv
printf 'android\tunit\tdevice\n' >"$request"
mkdir -p "$tmp/absent"
cp "$lib" "$tmp/absent/command-runtime.sh"
run 2 absent bash -c 'source "$1"; harness_command_run build 5 ok 0 "$2" -- true' _ "$tmp/absent/command-runtime.sh" "$request"
run 0 legacy env HARNESS_LEGACY_SINGLE_SESSION=1 bash -c 'source "$1"; harness_command_run build 5 ok 0 "$2" -- true' _ "$tmp/absent/command-runtime.sh" "$request"
head -n 1 "$tmp/err" | cmp -s - <(printf 'compat: lease-provider=legacy\n') || fail legacy

mkdir -p "$tmp/good/common/.harness/lib"
cp "$lib" "$tmp/good/common/.harness/lib/command-runtime.sh"
cp "$repo/common/.harness/lib/resource-leases.sh" "$tmp/good/common/.harness/lib/resource-leases.sh"
run 0 provider env HARNESS_RESOURCE_LEASE_ROOT="$tmp/leases" bash -c 'source "$1"; harness_command_run build 5 ok 0 "$2" -- true' _ "$tmp/good/common/.harness/lib/command-runtime.sh" "$request"
find "$tmp/leases" -name 'active-*' -print -quit | grep -q . && fail release
printf 'invalid\n' >"$tmp/invalid.tsv"
run 2 acquire env HARNESS_RESOURCE_LEASE_ROOT="$tmp/leases" bash -c 'source "$1"; harness_command_run build 5 ok 0 "$2" -- true' _ "$tmp/good/common/.harness/lib/command-runtime.sh" "$tmp/invalid.tsv"
cmp -s "$tmp/err" <(printf 'error: command runtime lease acquire\n') || fail acquire-error
(cd "$tmp/good/common/.harness/lib" && HARNESS_RESOURCE_LEASE_ROOT="$tmp/leases" bash -c 'source command-runtime.sh; harness_command_run build 5 ok 0 "$1" -- true' _ "$request") >/dev/null 2>"$tmp/basename.err" || fail basename-source
grep -q '^runtime: class=build attempt=1/1 ' "$tmp/basename.err" || fail basename-source-stderr
mkdir -p "$tmp/bad"
cp "$lib" "$tmp/bad/command-runtime.sh"
printf 'harness_lease_acquire(){ :; }\n' >"$tmp/bad/resource-leases.sh"
run 2 damaged bash -c 'source "$1"; harness_command_run build 5 ok 0 "$2" -- true' _ "$tmp/bad/command-runtime.sh" "$request"

cat >"$tmp/signal.sh" <<'SH'
source "$1"
trap 'printf original >"$MARK"' INT
trap -p HUP INT TERM >"$BEFORE"
printf '%s\n' "$$" >"$PIDFILE"
harness_command_run mutate 20 ok 0 - -- sleep 20
rc=$?
trap -p HUP INT TERM >"$AFTER"
[[ $rc == 130 && ! -e $MARK && -s $BEFORE ]] || exit 1
cmp -s "$BEFORE" "$AFTER"
SH
MARK=$tmp/handler BEFORE=$tmp/before AFTER=$tmp/after PIDFILE=$tmp/shell.pid python3 -c 'import os,signal,subprocess,sys,time
p=subprocess.Popen(["bash",sys.argv[1],sys.argv[2]],stdout=open(sys.argv[3],"wb"),stderr=open(sys.argv[4],"wb"))
for _ in range(1000):
 try:
  pid=int(open(os.environ["PIDFILE"]).read());break
 except (FileNotFoundError,ValueError):time.sleep(.01)
else:raise SystemExit(1)
time.sleep(.2);os.kill(pid,signal.SIGINT);raise SystemExit(p.wait())' "$tmp/signal.sh" "$lib" "$tmp/sig.out" "$tmp/sig.err" || fail signal-contract
[[ ! -s $tmp/sig.out && ! -e $tmp/handler ]] || fail signal-bytes
grep -q 'result=signal:2' "$tmp/sig.err" || fail signal-diag

rm -rf -- "$tmp"
trap - EXIT
printf 'RESULT PASS  command runtime\n'
