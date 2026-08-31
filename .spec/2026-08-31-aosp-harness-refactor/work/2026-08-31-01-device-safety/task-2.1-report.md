# Task 2.1 Report — Pin Claude verifier ADB target

Status: DONE

Commits:

- `fb161f9 fix: pin Claude verifier adb target`

红阶段证据: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-08-31-01-device-safety/evidence/task-2.1-red-claude-invalid-serial.log`

改动:

- Claude verifier now rejects real-mode `--allow-skip` before serial validation, requires a safe explicit `ANDROID_SERIAL`, and routes real `shell`/`logcat` calls through the split argv array `adb -s "$serial"`.
- The affected Claude legacy fake-ADB fixture now requires `-s demo-serial`, and its real-mode verifier fixture explicitly supplies that serial.

全部验证:

- Saved red phase: `DEVICE_SAFETY_TEST_SCOPE=claude-invalid-serial bash ./tests/test-device-safety.sh` exited 1 with the required missing-serial/zero-ADB oracle failures.
- `bash -n ./claude-code/features/dev-sidebar/verify-sidebar.sh`
- `bash -n ./claude-code/features/.harness/tests/test-harness.sh`
- `DEVICE_SAFETY_TEST_SCOPE=claude-invalid-serial bash ./tests/test-device-safety.sh`
- `DEVICE_SAFETY_TEST_SCOPE=claude-valid-serial bash ./tests/test-device-safety.sh`
- `DEVICE_SAFETY_TEST_SCOPE=claude-flag-demo bash ./tests/test-device-safety.sh`
- `DEVICE_SAFETY_TEST_SCOPE=legacy bash ./tests/test-device-safety.sh`
- `git diff HEAD^ HEAD --check`

All green-path device verification used the task's private fake ADB fixture; no real ADB, CVD, AOSP build, or network operation was run.

顾虑: 无。
