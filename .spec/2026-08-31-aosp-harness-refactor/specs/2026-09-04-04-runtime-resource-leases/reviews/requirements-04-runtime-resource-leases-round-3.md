# Review: 04-runtime-resource-leases requirements round 3

verdict: PASS  
阻断: 0 / 重要: 0 / 次要: 0

复查口径：本轮仅核对 round 2 的 I3-R2 与 S2-R2，未开放式重审其他区域，未修改 `requirements.md`，未重跑机械 checker。

## Findings

无阻断、重要或次要 finding。

## Round 2 findings 复查

### I3-R2 — 已修复

- 术语层已唯一：`requirements.md:23` 明确 workspace 做 `realpath` 后，结果中任一 ASCII 控制字节 `0x00..0x1f` 或 `0x7f` 都使整个 request 非法，且明确“不做转义”；后续只序列化合法行，因而 `domain<TAB>canonical_id<TAB>mode<LF>` 不再被规范化后路径打破。
- API 和错误表已同步：`requirements.md:31` 将“不含 ASCII 控制字节”纳入 workspace key 成立条件；`requirements.md:37` 将 `realpath` 结果含 `0x00..0x1f`/`0x7f` 固定映射为 publish 前 rc 2、stdout 空、stderr 精确 `error: resource lease operation failed\n`。
- 主动反证已同步：`requirements.md:45` 要求覆盖“无控制字节的 workspace 软链指向含 TAB/LF/CR 或其他 ASCII 控制字节的真实目标”并断言 rc 2；`requirements.md:58` 的验收清单也要求任一 ASCII 控制字节都 rc 2。
- 结论：输入检查、`realpath` 后检查、规范 bytes/hash、固定错误双流和 fixture 现已闭环，不再存在“拒绝/直接嵌入/自行转义”的实现分叉。

### S2-R2 — 已修复

- `requirements.md:47` 明确声明 requirements 阶段不宣称 400 行可实施性已被证明，并将证明义务固定在门③ design：必须以真实可运行、固定 shfmt 后的三文件 prototype 给出 exact3/`<=400` 证据。
- 失败路径已唯一：同一条要求门③若无法证明预算，必须依 `PLAN.md:67` 回流拆片，不得删除承重 oracle 硬压过门。
- `requirements.md:67` 在验收清单中再次点名门③ runnable/fixed-shfmt/exact3/`<=400` 与失败回流，因而不再只有最终验收数字而无前置 sizing owner。
- 结论：sizing 风险已明确留给门③，责任人、证据形态和回流条件均可执行。

## ① 规格符合性

**PASS。** Round 2 唯一重要 finding I3-R2 已在规范字节、rc/双流和主动 fixture 三层同步闭环；本轮限定范围内无剩余 PLAN/已有裁决冲突。

## ② 文档质量

**PASS。** I3-R2 的精确字节集同时出现在术语、R2/R5、R9 和验收清单，无内部漂移；S2-R2 也已把“当前未证明”、“门③如何证明”与“失败时如何回流”写清。

## 最终判定

**PASS（0 阻断 / 0 重要 / 0 次要）。** 可进入门③ design；门③仍必须依 R10 交付 runnable fixed-shfmt exact3/`<=400` prototype 证据，本 PASS 不替代该 sizing 证明。
