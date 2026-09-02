# ledger — spec: 2026-09-03-03c-session-write-interrupts
# plan: （PLAN.md 路径与版本；小需求写「无」）
# worktree: （工作区路径）

> 会话压缩之后，「我刚做完什么」的记忆不可靠。这份文件和 git log 才是。
> `任务 N: 完成` 是唯一的恢复锚点。

---
- requirements round1：PASS（阻断0/重要0/次要2），报告：reviews/requirements-03c-session-write-interrupts-round-1.md。次要1（R4「child的process-group」在非job-control shell下如何建立/转发而不打回facade自身）留门③ design正面回答；次要2（R6「flag」缩写指代--dependency-absent）措辞紧凑、不改。起草期一次ID修正：NEXT按PLAN第53行定为03d下一切片（规范ID全名见PLAN，按tasks裁定6本片ledger不逐字记录）并改为日期无关机械形式（控制器指示有误、起草者按指示落地后由控制器复核PLAN发现，唤回修订）。check-req/check-criteria/check-analyze/check-plan与diff --check全rc=0。
- 自动通过: 门② requirements按autopilot通过。R1–R8全[计划]来源、frontmatter五字段+已由用户确认、主验证命令与验收清单/四不变量（含上游七文件同集）闭合；独立review一轮即PASS；无[推断]/[默认]待问项。如果错了代价：门②误放会让design建立在错口径上——reviewer逐字对照PLAN/DECISIONS/实际代码排除。
- design round1：PASS（阻断0/重要0/次要4），报告：reviews/design-03c-session-write-interrupts-round-1.md。机制正确性经reviewer实际代码逐行核对+mktemp内7组bash语义实测：正PID单点转发覆盖义务（worker稳态无孙进程）、trap先装+pending锁存补转发无窗、first-signal-wins双侧幂等、wait循环rc>128&&kill -0无死锁、不打回facade自身、spawn-gap mutant经barrier封闭无假绿路径；setsid 2.39.3/set -m泄漏两条实测声明独立复跑证实；门②次要1已正面回答。四条次要：trap摘除不恢复调用方trap（留03d留意）、sizing纯分解预算无runnable prototype（numstat≤400执行期兜底）、「无孙进程」系稳态事实（措辞备注）、mermaid未经渲染器（离线无mermaid-cli，人工核对语法）。如果错了代价：机制误判会让03c执行期返工甚至假绿——reviewer已实测排除。
- 自动通过: 门③ design按autopilot通过。九节齐全、R映射8/8、frontmatter消费/产出逐字一致、mermaid 3图人工核对合法、sizing 45+345=390≤400闭合、文件清单与验收资产闭合；check-req/check-criteria/check-analyze对requirements仍rc=0、diff --check rc=0；独立review一轮即PASS。
- tasks round1：NEEDS_CHANGES（阻断1/重要1/次要3），报告：reviews/tasks-03c-session-write-interrupts-round-1.md。B1=任务1.2步骤7累计断言误用$TASK_BASE..$TASK_HEAD（该范围只含本任务单提交、恰两文件断言必失败）；I1=裁定6禁令范围与任务2.5报告commands字段冲突；M1=顺序门ls依赖无nullglob前提未写明；M2=`! ls && test`在set -e下短路陷阱；M3=mktemp变量衔接不明。唤回原起草者修复后交全新reviewer。
- tasks round2：PASS（阻断0/重要0/次要0），报告：reviews/tasks-03c-session-write-interrupts-round-2.md。B1改$BASE_SHA口径并内联理由、I1裁定6收窄到scoped rg三类文件+报告/日志用"$NEXT"间接形式、M1前提写明、M2拆独立命令、M3统一$tmp，逐条闭合；全量重读无新增。范围外观察2条备查（R8 nullglob措辞、$tmp既有风格）。门④落盘期控制器自查发现本ledger第9行（门②时写入、早于裁定6）逐字含03d规范ID全名，属任务2.5 scoped rg域内自命中隐患，已改为间接形式并复核全域（九份ledger+五份execution-base.env）仅此一处。如果错了代价：B1不修会让任务1.2提交门必然假红、裁定6域不收窄会让实现者在证据义务与禁令间二选一踩坑、ledger字面残留会让任务2.5/2.6顺序门自命中假红——均已排除。
- 自动通过: 门④ tasks按autopilot通过。八任务（1.1交付≤45行、1.2测试≤345行、2.1–2.6零delta）与03b/03b1同构；R1–R8映射完整、exact两文件+sizing 390≤400、探针恰2处、mutant双设计、顺序门日期无关、裁定6/7防自命中与inert滥用；check-tasks rc=0；round1五findings全修、round2全新reviewer PASS。如果错了代价：tasks口径错会让执行期八任务连环返工——两轮独立review+控制器域内自查排除。
