#!/usr/bin/env bash
# Throwaway sizing skeleton: every counted case executes a real oracle.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo=$(cd -- "$here/../../../../.." && pwd -P)
foundation=$repo/common/.harness/lib/session-state-foundation.sh
provider=$here/session-state-path.sh
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
fail() { printf 'prototype failure: %s\n' "$*" >&2; exit 1; }
passed=0

capture() {
  local tag=$1; shift
  set +e
  "$@" >"$tmp/$tag.out" 2>"$tmp/$tag.err"
  rc=$?
  set -e
}

expect() {
  local tag=$1 expected_rc=$2 stdout=$3 stderr=$4
  [[ $rc == "$expected_rc" ]] || fail "$tag rc=$rc expected=$expected_rc"
  cmp -s "$tmp/$tag.out" <(printf %s "$stdout") || fail "$tag stdout"
  cmp -s "$tmp/$tag.err" <(printf %s "$stderr") || fail "$tag stderr"
  ((passed += 1))
}

invoke() {
  local tag=$1 copy=$2 root=$3; shift 3
  capture "$tag" env -u XDG_RUNTIME_DIR -u TMPDIR HARNESS_STATE_ROOT="$root" \
    bash -c 'source "$1"; source "$2"; shift 2; _harness_session_path_core "$@"' _ \
    "$foundation" "$copy" "$@"
}

copy_provider() {
  cp "$provider" "$1"
  for marker in MANAGED_BEFORE_OPEN EXPECTED_EUID OS_ERROR; do
    [[ $(grep -c "HARNESS_TEST_MARKER_$marker" "$1") == 1 ]] || fail "$marker count"
  done
}

replace_once() {
  local file=$1 needle=$2 replacement=$3
  [[ $(grep -F -c -- "$needle" "$file") == 1 ]] || fail "needle count"
  python3 - "$file" "$needle" "$replacement" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
if text.count(sys.argv[2]) != 1:
    raise SystemExit(1)
path.write_text(text.replace(sys.argv[2], sys.argv[3]))
PY
  [[ $(grep -F -c -- "$replacement" "$file") == 1 ]] || fail "replacement count"
}

assert_safe_tree() {
  local path
  for path in "$@"; do
    [[ -d $path && ! -L $path && $(stat -c %u:%a "$path") == "$(id -u):700" ]] || fail "unsafe tree $path"
  done
}

# Source present and each missing dependency are executed in isolated shells.
capture source-present bash -c 'source "$1"; source "$2"; declare -F _harness_session_path_core >/dev/null' _ "$foundation" "$provider"
expect source-present 0 '' ''
for missing in harness_validate_feature_name _harness_session_state_foundation_path _harness_session_state_run; do
  capture "missing-$missing" bash -c 'source "$1"; unset -f "$3"; source "$2"; ! declare -F _harness_session_path_core >/dev/null' _ "$foundation" "$provider" "$missing"
  expect "missing-$missing" 0 '' ''
done

# Exact arity and validation fail before Python.
for spec in 'arity0|' 'arity1|one' 'arity3|one two three' 'bad-project|../bad ok' 'bad-session|ok ../bad'; do
  tag=${spec%%|*}; read -r -a args <<<"${spec#*|}"
  invoke "$tag" "$provider" "$tmp/$tag/state" "${args[@]}"
  expect "$tag" 2 '' $'error: unsafe session state\n'
done
mkdir "$tmp/fake-bin"
printf '#!/usr/bin/env bash\nprintf called >>%q\n' "$tmp/python-called" >"$tmp/fake-bin/python3"
chmod +x "$tmp/fake-bin/python3"
capture validate-wrapper env PATH="$tmp/fake-bin:$PATH" bash -c '
  source "$1"; calls=$4; harness_validate_feature_name() { printf "%s\n" "$1" >>"$calls"; [[ $1 != reject ]]; }; source "$2"
  _harness_session_path_core project reject' _ "$foundation" "$provider" "$tmp/unused" "$tmp/validate-calls"
expect validate-wrapper 2 '' $'error: unsafe session state\n'
[[ ! -e $tmp/python-called && $(cat "$tmp/validate-calls") == $'project\nreject' ]] || fail 'validate fail-fast'

# Four roots plus physical symlink parent and two-project/two-session isolation.
mkdir "$tmp/harness" "$tmp/xdg" "$tmp/tmpdir" "$tmp/physical"
ln -s "$tmp/physical" "$tmp/logical"
invoke root-harness "$provider" "$tmp/harness/state" p s
expect root-harness 0 "$tmp/harness/state/p/s"$'\n' ''
capture root-xdg env -u HARNESS_STATE_ROOT -u TMPDIR XDG_RUNTIME_DIR="$tmp/xdg" bash -c 'source "$1"; source "$2"; _harness_session_path_core p s' _ "$foundation" "$provider"
expect root-xdg 0 "$tmp/xdg/aosp-harness-$(id -u)/p/s"$'\n' ''
capture root-tmp env -u HARNESS_STATE_ROOT -u XDG_RUNTIME_DIR TMPDIR="$tmp/tmpdir" bash -c 'source "$1"; source "$2"; _harness_session_path_core p s' _ "$foundation" "$provider"
expect root-tmp 0 "$tmp/tmpdir/aosp-harness-$(id -u)/p/s"$'\n' ''
default_project=prototype-default-$$
capture root-default env -u HARNESS_STATE_ROOT -u XDG_RUNTIME_DIR -u TMPDIR bash -c 'source "$1"; source "$2"; _harness_session_path_core "$3" s' _ "$foundation" "$provider" "$default_project"
expect root-default 0 "/tmp/aosp-harness-$(id -u)/$default_project/s"$'\n' ''
rmdir "/tmp/aosp-harness-$(id -u)/$default_project/s" "/tmp/aosp-harness-$(id -u)/$default_project"
invoke root-physical "$provider" "$tmp/logical/state" p s
expect root-physical 0 "$tmp/physical/state/p/s"$'\n' ''
for value in '' relative "$tmp/../escape"; do
  capture dangerous-root env HARNESS_STATE_ROOT="$value" bash -c 'source "$1"; source "$2"; _harness_session_path_core p s' _ "$foundation" "$provider"
  expect dangerous-root 2 '' $'error: unsafe session state\n'
done
mkdir "$tmp/isolation"
for project in p1 p2; do for session in s1 s2; do invoke iso "$provider" "$tmp/isolation/state" "$project" "$session"; expect iso 0 "$tmp/isolation/state/$project/$session"$'\n' ''; done; done
assert_safe_tree "$tmp/isolation/state" "$tmp/isolation/state/p1" "$tmp/isolation/state/p2" "$tmp/isolation/state/p1/s1" "$tmp/isolation/state/p1/s2" "$tmp/isolation/state/p2/s1" "$tmp/isolation/state/p2/s2"

# Three layers x symlink/file/wrong-mode are real static attacks.
for kind in symlink file mode; do
  for layer in root project session; do
    base=$tmp/static-$kind-$layer; mkdir -p "$base"
    root=$base/state; target=$root
    [[ $layer == root ]] || { mkdir -m 700 "$root"; target=$root/project; }
    [[ $layer != session ]] || { mkdir -m 700 "$target"; target=$target/session; }
    case $kind in symlink) mkdir "$base/victim"; ln -s "$base/victim" "$target";; file) : >"$target";; mode) mkdir -m 755 "$target";; esac
    invoke static "$provider" "$root" project session
    expect static 2 '' $'error: unsafe session state\n'
  done
done

# Root-level load-bearing mutations; 03a1 repeats the driver at project/session.
managed='    pass  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN'
catch_line='            pass  # provider-copy catch sentinel is injected here'
for kind in dir link file; do
  base=$tmp/swap-$kind; mkdir "$base"; mkdir -m 700 "$base/state"
  copy=$base/provider.sh; copy_provider "$copy"; sentinel=$base/hit
  case $kind in
    dir) action="os.rename(name, name+'.old', src_dir_fd=parent_fd, dst_dir_fd=parent_fd); os.mkdir(name, 0o700, dir_fd=parent_fd)";;
    link) action="os.rename(name, name+'.old', src_dir_fd=parent_fd, dst_dir_fd=parent_fd); os.symlink('state.old', name, dir_fd=parent_fd)";;
    file) action="os.rename(name, name+'.old', src_dir_fd=parent_fd, dst_dir_fd=parent_fd); os.close(os.open(name, os.O_CREAT|os.O_WRONLY, 0o600, dir_fd=parent_fd))";;
  esac
  replace_once "$copy" "$managed" "    if phase == 'before_open' and name == 'state': $action; pathlib.Path('$sentinel').touch()  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN"
  invoke swap "$copy" "$base/state" project session
  expect swap 2 '' $'error: unsafe session state\n'; [[ -e $sentinel ]] || fail 'swap sentinel'
done

for kind in safe unsafe disappear; do
  base=$tmp/eexist-$kind; mkdir "$base"; copy=$base/provider.sh; copy_provider "$copy"; sentinel=$base/hit; caught=$base/caught
  if [[ $kind == disappear ]]; then
    action="if name == 'state': (os.mkdir(name, 0o700, dir_fd=parent_fd), pathlib.Path('$sentinel').touch()) if phase == 'before_mkdir' else (os.rmdir(name, dir_fd=parent_fd), pathlib.Path('$base/gone').touch()) if phase == 'after_eexist' else None"
  else
    action="if phase == 'before_mkdir' and name == 'state': os.mkdir(name, 0o700, dir_fd=parent_fd); pathlib.Path('$sentinel').touch()"
    [[ $kind == safe ]] || action="$action; os.chmod(name, 0o755, dir_fd=parent_fd)"
  fi
  replace_once "$copy" "$managed" "    $action  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN"
  replace_once "$copy" "$catch_line" "            pathlib.Path('$caught').touch()  # provider-copy catch sentinel is injected here"
  invoke eexist "$copy" "$base/state" project session
  case $kind in safe) expected=0; out="$base/state/project/session"$'\n'; err='';; unsafe) expected=2; out=''; err=$'error: unsafe session state\n';; disappear) expected=1; out=''; err=$'error: session state operation failed\n';; esac
  expect eexist "$expected" "$out" "$err"; [[ -e $sentinel && -e $caught ]] || fail 'eexist sentinel'
done

base=$tmp/mkdir-replace; mkdir "$base"; copy=$base/provider.sh; copy_provider "$copy"; sentinel=$base/hit
replace_once "$copy" "$managed" "    if phase == 'before_open' and name == 'state' and made: os.rename(name, name+'.old', src_dir_fd=parent_fd, dst_dir_fd=parent_fd); os.mkdir(name, 0o700, dir_fd=parent_fd); os.chmod(name, 0o755, dir_fd=parent_fd); pathlib.Path('$sentinel').touch()  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN"
invoke mkdir-replace "$copy" "$base/state" project session
expect mkdir-replace 2 '' $'error: unsafe session state\n'; [[ $(stat -c %a "$base/state") == 755 && -e $sentinel ]] || fail 'replacement modified'

for kind in owner eio; do
  base=$tmp/$kind; mkdir "$base"; copy=$base/provider.sh; copy_provider "$copy"
  if [[ $kind == owner ]]; then
    replace_once "$copy" '    expected_euid = os.geteuid()  # HARNESS_TEST_MARKER_EXPECTED_EUID' "    expected_euid = os.geteuid() + (name == 'state'); pathlib.Path('$base/hit').touch()  # HARNESS_TEST_MARKER_EXPECTED_EUID"
    expected=2; err=$'error: unsafe session state\n'
  else
    replace_once "$copy" '        pass  # HARNESS_TEST_MARKER_OS_ERROR' '        raise OSError(errno.EIO)  # HARNESS_TEST_MARKER_OS_ERROR'
    expected=1; err=$'error: session state operation failed\n'
  fi
  invoke "$kind" "$copy" "$base/state" project session
  expect "$kind" "$expected" '' "$err"
  [[ $kind != owner || -e $base/hit ]] || fail 'owner sentinel'
done

for phase in before_mkdir after_eexist before_open; do grep -q "\"$phase\"" "$provider" || fail "phase $phase"; done
! grep -q fchmod "$provider" || fail 'forbidden fchmod'
printf 'PROTOTYPE PASS  session path sizing (%s executed cases)\n' "$passed"
