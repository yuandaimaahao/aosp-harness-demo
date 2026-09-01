# PLAN v5.6 增量 review round 2

Reviewer: `review_plan_v5_2`

Verdict: **PASS** — blocker 0 / important 0 / minor 1

审查范围：只复核round1的I1–I3/M1及其直接受影响文本，对照当前`PLAN.md`、`PLAN-history.md`、round7 sizing report/evidence和更新后的两份prototype；未重审无关旧PLAN内容。

## Round 1 findings复核

| finding | 状态 | 精确证据 |
|---|---|---|
| I1 matrix fail-closed优先级与prototype不符 | ✅ 闭合 | `PLAN.md:111`与entrypoint `:29-51`一致：argv后立即生成/校验37-row matrix，再进入provider/driver/core/inert。新增隔离child以provider缺席+重复EIO主动反证顺序；本reviewer实跑损坏态rc1、stdout0，完整provider缺席态仍rc0/41B。 |
| I2 03a2独立判据可被inert满足、depth-1未固化 | ✅ 闭合 | `PLAN.md:48`明确要求dependency-present的driver protocol/self-test/default、37/37及九类计数；`:107`要求03a1完整历史和真实file-URL depth-1 self-test；`:111`要求03a2两种checkout的default与offline，并继续禁止inert摘要作为验收证据。 |
| I3 03a2回滚命令依赖未来03b且不证默认发现 | ✅ 闭合 | `PLAN.md:219`改为删除root test后直接运行private driver self-test与`bash ./scripts/check.sh --offline`，不再依赖03b文件，同时机械证明driver仍绿且不进入root test glob。 |
| M1 `新墖`错字 | ✅ 闭合 | `PLAN.md:8`与`PLAN-history.md:57`均改为`新增`。 |

## 新finding

### Minor 1 — 03a2独立判据出现新错字

- 位置：`PLAN.md:48`。
- `protocol`/`self-test`与入口“`址退0`”应为“`均退0`”。上下文、详情和CLI契约足以消除歧义，不影响依赖、验收语义或机械检查。

## 一致性结论

- spec表、owner、详情、直接边、回滚矩阵、回滚命令、依赖图与顺序仍逐处一致；直接边为`03a→03a1`、`03a→03a2`、`03a1→03a2`、`03a→03b`、`03a2→03b`，无环。
- 03a1/03a2均为exact1独占文件；更新后的实测规模为driver 381/400、entrypoint 109/400，P5与400行门闭合。旧round1 review保留当时98/400的历史陈述，不属于v5.6当前口径漂移。
- private CLI及rc/双流继续与prototype一致；matrix active self-disproof没有改变driver absent=inert、driver corrupt=fail closed、provider absent优先于driver读取等回滚语义。
- 03b gate仍只在03a1/03a2 accepted HEAD、全PASS manifest和dependency-present 37-case/九类证据齐全后解除；无运行时API依赖或partial capability。
- 默认发现和浅克隆闭合：private Python driver不在root `tests/test-*.sh` glob；03a1 self-test与03a2 default/offline的真实depth-1门均已写入PLAN。

## Mechanical/runtime evidence

- `check-plan.py PLAN.md`: rc0。
- `git diff --check`（PLAN、history、round7 report/evidence/prototype）: rc0。
- LOC：driver 381，entrypoint 109。
- 本reviewer实跑：dynamic rc0/精确41B；provider absent rc0/精确41B；provider absent+损坏matrix rc1/无成功stdout。

## 最终判定

**PASS**。round1三项important和一项minor均已闭合；新发现仅为不承重文字错字，可在后续文档修订时一并改正。
