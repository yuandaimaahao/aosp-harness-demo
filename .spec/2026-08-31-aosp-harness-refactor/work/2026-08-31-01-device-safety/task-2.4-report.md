# 任务 2.4 实现报告

Status: DONE

Commits:

- `bcd0c9b0b675c384c346dcd0171a055b67a2712c` `test(device-safety): compress regression harness`

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-08-31-01-device-safety/task-2.4-red.txt

## 摘要

仅重构 `tests/test-device-safety.sh`，通过共享 capture/fake-ADB、skill 常量与表驱动 synthetic cases 压缩重复实现。两个 verifier、两个 skill 和 Claude legacy fixture 在本任务提交中未改动；`d956617..bcd0c9b` 的文件集合只有根测试。

保留的判据包括：10 个非法 serial（含实际 LF）、2 个合法 serial、Claude/Codex 共 4 个 flag 优先级组合、2 个 Demo SKIP、fake ADB 未知 serial/命令 fail-closed、两个 skill 的 block/contract 检查、standalone `adb` 与 `device_serial` 保守 allowlist 的全部历史负向 cases、两个 skill 各 2 个 mutation，以及 3 套 legacy 回归。

## 压缩前后行数

| 指标 | 压缩前 | 压缩后 |
|---|---:|---:|
| `tests/test-device-safety.sh` 文件行数 | 766 | 268 |
| `BASE..HEAD` 总新增+删除 | 818 | 320 |
| PLAN 硬上限 | 400 | 400 |

压缩后 `git diff --numstat 2f3e46baa2ed60d284da6c98dc28452c44f98786..HEAD`：

```text
11  1  claude-code/features/.harness/skills/build-sepolicy/SKILL.md
9   4  claude-code/features/.harness/skills/build-services-jar/SKILL.md
4   1  claude-code/features/.harness/tests/test-harness.sh
15  2  claude-code/features/dev-sidebar/verify-sidebar.sh
5   0  codex/features/dev-sidebar/verify-sidebar.sh
268 0  tests/test-device-safety.sh
```

精确硬门：

```bash
test "$(git diff --numstat 2f3e46baa2ed60d284da6c98dc28452c44f98786..HEAD | awk '{sum += $1 + $2} END {print sum + 0}')" -le 400
```

结果：exit `0`，计算值 `320`。

## 逐 scope 原始输出

```text
BASH_N OK
RUN fixture
OK  fixture
RUN claude-invalid-serial
OK  claude-invalid-serial
RUN claude-valid-serial
OK  claude-valid-serial
RUN claude-flag-demo
OK  claude-flag-demo
RUN codex-flag-demo
OK  codex-flag-demo
RUN skill-blocks
OK  skill-blocks
RUN skill-contract-selftest
OK  skill-contract-selftest
RUN mutation-selftest
OK  mutation-selftest
RUN skills
OK  skills
RUN legacy
PASS  demo harness startup, process layer, and strict verification
PASS  Codex feature context selection and branch checks
RESULT PASS  shared Harness regression suite
OK  legacy
```

以上 scope 使用：

```bash
run_scopes=(
  fixture claude-invalid-serial claude-valid-serial
  claude-flag-demo codex-flag-demo skill-blocks
  skill-contract-selftest mutation-selftest skills legacy
)
for scope in "${run_scopes[@]}"; do
  DEVICE_SAFETY_TEST_SCOPE="$scope" bash ./tests/test-device-safety.sh || exit
done
```

## 完整入口原始输出

命令：`bash ./tests/test-device-safety.sh`

```text
PASS  demo harness startup, process layer, and strict verification
PASS  Codex feature context selection and branch checks
RESULT PASS  shared Harness regression suite
RESULT PASS  device safety
```

退出码 `0`，末行精确为 `RESULT PASS  device safety`。

## 其他门禁

- `bash -n ./tests/test-device-safety.sh`: exit `0`
- `git diff --check 2f3e46baa2ed60d284da6c98dc28452c44f98786..HEAD`: exit `0`
- `git status --short`: 无输出
- `git diff --name-only d9566179fadb9a3a5e4347806ec2f258a5885ba5..HEAD`: 仅 `tests/test-device-safety.sh`
- 未知 scope 失败路径：exit `2`，输出 `error: unknown DEVICE_SAFETY_TEST_SCOPE: does-not-exist`，且不含总成功末行

## 顾虑

无。验收只使用脚本创建的私有 fake ADB；未连接真实 ADB/CVD，未执行 AOSP build 或网络访问。
