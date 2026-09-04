# PLAN v5.9 增量复审：Round 2

结论：**PASS**

复审范围只针对 round 1 唯一阻断 B1：04a 是否已经按项目全局 `git diff --numstat` 的 additions+deletions 口径，从错误的 `2/2 + 398/0 = 402` 收敛为 provider `2/2` + assurance `396/0` = `400`，以及旧 398/402 是否仅作为历史失败证据保留。

Finding 统计：Blocking 0，Important 0，Minor 0。

## Round 1 B1 复核

**已闭合。**

- `PLAN.md:70` 的全局硬门仍明确为新增+删除合计不超过 400，没有被局部改写为 additions-only。
- 当前 v5.9 摘要、04a 详情、`PLAN-history.md` v5.9、`DECISIONS.md` v5.9 新行、04a `requirements.md` R1/R9/验收清单、最新 ledger 裁定与 `requirements-prototype-boundary.md` 已一致写成 provider `2增2删`、assurance `396增0删`，总 churn 为 `2+2+396=400`。
- 独立机械比较当前生产 provider 与 04a patched prototype，`git diff --no-index --numstat` 实得 `2/2`，且 diff 只有 deadline 相邻两行；当前 04a assurance prototype 经 `wc -l` 实得 396 行。按全局算法求和为 `2+2+396=400`，P5 硬门不再失败。
- 398/402 只出现在可辨识的历史上下文：PLAN v5.8 的原转交边界、v5.9 对“起草前 398 行原型失败”的因果叙述、prototype-boundary 的“原边界反证”、requirements round 1/PLAN round 1 finding，以及 ledger 中先记录的失败裁定与随后 review FAIL。ledger 的最新裁定明确把 398 收敛为 396 并固定 churn=400；当前 requirements、当前 prototype 和当前 PLAN 边界均不再使用 398/402 作为可验收预算。
- 上游 04 spec 内保留的 398 行 assurance 是 v5.8 交接时的历史 sizing/failure artifact；当前 04a 自有 prototype 是 396 行，路径和权威阶段可机械区分，没有污染当前 exact2 边界。

## 独立机械复跑

```text
provider numstat: 2/2
assurance lines: 396
total churn: 2+2+396=400
shfmt: v3.14.0
ShellCheck version field: 0.11.0
bash -n: PASS
shfmt -d -i 2 -ci -bn: PASS
shellcheck -x --severity=warning: PASS
default: RESULT PASS  resource lease assurance
all: RESULT PASS  resource lease assurance
--dependency-absent: RESULT PASS  resource lease assurance
check-plan.py: rc0
git diff --check（本轮 PLAN/spec 文档范围）: rc0
```

同时核对 prototype 中的 docs 与 04 基础测试 SHA-256 分别与当前 tracked 文件一致；provider 除上述 `2/2` deadline hunk 外无其他差异。

## P1–P5 与受影响边界

| 项 | 结论 | 依据 |
|---|---|---|
| P1 独立验收 | PASS | exact2、固定摘要、active/inert 与完整 assurance 矩阵边界不变。 |
| P2 独立回滚 | PASS | 删除 assurance 并恢复 provider 两行，精确回到已验收 04 基线。 |
| P3 可见产出 | PASS | deadline 最后一轮无 sleep 锁尝试修复与 assurance 均保留。 |
| P4 用户问题 ≤15 | PASS | 无新增用户决策。 |
| P5 人审 <1h / churn ≤400 | PASS | 两文件 exact diff，机械总 churn 恰为 400。 |

04a 对 04 provider 的串行叠改声明、`04a -> 05/06/08` dependency-present 门、05 五类 NEXT 资产缺席条件及独立回滚描述均未因压缩发生漂移。

## 最终判定

**PASS（Blocking 0 / Important 0 / Minor 0）**。Round 1 B1 已由真实 396 行 fixed-tool-clean runnable prototype 和统一的 `2+2+396=400` churn 口径闭合；旧 398/402 仅保留为有明确前后关系的历史失败与 review 证据，不再控制当前实施或验收边界。
