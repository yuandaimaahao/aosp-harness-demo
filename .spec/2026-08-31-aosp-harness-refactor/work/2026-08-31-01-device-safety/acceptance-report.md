# 2026-08-31-01-device-safety 验收报告

## ① 判据执行结果

验收基线：`2f3e46baa2ed60d284da6c98dc28452c44f98786`

验收 HEAD：`bcd0c9b0b675c384c346dcd0171a055b67a2712c`

主判据与十个显式 scope 原始输出：

```text
[accept] full device-safety suite
PASS  demo harness startup, process layer, and strict verification
PASS  Codex feature context selection and branch checks
RESULT PASS  shared Harness regression suite
RESULT PASS  device safety
FULL_SUITE_RC=0
[accept] explicit scope matrix
SCOPE_fixture_RC=0
SCOPE_claude-invalid-serial_RC=0
SCOPE_claude-valid-serial_RC=0
SCOPE_claude-flag-demo_RC=0
SCOPE_codex-flag-demo_RC=0
SCOPE_skill-blocks_RC=0
SCOPE_skill-contract-selftest_RC=0
SCOPE_mutation-selftest_RC=0
SCOPE_skills_RC=0
SCOPE_legacy_RC=0
[accept] unknown-scope fail-closed
UNKNOWN_SCOPE_RC=2 SUCCESS_LINE=0 ERROR_LINE=1
```

语法、入口、diff 与预算原始输出：

```text
[accept] syntax and entrypoints
BASH_N_RC=0
ENTRYPOINTS_RC=0
DIFF_CHECK_RC=0
[accept] budget
11  1  claude-code/features/.harness/skills/build-sepolicy/SKILL.md
9   4  claude-code/features/.harness/skills/build-services-jar/SKILL.md
4   1  claude-code/features/.harness/tests/test-harness.sh
15  2  claude-code/features/dev-sidebar/verify-sidebar.sh
5   0  codex/features/dev-sidebar/verify-sidebar.sh
268 0  tests/test-device-safety.sh
CHANGED_FILES=6 LIMIT=8
CHANGED_LINES=320 LIMIT=400
[accept] convergence
CONVERGE_RC=0
[accept] worktree status
STATUS_ENTRIES=0
ACCEPTANCE_RC=0
```

`check-converge.py` 已对 requirements、tasks 和 `BASE..HEAD` 文件集合完成独立收敛检查，退出 `0`。

## ② 逐条对照

- R1：`claude-valid-serial` 对 `demo-serial`、`A0._:-z` 均通过；测试要求每条 fake ADB 日志精确以对应 `adb -s <serial> ` 开头，并要求末行 `RESULT PASS`。
- R2：`claude-invalid-serial` 覆盖缺失值及 9 个非法值，逐项要求退出 `2`、stderr 含 `ANDROID_SERIAL`、fake ADB 日志为空。
- R3：`skill-blocks`、`skill-contract-selftest`、`mutation-selftest` 和 `skills` 均退出 `0`；两个 skill 各有唯一真机块、唯一安全 preflight，枚举的 ADB 命令均固定使用 `device_serial`。四个 mutation 与历史负向集合证明 oracle 可拒绝弱 regex、裸/复合 ADB 和额外 target。
- R4：`claude-flag-demo`、`codex-flag-demo` 均退出 `0`；各自覆盖 serial 缺失与 `-bad`，要求 flag 错误先于 serial 错误、退出 `2` 且零 ADB。
- R5：同一双入口 scope 覆盖应用缺失的 `--demo --allow-skip`，要求 `SKIP` 明细、末行 `RESULT PASS (SKIP allowed)` 和退出 `0`。
- R6：所有设备路径只在每个 fixture 的私有 fake-ADB `PATH` 中运行；未知 serial/命令分别 fail-closed，拒绝路径要求空日志，验收未访问开发机 ADB server。
- R7：两个 verifier 入口 `test -x` 通过；`legacy` scope 在私有 fake ADB 下运行 Claude、Codex、common 三套旧回归并退出 `0`。

不变量：

- 开发机真实 ADB 调用数为 `0`：主判据和显式 scope 全部由私有 fake ADB 隔离，拒绝路径以空日志取证。
- 三套旧回归失败数为 `0`：主判据原始输出包含三套聚合 PASS，`SCOPE_legacy_RC=0`。
- 既有 verifier 用户入口删除数为 `0`：`ENTRYPOINTS_RC=0`，两个既有路径均保留且可执行。

## ③ 执行期裁定

按“如果错了”的代价从高到低列出；ledger 中的原文不省略：

1. 

   ```text
   23:28 task=1.6 熔断裁定：采用 standalone-adb 保守边界与 `device_serial` executable-line allowlist，拒绝任意第二 adb token 和除唯一初始化/guard/固定 ADB 行外的全部变量提及；实现 commit=[596a65a]，selftest+bash-n+expected-red PASS。若判断错误，代价是合法但复杂的 skill Bash 写法会被要求拆成简单单行；若继续局部解析，代价是安全 oracle 可被新 shell 语法绕过。
   ```

2. 

   ```text
   00:03 裁定: 验收追加 task 2.4，仅压缩 `tests/test-device-safety.sh` 的重复 helper/oracle，保留全部已审行为和生产文件不动；若判断错误，代价是表驱动重构可能引入测试假绿，因此必须跑每个内部 scope、完整验收并做独立 diff review；若不修，PLAN 的 400 行硬预算无法通过。
   ```

3. 

   ```text
   23:49 裁定: task=2.1 的隔离本地提交沿用仓库 conventional commit，不虚构外部 AR/BUG ID；若判断错误，代价是最终集成前重写本地 commit message，不影响代码/验证。
   ```

其中第 2 项已由十个显式 scope、默认聚合和独立压缩 diff review 双重覆盖；review 结论为 12/12 规格项通过、0 finding、0 warning。

## ④ 跳过的门禁

`STATE.md` 的 SKIPPED 表为空，本 spec 没有跳过门禁。

## ⑤ 挂账 findings

- 设计 review 的 M1（skill oracle 不能只做全文件字符串存在性检查）已闭合：实现采用 fenced-block 提取、保守 allowlist、合成负向和逐 skill mutation。
- 独立实现 review 没有遗留未修的阻断、重要或次要 finding；任务 1.6 达轮次上限后的 parser 风险已作为上方熔断裁定显式保留。

## ⑥ 结论

可以验收。R1-R7 与三条不变量均有本次消息内的新鲜执行证据；收敛、入口、语法、工作树清洁度和 6 文件/320 行预算全部通过，且没有跳过门禁或未处置 finding。
