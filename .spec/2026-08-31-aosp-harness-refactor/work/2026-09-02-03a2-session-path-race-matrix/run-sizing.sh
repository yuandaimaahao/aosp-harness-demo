#!/usr/bin/env bash
# THROWAWAY CONTROLLER: execute the 03a2 sizing/contract evidence matrix.
set -euo pipefail

WORK_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO=$(cd -- "$WORK_DIR/../../../.." && pwd -P)
ENTRY="$WORK_DIR/prototype/tests/test-session-path-races.sh"
FIXTURES="$WORK_DIR/prototype/fixtures"
TOOLS=${HARNESS_SIZING_TOOLS:-$WORK_DIR/tools}
TMP_RUN=$(mktemp -d "${TMPDIR:-/tmp}/03a2-sizing.XXXXXX")
trap 'rm -rf -- "$TMP_RUN"' EXIT
EXPECTED="$TMP_RUN/entry.expected"
PRIVATE_EXPECTED="$TMP_RUN/private.expected"
PROTOCOL_EXPECTED="$TMP_RUN/protocol.expected"
printf 'RESULT PASS  session path race assurance\n' >"$EXPECTED"
printf 'RESULT PASS  session path race driver\n' >"$PRIVATE_EXPECTED"
printf 'session-path-race-driver-v1\n' >"$PROTOCOL_EXPECTED"
mkdir -p "$TMP_RUN/results"

die() {
  printf 'FAIL evidence: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS %-34s %s\n' "$1" "$2"
}

make_root() {
  local name=$1 root="$TMP_RUN/roots/$1"
  mkdir -p "$root/tests/lib" "$root/common/.harness/lib"
  cp "$ENTRY" "$root/tests/test-session-path-races.sh"
  cp "$REPO/tests/lib/session-path-race-driver.py" "$root/tests/lib/session-path-race-driver.py"
  cp "$REPO/common/.harness/lib/session-state-foundation.sh" "$root/common/.harness/lib/session-state-foundation.sh"
  cp "$REPO/common/.harness/lib/session-state-path.sh" "$root/common/.harness/lib/session-state-path.sh"
  printf '%s\n' "$root"
}

run_entry() {
  local root=$1 label=$2
  shift 2
  ENTRY_OUT="$TMP_RUN/results/$label.out"
  ENTRY_ERR="$TMP_RUN/results/$label.err"
  set +e
  bash "$root/tests/test-session-path-races.sh" "$@" >"$ENTRY_OUT" 2>"$ENTRY_ERR"
  ENTRY_RC=$?
  set -e
}

expect_pass() {
  local root=$1 label=$2
  shift 2
  run_entry "$root" "$label" "$@"
  [[ $ENTRY_RC == 0 && ! -s $ENTRY_ERR ]] || die "$label rc=$ENTRY_RC stderr=$(wc -c <"$ENTRY_ERR")"
  cmp -s "$ENTRY_OUT" "$EXPECTED" || die "$label summary bytes"
  pass "$label" "rc0 stdout41 stderr0"
}

expect_fail() {
  local root=$1 label=$2
  shift 2
  run_entry "$root" "$label" "$@"
  [[ $ENTRY_RC == 1 && ! -s $ENTRY_OUT ]] || die "$label rc=$ENTRY_RC stdout=$(wc -c <"$ENTRY_OUT")"
  ! grep -Fq 'RESULT PASS' "$ENTRY_OUT" || die "$label printed PASS"
  pass "$label" "rc1 stdout0 no-PASS"
}

real_root=$(make_root dependency-present)
expect_pass "$real_root" default-37
expect_pass "$real_root" explicit-all all
cmp -s "$TMP_RUN/results/default-37.out" "$TMP_RUN/results/explicit-all.out" || die 'default/all mismatch'
pass default-all-identical 'byte-identical summaries; real driver enforces 37/37 ordered log'

fake_root=$(make_root fake-argv)
cp "$FIXTURES/fake-driver.py" "$fake_root/tests/lib/session-path-race-driver.py"
fake_log="$TMP_RUN/fake-driver.argv"
export FAKE_DRIVER_ARGV_LOG=$fake_log
expect_pass "$fake_root" fake-exact-argv
unset FAKE_DRIVER_ARGV_LOG
mapfile -t fake_calls <"$fake_log"
[[ ${#fake_calls[@]} == 2 && ${fake_calls[0]} == protocol ]] || die 'fake driver call count/protocol'
IFS=$'\t' read -r fake_mode fake_foundation fake_provider fake_workspace fake_tsv fake_case_log <<<"${fake_calls[1]}"
[[ $fake_mode == run-matrix && $fake_foundation == "$fake_root/common/.harness/lib/session-state-foundation.sh" ]] || die 'fake run-matrix foundation argv'
[[ $fake_provider == "$fake_root/common/.harness/lib/session-state-path.sh" && $fake_workspace == /* ]] || die 'fake run-matrix provider/workspace argv'
[[ $fake_tsv == /* && $fake_case_log == "$fake_workspace/cases.log" ]] || die 'fake run-matrix TSV/log argv'
! grep -Fq self-test "$fake_log" || die 'entrypoint called self-test'
pass fake-argv-sequence 'exact protocol,run-matrix; self-test count 0'

matrix_root=$(make_root matrix-damage-provider-absent)
cp "$FIXTURES/fake-driver.py" "$matrix_root/tests/lib/session-path-race-driver.py"
rm -f -- "$matrix_root/common/.harness/lib/session-state-path.sh"
matrix_log="$TMP_RUN/matrix-damage.argv"
export HARNESS_TEST_MATRIX_DAMAGE=duplicate FAKE_DRIVER_ARGV_LOG=$matrix_log
expect_fail "$matrix_root" matrix-before-provider
unset HARNESS_TEST_MATRIX_DAMAGE FAKE_DRIVER_ARGV_LOG
[[ ! -e $matrix_log || ! -s $matrix_log ]] || die 'matrix damage read driver before failure'
pass matrix-priority 'duplicate rejected before absent provider/driver access'

provider_absent=$(make_root provider-absent)
cp "$FIXTURES/fake-driver.py" "$provider_absent/tests/lib/session-path-race-driver.py"
rm -f -- "$provider_absent/common/.harness/lib/session-state-path.sh"
provider_absent_log="$TMP_RUN/provider-absent.argv"
export FAKE_DRIVER_ARGV_LOG=$provider_absent_log
expect_pass "$provider_absent" provider-absent
unset FAKE_DRIVER_ARGV_LOG
[[ ! -e $provider_absent_log || ! -s $provider_absent_log ]] || die 'provider absent touched driver'
pass provider-absent-zero 'inert surface PASS; driver calls 0'

anchors=(HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN HARNESS_TEST_MARKER_EXPECTED_EUID HARNESS_TEST_MARKER_OS_ERROR)
for anchor in "${anchors[@]}"; do
  for mutation in missing duplicate; do
    for downstream in foundation-absent core-unavailable flag; do
      label="anchor-${anchor##*_}-$mutation-$downstream"
      root=$(make_root "$label")
      if [[ $mutation == missing ]]; then
        sed -i "s/$anchor/BROKEN_ANCHOR_${anchor##*_}/" "$root/common/.harness/lib/session-state-path.sh"
      else
        printf '\n# %s\n' "$anchor" >>"$root/common/.harness/lib/session-state-path.sh"
      fi
      args=()
      case $downstream in
        foundation-absent) rm -f -- "$root/common/.harness/lib/session-state-foundation.sh" ;;
        core-unavailable) printf '# core-unavailable fixture\n' >"$root/common/.harness/lib/session-state-foundation.sh" ;;
        flag) args=(--dependency-absent) ;;
      esac
      expect_fail "$root" "$label" "${args[@]}"
    done
  done
done
pass anchor-cross-product '3 anchors x missing/duplicate x 3 downstream states = 18 fail-closed'

driver_absent=$(make_root driver-absent)
rm -f -- "$driver_absent/tests/lib/session-path-race-driver.py"
expect_pass "$driver_absent" driver-absent

driver_symlink=$(make_root driver-symlink)
rm -f -- "$driver_symlink/tests/lib/session-path-race-driver.py"
ln -s "$REPO/tests/lib/session-path-race-driver.py" "$driver_symlink/tests/lib/session-path-race-driver.py"
expect_fail "$driver_symlink" driver-symlink

driver_directory=$(make_root driver-directory)
rm -f -- "$driver_directory/tests/lib/session-path-race-driver.py"
mkdir "$driver_directory/tests/lib/session-path-race-driver.py"
expect_fail "$driver_directory" driver-directory

for variant in protocol-mismatch protocol-rc protocol-stderr syntax-error; do
  root=$(make_root "driver-$variant")
  cp "$FIXTURES/$variant.py" "$root/tests/lib/session-path-race-driver.py"
  expect_fail "$root" "driver-$variant"
done

for mode in run-rc run-stderr run-summary log-duplicate; do
  root=$(make_root "driver-$mode")
  cp "$FIXTURES/fake-driver.py" "$root/tests/lib/session-path-race-driver.py"
  export FAKE_DRIVER_MODE=$mode
  expect_fail "$root" "driver-$mode"
  unset FAKE_DRIVER_MODE
done
pass driver-damage-matrix 'absent inert; symlink/directory/protocol/syntax/rc/stderr/result/log fail closed'

for inert_mode in foundation-absent core-unavailable flag; do
  root=$(make_root "inert-$inert_mode")
  cp "$FIXTURES/fake-driver.py" "$root/tests/lib/session-path-race-driver.py"
  inert_log="$TMP_RUN/inert-$inert_mode.argv"
  export FAKE_DRIVER_ARGV_LOG=$inert_log
  args=()
  case $inert_mode in
    foundation-absent) rm -f -- "$root/common/.harness/lib/session-state-foundation.sh" ;;
    core-unavailable) printf '# core-unavailable fixture\n' >"$root/common/.harness/lib/session-state-foundation.sh" ;;
    flag) args=(--dependency-absent) ;;
  esac
  expect_pass "$root" "inert-$inert_mode" "${args[@]}"
  unset FAKE_DRIVER_ARGV_LOG
  mapfile -t inert_calls <"$inert_log"
  [[ ${#inert_calls[@]} == 1 && ${inert_calls[0]} == protocol ]] || die "$inert_mode invoked race cases"
done
pass inert-zero-case 'foundation/core/flag: protocol once, run-matrix/self-test zero, surface oracle PASS'

expect_fail "$real_root" args-unknown unknown
expect_fail "$real_root" args-extra all extra
expect_fail "$real_root" args-flag-value --dependency-absent value
pass argument-protocol 'unknown/extra/flag-value rc1; no PASS'

PATH="$TOOLS:$PATH"
[[ $(shfmt --version) == v3.14.0 ]] || die 'shfmt version'
[[ $(shellcheck --version | awk '/^version:/ {print $2}') == 0.11.0 ]] || die 'ShellCheck version'
shfmt -d -i 2 -ci -bn "$ENTRY" >"$TMP_RUN/shfmt.diff"
shellcheck -x --severity=warning "$ENTRY" >"$TMP_RUN/shellcheck.out" 2>"$TMP_RUN/shellcheck.err"
bash -n "$ENTRY"
[[ ! -s $TMP_RUN/shfmt.diff && ! -s $TMP_RUN/shellcheck.out && ! -s $TMP_RUN/shellcheck.err ]] || die 'fixed shell tools emitted output'
pass pinned-tools 'shfmt v3.14.0; ShellCheck 0.11.0; exact argv/file; bash -n'

physical_lines=$(wc -l <"$ENTRY")
[[ $physical_lines -le 400 ]] || die "entrypoint LOC $physical_lines"
pass sizing "entrypoint physical LOC $physical_lines/400"

candidate="$TMP_RUN/candidate-source"
git clone --no-local "$REPO" "$candidate" >"$TMP_RUN/candidate-clone.log" 2>&1
cp "$ENTRY" "$candidate/tests/test-session-path-races.sh"
git -C "$candidate" add tests/test-session-path-races.sh
git -C "$candidate" -c user.name='03a2 prototype' -c user.email='prototype@example.invalid' commit -m 'test(session): stage race matrix prototype' >"$TMP_RUN/candidate-commit.log"
[[ $(git -C "$candidate" diff-tree --no-commit-id --name-only -r HEAD) == tests/test-session-path-races.sh ]] || die 'candidate exact file'
candidate_numstat=$(git -C "$candidate" diff-tree --no-commit-id --numstat -r HEAD | awk '{sum += $1 + $2} END {print sum + 0}')
[[ $candidate_numstat -le 400 ]] || die "candidate numstat $candidate_numstat"
pass candidate-diff "exact1; numstat $candidate_numstat/400"

verify_checkout() {
  local kind=$1 checkout=$2 before after
  before=$(sha256sum "$checkout/common/.harness/lib/session-state-path.sh" "$checkout/tests/lib/session-path-race-driver.py")
  python3 "$checkout/tests/lib/session-path-race-driver.py" protocol >"$TMP_RUN/$kind.protocol" 2>"$TMP_RUN/$kind.protocol.err"
  cmp -s "$TMP_RUN/$kind.protocol" "$PROTOCOL_EXPECTED" && [[ ! -s $TMP_RUN/$kind.protocol.err ]] || die "$kind protocol"
  python3 "$checkout/tests/lib/session-path-race-driver.py" self-test \
    "$checkout/common/.harness/lib/session-state-foundation.sh" \
    "$checkout/common/.harness/lib/session-state-path.sh" >"$TMP_RUN/$kind.selftest" 2>"$TMP_RUN/$kind.selftest.err"
  cmp -s "$TMP_RUN/$kind.selftest" "$PRIVATE_EXPECTED" && [[ ! -s $TMP_RUN/$kind.selftest.err ]] || die "$kind self-test"
  bash "$checkout/tests/test-session-path-races.sh" >"$TMP_RUN/$kind.direct" 2>"$TMP_RUN/$kind.direct.err"
  cmp -s "$TMP_RUN/$kind.direct" "$EXPECTED" && [[ ! -s $TMP_RUN/$kind.direct.err ]] || die "$kind direct"
  (cd "$checkout" && bash ./scripts/check.sh --offline) >"$TMP_RUN/$kind.offline" 2>"$TMP_RUN/$kind.offline.err"
  [[ ! -s $TMP_RUN/$kind.offline.err ]] || die "$kind offline stderr"
  [[ $(grep -Fxc 'RESULT PASS  session path race assurance' "$TMP_RUN/$kind.offline") == 1 ]] || die "$kind offline discovery"
  grep -Fqx 'RESULT PASS  aosp-harness offline quality gate' "$TMP_RUN/$kind.offline" || die "$kind offline summary"
  after=$(sha256sum "$checkout/common/.harness/lib/session-state-path.sh" "$checkout/tests/lib/session-path-race-driver.py")
  [[ $after == "$before" ]] || die "$kind dependency SHA changed"
  [[ -z $(git -C "$checkout" status --porcelain) ]] || die "$kind checkout dirty"
  pass "$kind-checkout" 'protocol28/selftest38/direct41; offline discovered once; SHA stable; clean'
}

full="$TMP_RUN/full"
depth="$TMP_RUN/depth1"
git clone --no-local "$candidate" "$full" >"$TMP_RUN/full-clone.log" 2>&1
git clone --depth 1 "file://$candidate" "$depth" >"$TMP_RUN/depth-clone.log" 2>&1
verify_checkout full "$full"
verify_checkout depth1 "$depth"
[[ $(git -C "$depth" rev-list --count HEAD) == 1 && -s $depth/.git/shallow ]] || die 'depth-1 proof'
pass depth1-proof "commit-count 1; shallow-bytes $(wc -c <"$depth/.git/shallow"); no historical SHA query"

rollback="$TMP_RUN/rollback"
git clone --no-local "$candidate" "$rollback" >"$TMP_RUN/rollback-clone.log" 2>&1
git -C "$rollback" rm tests/test-session-path-races.sh >"$TMP_RUN/rollback-rm.log"
git -C "$rollback" -c user.name='03a2 prototype' -c user.email='prototype@example.invalid' commit -m 'revert: remove race matrix prototype' >"$TMP_RUN/rollback-commit.log"
python3 "$rollback/tests/lib/session-path-race-driver.py" self-test \
  "$rollback/common/.harness/lib/session-state-foundation.sh" \
  "$rollback/common/.harness/lib/session-state-path.sh" >"$TMP_RUN/rollback.selftest" 2>"$TMP_RUN/rollback.selftest.err"
cmp -s "$TMP_RUN/rollback.selftest" "$PRIVATE_EXPECTED" && [[ ! -s $TMP_RUN/rollback.selftest.err ]] || die 'rollback self-test'
(cd "$rollback" && bash ./scripts/check.sh --offline) >"$TMP_RUN/rollback.offline" 2>"$TMP_RUN/rollback.offline.err"
[[ ! -s $TMP_RUN/rollback.offline.err ]] || die 'rollback offline stderr'
grep -Fqx 'RESULT PASS  aosp-harness offline quality gate' "$TMP_RUN/rollback.offline" || die 'rollback offline'
[[ $(find "$rollback/tests" -maxdepth 1 -type f -name 'test-session-path-races.sh' | wc -l) == 0 ]] || die 'rollback discovery count'
[[ $(grep -Fxc 'RESULT PASS  session path race assurance' "$TMP_RUN/rollback.offline" || :) == 0 ]] || die 'rollback race summary present'
[[ ! -e $rollback/common/.harness/lib/session-state-snapshot.sh && ! -e $rollback/tests/test-session-snapshot.sh ]] || die 'rollback unexpectedly needs 03b'
[[ -z $(git -C "$rollback" status --porcelain) ]] || die 'rollback checkout dirty'
pass independent-rollback 'delete exact entrypoint; driver selftest38/offline PASS; discovery0; 03b absent; clean'

git -C "$REPO" diff --check
pass repository-integrity 'git diff --check rc0; production/spec/STATE/ledger not written by runner'
printf 'RESULT PASS  03a2 sizing prototype\n'
