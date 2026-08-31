# Task 1.1 Report

Status: DONE

Commits:

- `782387ab4688f55495e56fc1430e2cd998f82c2f` — `test: add device safety fixture scope`

Changed files:

- `tests/test-device-safety.sh` (created)

## Red-stage evidence

- Command: `test -e ./tests/test-device-safety.sh; rc=$?; printf 'red_test_e_rc=%s\\n' "$rc"`
- Exit code: `1`
- Key output: `red_test_e_rc=1`
- 红阶段证据: `task-1.1-red-test-evidence.txt`

## Green-stage verification

- `DEVICE_SAFETY_TEST_SCOPE=fixture bash ./tests/test-device-safety.sh` — exit `0`; the isolated fake ADB returned each specified response, rejected an unknown serial with `91`, rejected an unknown command with `92`, logged command names, used its private PATH-first `adb`, and had its cleanup trap registered.
- `bash -n ./tests/test-device-safety.sh` — exit `0`.
- `./tests/test-device-safety.sh` — exit `0`.
- `DEVICE_SAFETY_TEST_SCOPE=unknown bash ./tests/test-device-safety.sh` — exit `2`; stderr: `error: unknown DEVICE_SAFETY_TEST_SCOPE: unknown`.
- `git diff --check` — exit `0`.

Concerns: None. This task intentionally provides only the fixture scope and runner skeleton; later task-owned scopes are not present yet.
