---
project: 2026-09-01-aosp-feature-minimal-checkout
kind: large
phase: select
phase_status: in_progress
basis: 复盘完成：五问均否，00a/00b拆分、顺序和730/630预算继续成立；无新增产品spec或调研问题，下一片选择2026-09-01-00a-seed-contract-runtime
updated: '2026-09-02T01:59:59+08:00'
current_spec: null
spec_stage: null
mode: standard
workflow: requirements-first
---
# 2026-09-01-aosp-feature-minimal-checkout 状态

## 待确认项

调研范围：

  查：
  - 当前 aosp-harness-demo 中 feature、framework、AOSP 源码与构建命令的组织方式。
  - 从一个 feature 如何推导所需 AOSP Git 单仓、编译框架及其闭包依赖。
  - “单仓单编”在 Soong/Make 环境下的必要条件、不可避免的公共依赖与失败边界。
  - 可落地的最小化下载/编译方案，包括 manifest 或依赖描述、缓存、校验和回退机制。
  - 选取仓库内一个现有 feature 做静态走查，给出可执行的验收命令草案。

  不查：
  - 不下载或编译完整 AOSP 整机镜像。
  - 不扩展到具体业务 feature 的功能开发。
  - 不覆盖厂商私有 BSP/vendor 工程的通用最小化方案；如发现依赖，只记录为边界或风险。

调研范围已确认（2026-09-01，用户回复“ok”）。

> 这份文件的 frontmatter 是机器读的唯一真相。正文是给人看的流水账。
> 每次决定下一步动作之前重读本文件，不要靠会话记忆判断当前在第几步。

## 阶段流水

| 时间 | 从 | 到 | 依据 |
|---|---|---|---|
| 2026-09-01T21:10:27+08:00 | — | research | 分型完成：large，待确认调研范围 |
| 2026-09-01T21:24:13+08:00 | research | plan | 调研完成：三路独立证据已落盘，report 已通过校验 |
| 2026-09-01T22:10:15+08:00 | plan | select | 门①通过：用户批准 PLAN v4；00 验证输入为 ~/Project/lk7k-a17/system 与 lunch sys_mssi_64_64only_cn_armv82-fooding-userdebug |
| 2026-09-01T22:15:30+08:00 | select | spec/requirements | new-spec.sh 建了 2026-09-01-00-environment-seed-preflight |
| 2026-09-01T23:03:51+08:00 | spec/requirements | spec/design | 门②自动通过：requirements 三轮独立 review 达 fix_loop_max=3 后依熔断规则逐条裁定并修复，PLAN v5 与 DECISIONS/ledger 已同步，三项 requirements checker 及 check-plan 均 exit 0 |
| 2026-09-01T23:46:39+08:00 | spec/design | spec/tasks | 门③自动通过：design 三轮独立 review 达 fix_loop_max=3 后依熔断规则逐条裁定，动态 frozen base、五类 exact mutation oracle、closed supersession schema、single-parent terminal exception 与 19-path create scope 已同步；check-plan/check-req/check-criteria/check-analyze/git diff --check 均 exit 0 |
| 2026-09-02T00:15:55+08:00 | spec/tasks | spec/execute | 门④自动通过：tasks三轮独立review达fix_loop_max=3后逐条接受并修复；改为六个non-overlap files/四任务独立review/two-parent merge，所有prospective diff相对task parent和frozen base，exact worktree/channel/ledger/cleanup闭合；check-tasks/check-plan/check-req/check-criteria/check-analyze/git diff --check均exit 0 |
| 2026-09-02T01:54:43+08:00 | spec/execute | spec/accept | execute完成：四任务均经fresh independent diff review PASS；recovery merge a79edb650066bf47d6908fe00ec22c0d6749ef14 parent1=7b46dfba287f2e3e3fb9ca00c3186b69c4720dc7 parent2=55884d4b4819cb2fbda1e4468a25164dc7157b40；六路径744/800；self-test/pre-commit-complete/ledger sync/main acceptance/isolated revert-m1/三项旧harness回归均PASS；未运行AOSP命令 |
| 2026-09-02T01:59:41+08:00 | spec/accept | retro | 门⑤自动通过：本轮self-test/pre-commit-complete/main acceptance exact PASS；merge a79edb65为two-parent四任务六路径、common增量0、744/800；R1-R27 owners和summary上限通过；check-converge真实base/head spec-root相对模式exit0；全部裁定/挂账/SKIPPED已归档 |
| 2026-09-02T01:59:59+08:00 | retro | select | 复盘完成：五问均否，00a/00b拆分、顺序和730/630预算继续成立；无新增产品spec或调研问题，下一片选择2026-09-01-00a-seed-contract-runtime |

## SKIPPED 记录

软门禁跳过记录。收口时会逐条重报一次。

| 时间 | 阶段 | 缺什么 | 批准人 |
|---|---|---|---|

## Review ledger

| 时间 | 产物 | 轮次 | 结果 | 处置 |
|---|---|---:|---|---|
| 2026-09-01 | PLAN | 1 | FAIL：3 阻断 / 5 重要 / 2 次要 | 修订为 PLAN v2；证据 `work/plan-review-round-1.md` |
| 2026-09-01 | PLAN | 2 | FAIL：2 阻断 / 4 重要 | 修订为 PLAN v3；证据 `work/plan-review-round-2.md` |
| 2026-09-01 | PLAN | 3 | FAIL：2 阻断 / 3 重要 / 1 次要 | 达到 `fix_loop_max=3`，熔断裁定并修订为 PLAN v4；代价与解法见 `PLAN.md` 「Review 熔断裁定」 |
