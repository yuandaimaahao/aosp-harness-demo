#!/usr/bin/env bash

if declare -F harness_validate_feature_name >/dev/null \
  && declare -F _harness_session_state_foundation_path >/dev/null \
  && declare -F _harness_session_state_run >/dev/null; then
  _harness_session_path_core() (
    if [[ $# != 2 ]] \
      || ! harness_validate_feature_name "$1" >/dev/null 2>&1 \
      || ! harness_validate_feature_name "$2" >/dev/null 2>&1; then
      printf '%s\n' 'error: unsafe session state' >&2
      return 2
    fi
    printf '%s\n' 'error: session state operation failed' >&2
    return 1
  )
fi
