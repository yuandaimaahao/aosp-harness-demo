# Review: task 2.6 03d-session-remove-prune round 1
verdict: PASS
阻断: 0 / 重要: 0 / 次要: 2

## findings
- [次要1] 任务单给出的 before.sha 路径（$W/task-2.1-logs/before.sha）与实际位置（$W/evidence/task-2.1-logs/before.sha）不一致，且任务单描述的九文件清单与 tasks.md UPSTREAM9/before.sha 实际清单不同（实际含 path-race 两文件、不含 03b/03c coverage fragment）。已按 before.sha 为准核验，不影响结论。
- [次要2] 红相 rc=1 无法原地复跑（acceptance 报告已存在），与命令语义一致，属零 delta 任务固有性质，备案。

## 核对记录

A. manifest 机械核验：当前 8 行全过（六列、行号、task- 前缀按序、40 位 hex、reviewer 非空、全 PASS、相邻连续、首行 base=d8c2baae、第 8 行 head=388a83d5）；/tmp 副本追加计划第 9 行后跑 tasks.md 步骤 4 原样 awk → exit 0。git log 自 BASE 起恰三提交线性链 0bb53a04→df38c345→388a83d5，与 manifest 行 1–3 一致。

B. acceptance 报告抽验：accepted HEAD/BASE/行数 110/46/204/18/commit 0bb53a04/df38c345/388a83d5 与源报告一致；active 摘要双空格字面、checks=72、argv 非法表五行、五 fixture 取值与 task-1.3 逐字一致；双 anchor 与两 mutant（failures=3/1）描述一致；exact4/378、五路验证数字（full=198、depth-1=1、rollback 恰四行 D、顺序门 17 文件）与 2.1–2.5 一致；六类 inert fixture 与 coverage fragment R6 行一致。

C. 终门重跑（worktree 只读复跑）：check-tasks/check-req/check-criteria/check-analyze 各 rc0；default rc0 stdout 27B cmp 逐字一致 stderr 0B；offline rc0 发现恰 1 次末行 PASS；git diff --check rc0、跑后 clean；name-only 恰 EXACT4、numstat=378≤400、上游九文件范围为空；03e 顺序门五门全过（worktree 16 文件与仓库根 17 文件两处 scoped rg 均零匹配）。

D. 文书契约：red 恰 7 行、rc=1 语义一致；evidence.tsv 4/4 FRESH；两份报告红证据路径行独占零尾随空白；acceptance 报告 rg '03e-claude' 零命中。
