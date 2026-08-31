# Task 1.6 Fuse Report

Status: DONE

Commits: `596a65a test: conservatively lock skill adb oracle`

红阶段证据: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-08-31-01-device-safety/task-1.6-fuse-services-preflight-red.log`

验证:

- `bash -n ./tests/test-device-safety.sh`：通过。
- `DEVICE_SAFETY_TEST_SCOPE=fixture bash ./tests/test-device-safety.sh`：通过。
- `DEVICE_SAFETY_TEST_SCOPE=skill-contract-selftest bash ./tests/test-device-safety.sh`：通过。保留既有合成负向用例，并确认 `adb -s "$device_serial" root; adb>/tmp/adb.out` 与 `device_serial+=-other` 都被拒绝；仅静态读取临时 Markdown fixture。
- `DEVICE_SAFETY_TEST_SCOPE=skill-contract bash ./tests/test-device-safety.sh`：预期退出 1；首错保持为 `FAIL  build-services-jar device block 1: missing safe serial preflight`，证据已保存。
- `git diff --check`：通过。

顾虑:

- 熔断裁定采用保守 allowlist；后续生产 skill 必须保持任务指定的精确 preflight 和 ADB 前缀。未执行 Markdown 命令、设备操作或网络访问。
