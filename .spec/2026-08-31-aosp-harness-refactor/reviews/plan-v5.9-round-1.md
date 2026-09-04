# PLAN v5.9 增量审查：Round 1

结论：**FAIL**

审查基线：`main@ffb05899c33d04b4c3d1c6605b3d39b1e6a05204` 的 PLAN v5.8。范围只含 v5.9 对 04a 的 deadline 相邻修复、由此受影响的规模、依赖、回滚和资源冲突。

已完整核对当前 `PLAN.md`、`PLAN-history.md` 的 v5.9、`DECISIONS.md` 新行、`specs/2026-09-04-04a-runtime-resource-lease-assurance/reviews/requirements-prototype-boundary.md`、04a 当前 `requirements.md`，并按强制项重新读取 `research/report.md`。v5.9 仍对应调研报告“验收强度与契约漂移”中运行时租约仅有文字约束、无实际锁的分类，也保持“common 为共享内核、离线门禁阻止漂移”的总目标；没有把真机、跨平台或性能未知写成已验证事实。

Finding 统计：Blocking 1，Important 0，Minor 0。

## Findings

### Blocking

#### B1. 04a 的 `2+398=400` 只统计 additions，违反 PLAN 自己按 numstat 新增加删除求和的 400 行硬门

- `PLAN.md:70` 把每片硬门定义为“400 行新增+删除（用 `git diff --numstat` 机械统计）”；项目既有执行命令也一直以 `lines += $1+$2` 落实这个口径。它不是“仅 additions”的预算。
- v5.9 的 provider 修复是 `2` 增、`2` 删，assurance 是 `398` 增、`0` 删。因此真实 numstat 总和是 `2+2+398=402`，不是 `PLAN.md:11,146`、`PLAN-history.md` v5.9、DECISIONS 新行和 prototype-boundary 报告所写的 `400/400`。
- 04a `requirements.md` R1/R9 进一步把硬门写成 provider `2/2`、assurance `398/0`，却同时要求 `2+398=400`，机械验收若按全局规则求 `$1+$2` 必然失败。由此 P5 和“无需再次回 PLAN”的结论当前不成立。
- 精确修法：保持 provider 的 `2/2` 修复不变，把 fixed-shfmt assurance 原型在不删承重 oracle 的前提下收敛到最多 `396` 个新增行，并重跑 default/all/dependency-absent、固定工具与四类 mutant；或者回 PLAN 继续拆片。不能只把 400 行口径局部改成 additions-only，因为那会与全局硬门和此前所有片的验收算法冲突。

## 增量核对

### 真实失败与修复语义

- prototype-boundary 给出了 fixed-shfmt 398 行原型在已合入 provider 上的真实失败：`FAIL monotonic attempt count`，诊断日志只有一次 `flock`。本 reviewer 也直接运行已归档原型，复现 rc1、同一 FAIL 与固定外层 operation-failed 行。因此从 exact1 assurance 扩为包含 provider 修复的 exact2，有真实失败依据，不是纸面推断。
- 两行候选语义与当前锁定约束一致：扫描后发现 deadline 到达便 `continue`，绕过 sleep；下一轮先执行第二次 `flock`；若拿到锁，既有锁后 deadline 检查先于 `recover_trash`/`active_records`，因此在读 record、回收 stale 或 publish 前返回 3。`wait=0` 分支仍在扫描后直接返回，不进入额外轮次。
- prototype-boundary 还记录隔离副本的 active/default、all、dependency-absent 三路逐字 PASS，足以支持“两行修复能杀掉已复现失败”的方向判断；最终实现仍应按 requirements R9/R10 跑 base/offline/full/depth-1/rollback。

### P1–P5

| 项 | 结论 | 依据 |
|---|---|---|
| P1 独立验收 | PASS | exact 两文件、固定入口、active 与 inert 分离，主摘要和完整矩阵明确。 |
| P2 独立回滚 | PASS | 删除 assurance 并精确恢复 provider 两行即可回到已验收 04 基线；无需回滚其他已合入 spec，且 05/06/08 尚未启动。 |
| P3 可见产出 | PASS | 闭合既有 R7 最终无 sleep 锁尝试，并交付默认发现 assurance。 |
| P4 用户问题 ≤15 | PASS | 无新增待用户决策问题。 |
| P5 人审 <1h / 400 行 | **FAIL** | exact2 边界清楚，但 numstat churn 是 402，触发硬熔断。 |

### 依赖、回滚、顺序门与资源冲突

- spec 表、依赖契约与 Mermaid 图均保留 `04 -> 04a`，并一致包含 `04a -> 05/06/08`；实施顺序仍是 `04 -> 04a -> 05 -> 06 -> 07 -> 08`，没有引入环。
- 05 的 spec/ref/worktree/execution BASE/dispatch 五类真实资产当前均缺席；04a inert PASS 不能解除 05/06/08 门的文字在 PLAN、依赖表、requirements R10 中一致。
- 04a 不再与 04 文件完全独占，但 `PLAN.md` 资源冲突节已明确这是串行的唯一 provider 相邻叠改，且 05/06/08 均未启动；叠改 owner 与时序闭合。
- 回滚矩阵明确恢复 provider 两行并删除 assurance，既有 04 基础测试继续绿色，同时公开记录会重新暴露 fail-closed 的 deadline 可用性缺口；没有伪称回滚后仍保留 04a 保证。

## 最终判定

**FAIL（Blocking 1 / Important 0 / Minor 0）**。真实失败、两行修复语义、依赖门、独立回滚和资源叠改声明均闭合；唯一阻断是 04a 实际 `git diff --numstat` 总和为 402，违反 PLAN 的 400 行/P5 硬门。在给出 ≤396 行 assurance 的等强度 runnable 证据或继续拆片前，v5.9 不能通过。
