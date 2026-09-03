# task-2.4 报告：验证exact rollback

task: task-2.4
base: 388a83d5816659428e510bd9540d2a88cc2613e7（ACCEPTED_HEAD，零 delta 任务不改变任何真实 checkout 的 HEAD）
head: 388a83d5816659428e510bd9540d2a88cc2613e7（rollback clone 起点逐字一致）
files: 无源码改动（零 delta controller 验证任务；rollback commit 只存在于已删除的临时 clone）

红阶段证据: .spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/evidence/task-2.4-red.txt

## commands

1. `test ! -s task-2.4-report.md` → rc0（红：报告缺席）。
2. `git clone --no-local "$IMPLEMENTATION_WORKTREE" "$tmp/rollback"`，HEAD 逐字=ACCEPTED_HEAD；`git rm` 恰四交付文件后提交普通 rollback commit `9dea7bca331e10193c3a85da9366fc8fdae5e161`；`git diff --name-status HEAD~1 HEAD` 恰四行 `D`、路径逐字等于 `$EXACT4`（git 输出序）。
3. rollback clone 中：`bash tests/test-session-snapshot.sh` rc0 末行逐字 `RESULT PASS  session snapshot safety`；`bash tests/test-session-snapshot-assurance.sh` rc0 末行逐字 `RESULT PASS  session snapshot assurance`；`bash tests/test-session-signals.sh` rc0 末行逐字 `RESULT PASS  session write interrupts`（日志 evidence/task-2.4-logs/snap.out/assur.out/signals.out）。
4. `bash ./scripts/check.sh --offline` rc0 末行 PASS；`! rg -q 'RESULT PASS  session state$' offline.log`（本入口发现 0 次，行尾锚）；四交付文件均 `test ! -e` 缺席；clean（日志 offline.log）。
5. rollback commit 不落任何真实分支：主仓库与 implementation worktree 各自 `git branch --contains 9dea7bca…` 均 error: no such commit、`git cat-file -t` fatal——对象只存在于临时 clone，已随 clone 删除。
6. candidate/full/depth-1 checkout 未被触碰（本任务全程只在临时 clone 操作）；临时 clone 已 rm -rf。

## results

exact rollback 独立验证全绿：恰四行 D 删除本片交付、03b/03b1/03c 三入口与 offline 全绿、本入口发现 0 次、rollback commit 不落任何真实分支、clean。本片可无损撤出。
