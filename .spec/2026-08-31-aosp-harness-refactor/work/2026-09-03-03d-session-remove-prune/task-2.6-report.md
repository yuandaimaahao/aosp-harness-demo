# task-2.6 报告：收敛manifest、ledger与终交付

task: task-2.6
base: 388a83d5816659428e510bd9540d2a88cc2613e7（ACCEPTED_HEAD，零 delta 任务不改变 HEAD）
head: 388a83d5816659428e510bd9540d2a88cc2613e7
files: 无源码改动（验收资产：green/acceptance 报告、red 证据、manifest 第 9 行）

红阶段证据: .spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/evidence/task-2.6-red.txt

## commands

1. `test -s "$WORK/acceptance/acceptance-report.md"` → rc1（红：报告缺席）；`git rev-parse HEAD` 逐字=ACCEPTED_HEAD `388a83d5816659428e510bd9540d2a88cc2613e7`；`git status --porcelain` 空。
2. 汇总 candidate/full/depth-1/rollback/order 五路日志与任务 1.1–1.3 交付报告到 green 报告与 `acceptance/acceptance-report.md`：accepted HEAD、active 摘要（default 逐字 `RESULT PASS  session state\n`、checks=72）、双 anchor 注入行（EIO `pass  # HARNESS_TEST_MARKER_OS_ERROR` rc1 固定 stderr、`PRUNE_BEFORE_IDENTITY` 换入攻击 rc2 固定 stderr 双目录保留）、两 mutant 自反证（(a) failures=3 换入行 FAIL；(b) failures=1 幂等 prune 行 FAIL）、exact4/400=378、六类 inert fixture（五 missing-* + aggregator-absent）、五路验证结论。
3. 生成本任务 evidence package（`evidence/task-2.6-evidence.tsv`，sha256+size 逐行实算）；交全新独立 explore reviewer 审查（重点：manifest awk 机械核验、acceptance 报告与各任务源报告抽验一致、终门重跑）。
4. reviewer PASS 后由 controller 追加 manifest 第 9 行 `9	task-2.6	<ACCEPTED_HEAD>	<ACCEPTED_HEAD>	kimi	PASS`。
5. 跑 tasks.md 步骤 4 的 awk 全量核验（九行、六列、相邻连续、首行 base=BASE_SHA、末行 head=ACCEPTED_HEAD、reviewer 非空、全 PASS），必须 exit 0。
6. mark 任务 2.6 完成；ledger 追加完成锚点行（终交付锚点 `session-state-provider-v1`、accepted HEAD、active 摘要、双 anchor、mutant 证据、checks=72、exact4/378、full/depth/rollback/order 四路；裁定 6：不逐字含 NEXT 规范 ID 全名）+ sync-ledger。
7. 终门重跑：check-tasks/check-req/check-criteria/check-analyze、candidate default/offline、`git diff --check`、clean、03e 顺序门（同任务 2.5 五门）。

## results

- 红阶段：rc1，acceptance 报告缺席确认（证据见上）。
- green：acceptance 报告与 evidence package 生成完毕，内容逐节对照任务 1.1–2.5 源报告汇总（详见 `acceptance/acceptance-report.md`）。
- 本任务不改变任何 checkout 的 HEAD；manifest 第 9 行、awk 核验、ledger 锚点与终门结果在本报告 review PASS 后由 controller 完成并补记于 ledger。
