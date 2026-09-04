# Requirements 04 v5.8 backflow review round 1

verdict: **NEEDS_CHANGES**  
规格符合性：NEEDS_CHANGES；质量：NEEDS_CHANGES；阻断0 / 重要1 / 次要1。

- 重要：57行基础原型未逐字证明“仅两个 public API”，且 inventory 只排除 active/tmp/trash 三类已知 glob，不能拒绝未知资产。
- 次要：ledger 版本头仍写 PLAN v5.7。
- 其余 R1–R8 生产正确性、R9 向基础合同收窄、R10 exact3/checkout/rollback/04a NEXT 门、frontmatter 与 seam 边界通过。

