# ledger — spec: 2026-09-03-03c-session-write-interrupts
# plan: （PLAN.md 路径与版本；小需求写「无」）
# worktree: （工作区路径）

> 会话压缩之后，「我刚做完什么」的记忆不可靠。这份文件和 git log 才是。
> `任务 N: 完成` 是唯一的恢复锚点。

---
- requirements round1：PASS（阻断0/重要0/次要2），报告：reviews/requirements-03c-session-write-interrupts-round-1.md。次要1（R4「child的process-group」在非job-control shell下如何建立/转发而不打回facade自身）留门③ design正面回答；次要2（R6「flag」缩写指代--dependency-absent）措辞紧凑、不改。起草期一次ID修正：NEXT按PLAN第53行定为03d-session-remove-prune并改为日期无关机械形式（控制器指示有误、起草者按指示落地后由控制器复核PLAN发现，唤回修订）。check-req/check-criteria/check-analyze/check-plan与diff --check全rc=0。
- 自动通过: 门② requirements按autopilot通过。R1–R8全[计划]来源、frontmatter五字段+已由用户确认、主验证命令与验收清单/四不变量（含上游七文件同集）闭合；独立review一轮即PASS；无[推断]/[默认]待问项。如果错了代价：门②误放会让design建立在错口径上——reviewer逐字对照PLAN/DECISIONS/实际代码排除。
- design round1：PASS（阻断0/重要0/次要4），报告：reviews/design-03c-session-write-interrupts-round-1.md。机制正确性经reviewer实际代码逐行核对+mktemp内7组bash语义实测：正PID单点转发覆盖义务（worker稳态无孙进程）、trap先装+pending锁存补转发无窗、first-signal-wins双侧幂等、wait循环rc>128&&kill -0无死锁、不打回facade自身、spawn-gap mutant经barrier封闭无假绿路径；setsid 2.39.3/set -m泄漏两条实测声明独立复跑证实；门②次要1已正面回答。四条次要：trap摘除不恢复调用方trap（留03d留意）、sizing纯分解预算无runnable prototype（numstat≤400执行期兜底）、「无孙进程」系稳态事实（措辞备注）、mermaid未经渲染器（离线无mermaid-cli，人工核对语法）。如果错了代价：机制误判会让03c执行期返工甚至假绿——reviewer已实测排除。
- 自动通过: 门③ design按autopilot通过。九节齐全、R映射8/8、frontmatter消费/产出逐字一致、mermaid 3图人工核对合法、sizing 45+345=390≤400闭合、文件清单与验收资产闭合；check-req/check-criteria/check-analyze对requirements仍rc=0、diff --check rc=0；独立review一轮即PASS。
