# Task 1.4 fix1 review — round 2

结论：**PASS**

计数：阻断 0，重要 0，次要 1，⚠️ 0。

本轮只审 `d497a87d..9be78e07` 的修复包及其对 round1 I1/I2/I3/M1 的闭合；未修改实现、未重跑实现者已经报告的测试。

## ① 规格符合性

- ✅ **I1：LF + 空格路径保持单个 argv，且经过关联数组查找边界。** static fixture 新建真实文件名 `$'candidate\n with space.sh'`，它由生产 gate 的 NUL 发现/数组路径进入 `quality_run_static`，必然先求值 `${approved[$path]-}`，再进入静态工具。`assert_calls` 从 fake 工具的 NUL byte log 还原每次调用，要求 ShellCheck 与 shfmt 都各收到一个完整的 `odd` 路径参数，而不是按 LF 或空格拆分。base case 同时要求原始 approved exact pair 不出现在调用中，changed case 又要求同一路径变化后进入调用，关联查找和 exact-pair 两侧均有证据。
- ✅ **I2：ShellCheck 与 shfmt 两条错误路径均 fail-fast。** 特殊路径在 C 序中位于 changed approved、`new.sh` 和 `scripts/check.sh` 之前。ShellCheck failure 精确要求调用序列为 ShellCheck 仅特殊路径、shfmt 零调用；shfmt failure 精确要求两个工具都仅特殊路径。两 case 还分别要求 Gitleaks 日志为空、总 PASS 不出现，因此同时覆盖失败工具、另一静态工具/后续候选、秘密阶段和成功尾行的短路。
- ✅ **I3：non-anchor 是独立的 30 行 mutation。** `append-current` 仍追加第 31 行并显式断言 31 行；`non-anchor` 则只替换 canonical 第一行的 40-hex blob，路径和行位置不变，保持 30 行。fixture validator 在调用 gate 前要求 30 行、合法字段、严格 C 序和 path/blob 唯一；随后 gate 必须因固定摘要不符返回 2，三个工具调用均为空。它不再与 append-current 共用同一变异形态。
- ✅ **M1：独立判据已有可定位失败。** 两个静态 failure case 将 rc、精确调用序列、Gitleaks 零调用、无总 PASS 分成四个带工具标签的断言；mutation 将 fixture 形态、rc 和工具零调用分开。Python argv oracle 失败也携带具体 tool 与实际 records，round1 指出的单行不可定位问题已闭合。
- ✅ **预算与范围。** fix 包只改 `tests/test-quality-gate.sh`，无生产行为变更或越界文件。最终 task base `d3de2837` 到 review head 的 diff 为 test `34+/1-`（churn 35）、gate `13+/0-`、baseline `30+/0-`，分别命中/低于 35/15/30 上限；六文件总预算也未被本修复扩大。fix 包自身 `26+/24-` 是对中间版本的重排，不应再次累加到以 task base→最终 head 定义的交付预算。
- ✅ **回归面。** 修复没有改 `scripts/check.sh` 或 baseline；base/changed 两个成功 oracle 仍完整约束普通候选、approved 豁免和 changed 必检顺序。实现者报告 contract 与真实 offline gate 均为 rc 0，且提供了红阶段证据；本轮按审查禁令不重复执行。

## Findings

### 阻断

无。

### 重要

无。

### 次要

1. **M2 — test 的 `baseline_valid` 与生产 gate 的 baseline `awk` predicate 近乎逐字重复。** 这不会使本轮 I3 假绿：non-anchor 只替换 blob，30 行和路径顺序由构造保持，最终拒绝还由独立的固定 SHA-256 门完成；但以后若 baseline 格式规则调整，两份 predicate 可能同步漂移或产生维护重复。可在后续触及该测试时把 fixture 自证改成独立 Python oracle，当前不阻塞。

## ② 质量四项

- **有没有做简报没要求的事（YAGNI）：** 没有。修复只重排 contract，并逐项对应 I1/I2/I3/M1。
- **验证是不是真的在验：** 是。特殊路径用 byte-level NUL log 验 argv；两个工具 failure 用精确序列验短路；non-anchor 先验 fixture 形态再验 rc 2 和工具零调用；不存在空断言、恒真断言或只跑不验。
- **有没有逻辑块被逐字复制：** 有一处非阻断重复，见 M2；除此之外 `assert_calls` 集中复用了调用序列 oracle，没有再复制同类断言块。
- **错误路径有没有被处理：** 是。ShellCheck、shfmt、六类 baseline mutation 都有明确 rc、调用边界和成功尾行约束；本修复未引入资源、网络或秘密阶段副作用。

## ⚠️

无。实现者测试结果仅采用 fix report 的既有证据，符合本轮“不重跑”约束；本轮要求的四个闭合点均可从修复 diff 判断。
