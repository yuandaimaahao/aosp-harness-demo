# 2026-09-03-03d-session-remove-prune 验收归档

## 改了什么

新增 exact 四文件（BASE `d8c2baaee20c52c2f4bac88eb6d4938af2d61516` → accepted HEAD `388a83d5816659428e510bd9540d2a88cc2613e7`，110+46+18+204=378 行 ≤400，git 输出序）：

- `common/.harness/lib/session-state-remove.sh`（110 行）：source-inert 的 remove 模块。`_harness_session_write_with_signals` 单检查 guard（缺席静默 rc0、零定义、双流空）；齐全则定义唯一私有 export `_harness_session_remove_core <project-id> <session-id>`——non-creating verified 删除 feature 规则文件，held parent/child fd identity 三方核对（`PRUNE_BEFORE_IDENTITY`）后自底向上 prune 安全的空 session/project/root；成功或目标缺失 rc0、普通 OS 错（含真实 EIO）rc1、协议/安全错 rc2，stdout 恒空、stderr 固定（rc1 `error: session state operation failed`、rc2 `error: unsafe session state`）、无 rc3 分支；ENOENT/ENOTEMPTY 幂等、并发非空保留他项。两个 exact-once 无副作用 anchor（`pass  # HARNESS_TEST_MARKER_OS_ERROR`、`pass  # PRUNE_BEFORE_IDENTITY`）供测试同步注入。
- `common/.harness/lib/session-state.sh`（46 行）：thin aggregator。preflight 五模块文件路径 `[[ -f && -r ]]` → foundation→path→snapshot→signals→remove 唯一顺序逐个静默 source（各 `2>/dev/null`）→ 9 个预期 export 逐个 `declare -F` 点名 → 全部通过才进入纯四转接定义 + `HARNESS_SESSION_STATE_PROVIDER_VERSION=1` marker 赋值的单临界区；任一失败静默 rc1、双流空、五 API 不定义、marker 不设（partial capability 物理不可能）。
- `tests/test-session-state.sh`（204 行）：默认发现、shfmt-clean 的完整集成矩阵，固定摘要 `RESULT PASS  session state`（PASS 后两空格逐字，printf 字面量恰 2 处），只接受无参数/`all`/唯一 `--dependency-absent`/唯一 `--session-provider-fixture` 五值。active 覆盖：remove 矩阵（存在删除+全层 prune、缺失幂等仍 prune、并发非空保留、rc 表逐字、双 anchor 注入行——EIO rc1 固定 stderr、换入攻击 rc2 双目录保留）、aggregator 发布面（五 API 逐个 declare -F、marker 精确 1、四转接透传各一例、无逻辑副本 rg 断言）、六类 inert fixture（五 missing-* + aggregator-absent 自愿加严）、argv 非法表 5 行；双 mutant 自反证（(a) 删 identity 核对→failures=3 换入行 FAIL、(b) feature 缺失不 prune→failures=1 幂等 prune 行 FAIL）。断言计数 checks=72（default==all 逐字一致，inert 探针 checks=0）。
- `tests/coverage.d/03d-session-state.md`（18 行）：03d 独占 coverage fragment，登记 R1–R9 到测试区段映射，不触碰 02 的 `tests/COVERAGE.md`。

九任务全部完成，review manifest 九行六列连续（awk 全量核验 rc=0，首行 base=execution BASE、末行 head=ACCEPTED_HEAD）。candidate（2.1）/full 完整历史（2.2，rev-list=198）/真实 `git clone --depth 1 file://`（2.3，count=1 且 .git/shallow 恰一行）/隔离 rollback（2.4，恰四行 D、03b/03b1/03c 三入口逐字 PASS、offline 本入口发现 0 次）/03e 顺序门（2.5，目录/分支/worktree/scoped rg 17 文件全缺席零匹配）零 delta 验证全 PASS；实现以 fast-forward `388a83d` 合入 main，post-merge 回归（default 逐字 + 03b/03b1/03c/path-races 入口 + offline 发现恰一次）全绿；worktree 与分支已清理零残留。

执行期 spec 修订记录（均已随验收同批提交）：无 design/tasks 机制修订；任务 1.2 review round1 阻断 B1（语法错损坏模块经 source 泄漏 bash 解析错误到 stderr，违反 R6 无条件双流空）按 reviewer 建议修复——&& 链中五个 source 各加 `2>/dev/null`（模块 source 期契约静默，无合法输出被吞），amend 保持裁定 1 单提交（653e756f→df38c345），全新 reviewer round2 PASS；controller 追加 manifest 第 1 行时 task-id 误写 `1.1`（应为 `task-1.1`），已自行 sed 修正。

## 验收证据路径

- 验收报告：`.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/acceptance/acceptance-report.md`
- 任务报告/日志/review：`.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/`（task-*-report.md、task-*-review-round-*.md、evidence/、review-manifest.tsv）
- ledger：`.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-03-03d-session-remove-prune/ledger.md`

## 适用范围

本片只交付 remove 模块、complete-provider aggregator 与其默认发现测试及独占 coverage fragment，不修改任何前序模块/测试（上游九文件 BASE..HEAD 零变更）。03e（Claude hook/demo 接入完整安全状态 API）启动门——dependency-present active 证据（checks=72）、exact4/400（378）、full/depth-1/rollback/offline 与 03e 顺序门证据入 ledger——已由本验收满足并记录于 DECISIONS.md；inert PASS 未作为本片任何验收证据，也未解除 03e 顺序门。
