#!/usr/bin/env bash
set -u

fail() {
  printf '%s\n' "error: $1" >&2
  exit 2
}

[[ $# -ge 4 && $3 == -- ]] || fail 'usage: run-command.sh <class> <none|workspace-build|android-device|android-cvd> -- <command...>'
class=$1
resource=$2
shift 3
[[ -n ${1-} ]] || fail 'command is required'

session=${HARNESS_SESSION_ID-}
wait_seconds=${HARNESS_LEASE_WAIT_SECONDS-0}
instance=${ANDROID_INSTANCE_ID-}
safe='^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$'
[[ $session =~ $safe ]] || fail 'HARNESS_SESSION_ID must be a safe explicit identifier'
[[ $wait_seconds =~ ^(0|[1-9][0-9]{0,2})$ && $wait_seconds -le 300 ]] || fail 'HARNESS_LEASE_WAIT_SECONDS must be 0..300'

case $class in
  query) timeout=${HARNESS_COMMAND_QUERY_TIMEOUT_SECONDS-30} ;;
  mutate) timeout=${HARNESS_COMMAND_MUTATE_TIMEOUT_SECONDS-120} ;;
  reconnect) timeout=${HARNESS_COMMAND_RECONNECT_TIMEOUT_SECONDS-30} ;;
  build) timeout=${HARNESS_COMMAND_BUILD_TIMEOUT_SECONDS-7200} ;;
  cvd) timeout=${HARNESS_COMMAND_CVD_TIMEOUT_SECONDS-600} ;;
  *) fail 'invalid command class' ;;
esac
[[ $timeout =~ ^[1-9][0-9]{0,4}$ && $timeout -le 86400 ]] || fail 'command timeout must be 1..86400'

here=$(CDPATH='' cd -- "${BASH_SOURCE[0]%/*}" && pwd -P) || fail 'cannot resolve runtime directory'
runtime=$here/../lib/command-runtime.sh
[[ -f $runtime && ! -L $runtime ]] || fail 'command runtime is unavailable'
# shellcheck source=/dev/null
source "$runtime" || fail 'command runtime failed to load'

request=-
tmp=''
cleanup() {
  local rc=0
  [[ -z $tmp ]] || command rm -rf -- "$tmp" || rc=1
  return "$rc"
}
if [[ $resource != none ]]; then
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/aosp-harness-command-request.XXXXXX") || fail 'cannot create lease request'
  chmod 700 "$tmp" || {
    cleanup
    fail 'cannot secure lease request'
  }
  request=$tmp/request.tsv
  case $resource in
    workspace-build) printf 'workspace\t%s\tbuild\n' "$(pwd -P)" >"$request" || {
      cleanup
      fail 'cannot write lease request'
    } ;;
    android-device | android-cvd)
      [[ $instance =~ $safe ]] || {
        cleanup
        fail 'ANDROID_INSTANCE_ID must be a safe explicit identifier'
      }
      mode=${resource#android-}
      printf 'android\t%s\t%s\n' "$instance" "$mode" >"$request" || {
        cleanup
        fail 'cannot write lease request'
      }
      ;;
    *)
      cleanup
      fail 'invalid resource kind'
      ;;
  esac
  chmod 600 "$request" || {
    cleanup
    fail 'cannot secure lease request'
  }
fi

harness_command_run "$class" "$timeout" "$session" "$wait_seconds" "$request" -- "$@"
rc=$?
cleanup || [[ $rc -ne 0 ]] || rc=2
exit "$rc"
