# Review: 04-runtime-resource-leases requirements round 2

verdict: NEEDS_CHANGES  
阻断: 0 / 重要: 1 / 次要: 1

复查口径：`reuse_reviewer=true`。本轮只逐项复查 round 1 的 B1/B2/I1-I5/S1-S2 修复增量，未开放式重审已通过区域，未重跑机械 checker。

## Findings

### 阻断

无。

### 重要

- [重要 I3-R2] `realpath` 后的 workspace `canonical_id` 仍可带入 TSV 分隔字节，规范 request/hash 尚不是对所有合法文件系统状态的唯一协议。证据：`requirements.md:23` 只禁止输入 TSV 的空行/CR/NUL/非三列，然后对 workspace 路径做 `realpath` 并直接以 `domain<TAB>canonical_id<TAB>mode<LF>` 序列化；`requirements.md:31,37` 也只要求 `realpath` 成功，没有验证规范化后的路径字节。一个不含 TAB/LF/CR 的输入软链可指向名称含 TAB、LF 或 CR 的真实目标；`realpath` 结果便会打破三列/一行序列化，尾部 LF 还可在 command substitution 中被剔除。后果：实现可在“拒绝”、“将分隔字节当内容”或“自行转义”之间分叉，同一 workspace 可得到歧义 request bytes/hash，甚至伪造额外记录。这仍属 round 1 I3 的规范字节闭环，不是新范围。建议修法：在 R2/R5 和验收清单中明确 `realpath` 结果若包含 TAB/LF/CR（或选定的全部禁止控制字节）则在 publish 前固定 rc 2/固定双流；或者改用明确的可逆长度编码并同步修改 canonical bytes 定义。R9 应增加“安全名软链→含分隔字节真实目标”的主动反证。

### 次要

- [次要 S2-R2] sizing 风险仍未显式留给门③。证据：`requirements.md:47,67` 继续只写最终 exact3/400 验收门，未声明当前 requirements 阶段不宣称 400 行可实施性，也未要求门③用真实 shfmt 后的 runnable 三文件原型验证余量；当前 `design.md` 仍只有标题。后果：round 1 S2 指出的执行期超门风险没有责任落点。建议修法：在 requirements 的 R10 或验收清单附近明记“本阶段不宣称 sizing 已证明；门③必须提供 fixed-format runnable prototype 的 exact3/<=400 证据，否则按 PLAN:67 回流拆片”。

## Round 1 findings 复查表

| Round 1 finding | 状态 | 增量复查结论 |
|---|---|---|
| B1 owner / command substitution / PID 复用 | ✅ 已修复 | `requirements.md:21-22` 用 `EUID+$$+/proc/$$/stat starttime` 定义逻辑 owner，明确不用 `BASHPID`，并写死 command substitution 由父 shell release 与 PID 复用为 stale；`requirements.md:35,39` 又把幂等/release 都收紧到同一 owner 三元组。语义唯一且可实现。 |
| B2 完整冲突矩阵 | ✅ 已修复 | `requirements.md:33,35,41,59` 固定异 owner 的任意同键同/异 mode 都占用 `3`，同 owner 仅 owner+session+hash 完整相同时幂等，其他重叠/子集/超集/换 session 均立即 `2`，不相交 request 可分别持有。 |
| I1 `0|2|3` / 双流 / bundle 后置条件 | ✅ 已修复 | `requirements.md:33,35,37,39,41` 已固定成功双流、operation-failed `2`、unavailable `3`、唯一 publish/unpublish 点、未 publish 临时残留不得被当 active，以及无法完整验证的 bundle 不得 unpublish。未新增与 PLAN 冲突的 rc 1。 |
| I2 状态根 / 隔离 | ✅ 已修复 | `requirements.md:25,37,45,63` 固定 override 优先级、默认 XDG/tmp 根、绝对路径、EUID/0700/非软链真目录条件、共享命名空间要求和每次 `mktemp` inventory。 |
| I3 规范 request bytes/hash/别名 | ⚠️ 部分修复 | `requirements.md:23-24,33,58` 已补非空/末 LF/空行/CR/NUL、调用时 PWD、规范后同键拒绝、C-locale 排序、精确 TSV 序列化和小写 SHA-256；但尚漏 `realpath` 自身引入分隔字节的路径，见 I3-R2。 |
| I4 假 adapter / 排序 / token 三要素 oracle | ✅ 已修复 | `requirements.md:45,57-63` 增加只记 serial/name argv 而以 instance ID 建 request 的假 adapter、命令零执行、逆序同 token、反向多键 barrier/无部分 active、异 owner 同/异 mode、不相交并行持有，以及 owner/session/request/hash 逐维损坏。 |
| I5 完整 docs contract | ✅ 已修复 | `requirements.md:43,64` 已要求协议文档完整记载 owner/PID/command substitution、状态根、canonical bytes/hash、冲突/重入矩阵、bundle 原子性、wait/stale/release 和完整双流错误表，后序 06/08 不需反读内部 requirements。 |
| S1 monotonic wait | ✅ 已修复 | `requirements.md:41,62` 固定首次尝试前的 monotonic deadline、到点后最后一次无 sleep 尝试，并规定耗时只作宽容 outer timeout，主 oracle 用 barrier/状态。 |
| S2 exact3/400 sizing 责任 | ⚠️ 未修复 | exact3/400 最终门仍自洽，但未明记门③ prototype/backflow 责任，见 S2-R2。 |

## ① 规格符合性

**NEEDS_CHANGES。** Round 1 的两项阻断均已消除：owner/session/request 身份、PID 复用和完整冲突矩阵现已与 PLAN 的跨会话独占目标一致。`0|2|3` 固定双流、bundle publish/unpublish 和状态根也已形成可实现后置条件。但 I3-R2 仍使规范 request 对一类真实可达 workspace 路径产生多解，需在进入 design 前收口。

## ② 文档质量

**NEEDS_CHANGES。** 主体协议的可读性和验收可执行性已显著改善；R3-R9 与验收清单现在能一一对应大多数承重语义。剩余问题很集中：补一条 realpath 后字段字节规则及 fixture，并将 sizing 证明义务明确交给门③。

## 最终判定

**NEEDS_CHANGES（0 阻断 / 1 重要 / 1 次要）。** 修复 I3-R2 后应再做一次窄复查；S2-R2 可同步以一句门③责任声明闭环。
