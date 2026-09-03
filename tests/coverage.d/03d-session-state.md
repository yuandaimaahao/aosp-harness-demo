# 03d session-state coverage fragment

范围: 2026-09-03-03d-session-remove-prune（session-state-provider-v1）。本 fragment 为 03d 独占，不修改 02 的 `tests/COVERAGE.md`。
主验证命令: `bash ./tests/test-session-state.sh`；成功唯一摘要 `RESULT PASS  session state`。

| 需求 | 测试区段（tests/test-session-state.sh） |
|---|---|
| R1 | 结构核对区段（remove 双 anchor exact-once、无 rc3 分支）+ fixture 循环 missing-signals/missing-remove 行经 aggregator 点名核对 remove export 在场/缺席 |
| R2 | fixture 循环 missing-signals 行：signals 缺席时 remove inert，aggregator rc1、marker 未设、完整五 API predicate 为 false |
| R3 | remove 矩阵：feature 存在删除+全层 prune、unsafe id/object rc2 固定 stderr、EIO anchor 注入行 rc1 固定 stderr、无 rc3 分支 rg 断言、stdout 恒空 |
| R4 | feature 缺失幂等 prune 行 + 并发非空注入行（rc0、双流空、namespace inventory 仅差被删 feature 与空 session 目录、concurrent 保留） |
| R5 | 依赖探测（隔离 shell source aggregator 后 marker 精确为 1）+ fixture 循环五 missing-* 行逐模块复现 |
| R6 | 六类 inert fixture（五 missing-* + aggregator-absent 自愿加严）：rc 非零、双流空（aggregator-absent 不断言双流）、marker 未设、五 API predicate false、同名哨兵函数不被当作 capability |
| R7 | aggregator 发布面：marker=1、五 public API 逐个 declare -F、四转接各一行 rg 断言、path/write/read/remove 透传各一例、aggregator 无模块内部逻辑副本 rg 断言 |
| R8 | 本文件整体：CLI 分流（无参数/all/`--dependency-absent`/`--session-provider-fixture` 五值）、argv 非法表 rc1 无 PASS、inert 出口与 active 出口双 printf 字面量恰 2 处 |
| R9 | 本 fragment 自身（tests/coverage.d/03d-session-state.md） |

红阶段 mutant 自反证（任务 1.3 证据，不入本文件断言）: (a) 删 `PRUNE_BEFORE_IDENTITY` identity 核对的 mutant 使换入攻击行确定性 FAIL；(b) feature 缺失不 prune 的 mutant 使幂等 prune 行确定性 FAIL。
