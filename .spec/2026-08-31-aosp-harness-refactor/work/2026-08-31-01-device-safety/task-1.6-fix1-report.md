# Task 1.6 Fix 1 Report

Status: DONE

Commits: `cab162d test: harden skill adb contract oracle`

红阶段证据: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-08-31-01-device-safety/task-1.6-fix1-services-preflight-red.log`

验证:

- `bash -n ./tests/test-device-safety.sh`：通过。
- `DEVICE_SAFETY_TEST_SCOPE=fixture bash ./tests/test-device-safety.sh`：通过。
- `DEVICE_SAFETY_TEST_SCOPE=skill-contract-selftest bash ./tests/test-device-safety.sh`：通过；合成安全 fixture 被接受，安全 root 后链裸 reboot、独立 `adb devices`、`adb -s "$other_serial" wait-for-device`、重复 preflight 均被拒绝，且仅静态读取临时文件。
- `DEVICE_SAFETY_TEST_SCOPE=skill-contract bash ./tests/test-device-safety.sh`：预期退出 1；首错为 `FAIL  build-services-jar device block 1: missing safe serial preflight`，证据已保存。
- `git diff --check`：通过。

顾虑:

- 生产 skill 尚未由 task 2.3 加入 preflight/固定目标，故 `skill-contract` 保持预期红阶段；未执行任何 Markdown 内命令或设备操作。
