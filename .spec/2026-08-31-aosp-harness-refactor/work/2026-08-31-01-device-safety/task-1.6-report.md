# Task 1.6 Report

Status: DONE

Commits: `8a9e196 test: add skill device target contract oracle`

红阶段证据: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-08-31-01-device-safety/task-1.6-services-preflight-red.log`

改动:

- 在 `tests/test-device-safety.sh` 增加 `device_safety_check_skill_file`，检查唯一 fenced 设备块、精确 serial 取值与 regex 的 preflight 顺序，以及每条目标 ADB 命令的 `adb -s "$device_serial"` 前缀。
- 增加 `skill-contract` scope，覆盖两个 Claude skill。

验证:

- `bash -n ./tests/test-device-safety.sh`：通过。
- `DEVICE_SAFETY_TEST_SCOPE=fixture bash ./tests/test-device-safety.sh`：通过。
- `DEVICE_SAFETY_TEST_SCOPE=skill-blocks bash ./tests/test-device-safety.sh`：按上游红阶段预期失败，`build-sepolicy` 尚无 fenced 设备块。
- `DEVICE_SAFETY_TEST_SCOPE=skill-contract bash ./tests/test-device-safety.sh`：退出 1；首错为 `FAIL  build-services-jar device block 1: missing safe serial preflight`，证据已保存。
- `git diff --check`：通过。

顾虑:

- 当前生产 skill 仍处红阶段；task 2.3 完成后应复跑 `skill-contract` 及后续 mutation/全量回归。
