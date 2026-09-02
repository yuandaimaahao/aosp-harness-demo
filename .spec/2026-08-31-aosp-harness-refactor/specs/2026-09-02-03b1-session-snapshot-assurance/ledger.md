# ledger — spec: 2026-09-02-03b1-session-snapshot-assurance
# plan: （PLAN.md 路径与版本；小需求写「无」）
# worktree: （工作区路径）

> 会话压缩之后，「我刚做完什么」的记忆不可靠。这份文件和 git log 才是。
> `任务 N: 完成` 是唯一的恢复锚点。

---
- requirements round1：PASS（阻断0/重要1/次要3），报告：reviews/requirements-03b1-session-snapshot-assurance-round-1.md。重要F1（R9 SHA集与不变量4 diff集不一致且未覆盖上游六文件、相对03b倒退）按「前两级进修复循环」处理：唤回起草者统一为六文件全集并顺手修三条次要（inert摘要逐字、R10 depth-1字样、R2协议损坏机械定义）。
- requirements round2：re-review PASS（阻断0/重要0/次要1），报告：reviews/requirements-03b1-session-snapshot-assurance-round-2.md。剩余次要：03c启动门枚举缺「full/depth-1/offline与回滚证据入ledger」字样，留到design/tasks阶段对齐措辞，验收时重报。
- prototype实跑：commit cbdbdde的snapshot-assurance-r1.sh（308行/240项断言）在main ffddb95上以main provider实跑rc0、stdout字节精确RESULT PASS  session snapshot assurance、stderr空；shfmt v3.14.0/ShellCheck 0.11.0/bash-n均rc0（reviewer独立复核一致）。
- 自动通过: 门② requirements按autopilot通过。R1–R10全[计划]来源、frontmatter五字段+已由用户确认、主验证命令与验收清单/四不变量闭合；check-req/check-criteria/check-analyze/check-plan与git diff --check全PASS；两轮独立review最终PASS，无[推断]/[默认]待问项，提问数0未超预算。
