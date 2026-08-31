# 任务 1.4 审查 Round 1：flag 优先级与 Demo SKIP 矩阵

## 范围与证据

- 审查对象：`3e4a0e2f..c4117263`，仅 `tests/test-device-safety.sh` 的 80 行新增测试判据。
- 依据：任务 brief、任务报告及所附 diff 包；本轮未修改实现、未执行验证命令。

## ① 规格逐项符合性

| 核查项 | 结论 | 证据 |
| --- | --- | --- |
| 四个真实 `--allow-skip` / serial 组合 | 符合 | `flag_cases` 精确列出 Claude/Codex 各自的 `__UNSET__` 与 `-bad`；各 verifier scope 仅筛选自身两例。 |
| 错误优先级 | 符合 | 四例均断言 rc `2` 且 stderr 含 `--allow-skip requires --demo`，同时断言 stderr 不含 `ANDROID_SERIAL`。 |
| 零 ADB 调用 | 符合 | 每例先创建独立 fake ADB 和空 `adb.log`，再断言 `[[ ! -s "$adb_log" ]]`。 |
| 两个 Demo SKIP 细节 | 符合 | Claude 与 Codex 各自以 `DEMO_APP_INSTALLED=0` 调用，断言 rc `0`、至少一行 `^SKIP  `、精确末行 `RESULT PASS (SKIP allowed)` 及零 ADB 调用。 |
| scope 隔离 | 符合 | 新增 `claude-flag-demo`、`codex-flag-demo`、聚合 `flag-demo`；前两个 scope 分别只调用一个 verifier，并为每个子例重置私有 fake ADB fixture。 |
| 路径保留 | 符合 | 调用既有 `./claude-code/features/dev-sidebar/verify-sidebar.sh` 和 `./codex/features/dev-sidebar/verify-sidebar.sh`，并先断言两个路径可执行；无路径删除或重命名。 |

结论：**PASS**。任务 1.4 作为测试矩阵增量，完整覆盖其规定的 flag 优先级与 Demo SKIP 判据；没有越出只增加测试判据的任务边界。

## ② 质量

结论：**PASS**。fixture、stdout/stderr 和 ADB 日志均使用按 verifier/场景命名的临时目录，失败消息能够定位到具体入口和场景。新增 helper 避免了 Claude/Codex 两套断言漂移；在既有 Bash 3.2 风格下未引入新依赖或不兼容语法。

## Findings

- 阻断：0
- 重要：0
- 次要：0

⚠️ 无。

## 最终结论

**PASS**（阻断 0 / 重要 0 / 次要 0）。
