# 2026-09-02-03b-session-snapshot-safety 验收归档

## 改了什么

新增 exact 两个文件（BASE `3d15a0d76c2a2e6c8541c5d47001a55f0ca18649` → accepted HEAD `ab1e870ece16bbc24e1a86f84110366f84aae0d9`，208+192=400 行，零余量）：

- `common/.harness/lib/session-state-snapshot.sh`（208 行）：signal-aware create-once snapshot 模块。spawn-only `_harness_session_snapshot_worker write|read`（最终 exec Python、PID 稳定，供 03c 直接 background）与两个私有 core；held capture fd 消费 path core 输出（无 pathname reopen）；逐层 managed fd 重新验证；发布只用 Linux `renameat2(RENAME_NOREPLACE)`，ENOSYS/缺 symbol 双流空 rc1 无 fallback；Python child 首信号原子锁存、三信号转 ignore、close 前转移 ownership、cleanup 全 fd 遍历且 latched 129/130/143 优先于 cleanup 错误。source 在 validate/path core 缺席时静默 inert（三 export/四 public API/marker 全缺席）。
- `tests/test-session-snapshot.sh`（192 行）：默认发现基础矩阵，固定摘要 `RESULT PASS  session snapshot safety`，只接受无参数/`all`/`--dependency-absent`；dependency-absent 时 inert 零 active case。

八任务全部完成，review manifest 八行六列连续（awk 全量核验 rc0），每任务独立 review 最终 PASS（2.6 经 fix round 1 + 全新 reviewer re-review 0/0/0）。candidate/full/depth-1/rollback/order 五路零 delta 验证全 PASS；实现以 fast-forward `ab1e870` 合入 main，post-merge 回归（default + offline）全绿。

## 验收证据路径

- 验收报告：`.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/acceptance/acceptance-report.md`
- 任务报告/日志/review：`.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/`（task-*-report.md、task-*-review-round-*.md、evidence/、review-manifest.tsv）
- ledger：`.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-02-03b-session-snapshot-safety/ledger.md`

## 适用范围

本片只交付基础默认矩阵与八个无副作用 anchor；完整 provider-copy 动态 mutation/publish/signal 穷举属于 03b1，Bash facade 信号转发属于 03c。03b1 启动门（accepted HEAD、active 证据、八 anchor、signal 协议、exact2/400、全 PASS manifest 入 ledger）已由本验收满足并记录于 DECISIONS.md；03c 全部资产继续物理缺席。
