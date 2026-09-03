---
project: 2026-08-31-aosp-harness-refactor
kind: large
phase: spec
phase_status: in_progress
basis: 门③ design round2 PASS（reviews/design-03e-claude-session-lifecycle-round-2.md），ledger
  已记 round1/round2 与自动通过行
updated: '2026-09-03T11:40:44+08:00'
current_spec: 2026-09-03-03e-claude-session-lifecycle
spec_stage: tasks
mode: standard
workflow: requirements-first
---
# 2026-08-31-aosp-harness-refactor 状态

## 待确认项

当前门禁（门①）：请完整审查 `PLAN.md` v4，确认 10 个 spec 的拆法、顺序和默认架构口径。默认口径是保留三个顶层 Demo/入口，但将可运行公共逻辑收敛到 `common/.harness`。

调研范围已确认（2026-08-31）。

调研范围：

查：

- 工程定位、目录与模块边界、主要 harness 执行链路，以及文档与实际行为的一致性。
- 构建、配置、依赖和运行环境的可复现性、可移植性与失败反馈。
- 核心代码的职责分离、接口设计、扩展性、错误处理、资源生命周期、并发安全、日志与可观测性。
- 对 AOSP/ADB/设备交互边界的健壮性，包括命令、超时、重试、清理、隔离与可诊断性。
- 现有单元、集成和端到端测试的覆盖缺口、稳定性、可离线执行性，以及 CI/静态检查门禁。
- 安全性和工程卫生：秘密、输入边界、shell 调用、临时文件、平台兼容、重复代码、死代码与命名一致性。
- 形成有证据的缺陷清单、风险与优先级，并拆分成可独立验收的重构/完善规格；后续实施以保持现有对外行为为默认约束。

不查：

- 仓库之外的完整 AOSP 源码、厂商私有分区或具体产品定制实现，除非本工程的明确依赖边界必须核对。
- 需要真实量产设备、专用硬件或外部设备农场才能完成的性能/兼容性结论；这些只记为待验证项。
- 无证据的全量技术栈替换、新产品功能扩张，以及与 harness 质量无关的 AOSP 平台改造。
- 发布、提交、推送或外部系统变更；本次只修改并验证当前工作区。

> 这份文件的 frontmatter 是机器读的唯一真相。正文是给人看的流水账。
> 每次决定下一步动作之前重读本文件，不要靠会话记忆判断当前在第几步。

## 阶段流水

| 时间 | 从 | 到 | 依据 |
|---|---|---|---|
| 2026-08-31T19:03:07+08:00 | — | research | 分型完成：large，待确认调研范围 |
| 2026-08-31T19:10:48+08:00 | research/awaiting_user | research/in_progress | 用户确认调研范围 |
| 2026-08-31T19:40:52+08:00 | research | plan | 调研完成：report 已通过校验 |
| 2026-08-31T20:48:20+08:00 | plan/in_progress | plan/awaiting_user | PLAN v4 通过机械校验；三轮独立 agent review 达熔断上限，剩余 finding 已裁定落盘；等待门①人工拍板 |
| 2026-08-31T20:59:22+08:00 | plan | select | 门①通过：用户确认 PLAN v4 与默认架构口径，并要求后续 autopilot |
| 2026-08-31T21:00:21+08:00 | select | spec/requirements | new-spec.sh 建了 2026-08-31-01-device-safety |
| 2026-08-31T21:35:11+08:00 | spec/requirements | spec/design | 门② autopilot：PLAN v4 已由用户确认；三轮独立 requirements review 已完成，所有承重项已修复或在 fix_loop_max=3 后裁定；check-req、check-criteria、check-analyze 均通过 |
| 2026-08-31T21:52:54+08:00 | spec/design | spec/tasks | 门③ autopilot：design 八节和文件清单齐全，R1-R7 全覆盖，产出签名逐字一致；全新上下文 reviewer 对规格符合性与质量均 PASS，0 阻断、0 重要 |
| 2026-08-31T22:36:30+08:00 | spec/tasks | spec/execute | 门④ autopilot：三轮独立 tasks review 完成；所有承重项已修复或在 fix_loop_max=3 后裁定；测试与生产拆成 11 个可独立红绿的小任务，check-tasks/check-req/check-criteria 均通过 |
| 2026-09-01T00:00:59+08:00 | spec/execute | spec/accept | 任务 1.1-1.8 与 2.1-2.3 全部有实现报告、红阶段证据和独立 diff review；熔断裁定已记 ledger；完整 device-safety 回归 exit 0 且末行为 RESULT PASS  device safety |
| 2026-09-01T00:39:35+08:00 | spec/accept | retro | 01-device-safety 验收通过：R1-R7、不变量、收敛与 6 文件/320 行预算全部通过；已快进合入 main 并更新 PLAN/DECISIONS |
| 2026-09-01T00:40:12+08:00 | retro | select | 01-device-safety 复盘五问均否：PLAN 无需调整；下一片仍为 02-offline-quality-gate |
| 2026-09-01T00:41:21+08:00 | select | spec/requirements | new-spec.sh 建了 2026-09-01-02-offline-quality-gate |
| 2026-09-01T01:47:59+08:00 | spec/requirements | spec/design | 门② autopilot：requirements 三轮独立审查最终 PASS，R1-R9/不变量/摘要/预算闭合，三项机械检查全通过 |
| 2026-09-01T02:19:09+08:00 | spec/design | spec/tasks | 门③ autopilot：design 独立复审 PASS（0 阻断/0 重要/0 次要），八节、R1-R9 映射、接口签名、Mermaid、6 文件/387 行预算与机械检查全部通过 |
| 2026-09-01T03:19:43+08:00 | spec/tasks | spec/execute | 门④ autopilot：三轮独立 tasks review 已达 fix_loop_max=3；前两轮 findings 闭合，第三轮 3 重要/1 次要均按熔断规则采纳修复并记录错误代价；check-tasks/check-req/check-criteria/git diff --check 全通过，6 个串行任务覆盖 R1-R9 与 6 文件/387 行硬门 |
| 2026-09-01T10:59:08+08:00 | spec/execute | spec/accept | 六个串行任务全部 DONE：每任务均有红阶段证据、实现报告、普通 Conventional Commit 与全新上下文独立 diff review；所有阻断/重要 findings 已修复并 re-review PASS，sync-ledger 通过，隔离 worktree clean |
| 2026-09-01T11:02:41+08:00 | spec/accept | retro | 02-offline-quality-gate 验收通过：R1-R9/三条不变量/六文件289行/两个固定摘要/收敛检查均通过；source 已快进合入 main，work 证据已单独提交，PLAN/DECISIONS 已更新 |
| 2026-09-01T11:03:08+08:00 | retro | select | 02 复盘五问均否：不改 PLAN、不补调研，下一片仍为 03-session-state-safety |
| 2026-09-01T11:04:46+08:00 | select | spec/requirements | new-spec.sh 建了 2026-09-01-03-session-state-safety |
| 2026-09-01T11:40:15+08:00 | spec/requirements | spec/design | 门② autopilot：三轮独立 requirements review 已达上限并逐项裁定；R1-R9、五 API 与攻击/生命周期边界闭合，机械检查全通过 |
| 2026-09-01T15:35:55+08:00 | spec/design | spec/tasks | 门③ autopilot：PLAN v5.1 收窄 design 三轮独立 review 最终 PASS，R1-R9、算法边界、六 marker 与 3 文件/359 行 sizing 闭合，机械检查全通过 |
| 2026-09-01T16:14:21+08:00 | spec/tasks | spec/execute | 门④ autopilot：三轮全新上下文 tasks review 达熔断上限并融合全部承重 finding；16 个串行任务覆盖 R1-R9、六 marker、BASE 证据和 3文件/400行硬门，check-plan/check-tasks/check-req/check-criteria/check-analyze/git diff --check 全通过 |
| 2026-09-01T17:10:08+08:00 | spec/execute | spec/accept | 执行中 sizing 证据触发验收回流：task1.1/1.2 已独立 review 完成，但 validate+fresh-path 已373/400，剩余承重功能无法在原硬门内实现 |
| 2026-09-01T17:10:08+08:00 | spec/accept | spec/requirements | accept backflow：保留五API内聚与三文件边界，基于真实diff重定1200设计目标/1400硬门并重走 requirements、design、tasks review |
| 2026-09-01T18:07:04+08:00 | spec/requirements | spec/design | 门② autopilot：foundation requirements 三轮独立审查已熔断并采纳全部承重 finding；R1-R6、双 private export、根真值表、source/public surface、六列 manifest 与 2文件/400行门闭合，机械检查全通过 |
| 2026-09-01T18:15:45+08:00 | spec/design | spec/tasks | 门③ autopilot：foundation design 三轮全新上下文独立审查最终 PASS；八节、R1-R6、双 private 接口、root/fd 算法、测试、manifest、373+27/400 和发布边界闭合，机械检查全通过 |
| 2026-09-01T18:32:03+08:00 | spec/tasks | spec/execute | 门④ autopilot：foundation tasks 三轮独立审查已熔断并采纳全部承重 finding；task1.3 393行 sizing、确定性 red、双 private 矩阵、绝对路径 pre/post/final 门和 manifest 边界闭合，机械检查全通过 |
| 2026-09-01T19:00:12+08:00 | spec/execute | spec/accept | 任务1.1-1.3均有红阶段证据、普通提交和独立review最终PASS；六列manifest连续绑定execution BASE到最终HEAD，exact 2 files/400 lines，foundation与offline门禁PASS |
| 2026-09-01T19:03:20+08:00 | spec/accept | retro | 03 foundation验收通过：R1-R6、三条不变量、exact2/400、连续review manifest与收敛检查全PASS；source已快进合入main，PLAN/DECISIONS已更新 |
| 2026-09-01T19:04:06+08:00 | retro | select | 03 foundation复盘五问均否：PLAN v5.3无需调整；下一片为03a-session-path-safety |
| 2026-09-01T19:05:19+08:00 | select | spec/requirements | new-spec.sh 建了 2026-09-01-03a-session-path-safety |
| 2026-09-01T19:27:15+08:00 | spec/requirements | spec/design | 门② autopilot：03a requirements三轮独立review最终PASS；R1-R7、逐层竞态/攻击oracle、inert回滚、exact2/400与manifest闭合，机械检查全PASS |
| 2026-09-01T20:12:15+08:00 | spec/design | spec/tasks | 门③ autopilot：PLAN v5.4与03a1拆片增量review PASS；03a requirements backflow和design round3最终PASS，40-case runnable sizing 311/400与全部机械检查PASS |
| 2026-09-01T20:27:43+08:00 | spec/tasks | spec/execute | 门④ autopilot：03a tasks三轮独立review最终PASS；四任务唯一红首错、逐任务review串行、最终HEAD exact2/400与manifest/clean门闭合 |
| 2026-09-01T22:16:19+08:00 | spec/execute | spec/accept | execute audit：task4 fix1 BLOCKED，shfmt-clean exact2实测527/400，必须进入accept backflow而非继续实现 |
| 2026-09-01T22:16:19+08:00 | spec/accept | spec/design | accept backflow：PLAN v5.5将全部动态mutation测试移至03a1，03a重新设计shfmt-clean<=400交付边界 |
| 2026-09-01T22:48:55+08:00 | spec/design | spec/tasks | 门③ autopilot回流：PLAN/requirements round2 PASS，design/tasks round3 PASS，round2 runnable sizing与机械检查闭合392/400 |
| 2026-09-01T22:48:55+08:00 | spec/tasks | spec/execute | 门④ autopilot回流：task4 v5.5边界经独立review PASS，真实foundation缺席、managed-body oracle、固定工具及exact2门均闭合 |
| 2026-09-01T23:18:14+08:00 | spec/execute | spec/accept | 四任务完成且最终review PASS；BASE..HEAD exact2=391/400，manifest连续、固定工具、完整/浅克隆offline与clean门全部通过 |
| 2026-09-01T23:31:42+08:00 | spec/accept | retro | 03a验收PASS：R1-R7、无SKIPPED、exact2=391/400、四行manifest、full/depth1 offline与收敛门全通过；实现已合入main 2f07821 |
| 2026-09-01T23:32:01+08:00 | retro | select | 03a复盘五问完成：无需再改PLAN或补调研；保留worktree追溯；下一片03a1-session-path-race-assurance |
| 2026-09-01T23:32:24+08:00 | select | spec/requirements | new-spec.sh 建了 2026-09-01-03a1-session-path-race-assurance |
| 2026-09-02T00:05:20+08:00 | spec/requirements | spec/design | 门② autopilot：requirements三轮review最终PASS；round4 only-anchor原型280/400、19 case与全部组合态实跑，机械检查全通过 |
| 2026-09-02T01:04:50+08:00 | spec/design | spec/requirements | design sizing backflow：round6完整单文件411/400 BLOCKED；PLAN v5.6按round7实跑private driver + 109/400 root matrix拆为03a1/03a2，增量review round2 PASS，当前03a1按driver边界重走门②–④ |
| 2026-09-02T01:17:36+08:00 | spec/requirements | spec/design | 门② autopilot回流：03a1 private driver requirements round1初审2 important已即时修复，最终PASS（0/0/0）；R1-R9、round7拆分原型与check-req/check-criteria/check-analyze/diff-check全通过 |
| 2026-09-02T01:59:54+08:00 | spec/design | spec/tasks | 门③ autopilot回流：design三轮review的path isolation、subset/self-disproof、order/sort、depth-1、Python3.8、hash-before-log与Path契约均修复/裁定闭合；round7 driver exact400/400、实跑与机械检查全PASS |
| 2026-09-02T02:29:41+08:00 | spec/tasks | spec/execute | 门④ autopilot回流：tasks三轮review达熔断上限，五任务纵切、代码骨架、真实红因、accepted-HEAD checkout、current diff、14-mutant、双仓根与03a2 fail-closed顺序门全部修复/实跑裁定；机械检查全PASS |
| 2026-09-02T08:58:54+08:00 | spec/execute | spec/accept | 五任务均完成普通提交与独立diff review PASS；manifest连续绑定c959efa至1c6e14f，candidate exact1/400、14-copy、full/depth-1与回归证据齐全，进入controller验收 |
| 2026-09-02T09:04:25+08:00 | spec/accept | retro | 03a1验收PASS并以bf489b0合入main；accepted HEAD、五行manifest、full/depth-1及post-merge回归全部闭合 |
| 2026-09-02T09:04:25+08:00 | retro | select | 03a1复盘五问均否，不改PLAN或补调研；下一片固定为03a2-session-path-race-matrix |
| 2026-09-02T09:04:43+08:00 | select | spec/requirements | new-spec.sh 建了 2026-09-02-03a2-session-path-race-matrix |
| 2026-09-02T09:15:22+08:00 | spec/requirements | spec/design | 门② autopilot：03a2 requirements round2独立review PASS；R1-R10、优先级、rollback、固定工具、full/depth与顺序门闭合，机械检查全PASS |
| 2026-09-02T09:37:08+08:00 | spec/design | spec/tasks | 门③ autopilot：03a2 design round2独立review PASS（0/0/0）；概览与时序仅保留matrix duplicate递归自证，其余损坏由controller隔离夹具验收，137/400扩展原型与机械检查全PASS |
| 2026-09-02T09:58:58+08:00 | spec/tasks | spec/execute | 门④ autopilot：03a2 tasks三轮独立review最终PASS；三任务纵切、可执行Bash骨架、fake零/精确调用、显式BASE、双仓accepted/full/depth-1/rollback、三行manifest与03b fail-closed顺序门闭合，机械检查全PASS |
| 2026-09-02T10:59:09+08:00 | spec/execute | spec/accept | 三任务均有真实red、普通提交和独立diff review最终PASS；manifest连续绑定6f26119至b9582e5，dependency-present 37/37、九类、exact1/141、full/depth-1/rollback、pinned tools、offline、clean及03b全缺席的controller终门PASS |
| 2026-09-02T11:01:38+08:00 | spec/accept | retro | 03a2验收PASS：R1-R10、三行manifest、dependency-present 37/37、九类、exact1/141、full/depth-1/rollback、收敛门与post-merge回归全PASS；实现以merge `744acdc`合入main |
| 2026-09-02T11:01:38+08:00 | retro | select | 03a2复盘五问均否：需求无漏项、设计假设成立、任务边界适配、未发现新跨片风险、不需补调研；PLAN v5.6不变，下一片03b-session-snapshot-safety |
| 2026-09-02T11:03:58+08:00 | select | spec/requirements | new-spec.sh 建了 2026-09-02-03b-session-snapshot-safety |
| 2026-09-02T13:06:14+08:00 | spec/requirements | spec/design | 门② autopilot：03b requirements三轮独立审查最终PASS（0阻断/0重要/0次要），round2全部finding与held-capture follow-up闭环；prototype exact2=397/400、assurance274/400/227项，固定工具、base/assurance、provider缺席inert与机械检查全PASS |
| 2026-09-02T13:50:20+08:00 | spec/design | spec/tasks | 门③ autopilot：03b design三轮独立审查最终PASS（0阻断/0重要/0次要）；cleanup close全fd遍历、temp嵌套finally、latched signal优先与五次close mutant反证闭环；exact2=400/400、assurance=308/400，固定工具、base/assurance和机械检查全PASS |
| 2026-09-02T14:44:36+08:00 | spec/tasks | spec/execute | 门④ autopilot：03b tasks三轮独立review达fix_loop_max=3，全部承重finding已采纳并记录错误代价；最终八任务以固定208/192 blob机械落地，candidate/full/depth-1/rollback/order/terminal独立；check-tasks与R1-R9并集、requirements/criteria/analyze、prototype blob及diff-check全PASS |
| 2026-09-02T19:22:20+08:00 | spec/execute | spec/accept | 03b 八任务全部完成：task1.1/1.2 固定blob机械落地（208+192=400 exact2 零余量），2.1-2.6 candidate/full/depth-1/rollback/order/terminal 六路零delta验证全 PASS；每任务独立 review 最终 PASS（2.6 经 fix round1+re-review）；八行六列 manifest awk 全量核验 rc0；check-tasks/check-req/check-criteria/check-analyze、default/offline、diff-check、clean、03b1/03c 顺序门全部通过；sync-ledger rc0 |
| 2026-09-02T19:32:15+08:00 | spec/accept | retro | 03b验收通过：R1-R9逐条对照、四不变量、exact2=208+192=400、八行manifest awk、check-converge、candidate/full/depth-1/rollback/order五路、SKIPPED为空、次要findings已重报；主验证与offline本消息实跑byte-exact PASS；source已FF合入main ab1e870且post-merge回归全绿；PLAN/DECISIONS/decisions已更新 |
| 2026-09-02T19:33:40+08:00 | retro | select | 03b复盘五问均否：不改PLAN不补调研；下一片固定为2026-09-02-03b1-session-snapshot-assurance（PLAN v5.7），其启动门已由03b验收满足并记录于DECISIONS/ledger |
| 2026-09-02T19:34:32+08:00 | select | spec/requirements | new-spec.sh 建了 2026-09-02-03b1-session-snapshot-assurance |
| 2026-09-02T20:26:59+08:00 | spec/requirements | spec/design | 门② autopilot：03b1 requirements两轮独立review最终PASS（round2 0阻断/0重要/1次要），F1六文件上游集统一修复闭合；R1-R10全[计划]、判据/不变量/确认依据闭合；prototype cbdbdde 308/400 240项在main实跑rc0字节精确；check-req/criteria/analyze/plan与diff-check全PASS |
| 2026-09-02T20:55:31+08:00 | spec/design | spec/tasks | 门③ autopilot：03b1 design两轮独立review最终PASS（round2 0/0/0）；R8 unlink-errno oracle以ASSURANCE_UNLINK_LOG注入闭合；八节/R1-R10映射/签名/mermaid/exact1≤400 sizing/文件清单全闭合 |
| 2026-09-02T22:10:56+08:00 | spec/tasks | spec/execute | 门④ autopilot：03b1 tasks三轮独立review最终PASS（round3 0/0/0）；M1探针字面量恰3处闭合；7任务（1.1交付+2.1-2.6零delta）编号/依赖/manifest awk/03c顺序门/R1-R10映射全闭合；check-tasks rc=0 |
| 2026-09-03T00:20:05+08:00 | spec/execute | spec/accept | 03b1验收六块全过：accepted HEAD c7a18ed（exact1=346≤400）FF合入main、post-merge回归全绿、七任务manifest awk rc=0、candidate/full/depth-1/rollback/order五路零delta全PASS、03c顺序门7项；簿记1d32b50 |
| 2026-09-03T00:20:21+08:00 | spec/accept | retro | 03b1 accept完成（1d32b50簿记+证据提交、c7a18ed FF合入main、post-merge回归全绿）；进入复盘 |
| 2026-09-03T00:22:04+08:00 | retro | select | 03b1复盘五问均否、PLAN v5.7不变；03c启动门证据已入ledger，选择03c-session-write-interrupts |
| 2026-09-03T00:22:16+08:00 | select | spec/requirements | new-spec.sh 建了 2026-09-03-03c-session-write-interrupts |
| 2026-09-03T00:36:47+08:00 | spec/requirements | spec/design | 门② autopilot：03c requirements一轮独立review即PASS（0/0/2，次要留门③）；R1-R8全[计划]、验收清单/四不变量/上游七文件同集/主验证命令闭合；四个checker+diff --check全rc=0 |
| 2026-09-03T01:11:42+08:00 | spec/design | spec/tasks | 门③ autopilot：03c design一轮独立review即PASS（0/0/4）；机制正确性实测无死锁/丢信号/打回自身/假绿；R映射8/8、sizing 390≤400、frontmatter逐字一致；门②次要1已正面回答 |
| 2026-09-03T01:56:42+08:00 | spec/tasks | spec/execute | 门④ tasks 两轮独立 review：round1 NEEDS_CHANGES(1/1/3) 修复后 round2 PASS(0/0/0)，报告 reviews/tasks-03c-session-write-interrupts-round-{1,2}.md；check-tasks rc=0 |
| 2026-09-03T05:31:47+08:00 | spec/execute | spec/accept | 验收六块全过：主验证实跑 default 逐字+offline 发现恰1次、四不变量（exact2/370≤400/上游七文件零变更/check-converge rc0）、R1–R8 对照、裁定重报、SKIPPED 无、次要 findings 重报；FF 合入 main（648fe66）post-merge 回归全绿，worktree/分支已清理；簿记 93abba7+9e799a4 |
| 2026-09-03T05:33:08+08:00 | spec/accept | retro | 五问复盘均否：交付与PLAN v5.7/03d前提一致、无计划外工作、03d口径不变、顺序门证据齐、无未决问题；PLAN v5.7不变 |
| 2026-09-03T05:34:15+08:00 | retro | select | 五问复盘均否，进入 select 建 03d-session-remove-prune |
| 2026-09-03T05:34:15+08:00 | select | spec/requirements | new-spec.sh 建了 2026-09-03-03d-session-remove-prune |
| 2026-09-03T06:09:40+08:00 | spec/requirements | spec/design | 门② requirements round2 PASS(0/0/0)，四checker rc0，自动通过已记ledger |
| 2026-09-03T06:29:39+08:00 | spec/design | spec/tasks | 门③ design round1 PASS(0/0/2)，M1落盘期已修M2留门④，checker全绿，自动通过已记ledger |
| 2026-09-03T07:09:24+08:00 | spec/tasks | spec/execute | 门④ tasks round3 PASS(0/0/0)，check-tasks rc0，自动通过已记ledger |
| 2026-09-03T09:47:00+08:00 | spec/execute | spec/accept | 03d execute 完成：任务 1.1-2.6 全部 DONE 且独立 review PASS；九行六列 manifest awk 全量核验 rc0；终门（check-tasks/check-req/check-criteria/check-analyze、default 逐字、offline 发现恰1次、diff --check、clean、03e 顺序门五门）全绿 |
| 2026-09-03T09:54:11+08:00 | spec/accept | retro | 03d 验收六块全过：accepted HEAD 388a83d5 exact4=378≤400 FF 合入 main、post-merge 回归全绿（default 逐字+03b/03b1/03c/path-races 入口+offline 发现恰1次）、九任务 manifest awk rc0、worktree/分支已清理；簿记 daa359d+98776b7 |
| 2026-09-03T09:54:29+08:00 | retro | select | 03d 复盘五问均否：交付与 PLAN v5.7 一致、无计划外工作、03e 口径不变、顺序门证据齐、无未决问题；PLAN v5.7 不变 |
| 2026-09-03T09:54:52+08:00 | select | spec/requirements | new-spec.sh 建了 2026-09-03-03e-claude-session-lifecycle |
| 2026-09-03T10:55:00+08:00 | spec/requirements | spec/design | 门② requirements round3 PASS(0/0/2)，check-req/check-criteria/check-analyze/diff --check 全 rc0，自动通过已记ledger |
| 2026-09-03T11:40:44+08:00 | spec/design | spec/tasks | 门③ design round2 PASS（reviews/design-03e-claude-session-lifecycle-round-2.md），ledger 已记 round1/round2 与自动通过行 |

## SKIPPED 记录

软门禁跳过记录。收口时会逐条重报一次。

| 时间 | 阶段 | 缺什么 | 批准人 |
|---|---|---|---|
