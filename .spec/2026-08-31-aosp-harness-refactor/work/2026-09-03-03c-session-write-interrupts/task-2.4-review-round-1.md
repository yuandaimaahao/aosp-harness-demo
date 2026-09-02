# Review 报告：03c-session-write-interrupts 任务 2.4「验证 exact rollback」

**结论：PASS**（阻断 0 / 重要 0 / 次要 0）

独立复核，未凭报告转述；所有关键断言均在本地实算或独立重做。只读操作，rollback 重放在 mktemp 沙箱内完成并已删除。

## 1. 红证据复核 — 通过

- `evidence/task-2.4-red.txt`（376B）为固定六行 schema（task/command/expected/rc/stdout_sha256/stderr_sha256）+ assertion 行，措辞与 task-2.3 红文件同构。
- `rc=1`、`expected=rc!=0（报告缺席即红）`，红原因为 `test -s "$WORK/task-2.4-report.md"` 报告缺席，与任务书步骤 1 一致。
- 实算 `task-2.4-logs/red.{stdout,stderr}` sha256 均为 `e3b0c44…b855`（空流），与 red.txt 第 5/6 行逐字一致。
- 文件尾字节为 `stderr}.\n`，单一换行收尾，无尾随字符。

## 2. exact rollback 独立重做 — 通过

在 `tmp=$(mktemp -d)`（`/tmp/tmp.4WN53v2P78`）内独立执行：

- `git clone --no-local <worktree> "$tmp/rollback"` rc0；`git rev-parse HEAD` 输出 `648fe667396e6273f7d497479f16d7daf4560d18`，逐字等于 ACCEPTED_HEAD。
- `git rm common/.harness/lib/session-state-signals.sh tests/test-session-signals.sh` rc0，提交 rollback commit rc0。
- `git diff --name-status HEAD~1 HEAD` 实得恰为两行 `D	common/.harness/lib/session-state-signals.sh` 与 `D	tests/test-session-signals.sh`；与期望 printf 串 `cmp -s` rc0——只删本片两文件，不多不少。

## 3. rollback 后运行门（reviewer 的 rollback clone 内）— 通过

- `bash tests/test-session-snapshot.sh` rc0，stderr 0B，stdout 与 `RESULT PASS  session snapshot safety\n` cmp -s rc0（逐字）。
- `bash tests/test-session-snapshot-assurance.sh` rc0，stderr 0B，stdout 与 `RESULT PASS  session snapshot assurance\n` cmp -s rc0（逐字）。
- `bash ./scripts/check.sh --offline` rc0，stderr 0B；`rg -c 'session write interrupts'` 无匹配（rc1，发现 0 次）；末行逐字 `RESULT PASS  aosp-harness offline quality gate`。
- `test ! -e` 两文件均成立；`git status --porcelain` 空（clean）。
- 用后已 `rm -rf` 临时目录，复查路径不存在。

## 4. 证据一致性 — 通过

- `evidence/task-2.4-evidence.tsv` 25 行逐行实算 sha256+size，全部匹配，零 MISMATCH。
- 报告含六节（task/base/head/files/commands/results），base==head==ACCEPTED_HEAD；末节红阶段证据独占一行，尾部字节 `red.txt.\n`，无尾随字符。
- review 包 `review-648fe667-648fe667.md` sha256 `cbbb1550…47080`，与 2.1/2.2/2.3 evidence.tsv 中同名文件记录逐字一致（同名同 sha256，四次重新生成内容相同）；目录下另三个 review-*.md 为历史任务的 base..head 包，不冲突。
- 日志抽查与报告声明一致：`clone.stderr` 指向 mktemp 路径；`git-rm.stdout` 两行 rm；`rollback-commit.stdout` 显示 `[spec/2026-09-03-03c-session-write-interrupts b6ecfdd] … 2 files changed, 370 deletions(-)`；`rollback-diff.stdout` 恰两行 D；`snapshot.stdout`（37B）/`assurance.stdout`（40B）逐字 PASS 行；`offline.stdout`（471B）无 `session write interrupts`、末行为 quality gate PASS；`status.stdout` 空。日志目录恰 21 个文件。
- rollback commit `b6ecfddfa63ba105439d5b471e643102268eb068`：implementation worktree 与主仓库 `git cat-file -t` 均 fatal（对象不存在），`git branch --contains` 报 no such commit——确认只存在于已删除的 mktemp clone，未落任何真实分支。

## 5. 零 delta 纪律 — 通过

- implementation worktree：HEAD=`648fe667…`（逐字等于 ACCEPTED_HEAD），`git status --porcelain` 空，log 顶端仍为 `648fe66 test(session): add write interrupt signal matrix`，无新提交。
- `find $WORK -name '*candidate*'/-'*full*'/'*depth*'/'*rollback*'` 无残留目录；任务 2.3/2.4 的 tmpdir 记录路径均已不存在（2.1/2.2 无 tmpdir.txt 记录，目录扫描亦无残留）。
- 主仓库 `git status --porcelain` 中的改动均属其他 spec（2026-09-01-aosp-feature-minimal-checkout）与 03c spec 文档/ledger 的 controller 活动及既有未跟踪 work 目录；本任务无提交、无源码改动，验收资产均在未跟踪 work 目录内，无本任务引入的新变化。

## Findings

无。
