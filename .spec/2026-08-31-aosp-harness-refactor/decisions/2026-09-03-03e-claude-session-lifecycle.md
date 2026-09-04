# 2026-09-03-03e-claude-session-lifecycle 验收归档

## 改了什么

新增/修改 exact 六文件（BASE `cc04996e1e405c00e16be3b57d3ef62d90cd7fd1` → accepted HEAD `5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`，numstat 总和 367 ≤400）：

- `claude-code/features/.harness/hooks/load-feature.sh`、`check-branch-drift.sh`、新增 `session-end.sh`：内联 complete-provider guard（source aggregator + marker 精确 1 + 五 public API 合取才 v1）；每 hook `compat_legacy` 字面量恰 1 处；SessionStart 按 source 分级建/读基线；UserPromptSubmit 漂移 exit 2；SessionEnd 校验先于幂等 remove，非法输入零删除。
- `claude-code/features/.harness/settings.json`：注册 SessionEnd 指向 `session-end.sh`。
- `claude-code/run-demo.sh`：全部持久写入限于 `mktemp -d "${TMPDIR:-/tmp}/claude-harness-demo.XXXXXX"` 与单 EXIT trap。
- `tests/test-claude-session-lifecycle.sh`（176 行顶格）：默认发现生命周期矩阵，固定摘要 `RESULT PASS  claude session lifecycle`。

八任务全部完成，review manifest 八行六列连续（awk rc0）。candidate/full（rev-list=208）/depth-1（count=1，shallow 1 行）/rollback（2D+4M，对 BASE diff 空）/顺序门（18 份 scoped 文件=11 ledger+7 execution-base+0 dispatch，零匹配）零 delta 验证全 PASS。

## 验收证据路径

- 验收报告：`.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03e-claude-session-lifecycle/acceptance/acceptance-report.md`
- 任务报告/review：`.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03e-claude-session-lifecycle/`
- ledger：`.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-03-03e-claude-session-lifecycle/ledger.md`

## 适用范围

本片只改 Claude 三 hook、settings.json、run-demo 与其默认发现测试，不修改上游十二 tracked 文件。后序片启动门由 DECISIONS 2026-09-04 验收行满足；legacy-only PASS 未作为本片验收证据。R7 净变更口径不含 `claude-feature --dry-run` 对 tracked `CLAUDE.md` 软链的既有写入（b2fab19 已有）。
