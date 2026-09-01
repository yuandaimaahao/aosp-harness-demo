# PLAN v6 增量独立审查 — Round 2

审查对象：`PLAN.md` v6 当前磁盘版本，以及 Round 1 后为 I1–I5/M1 所作的增量修订。

同时完整读取：`PLAN-history.md`、`DECISIONS.md`、原 `00-environment-seed-preflight/requirements.md`、`design.md`、`sizing-prototype.md`、`work/plan-review-v6-incremental-round-1.md`、`research/report.md`、spec `references/02-decompose.md` 与 `references/07-review.md`。本轮只审 v6 拆分及其受影响范围，不重审未受影响的 01–05 方案；未运行 AOSP、lunch、build、sync 或 download。

## 结论摘要

- 结论：**通过**。Findings 为 0 个阻断、0 个重要、1 个次要。
- Round 1 的 I1–I5 与 M1 均已关闭：00a/00b 有逐片 sizing，00a revert 后的所有后序 direct wrapper 有精确 fail-closed 协议，preflight stdout 与 control gate 已分层且成功 gate 进入整体验收，01 owner 已改正，`DECISIONS.md` 已写入 v6 owner/gate/rollback 覆盖口径。
- 00a/00b 均满足 P1–P5。00a 高位 730 行、summary 高位 140 行；00b 明细高位 630 行、summary 高位 160 行。即便按 sizing 中“原 environment 半片减重复项”做更保守的区间运算，00b 高位也是 670，仍低于 800。
- 拆分仍位于已冻结的 seed/store ABI：00a 用纯 fixture 交付可验证 runtime 能力，00b 用真实环境交付 seed/terminal knowledge；依赖为 `00a -> 00b -> 01`，无环且实现串行。

## 验证记录

- `python3 /home/zzh0838/.codex/skills/spec/scripts/check-plan.py .spec/2026-09-01-aosp-feature-minimal-checkout/PLAN.md`：exit 0，无输出。
- `check-plan.py` 只证明 PLAN 形状通过；本轮另行人工复算 sizing、逐项检查 P1–P5，并核对 owner、rollback、gate 与 decisions supersession。

## Round 1 findings 关闭情况

| 上轮项 | 结论 | 证据与判断 |
|---|---|---|
| I1 — 00b P5 未证明 | ✅ 已关闭 | `sizing-prototype.md:16-19` 给出 00a `610–730`、summary `100–140`，00b `470–630`、summary `120–160`；`PLAN.md:9,66-67`、`PLAN-history.md:44-48` 与该高位一致。00b 的保守扣减上界 670 也低于 800。 |
| I2 — 00a revert 牵连后序/P2 | ✅ 已关闭 | `PLAN.md:83-84,181,190` 固定每个后序 direct wrapper 在 import 前检查 00a marker/schema；单独 revert 00a 后后序 commit 保留，精确 exit 30、stdout 空、stderr `CONTRACT RUNTIME_UNAVAILABLE`，不要求联动 revert，并验旧 harness 回归。`DECISIONS.md:23` 同步该覆盖口径。 |
| I3 — preflight stdout/control gate 混层 | ✅ 已关闭 | `PLAN.md:25-28,67,91` 将 preflight exact stdout 固定为单行 `ENV PASS public_aosp17_cuttlefish`；随后独立执行 `verify-seed --ref ... --require-public-real`，仅其 exit 0 后 control plane 才记录 `GATE CONTINUE_PUBLIC` 并继续。整体验收使用 `set -euo pipefail`，因此 verifier 非零时不会执行 gate 或后序命令。原 requirements R19/R20 的 preflight 与负向 gate 语义未被混回同一 stdout。 |
| I4 — 01 CLI owner 冲突 | ✅ 已关闭 | `PLAN.md:100,160,209` 一致规定 dispatcher/runtime 归 00a；01 只在既有 versioned directory 新增独占 contract schema、validator 和 `verify-lock` command module，公共 dispatcher/runtime 零修改。 |
| I5 — DECISIONS 旧 00 口径冲突 | ✅ 已关闭 | `DECISIONS.md:12,16,18,23` 已明确 v6 当前口径：00a 管 schema/digest/store/ref/dispatcher，00b 管 preflight/provider/publish；preflight 与 control gate 分层；00a rollback 使用精确 runtime-unavailable 协议。`PLAN v5 public chain` 行保留来源历史，但其 producer shorthand 由这些 v6 行明确覆盖。 |
| M1 — 原 00 headline 算术不一致 | ✅ 已关闭 | `sizing-prototype.md:3,7-12`、`PLAN.md:9`、`PLAN-history.md:44`、`design.md:5` 已统一为可复算的 `610–730 + 620–820 - 240–340 = 890–1310`。最低 890 仍严格超过 800，R24 replan 触发有效。 |

## 00a/00b P1–P5 复核

| spec | P1 独立验收 | P2 独立回滚 | P3 独立产出 | P4 ≤15 | P5 <1h |
|---|---|---|---|---|---|
| 00a | ✅ `verify-seed` golden + schema/path/digest/publish/fault fixture matrix，不需真实 AOSP | ✅ revert 不要求撤回后序 commit；后序 direct wrapper 精确 fail closed，旧 harness PASS | ✅ dispatcher、schema/digest、store/ref runtime 能力 | ✅ 0 个新增问题 | ✅ diff 高位 730、summary 高位 140 |
| 00b | ✅ real public preflight + public-real verifier；环境不足以 terminal report 独立产出 knowledge | ✅ revert 00b 不修改 00a；`SEED ABI PASS` 与旧 harness 保留 | ✅ real seed/ref 或 terminal report | ✅ 0 个新增问题 | ✅ 明细高位 630、summary 高位 160；保守扣减高位 670 仍过门 |

两片切口没有要求往返修改共同 ABI：00a 独占 schema/runtime/publisher，00b 只填充真实观测并调用它。文件 owner、依赖图和资源冲突节一致，且所有实现类 spec 继续串行。

## Findings

### 阻断

无。

### 重要

无。

### 次要

#### M1 — 00b 的“扣除重复项”文字与其明细区间不是同一个区间算式

- **位置：** `sizing-prototype.md:17`。
- **依据：** 该行先说从 combined environment 半片 `620–820` 扣除 `150–210`，保守区间运算应为 `410–670`；随后按新的实现/测试/wrapper 明细相加得到 `470–630`。后者自身算术正确，但文档没有说明它是重估后的收窄区间，而不是前一算式的直接结果。
- **影响：** 不改变拆分或 P5：两种算法的上界 630/670 均低于 800，summary 上界仍为 160；不会让 00b 越过人审 gate。
- **建议：** 后续顺手将文字改为“保守扣减区间 `410–670`；按组件重估为 `470–630`”，或只保留一种算法，避免读者误以为两式严格相等。本项不阻塞门①。

## 增量一致性结论

- **溯源：** v6 仍由原 requirements R24 + sizing 触发；`PLAN-history.md` 明确记录证据，没有无来源漂移。
- **粒度：** 00a/00b 各自具备命令判据、rollback absence protocol、能力/知识产出与受限人审预算，满足 P1–P5。
- **依赖与 owner：** `00a -> 00b -> 01` 无环；dispatcher/runtime、preflight/provider、`verify-lock` owner 唯一，资源冲突节不再把 CLI creator 写给 01。
- **目标与排序：** fixture runtime 先行、真实环境单点失败次之，仍在投入 closure 实现前 fail closed；public `services` 目标与 01–05 顺序未被拆分改变。
- **public gate：** exact preflight stdout、public-real ref verifier、control-plane gate 和后序执行已形成可执行顺序；local seed 仍不能解锁 01。

VERDICT: PASS
