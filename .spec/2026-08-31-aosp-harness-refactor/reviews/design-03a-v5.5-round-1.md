# 03a design/tasks v5.5 review — round 1

Reviewer: `review_design_03a_r1`

Verdict: **NEEDS_CHANGES** — blocker 0 / important 2 / minor 0

## Findings

1. 只做全文件phase occurrence会允许把调用移入dead/unrelated代码而假绿；必须提取`open_managed`函数体，并证明三个phase在全文件与该函数体内各一次。
2. tasks直接调用PATH中的工具，未证明版本为sizing使用的shfmt 3.14.0/ShellCheck 0.11.0；必须先精确断言版本或使用固定绝对路径。

task3历史与task4最终删除可审计，manifest连续链可保持。
