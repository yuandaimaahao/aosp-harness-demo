#!/usr/bin/env bash
# session-state.sh -- thin aggregator for the session-state provider.
# Guard: preflight verifies that the five module files (foundation, path,
# snapshot, signals, remove) next to this script (paths anchored at
# BASH_SOURCE) exist and are readable, then sources them in that only
# valid order, each with rc0, then name-checks the nine expected exports.
# Any missing or unreadable file, non-zero source, or missing export:
# silent rc1, both streams empty, no provider marker, none of the four
# public state APIs defined (missing-module state falls back to legacy).
# Only when every check passes does the single critical section below
# define the four one-line forwarding functions and set the provider
# marker; partial capability is physically impossible. No module
# internals are copied here.

# shellcheck disable=SC1090,SC2034
_harness_session_state_dir=${BASH_SOURCE[0]%/*}
[[ $_harness_session_state_dir != "${BASH_SOURCE[0]}" ]] || _harness_session_state_dir=.
if [[ -f $_harness_session_state_dir/session-state-foundation.sh && -r $_harness_session_state_dir/session-state-foundation.sh ]] \
  && [[ -f $_harness_session_state_dir/session-state-path.sh && -r $_harness_session_state_dir/session-state-path.sh ]] \
  && [[ -f $_harness_session_state_dir/session-state-snapshot.sh && -r $_harness_session_state_dir/session-state-snapshot.sh ]] \
  && [[ -f $_harness_session_state_dir/session-state-signals.sh && -r $_harness_session_state_dir/session-state-signals.sh ]] \
  && [[ -f $_harness_session_state_dir/session-state-remove.sh && -r $_harness_session_state_dir/session-state-remove.sh ]] \
  && source "$_harness_session_state_dir/session-state-foundation.sh" 2>/dev/null \
  && source "$_harness_session_state_dir/session-state-path.sh" 2>/dev/null \
  && source "$_harness_session_state_dir/session-state-snapshot.sh" 2>/dev/null \
  && source "$_harness_session_state_dir/session-state-signals.sh" 2>/dev/null \
  && source "$_harness_session_state_dir/session-state-remove.sh" 2>/dev/null \
  && declare -F harness_validate_feature_name >/dev/null \
  && declare -F _harness_session_state_run >/dev/null \
  && declare -F _harness_session_state_foundation_path >/dev/null \
  && declare -F _harness_session_path_core >/dev/null \
  && declare -F _harness_session_snapshot_worker >/dev/null \
  && declare -F _harness_session_snapshot_write_core >/dev/null \
  && declare -F _harness_session_snapshot_read_core >/dev/null \
  && declare -F _harness_session_write_with_signals >/dev/null \
  && declare -F _harness_session_remove_core >/dev/null; then
  unset _harness_session_state_dir
else
  unset _harness_session_state_dir
  return 1 2>/dev/null || exit 1
fi
harness_session_state_path() { _harness_session_path_core "$@"; }
harness_session_state_write() { _harness_session_write_with_signals "$@"; }
harness_session_state_read() { _harness_session_snapshot_read_core "$@"; }
harness_session_state_remove() { _harness_session_remove_core "$@"; }
HARNESS_SESSION_STATE_PROVIDER_VERSION=1
