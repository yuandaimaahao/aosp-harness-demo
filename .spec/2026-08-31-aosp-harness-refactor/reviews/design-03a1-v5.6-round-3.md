# 03a1 design v5.6 review — round 3

Reviewer: `review_plan_v5_2`

Verdict: **NEEDS_CHANGES** — blocker 0 / important 1 / minor 0

审查范围：只复核round2 I1、I2、M1及直接修改的requirements/design、400行prototype、round7 report/evidence；未重审无关旧内容，未修改spec、PLAN或prototype。本文为唯一新增文件。

## Round 2 findings复核

| finding | 状态 | 精确证据 |
|---|---|---|
| I1 Python 3.8下限不兼容 | ✅ 闭合 | prototype `session-path-race-driver.py:47`已等行改为`parent.lstat()`；仍为400/400。本reviewer以Python 3.9实跑`protocol`和`self-test`均rc0、精确28B/38B，`ast.parse(feature_version=(3, 8))`通过；report/evidence另记录Python 3.9 subset、full和depth-1。未发现其余3.8以后API。 |
| I2 provider oracle晚于CASE_LOG写入且逐case承诺不实 | ✅ 闭合 | `design.md:72`已收敛为matrix开始/全部case结束的before/after hash；prototype `:390`在`:391`的held-fd log write之前检查provider bytes。report `:55`与evidence `:31-32`给出隔离ordering反证：case hook 1、provider变化、rc1、stdout0、无PASS、log 0B，且不混入固定14项。 |
| M1 absolute/normalized约束未进入契约 | ❌ 未完全闭合 | R3和design现在写入absolute/normalized/root-to-parent physical约束，但prototype没有按raw argv机械拒绝`.` alias，验收清单也遗漏该反例，详见I1。 |

其余受影响文本一致：R3的root-to-parent每层physical non-symlink、absent leaf、direct fresh log、held-fd和0-case/provider不变语义均与design/report一致；R6及canonical bytes排序没有回退；owner、CLI、14项self-disproof、full/depth-1、exact1/400与03a2顺序门无新问题。

## Important

### I1 — R3明确拒绝`.`/`..`非normalized alias，但prototype在构造`Path`时已吞掉`.`，相关验收清单也未覆盖

- 位置：`requirements.md:25,48`；`design.md:66`；round7 driver `:31,46-51`；`round7-sizing-report.md:27`；`round7-evidence.log:20-30`。
- 证据：R3要求workspace与log是无`.`/`..`别名的normalized absolute path，并在case前拒绝relative/non-normalized path。prototype `:31`先把CLI字符串转换成`pathlib.Path`，随后只检查`workspace.is_absolute()`、resolved parent及`case_log.parent == workspace`；`Path('/x/./workspace')`在检查前已规范成`/x/workspace`，因此无法证明原始参数没有`.`。本reviewer实跑1-row `run-matrix`，显式传入`$TMP/./workspace`和`$TMP/workspace/./cases.log`，实际rc0、stdout精确38B、stderr0并写1行log，而契约要求0-case rc1。当前evidence只覆盖parent symlink/leaf alias/既有对象等七类，没有dot/dotdot raw-path反证；验收清单`requirements.md:48`也未列relative/non-normalized。
- 影响：round2 M1只是把额外限制写进文档，实际CLI仍未实现该“必须拒绝”分支，400/400证据因此尚未支付完整R3。虽然未来03a2使用normalized absolute temp path，不构成立即production风险，但requirements、design、prototype三者仍不一致，无法进入tasks。
- 可执行修复：在转换为`Path`前保留workspace/log原始argv，并以机械规范化比较拒绝`.`/`..`、relative和非canonical形式；可把条件合并进现有preflight行保持400。将relative、workspace `./`、workspace `../`、log `./`、log `../`加入验收清单和0-case/provider-same/log-absent evidence，然后重跑Python 3.9 subset与LOC门。若不需要禁止`.`文本别名，则回流删除R3/design的该承诺，不能继续声称prototype已证明。

## Mechanical/runtime evidence

- `check-req.py`: rc0
- `check-criteria.py`: rc0
- `check-analyze.py`: rc0
- `check-plan.py`: rc0
- `git diff --check`: rc0（写本报告前）
- LOC：driver 400/400。
- Python 3.9：protocol/self-test均rc0，精确28B/38B；Python 3.8 grammar PASS。
- 定向反证：带`.` alias的workspace/log执行1-row `real-eio`得到rc0、stdout38B、stderr0、log 1行，未按R3拒绝。

## 最终判定

**NEEDS_CHANGES**。round2两项important已闭合，但M1回流后的explicit normalized-path requirement尚未由prototype及验收清单支付；补齐raw-path反证后再复审。
