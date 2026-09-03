# task-2.3 报告：验证真实depth-1 checkout

task: task-2.3
base: 388a83d5816659428e510bd9540d2a88cc2613e7（ACCEPTED_HEAD，零 delta 任务不改变 HEAD）
head: 388a83d5816659428e510bd9540d2a88cc2613e7（depth-1 clone HEAD 逐字一致）
files: 无源码改动（零 delta controller 验证任务）

红阶段证据: .spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/evidence/task-2.3-red.txt

## commands

1. `test ! -s task-2.3-report.md` → rc0（红：报告缺席）。
2. `git clone --depth 1 "file://$IMPLEMENTATION_WORKTREE" "$tmp/depth1"`（真浅克隆，file:// 协议不走本地硬链优化）；HEAD 逐字=ACCEPTED_HEAD；`git rev-list --count HEAD`=1；`.git/shallow` 恰 1 行（日志 evidence/task-2.3-logs/git-shallow.txt）。
3. depth1 中 `sha256sum $UPSTREAM9 > before.sha`（日志 before.sha）。
4. default：`bash ./tests/test-session-state.sh` → rc0，stdout 逐字 `RESULT PASS  session state\n`（cmp），stderr 0B（日志 default.out/default.err）。
5. offline：`bash ./scripts/check.sh --offline` → rc0；`rg -c 'RESULT PASS  session state$' offline.log`=1；末行 `RESULT PASS  aosp-harness offline quality gate`（日志 offline.log）。
6. `sha256sum -c before.sha` rc0；`git status --porcelain` 与 `git diff` 均空。
7. depth1 checkout 已删除。

## results

真实 depth-1 checkout 独立验证全绿：HEAD 逐字=ACCEPTED_HEAD、commit-count=1、shallow marker 恰一行、default 固定摘要逐字、offline 发现恰一次、上游九文件 SHA 不变、clean。未改变任何 checkout 的 HEAD。
