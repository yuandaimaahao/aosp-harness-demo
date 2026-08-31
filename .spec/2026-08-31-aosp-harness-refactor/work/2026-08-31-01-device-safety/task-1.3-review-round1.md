# 任务 1.3 审查 Round 1：Claude 合法 serial 正向矩阵

## 结论

**NEEDS_CHANGES** — 1 个 P1 finding。矩阵覆盖、fixture 隔离和结果断言均符合任务，但“每条记录以精确前缀开头”的 oracle 没有锚定行首，无法严格证明设备选择参数位于每个 fake-ADB argv 记录的开头。

## ① 规格符合性

| 任务要求 | 结论 | 审查结果 |
|---|---|---|
| 为 `demo-serial`、`A0._:-z` 建立独立 fixture，以私有 PATH 运行 Claude 真实 verifier `--since 200`，保存 rc/stdout/ADB 日志 | ✅ | 循环逐项调用 `device_safety_fake_adb_install "claude-valid-$case_index" "$serial"`，并分别保存 `stderr`、`stdout` 和 `adb_log`；调用显式传入 `ANDROID_SERIAL` 与私有 fake-ADB PATH。 |
| 每个 case 断言 rc=0、stdout 最后一行为精确 `RESULT PASS`、日志非空 | ✅ | `[[ "$rc" -eq 0 && "$(tail -n 1 "$stdout_file")" == 'RESULT PASS' ]]` 与非空日志断言均已实现。 |
| 每一行都以精确 `adb -s <对应 serial> ` 开头 | ❌ | `grep -Fvc "$expected_prefix" "$adb_log"` 仅证明每行**包含**该子串，未要求其在第 1 列；例如 `unexpected adb -s demo-serial shell ...` 会错误通过。 |
| 注册 `claude-valid-serial` scope | ✅ | 已注册至 `device_safety_run_claude_valid_serial_matrix`。 |
| 当前生产修复前的红阶段应非零，首错为 prefix oracle | ✅ | 报告记录该 scope exit 1，并列出两个 serial 的 prefix/结果失败；与任务指定的红阶段目的相符。未重跑。 |

## ② 质量结论

| 项目 | 结论 | 说明 |
|---|---|---|
| Oracle 精确前缀逐行校验 | ❌ | P1：检查未锚定行首，未完整实现“以…开头”的安全取证契约。应以 `awk` 的 `index($0, prefix) == 1`（或等价的逐行首位检查）替换。 |
| 合法字符边界 | ✅ | 两个计划指定的合法 serial `demo-serial`、`A0._:-z` 均按字面量覆盖，包含首字符和后续允许字符的代表组合。 |
| 日志/fixture 隔离 | ✅ | 每个 case 使用独立 fixture 目录与私有 `ADB_LOG`，stdout/stderr 也独立落盘；顺序执行下无交叉读取。 |
| 错误处理 | ✅ | verifier 非零不会因 `set -e` 中断矩阵，rc 会被采集后统一报告；全部 case 可继续执行以暴露多项失败。 |
| YAGNI | ✅ | 仅新增计划规定的 scope、两项 fixture 和三类断言，未引入公共运行时或额外抽象。 |

## Findings

### P1 — ADB 前缀 oracle 未要求行首，可能放过非固定目标的记录

文件：`tests/test-device-safety.sh`，`device_safety_run_claude_valid_serial_matrix`

`grep -Fvc "$expected_prefix" "$adb_log"` 对任意位置的固定字符串都视为匹配，并非任务要求的“每一行…开头”。这削弱 R1/R6 的核心取证：日志格式或包装层若在 `adb -s` 前添加意外 token，测试仍会通过。改为逐行检查 prefix 的首位匹配，并保留现有非空日志断言。

## ⚠️ 控制器核实项

- 本轮按要求未重跑报告中的验证。修正 P1 后，控制器应在生产修复完成的提交上运行 `DEVICE_SAFETY_TEST_SCOPE=claude-valid-serial bash ./tests/test-device-safety.sh`，确认两个 fixture 均转绿，且最终根级安全回归的末行严格为 `RESULT PASS  device safety`。

## 计数

- P0: 0
- P1: 1
- P2: 0
- P3: 0
- ⚠️ 控制器核实项: 1
