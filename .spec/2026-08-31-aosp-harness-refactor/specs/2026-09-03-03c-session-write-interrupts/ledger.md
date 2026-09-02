# ledger — spec: 2026-09-03-03c-session-write-interrupts
# plan: （PLAN.md 路径与版本；小需求写「无」）
# worktree: （工作区路径）

> 会话压缩之后，「我刚做完什么」的记忆不可靠。这份文件和 git log 才是。
> `任务 N: 完成` 是唯一的恢复锚点。

---
- requirements round1：PASS（阻断0/重要0/次要2），报告：reviews/requirements-03c-session-write-interrupts-round-1.md。次要1（R4「child的process-group」在非job-control shell下如何建立/转发而不打回facade自身）留门③ design正面回答；次要2（R6「flag」缩写指代--dependency-absent）措辞紧凑、不改。起草期一次ID修正：NEXT按PLAN第53行定为03d-session-remove-prune并改为日期无关机械形式（控制器指示有误、起草者按指示落地后由控制器复核PLAN发现，唤回修订）。check-req/check-criteria/check-analyze/check-plan与diff --check全rc=0。
- 自动通过: 门② requirements按autopilot通过。R1–R8全[计划]来源、frontmatter五字段+已由用户确认、主验证命令与验收清单/四不变量（含上游七文件同集）闭合；独立review一轮即PASS；无[推断]/[默认]待问项。如果错了代价：门②误放会让design建立在错口径上——reviewer逐字对照PLAN/DECISIONS/实际代码排除。
