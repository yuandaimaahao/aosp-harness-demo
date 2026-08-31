# PLAN 独立审查：Round 3

结论：**NEEDS_CHANGES**

审查范围：完整读取 `research/report.md`、v3 `PLAN.md`、前两轮 review 与 `config.yml`；先复核 Round 2 的 B1/I1–I4/M1，再按 A–E、P1–P5 和文档质量独立复审。未重跑调研命令。

Finding 统计：阻断 0，重要 2，次要 1，共 3 条。

## Round 2 finding 逐项复核

| 旧 finding | 状态 | 复核结论 |
|---|---|---|
| B1 `01/02/04` 独立回滚 | ✅ 已修复 | `09` 有不依赖 `01` 文件的等价 preflight；`02` 删除后各片判据仍可独立执行；`06` 对 `04` 缺席定义显式单会话降级/失败，`08` 保留 legacy adapter。 |
| I1 依赖边与 token 调用链 | ⚠️ 部分修复 | 三处直接边已完全一致，lease token 也改由 runtime 内部获取/释放；但 `09` 调用 runtime 所需的 session/wait 参数来源仍缺失，见 I2。 |
| I2 P5 不可证 | ✅ 已修复 | 每片硬限 8 个非生成文件、400 行增删，并设审查者一小时否决与实施前拆片规则，足以形成可执行上限。 |
| I3 跨类型 lease | ⚠️ 部分修复 | 已定义 workspace 的 source/build、Android 的 device/cvd 冲突及组合获取；同一 CVD 的两种身份仍未归一，见 I1。 |
| I4 docs 未进入自动 gate | ✅ 已修复 | `02` 字典序发现 `tests/test-*.sh`，`10` 产出 `tests/test-docs.sh`，因此完整态的 `check.sh --offline` 会持续执行 docs 检查。 |
| M1 provider present/absent 对象不清 | ✅ 已修复 | 已限定为“存在可回滚 provider 依赖的 consumer”，并明确 `01/02/10` 不适用。 |

## Findings

### 阻断

无。

### 重要

#### I1. `device` 与 `cvd` 仍可能无法锁住同一 Android 实例

- PLAN 第 84、190 行要求 `android` 域内 `device/cvd` 跨类型互斥，但 canonical ID 被定义为“已校验 serial/CVD name”。同一 CVD 的 ADB serial 与 CVD name 通常是两种表示；按 `domain+canonical_id` 加锁时会形成不同 key。
- 因而一个会话可能持有 `android/<adb-serial>/device`，另一个同时持有 `android/<cvd-name>/cvd`，与声称的物理资源互斥不一致。
- `04` 需定义可执行的实例身份归一协议（映射来源、失败语义和 fixture），或要求调用者对 device/CVD 操作传入同一个稳定 instance ID；组合请求还应拒绝同一物理资源的冲突别名。

#### I2. `09 → 06 → 04` 的调用仍缺 session/wait 参数来源

- `06` 的稳定签名要求 `<session-id> <wait-seconds> <lease-request-tsv|->`（第 92 行），`09` 只声明生成 lease request 并传入分离 argv（第 104、126 行）；`harness_verify <feature> [contract CLI args...]` 与 `05` 的 contract CLI 都没有 session ID 或等待时长。
- runtime 内部 acquire/release 已解决“谁取得 token”，但没有说明 dispatcher 从参数、环境还是新建 owner 中取得 session ID，也没有 wait 的默认值/校验协议。实现者无法仅按现有契约组装完整调用。
- 应把两者加入 `harness_verify` 的控制参数，或固定受校验的环境变量/生成规则与默认 wait，并补 v2、legacy、缺值、非法值和中断释放测试。

### 次要

#### M1. `05` 回滚矩阵误列 `06` 为消费者

PLAN 第 140 行称“`06/09` 的 legacy fixture”，但三处直接依赖边都表明只有 `09` 消费 `05`，`06` 不依赖 verifier contract。删去 `06` 或说明它为何相关，避免回滚矩阵暗示第四套依赖关系。

## ① 规格符合性

### 直接依赖机械核对

spec 表、依赖契约、依赖图抽取后均为同一组 15 条直接边：`01→02`、`01→09`、`02→03/04/05/07`、`03→08`、`04→06/08`、`05→09`、`06→09`、`07→08/09`、`08→10`、`09→10`；无环。

### A–E

- A 溯源：✅ report 的缺陷、冲突和未确认项均有实现、非目标或文档去向。
- B 粒度：✅ P1–P5 均有可执行约束；尤其 P5 由 8 文件/400 行硬限和审查者否决共同保障。
- C 依赖：⚠️ 三处边集合一致，回滚路径基本闭合；但 Android 实例 identity 与 `09` runtime 参数协议仍不完整。
- D 目标一致性：⚠️ 自动 docs gate、严格 verifier、安全 preflight 和 canonical core 均对齐总目标；lease 互斥尚不能覆盖其宣称的全部物理冲突。
- E 排序：✅ `01` 安全、`02` 门禁、`03` 高不确定性探针优先，随后按稳定切口串行，理由成立。

### P1–P5

| spec | P1 独验 | P2 回滚 | P3 产出 | P4 ≤15 | P5 <1h |
|---|---|---|---|---|---|
| `01`–`10` | ✅ | ✅ | ✅ | ✅ | ✅ |

P2 表示回滚不会要求同时回滚已合入消费者，允许显式、安全、已测试的 legacy 降级或 fail-closed。I1/I2 是跨 spec 协议完整性问题，不改变各片已有的独立产出与回滚外形。

## ② 质量

- 完整性：⚠️ 章节和遗留项去向齐全，回滚、门禁和规模约束已明显闭合；剩余两处运行协议不能靠实施者猜测。
- 随机出处抽查（3 组）：
  1. ✅ Claude `feature-common.sh:24-50` 未校验 feature 单路径组件，Codex 同名文件 `:3-55` 有白名单校验；支持 `03`。
  2. ✅ common verifier `:65-120` 只有 service/boot/system_server 主检查，Codex verifier `:188-313` 另有 crash baseline/package；支持 `05`。
  3. ✅ Claude feature 上下文 `:74-80` 引用不存在的 native skill，docs Codex 长文第 9 行链接不存在的同目录 README；支持 `10`。
- 推断当事实：✅ 风险等级明确属于本计划判断；真机、跨平台、覆盖率和时序未知均未写成已验证结论。
- 过度设计：✅ gate、lease、registry、runtime 和 adapter 均有 report 风险依据。
- 错误路径：⚠️ 主要负向路径已覆盖；同一 CVD 的身份别名和 `09` session/wait 缺失尚无明确失败协议。

## 最终判定

**NEEDS_CHANGES**。无阻断 finding；修复 I1、I2 后即可再次快速复核。M1 可同步修正。
