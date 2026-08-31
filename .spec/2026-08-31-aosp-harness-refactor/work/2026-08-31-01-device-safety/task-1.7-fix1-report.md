# Task 1.7 fix 1 report — isolated mutation probe

Status: DONE

Commits: `d92af9d test: isolate skill mutation oracle probes`

红阶段证据: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-08-31-01-device-safety/task-1.7-fix1-red-stage.log`

## 改动

- 删除 mutation 与既有合成 contract selftest 中对 `DEVICE_SAFETY_FAILURES` 的无条件复位；checker 改在隔离 subshell 中从零计数运行，外层只记录“错误接受 unsafe mutation”或“缺少预期失败标签”。
- mutation 直接调用 `device_safety_extract_device_blocks`，要求唯一 `block-1.bash`，仅在该块上改动完整 regex 或第一条以 fixed-prefix 开头的真实 ADB 行；再以精确 Bash fence 重组临时 skill。
- 保留 replacement-count=1 与 `cmp` 基线/变体差异检查；新增模拟 checker 接受 unsafe skill 的嵌套自测，确认外层断言会保留失败计数。

## 验证

- `bash -n ./tests/test-device-safety.sh` — exit 0。
- `DEVICE_SAFETY_TEST_SCOPE=fixture bash ./tests/test-device-safety.sh` — exit 0。
- `DEVICE_SAFETY_TEST_SCOPE=skill-contract-selftest bash ./tests/test-device-safety.sh` — exit 0。
- `DEVICE_SAFETY_TEST_SCOPE=mutation-selftest bash ./tests/test-device-safety.sh` — exit 0。
- `DEVICE_SAFETY_TEST_SCOPE=skills bash ./tests/test-device-safety.sh` — exit 1，当前生产文件保持预期红灯。
- `git diff --check` — exit 0。

## 顾虑

- 无；`skills` 红灯只反映尚未落地的生产 skill 安全改造。
