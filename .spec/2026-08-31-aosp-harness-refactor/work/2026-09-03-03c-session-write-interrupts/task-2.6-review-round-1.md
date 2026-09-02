# Review 报告：任务 2.6（步骤 1–2）收敛 manifest、ledger 与终交付

**结论：PASS**（阻断 0 / 重要 0 / 次要观察 2，均不违反任务书，不阻塞）

- 审查对象：`$WORK` 下任务 2.6 步骤 1–2 交付（红证据 + task-2.6-report.md + acceptance-report.md + evidence package + review 包）
- ACCEPTED_HEAD=`648fe667396e6273f7d497479f16d7daf4560d18`，BASE_SHA=`c9c82264b3f819a6a6449a0242e102e97b35c3b0`
- 验收权威：task-2.6-brief.md 任务 2.6 节步骤 1–2（步骤 3–6 归 controller，实现者声明未执行，属实——manifest 仍 7 行、tasks.md 任务 2.6 状态「未完成」）

## 1. 红证据复核 — 通过

- `evidence/task-2.6-red.txt` 共 7 行：固定六行 schema（`task=/command=/expected=/rc=/stdout_sha256=/stderr_sha256=`）+ 末行 `assertion=`，schema 与 tasks.md 固定格式一致。
- `rc=1`、`expected=rc!=0（报告缺席即红）`，红原因为 acceptance 报告缺席，与 brief 步骤 1 的 `test -s "$WORK/acceptance/acceptance-report.md"` 红条件一致。
- stdout/stderr sha256 均为 `e3b0c44...b855`（空串 sha256），与落盘日志实算一致：`evidence/task-2.6-logs/red.stdout`、`red.stderr` 均 0B。
- 时序自洽：red 日志 mtime `05:12:37.800` < acceptance-report.md mtime `05:16:07.456`（红先于绿）。rc=1 无法在事后重放（报告已存在），但记录值、空日志与缺席语义三者自洽。

## 2. acceptance 报告事实核对（对前七任务报告与日志原文逐条抽验）— 通过

- **accepted HEAD**：报告声明 `648fe66...`「任务 1.2 交付、任务 2.1 审计后固定」——与 task-1.2-report.md（TASK_HEAD=648fe66，amend 单提交）、task-2.1-report.md（声明固定）、manifest 第 3 行 base=head=648fe66 一致。✔
- **checks N=139**：task-1.2-report.md 记 `checks=139`（default/all 逐字一致）；日志实据 `evidence/task-1.2-logs/count-default.stderr` 与 `count-all.stderr` 内容均为 `checks=139`。✔
- **default 固定摘要逐字**：`RESULT PASS  session write interrupts\n`（cmp -s）、stderr 0B——与 task-1.2/2.1 报告一致，且 reviewer 已在 worktree 内独立复跑确认（见第 7 节）。✔
- **双 anchor 机制**：`SIGNALS_MODULE` 注入 probe 副本、BEFORE_SPAWN/AFTER_WAIT 双 marker 包装、`HARNESS_REFORWARD_LOG` 前向观测日志——与 task-1.2-report.md「files/commands」节一致。✔
- **F1 修复**：前向观测日志、driver 轮询放行、timeout 降为兜底、flake 实证 default/all 各 10 连跑全 rc0——与 task-1.2-report.md 一致（flake 日志 `flake-default-01..10.*`/`flake-all-01..10.*` 在场）。absent-beta 析取在源报告有、acceptance 报告未复述（见次要观察 O1，非误述）。✔
- **两 mutant 失败签名**：对 `task-1.2-logs/mutant-a.stdout/stderr` 实算——`RESULT FAIL ... checks=139 failures=6`，6 条 FAIL 恰为 3 个 gap 行 × 2 项（`reforward signal want=HUP|INT|TERM got=missing`、`reforward pid numeric want=yes got=no`），无 hang、无 124；mutant-b `failures=15`，12 条 `latched rc` FAIL（facade/gap/wait/group × HUP/INT/TERM，HUP→143、INT→143、TERM→129）+ 3 条 gap reforward 记录。与 acceptance 报告逐字吻合。✔
- **exact2/numstat 370**：task-1.2 与 task-2.1 两处记录一致（两文件、370 ≤ 400、UPSTREAM7 空）。✔
- **五路结论**：candidate（2.1，工具版本逐字/offline 恰 1 次/上游七文件 SHA 不变）、full（2.2，HEAD 逐字等于 ACCEPTED_HEAD）、depth-1（2.3，count=1、.git/shallow 非空）、rollback（2.4，name-status 恰两行 D、03b/03b1 摘要逐字、本入口发现 0 次）、03d 顺序门（2.5，15 个限定域文件 scoped rg 零匹配）——逐路与源报告一致。✔
- **终交付锚点** `session-signals-facade-v1`：与 tasks.md 裁定 5、requirements frontmatter 一致。✔
- 未发现任何与源报告不符的转述。

## 3. requirements 验收标准覆盖 — 通过（含两点完整性观察）

- 主验证命令（`bash ./tests/test-session-signals.sh`，rc0/stdout 逐字/stderr 空）✔；active 证据（dependency-present checks=139 vs inert checks=0）✔；exact2/400 ✔；03d 顺序门（间接措辞，入 ledger 前资产物理缺席）✔；candidate/full/depth-1/rollback 验收清单 ✔；manifest/工具版本/`git diff --check`/clean ✔。
- 观察 O2（次要）：requirements 四不变量中「winner 指纹不变」「owned temp 清零」两条与「inert PASS 不作本片验收证据」一句，acceptance 报告未逐字复述（task-1.2-report.md 有完整记录；acceptance 报告第 44 行以「dependency-present active 证据…入 ledger 前资产物理缺席成立」隐含 inert 不解除顺序门）。brief 步骤 2 规定的内容清单（accepted HEAD、active 摘要、双 anchor、两 mutant、checks 口径、exact2/400）已全部覆盖，故不构成违反，仅作完整性提示。

## 4. 裁定 6 与文字纪律 — 通过

- 对 task-2.6-report.md、acceptance-report.md、task-2.6-red.txt、task-2.6-logs/* 全量 grep `03d-session-remove-prune`：**零匹配**。
- 顺序门相关内容一律写「03d 顺序门」「下一切片」；task-2.6 报告 commands 节明确记录命令以 `"$NEXT"` 间接形式引用、不内联字面全名。✔

## 5. 证据一致性 — 通过

- `task-2.6-evidence.tsv` 13 行逐行实算 `sha256sum` + `stat -c%s`：**13/13 OK**（review 包、brief、acceptance 报告、8 个日志、red.txt、report）。
- task-2.6-report.md 恰含 task/base/head/files/commands/results 六节；末行红阶段证据独占行以 `\n` 结束、无尾随空白（od 验证，两份报告及 red.txt 均无行尾空格）。
- review 包 `review-648fe667-648fe667.md` sha256=`cbbb1550...`、106B——与 2.1/2.2/2.3/2.4/2.5 各自 evidence.tsv 记录的同名包 sha256 **逐一相同**（base==head 零 diff，重新生成内容一致）。
- 前七任务文件未被本任务改动：前七任务 report 与 review-manifest.tsv mtime 全部早于本任务红阶段（最晚 manifest 05:10:30 < red 05:12:37）；且前七任务各自的 evidence.tsv 全量自证实算通过（0 mismatch），内容与前轮 review 时一致。

## 6. 零 delta 纪律 — 通过

- worktree `git rev-parse HEAD` = `648fe667396e6273f7d497479f16d7daf4560d18`（与 ACCEPTED_HEAD 逐字一致，亦与 `head.stdout` 41B 落盘一致）。
- `git status --porcelain` 0 行（clean）；`git diff --check` 通过。
- `git log` 顶部即 `648fe66 test(session): add write interrupt signal matrix`，无新提交；manifest 保持 7 行（第 8 行追加为 controller 步骤 3，本任务未越权执行）。

## 7. 运行门抽验（worktree 内实跑）— 通过

```
$ bash ./tests/test-session-signals.sh >out 2>err
rc=0
$ printf 'RESULT PASS  session write interrupts\n' | cmp -s - out   → STDOUT-VERBATIM-OK
err 字节数=0
跑后 git status --porcelain = 0 行（无残留）
```

终交付锚点 `session-signals-facade-v1` 的默认入口在 ACCEPTED_HEAD 上实际可跑、输出逐字符合固定摘要。

## Findings

- 无阻断、无重要 finding。
- 次要观察 O1：acceptance 报告未复述 F1 修复的 absent-beta 析取（gap 行 winner 断言「absent 或 beta 均可证」，见 task-1.2-report.md「files」节）。非误述，brief 步骤 2 内容清单未要求，供 controller 写 ledger 完成锚点时参考。
- 次要观察 O2：acceptance 报告未逐字复述四不变量中的 winner 指纹/owned-temp 两条及「inert 不作验收证据」一句（隐含有覆盖，见第 3 节）。不违反 brief，供 controller 步骤 5 写 ledger 时补齐。

## 复现命令摘要

```bash
WORK=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03c-session-write-interrupts
# 证据包实算
while IFS=$'\t' read -r p s b; do [ "$(sha256sum "$p"|cut -d' ' -f1)" = "$s" ] && [ "$(stat -c%s "$p")" = "$b" ] || echo MISMATCH "$p"; done < "$WORK/evidence/task-2.6-evidence.tsv"
# 零 delta 与运行门
cd "$WORK/worktree" && git rev-parse HEAD && git status --porcelain | wc -l \
  && bash ./tests/test-session-signals.sh >out 2>err && printf 'RESULT PASS  session write interrupts\n' | cmp -s - out && test ! -s err
# 文字纪律
rg 03d-session-remove-prune "$WORK/task-2.6-report.md" "$WORK/acceptance/acceptance-report.md"  # 期望零匹配
```
