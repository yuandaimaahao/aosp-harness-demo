#!/usr/bin/env bash
# session-state-signals.sh -- private write signal-forwarding facade.
# Source guard: activates only when the 03b snapshot module already exports
# _harness_session_snapshot_worker, _harness_session_snapshot_write_core and
# _harness_session_snapshot_read_core; if any export is missing the module
# stays inert (source returns 0, both streams empty, nothing defined, no
# file I/O, no dependency redefined). When active it defines one private
# export, _harness_session_write_with_signals <project-id> <session-id>
# <feature>, which backgrounds the spawn-only worker and forwards
# HUP/INT/TERM to the single positive child PID: pending_signal latches the
# first signal, a spawn-gap signal is re-forwarded right after spawn, and a
# trap-broken wait is re-entered while the child lives. A latched
# HUP/INT/TERM returns exactly 129/130/143; otherwise the child exit code
# 0/1/2/3 passes through. Both streams stay empty; positive PID only.

if ! declare -F _harness_session_snapshot_worker >/dev/null \
  || ! declare -F _harness_session_snapshot_write_core >/dev/null \
  || ! declare -F _harness_session_snapshot_read_core >/dev/null; then
  return 0 2>/dev/null || exit 0
fi

_harness_session_write_with_signals() {
  local project_id=$1 session_id=$2 feature=$3
  local pending_signal='' child_pid='' child_rc=''
  trap '[[ -n $pending_signal ]] || { pending_signal=HUP; [[ -n $child_pid ]] && kill -HUP "$child_pid" 2>/dev/null; }' HUP
  trap '[[ -n $pending_signal ]] || { pending_signal=INT; [[ -n $child_pid ]] && kill -INT "$child_pid" 2>/dev/null; }' INT
  trap '[[ -n $pending_signal ]] || { pending_signal=TERM; [[ -n $child_pid ]] && kill -TERM "$child_pid" 2>/dev/null; }' TERM
  : # HARNESS_TEST_MARKER_SIGNALS_BEFORE_SPAWN
  _harness_session_snapshot_worker write "$project_id" "$session_id" "$feature" &
  child_pid=$!
  [[ -n $pending_signal ]] && kill -"$pending_signal" "$child_pid" 2>/dev/null
  while :; do
    wait "$child_pid"
    child_rc=$?
    ((child_rc > 128)) && kill -0 "$child_pid" 2>/dev/null || break
  done
  : # HARNESS_TEST_MARKER_SIGNALS_AFTER_WAIT
  trap - HUP INT TERM
  case $pending_signal in
    HUP) return 129 ;;
    INT) return 130 ;;
    TERM) return 143 ;;
  esac
  return "$child_rc"
}
