# PLAN 独立审查：Round 2

结论：**NEEDS_CHANGES**

审查范围：完整读取 `research/report.md`、v2 `PLAN.md`、`reviews/plan-round-1.md`、`config.yml`；按 A–E、P1–P5 和文档质量重新审查，并机械比对 spec 表、依赖契约、回滚矩阵与依赖图。`check-plan.py` 退出 0。未重跑调研命令。

Finding 统计：阻断 1，重要 4，次要 1，共 6 条。

## Round 1 finding 逐项复核

| 旧 finding | 状态 | 复核结论 |
|---|---|---|
| B1 独立回滚 | ❌ 未实质修复 | 新增了回滚矩阵和 absent fixture 原则，但 `01`、`02`、`04` 仍有不可执行的消费者降级路径，见 B1。 |
| B2 原 `06` 过大 | ⚠️ 部分修复 | 已拆为 `07`–`09`，稳定切口明显改善；但 `05/08/09/10` 没有足够边界证明全部产出可在 1 小时内审完，见 I2。 |
| I1 消费/产出签名 | ❌ 未实质修复 | 已增加契约表，但与依赖表不一致，且 lease token 的取得链和数个错误协议仍不闭合，见 I1。 |
| I2 运行时租约 | ⚠️ 部分修复 | `04` 已承接四类租约，`06/08` 消费；但跨类型冲突和 verifier 的 token 获取未定义，见 I3。 |
| I3 build/CVD 超时、覆盖率 | ✅ 已修复 | `06` 覆盖 `build|cvd`；`02/10` 明确数字覆盖率非目标及去向。 |
| I4 高不确定性排序 | ✅ 已修复 | `03` 在门禁后立即执行攻击/并发探针。 |
| I5 可选工具策略 | ✅ 已修复 | `--offline` 不探测可选工具；`--ci` 锁版本且缺工具失败。 |
| M1 “P0”无出处 | ✅ 已修复 | 改为“本计划最高风险缺口”，属于明确的计划排序判断。 |
| M2 registry 仅成功路径 | ✅ 已修复 | `07` 增加重名、缺键、非法值、重复 repo、畸形列负向测试。 |

## Findings

### 阻断

#### B1. 回滚矩阵仍不能证明 P2，且至少三条路径自相矛盾

- 回滚 `01` 会撤销 legacy verifier 的 serial/SKIP 修复；但已合入的 `09` 在 provider 缺席时正是回退 legacy verifier，同时又声称仍遵守 `01` 安全基线（PLAN 87、97、110 行）。除非 `09` 自带独立于 `01` 的前置安全层，否则这两件事不能同时成立。
- 回滚 `02` 会删除 `scripts/check.sh`，而已合入 `10` 的独立判据明确要求执行该命令（47、111 行）。所谓“后续测试仍可单独运行”不能让 `10` 的判据继续可执行。
- 回滚 `04` 后，矩阵声称 `06` 转 legacy 单会话模式；但 `06` 的公开签名强制接收 `<lease-token>`，无有效 token 返回 `2`，没有 absent sentinel、降级分支或 token 获取替代协议（75、100、113 行）。
- “每片都有 provider-absent fixture”是测试意图，不会自动补齐以上运行协议。至少 `01/02/04` 仍不满足 P2，计划中的切片集合尚不能成立。

### 重要

#### I1. spec 依赖、契约消费者和图的边集不一致，调用链也未闭合

- spec 表的直接边中没有 `01 → 09`，契约表却列 `09` 消费 `01`；契约表又把 `02` 的消费者写为 `03–10`，而 spec 表/图只给 `03/04/05/07` 直接依赖 `02`。若表表达直接依赖则边集冲突；若含传递消费，PLAN 没有标注，无法机械校验。
- `09` 调用 `harness_command_run ... <lease-token>`，但 `harness_verify <feature> ...` 没有 token 参数，`09` 也未声明消费 `04` 或由谁 acquire device/CVD lease。现有签名无法组成完整调用链。
- `03` 未规定 validate 的 stdout/stderr，`04` 未规定 release 返回码及 absent token 协议，`07` 未列出 resolver 的完整 key 集/转义规则，`08` 未说明 `contract_version=legacy` 输出在哪个通道。Round 1 要求的完整 shell 协议仍只是部分完成。
- ASCII 图的汇合线无法无歧义还原全部边。应以一份明确的直接边清单或可解析 Mermaid 为真相源，并让 spec 表、契约表逐边相等。

#### I2. `05/08/09/10` 的 P5 仍不可由 PLAN 证明

- `05` 同时产出契约文档、三入口行为矩阵、common 断言补齐及测试；`08` 同时迁移 Claude/Codex wrapper 与 session hook，并接入三个 provider 和双路径 fallback；`09` 迁移三套 verifier、dispatcher、三 provider 与 legacy fallback；`10` 重写多份 README/契约/长文同步并新增检查器。
- 拆掉原巨型 `06` 是实质进步，但上述各片没有文件/接口边界、review diff 上限或再次拆分阈值。按“全部产出”人审，不能可信保证 `<1h`。应再拆或给出可执行的审查规模约束；超界时必须在执行前拆片。

#### I3. 四类 lease 没有定义物理资源的跨类型互斥

- `04` 把 key 分为 `source|build|device|cvd`，资源冲突节只保证“同一 resource-id”一个 owner（67、159 行）。同一 AOSP tree 的 source 写入与 build、同一 CVD 的 device 操作与 CVD 生命周期操作，可能使用不同 type 而并发。
- 未定义规范 resource-id、跨类型冲突矩阵、多租约获取顺序或原子组合获取，既可能漏锁也可能死锁。“不可伪造 token”也没有对应验证协议。这使 Round 1 I2 只完成了租约外形，尚未闭合真实资源冲突。

#### I4. “单一离线门禁阻止漂移”没有纳入 docs 检查

- 总目标要求单一离线门禁阻止三套实现再次漂移，`10` 产出 `scripts/check-docs.sh`；但整体验收未运行它，`02` 的自动发现只覆盖 `tests/test-*.sh`（12–14、59、91 行）。
- `10` 自身验收会运行一次 docs check，却不能保证此后 `check.sh --offline` 持续覆盖文档/副本漂移。应让 `10` 提供可自动发现的测试入口，或定义 gate 的稳定插件协议；不要回头硬改 `02` 的固定文件清单。

### 次要

#### M1. provider-present/provider-absent 的全称要求对象不清

PLAN 22、121 行写“各 spec/每片”都要验证 provider present/absent，但 `01/02` 没有上游 provider，`10` 也不是运行时 provider 消费者。应改成“每个有可回滚 provider 依赖的 consumer”，并逐项列出 fixture 对；否则验收要求不可字面执行。

## ① 规格符合性

### A–E

- A 溯源：✅ 十片均能回指 report；冲突和“我没能确认的”主要项目都有实现、非目标或文档去向。
- B 粒度：❌ P1/P3/P4 基本成立，但 `01/02/04` 的 P2 不成立，`05/08/09/10` 的 P5 未被证明。
- C 依赖：❌ 拓扑意图无环，但 spec 表、契约消费者、ASCII 图不一致；lease/token 调用链和跨类型资源冲突未闭合。
- D 目标一致性：⚠️ 安全、contract、runtime、adapter、文档都有判据，也未把收益简单相加；但 docs check 未进入承诺的单一最终 gate。
- E 排序：✅ `01` 单点安全风险最先，`02` 建门禁，`03` 随即消除高不确定性；实现类固定串行。

### P1–P5

| spec | P1 独验 | P2 回滚 | P3 产出 | P4 ≤15 | P5 <1h |
|---|---|---|---|---|---|
| 01 | ✅ | ❌ | ✅ | ✅ | ✅ |
| 02 | ✅ | ❌ | ✅ | ✅ | ✅ |
| 03 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 04 | ✅ | ❌ | ✅ | ✅ | ✅ |
| 05 | ✅ | ⚠️ | ✅ | ✅ | ⚠️ |
| 06 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 07 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 08 | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| 09 | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| 10 | ✅ | ✅ | ✅ | ✅ | ⚠️ |

`⚠️` 表示 PLAN 尚不足以证明满足，不是默认通过。

### report 遗留项去向

✅ Demo/真实入口、verifier 强度、SKIP、canonical core 决策、真机/CVD/AOSP 时序、build/CVD timeout、跨平台、覆盖率、路径/软链/并发探针、租约、文档漂移均有明确去向。租约方案本身仍有 I3 的设计缺口；这属于处置不充分，而非遗漏去向。

## ② 质量

- 完整性：⚠️ 必备章节齐全且结构校验通过；依赖协议、回滚可执行性、P5 边界和最终 gate 闭合不足。
- 随机出处核对 3 条：
  1. ✅ 设备安全：Claude verifier 的真实路径确有裸 `adb`，Codex 确有 SKIP allowed 返回 PASS；支持 `01`。
  2. ✅ verifier 漂移：common 只检查 service/boot/system_server，Codex 另有 crash baseline/package；支持 `05`。
  3. ✅ session 状态：Claude hook 使用固定全局快照，Codex session-start 使用私有目录、权限及防软链处理；支持 `03`。
- 推断：⚠️ 未把真机、跨平台或覆盖率未知写成已验证事实；但“不可伪造 token”和所有切片 `<1h` 缺少可核对机制，不能当成已经成立。
- 过度设计：✅ 新增 gate、lease、registry、runtime 和 fallback 均有 report 风险依据；未发现无来源的产品扩张。
- 错误路径：⚠️ SKIP、非法 registry、超时、命令失败、stale owner 等覆盖明显加强；provider 缺席、token 获取/碰撞和跨类型锁冲突仍未定义完整。

## 最终判定

**NEEDS_CHANGES**。先修 B1；I1–I4 进入本轮改写。M1 可一并澄清或记账，但不能以结构校验通过替代语义修复。
