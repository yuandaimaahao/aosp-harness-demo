# Review 报告：任务 2.3 验证真实 depth-1 checkout

**结论：PASS**（阻断 0 / 重要 0 / 次要 0）

- 任务： 2026-09-03-03c-session-write-interrupts / task-2.3（R7，零 delta controller 验证）
- ACCEPTED_HEAD: `648fe667396e6273f7d497479f16d7daf4560d18`
- Reviewer：独立 agent（与实现者无共享上下文，全部结论经实算复核）

## 1. 红证据复核 — 通过

- `evidence/task-2.3-red.txt` 恰 7 行：六行 schema（`task=`/`command=`/`expected=`/`rc=`/`stdout_sha256=`/`stderr_sha256=`）+ 末行 `assertion=`，符合固定格式。
- `rc=1`；`stdout_sha256=stderr_sha256=e3b0c442...7852b855`（空流 sha256）。实算 `task-2.3-logs/red.stdout` 与 `red.stderr` 均为 0B，sha256 与声明逐字一致。
- 红原因为报告缺席：`command=test -s $WORK/task-2.3-report.md`，`test -s` 对缺席文件返 1，且日志时间戳（red.stdout 04:34）早于报告落盘（04:37），时序自洽。

## 2. depth-1 checkout 独立重做 — 通过（全部实算，非转述）

在自有 `mktemp -d` 内执行 `git clone --depth 1 "file://$IMPLEMENTATION_WORKTREE" "$tmp/depth1"`（file:// 形式）：

- clone rc=0；`git rev-parse HEAD` = `648fe667396e6273f7d497479f16d7daf4560d18`，逐字等于 ACCEPTED_HEAD。
- `git rev-list --count HEAD` = 1，恰为 1。
- `test -s .git/shallow` 成立，内容恰为一行 `648fe667396e6273f7d497479f16d7daf4560d18`，证明真浅克隆。
- 用后 `rm -rf` 删除，`test -e` 确认无残留。

## 3. 运行门独立重跑（reviewer 的 depth1 内）— 通过

- `bash ./tests/test-session-signals.sh`：rc=0；`printf 'RESULT PASS  session write interrupts\n' | cmp -s - out` 逐字一致；stderr 恰 0B。
- `bash ./scripts/check.sh --offline`：rc=0；stderr 0B；`rg -c 'RESULT PASS  session write interrupts'` = 1（自动发现恰一次）；末行逐字 `RESULT PASS  aosp-harness offline quality gate`。

## 4. 上游七文件不变量 — 通过

- reviewer 的 depth1 内：测试+offline 运行前 `sha256sum $UPSTREAM7 > before.sha`，运行后 `sha256sum -c` 七行全 `OK`，测试前后不变。
- `git status --porcelain` 0 行、`git diff` 0 字节，depth1 全程 clean。
- 实现者侧证据一致：`task-2.3-logs/upstream-before.sha` 七行与 `sha-after.stdout` 七行 `OK` 对应，哈希值与 reviewer 实算的上游文件 sha 逐一相同（抽查 snapshot 模块 `17dfa03a...` 一致）。

## 5. 证据一致性 — 通过

- `task-2.3-evidence.tsv` 恰 22 行；逐行实算 `sha256sum` 与 `stat -c%s`，22/22 全部匹配（ok=22 bad=0）。
- report 含固定六节 task/base/head/files/commands/results，base=head=ACCEPTED_HEAD 且注明零 delta 口径；末行红阶段证据路径独占一行，以单个 `\n` 结尾、无尾随字符（od -c 核实）。
- review 包 `review-648fe667-648fe667.md` 与 2.1/2.2 同名同 sha256：三个 evidence.tsv（2.1/2.2/2.3）记录均为 `cbbb1550...`（106B），当前文件实算同值；内容为空 commit 列表/空 diff 的 base==head 包，正确。
- 日志抽查：`clone.stderr`（45B，`Cloning into ...`）、`default.stdout`（38B 固定摘要）、`offline.stdout`（509B，本入口摘要恰 1 次、末行 quality gate PASS）、`status/diff/sha-after` 空/OK，均与报告「commands/results」声明逐条一致。
- manifest 当前 4 行（至 task-2.2），task-2.3 行按流程待本 review PASS 后由 controller 追加，时序正确。

## 6. 零 delta 纪律 — 通过

- implementation worktree：`git rev-parse HEAD` = ACCEPTED_HEAD；`git status --porcelain` 空；`git log` 顶端仍为 `648fe66 test(session): ...`（任务 1.2 提交），本任务无新提交。
- 临时残留：实现者记录的 `TMP=/tmp/tmp.ZIvRAdjpeS` 已不存在；reviewer 的 clone 目录用后删除并确认；worktree 内无 `.count.*`/mutant/depth1 残留目录。

## Findings

无。

## 备注（非 finding）

- red.txt 的 `command=` 行以字面 `$WORK` 记录（未展开），属记录风格，rc/sha256 实算一致，不影响证据效力；与 2.1/2.2 同口径。
