# Task 1.7 report — skill mutation oracle

Status: DONE

Commits: `f7c94e5 test: prove skill contract oracle mutations`

红阶段证据: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-08-31-01-device-safety/task-1.7-red-stage.log`

## 改动

- 在 `tests/test-device-safety.sh` 增加仅操作临时副本的逐 skill regex / bare-ADB mutation runner；每个 mutation 验证替换数恰为 1 且 `cmp` 证明副本已改变。
- 两类 mutation 均复用 `device_safety_check_skill_file`：regex 必须报 `missing safe serial preflight`，bare ADB 必须报 `bare adb`。
- 增加两个最小安全合成 skill 的 `mutation-selftest` scope，以及先检查生产 contract 再运行 mutation 的 `skills` scope。

## 验证

- `DEVICE_SAFETY_TEST_SCOPE=mutation-selftest bash ./tests/test-device-safety.sh` — exit 0。
- `DEVICE_SAFETY_TEST_SCOPE=skills bash ./tests/test-device-safety.sh` — exit 1，当前生产 skill 红阶段如上证据所示。
- `DEVICE_SAFETY_TEST_SCOPE=fixture bash ./tests/test-device-safety.sh` — exit 0。
- `DEVICE_SAFETY_TEST_SCOPE=skill-contract-selftest bash ./tests/test-device-safety.sh` — exit 0。
- `bash -n ./tests/test-device-safety.sh`、`git diff --check` — exit 0。

## 顾虑

- 当前生产 skill 尚未完成后续任务的安全 preflight / fenced-block 改造，因此 `skills` scope 按计划保持红灯；生产修复后该 scope 会继续执行四个 mutation 变体。
