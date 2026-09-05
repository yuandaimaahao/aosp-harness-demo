#!/usr/bin/env bash
set -u
root=$(CDPATH='' cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)
out=$(bash "$root/scripts/check-docs.sh") || exit 1
[[ $out == 'RESULT PASS  docs readiness' ]] || exit 1
printf 'RESULT PASS  docs\n'
