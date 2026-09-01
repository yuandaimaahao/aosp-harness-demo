#!/usr/bin/env bash

# Return success only for one safe ASCII component.  This predicate is quiet so
# callers can map failures to their own public API error contract.
_harness_component_is_safe() {
  LC_ALL=C
  [[ $# == 1 && ${#1} -ge 1 && ${#1} -le 128 && $1 =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

harness_validate_feature_name() {
  [[ $# == 1 ]] && _harness_component_is_safe "$1" || {
    printf '%s\n' 'error: invalid feature name' >&2
    return 2
  }
}
