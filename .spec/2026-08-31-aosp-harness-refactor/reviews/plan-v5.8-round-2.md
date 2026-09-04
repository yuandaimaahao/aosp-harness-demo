# PLAN v5.8 independent review — round 2

结论：**NEEDS_CHANGES**。规格符合性与设计质量均未通过；Blocking **1** / Important **1** / Minor **0**。

## Blocking

04a 的完整 assurance / exact1≤400 证明仍未闭合。唯一 seam、CLI/inert、self-overlap、barrier、PID reuse、monotonic、stored-record、I/O、closed stdout、fake Python、adapter 与一个 mutant 已存在，但 realpath 仅覆盖 TAB 且无 NUL；unpublish-side replace 没有 seam/fault oracle；adapter 没有两个不同 serial/name 的成功/被阻止调用；mutant 仅覆盖 global overlap。当前 377/400 只能证明不完整子集。

## Important

04→04a→05/06/08 的 spec 表、直接边、文本图、顺序和五类 NEXT 缺席门已补齐，但 rollback 的 04a 行遗漏 05；当前 04 requirements/design 仍待 PLAN 通过后回流。

## 首轮闭合状态

- core facade、strict state、Python 3.8、tombstone 与 exact3=336+7+57=400：已闭合。
- 04a 完整 assurance：未闭合。
- NEXT/依赖闭环：部分闭合。

