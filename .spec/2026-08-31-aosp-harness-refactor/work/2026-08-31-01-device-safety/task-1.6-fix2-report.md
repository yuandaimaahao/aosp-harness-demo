# Task 1.6 Fix 2 Report

Status: DONE

Commits: `1c49ee4 test: close skill oracle parsing gaps`

红阶段证据: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-08-31-01-device-safety/task-1.6-fix2-services-preflight-red.log`

验证:

- `bash -n ./tests/test-device-safety.sh`：通过。
- `DEVICE_SAFETY_TEST_SCOPE=fixture bash ./tests/test-device-safety.sh`：通过。
- `DEVICE_SAFETY_TEST_SCOPE=skill-contract-selftest bash ./tests/test-device-safety.sh`：通过；既有 chained/devices/other-serial/duplicate 用例，以及 `root; adb;`、`adb&&`、同行 preflight、注释 preflight、post-validation 重赋值均被静态拒绝，未执行任何 Markdown 内容。
- `DEVICE_SAFETY_TEST_SCOPE=skill-contract bash ./tests/test-device-safety.sh`：预期退出 1；首错仍为 `FAIL  build-services-jar device block 1: missing safe serial preflight`，证据已保存。
- `git diff --check`：通过。

顾虑:

- 生产 skill 仍由后续 task 2.3 修复；本轮只增强测试 oracle，未执行设备或 Markdown 命令。
