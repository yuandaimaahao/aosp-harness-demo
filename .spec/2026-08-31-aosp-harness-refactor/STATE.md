---
project: 2026-08-31-aosp-harness-refactor
kind: large
phase: select
phase_status: in_progress
basis: 02 复盘五问均否：不改 PLAN、不补调研，下一片仍为 03-session-state-safety
updated: '2026-09-01T11:03:08+08:00'
current_spec: null
spec_stage: null
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

## SKIPPED 记录

软门禁跳过记录。收口时会逐条重报一次。

| 时间 | 阶段 | 缺什么 | 批准人 |
|---|---|---|---|
