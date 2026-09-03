# ledger — spec: 2026-09-03-03e-claude-session-lifecycle
# plan: （PLAN.md 路径与版本；小需求写「无」）
# worktree: （工作区路径）

> 会话压缩之后，「我刚做完什么」的记忆不可靠。这份文件和 git log 才是。
> `任务 N: 完成` 是唯一的恢复锚点。

---
- requirements round1：NEEDS_CHANGES（阻断3/重要1/次要4），报告：reviews/requirements-03e-claude-session-lifecycle-round-1.md。B1=R8 CLI 缺 PLAN:223-234 逐字要求的六值 --session-provider-fixture；B2=R3/R5 静默推翻 DECISIONS 已确认口径（project-id 应为物理根完整 SHA-256、SessionStart 按 source 分级 compact 缺失报错、SessionEnd 缺事件名/session ID/reason 校验、2.1.234 未承接）；B3=R2「任一调用非零→legacy」与设计内码（read 缺失 3/write 同值 0/remove 缺失 0）自相矛盾；I1=fragment 排除引不存在的既定口径；S1–S4 引文/枚举/frontmatter/引用四处文稿问题。唤回原起草者修复后交全新 reviewer。如果错了代价：B1 让 PLAN 固定回滚命令对本入口全 rc1、P2 独立回滚失效；B2 让 08/10 按旧口径漂移；B3 让 v1 建基线成死代码。
- requirements round2：NEEDS_CHANGES（阻断0/重要2/次要1），报告：reviews/requirements-03e-claude-session-lifecycle-round-2.md。round1 全闭合，但修订引入：N1=R9 依据累加漏算 03b1 自身 assurance 交付（6+2+3=11≠12）；N2=SessionEnd 事件名非法时 R2/R5 之间行为未唯一确定；N3=事件名非法负向用例未入 R8 必覆盖集。唤回原起草者修复后交全新 reviewer。如果错了代价：N2 不修法会让实现者无法唯一确定 hook 行为、验收判定靠自由裁量。
- requirements round3：PASS（阻断0/重要0/次要2），报告：reviews/requirements-03e-claude-session-lifecycle-round-3.md。N1/N2/N3 全部真实闭合且 N2 修法未制造新三路径矛盾（非法输入→marker+rc0+不删任何状态；校验通过+v1→remove 幂等；校验通过+legacy→删全局快照，删除子句以校验通过为前置）；R1–R10 依据逐字复核、字面量六处一致、R6 与现状逐字吻合、机械检查全 rc0。次要 S1（SessionEnd 负向枚举缺 session ID 非法）落盘期已顺手补全；S2（partial 枚举不完备、R2 为超集行为唯一）备案。如果错了代价：门②误放会让 design 建在错口径上——三轮独立 review+逐字对照 PLAN/DECISIONS/现状代码排除。
- 自动通过: 门② requirements按autopilot通过。R1–R10全[计划]来源、frontmatter五字段+已由用户确认（确认依据引DECISIONS 03d验收行满足03e启动门）、主验证命令`bash ./tests/test-claude-session-lifecycle.sh`期望逐字节`RESULT PASS  claude session lifecycle\n`、验收清单10条与不变量4项（上游十二文件零变更命令逐字列十二路径、SessionStart/SessionEnd全路径rc0且UPS仅v1漂移rc2、demo mktemp外净变更0、offline回归0失败）闭合；round1三条阻断+round2两条重要全修、round3全新reviewer PASS；无[推断]/[默认]待问项。实质裁决记录：compat marker字面量定死为`compat: session-provider=legacy`（对齐PLAN:188 08行，PLAN:187未给03e字面量已注明）；fixture flag六值（PLAN:223-234逐字）；上游十二文件=03b1七+03c两+03d三shell，03d fragment为文档性资产由exact六文件diff门覆盖防改不计入SHA集。NEXT顺序门目标为04下一切片（规范ID全名见PLAN第55行，本片ledger不逐字记录）。如果错了代价：门②误放会让design建立在错口径上——reviewer逐字对照PLAN/DECISIONS/实际代码排除。
