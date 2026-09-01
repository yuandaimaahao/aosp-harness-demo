# PLAN v6 增量独立审查 — Round 1

审查对象：`PLAN.md` v6 当前磁盘版本及 v5→v6 受影响范围；同时完整读取 `research/report.md`、`PLAN-history.md`、原 `00-environment-seed-preflight/requirements.md`、`sizing-prototype.md`、`DECISIONS.md`、`references/02-decompose.md` 与 `references/07-review.md`。

审查边界：只核对拆分触发证据、00a/00b 的 P1–P5、切口稳定性，以及受影响的签名、owner、rollback、依赖、整体验收/public gate 和遗留 00 文本；未重审 v5 未受影响的 01–05 设计，也未修改 `PLAN.md` 或运行 AOSP/lunch/build/download。

## 结论摘要

- 结论：**不通过**。Findings 为 0 个阻断、5 个重要、1 个次要。
- 原 00 的拆分 gate **确实被触发**：按 sizing 表的区间做保守计算，最低仍为 `610 + 620 - 340 = 890` 行，严格高于 800。虽然表中 `1000–1200` 的标题区间不是由各行区间直接推出，但这不改变必须回 PLAN 的结论。
- `schema/store/runtime → environment provider` 是已有 closed ABI 上的稳定切口，00a 有 fixture 能力产出，00b 有 real seed 或 terminal knowledge 产出，依赖图也保持无环；但 00b 的上界仍可能超过 800、00a 回滚会移除 00b 依赖的 runtime，故两片尚未各自满足全部 P1–P5。
- 当前 PLAN 对 public gate 的执行者/输出字节仍有冲突，资源冲突节又把 CLI owner 写回 01；`DECISIONS.md` 中若干仍具规范效力的旧 00 owner/gate 文字也未声明被 v6 替代。

## 验证记录

- `python3 /home/zzh0838/.agents/skills/spec/scripts/check-plan.py .spec/2026-09-01-aosp-feature-minimal-checkout/PLAN.md`：exit 0，无输出。
- `check-plan.py` 只证明文档形状通过；以下 finding 均为它不覆盖的区间算术、P1–P5 和跨文档语义一致性。

## Findings

### 阻断

无。

### 重要

#### I1 — sizing 没有证明 00b 满足 P5；拆分后仍存在超过 800 行的预测

- **位置：** `sizing-prototype.md:5-19`；`PLAN.md:82-88`。
- **依据：** sizing 表给 environment 半片的实现+测试估算为 `620–820` 行，上界已经超过 800。`-240–340` 行共享收益只按“合并后可共享部分”给出，没有分配到 00a/00b，因此不能从表中推出 00b 的最终区间必然 `≤800`。末行直接声称“两片各自预计不超过 800 行和 1 小时人审”缺少逐片算式。PLAN 给 00b 写了 `≤800` 目标，但没有像 R24 那样证明当前 estimate 已过门。
- **影响：** v6 可能只是把原 00 的超限风险搬到 00b；这不满足 P5，也不足以作为进入新 requirements/design 的拆分依据。
- **建议：** 给出扣除共享后的 00a、00b 各自 implementation/test/non-generated diff 区间及 review summary 行数；按高位估算判门。若 00b 仍为 820，应在本次 PLAN 内继续沿稳定 provider artifact 再拆，而不是等实现后才发现超限。

#### I2 — 00a 的回滚会移除 00b 及后序实际依赖的 runtime，P2 未成立

- **位置：** `PLAN.md:76-88,156-158,175-186`。
- **依据：** 00b 明确消费 00a 的 schema/publisher/runtime；回滚矩阵却规定撤回 00a 后“后序 capability 不存在”，只说后序 direct modules “可单独审计”。这不是一个可执行的独立回滚结果，也没有给出 direct module 在 runtime 缺席时的精确 exit/status。它还弱于 v4 为解决 dispatcher 根依赖而固定 direct recovery ABI 的裁定：direct command 文件即使仍在，没有 00a 的 store/ref/schema runtime 也不能完成自身契约。
- **影响：** 回滚 00a 会使已合入 00b 及后序 command 失去运行能力，当前证据不足以满足“回滚它不牵连已合入其他 spec”的 P2。
- **建议：** 将不可撤回的最小 dispatcher/runtime 基座切成真正独立且有缺席协议的产出，或为每个后序 direct module 固定不依赖 00a commit 的入口/最小 runtime；至少写出回滚 00a 后逐个 consumer 的具体命令、精确 fail-closed 结果，并说明为何无需联动回滚其他 merge commit。

#### I3 — 00b 独立判据把 control-plane gate 混入了 `preflight` 的 exact stdout，整体验收没有执行 public gate

- **位置：** `PLAN.md:15-38,63-65,82-88,160-171`；原 `requirements.md:46,62-66,165-178`。
- **依据：** 00b 的独立判据写成 direct `preflight ...` 对 real public seed 输出 `ENV PASS`/`GATE CONTINUE_PUBLIC`；但稳定结果码表只给 preflight 成功状态 `ENV PASS`，原已确认 R19 更要求 stdout 精确一行 `ENV PASS SCOPE_ID`，`GATE CONTINUE_PUBLIC` 属于 control plane。整体验收只直接调用 `feature-closure preflight`，期望说明也只列 `ENV PASS`，没有另一个可执行命令或 ref/evidence assertion 证明控制面实际发出了 `GATE CONTINUE_PUBLIC` 才进入 01。
- **影响：** 实现者无法同时满足 exact one-line CLI ABI 与 00b 表中的两种输出；编排器也缺少可验收的 public-only advancement gate。
- **建议：** 保持 preflight 的 exact stdout 为 `ENV PASS public_aosp17_cuttlefish`，另行固定 control-plane gate 的命令/输入/精确输出；或者把门定义为编排器对 fixed public `kind=env_pass` ref、matching `real_source` object 与 exit 0 的原子判定，并在整体验收中显式断言。不要把两层输出写成同一 CLI 签名。

#### I4 — 资源冲突节仍把 closure CLI/目录的新增 owner 写给 01，与 00a owner 冲突

- **位置：** `PLAN.md:74-80,90-97,154-158,203-208`。
- **依据：** PLAN 已固定 00a 独占 `feature-closure` dispatcher、schemas/store/ref runtime，01 只新增 `verify-lock` command module且不得修改 dispatcher；但资源冲突节仍写“01 只新增 closure v1 目录/CLI”。这会让 01 被理解为 CLI/目录 creator，与 00a 的稳定 owner 和拆分顺序矛盾。
- **影响：** 文件 owner 不唯一，可能导致 01 修改或重建本应由 00a 固化的 ABI，破坏稳定切口和独立回滚。
- **建议：** 将该句改为 01 只在 00a 已存在的版本化目录下新增其独占 schema/validator/`verify-lock` command module；明确公共 dispatcher/runtime 零修改。

#### I5 — `DECISIONS.md` 的旧 00 owner/public gate 条目仍是活跃口径，与 v6 实际分工冲突

- **位置：** `DECISIONS.md:12,16,18-19`；`PLAN.md:82-88,142-158`。
- **依据：** `DECISIONS.md` 自称后序必须遵守已确认口径，但仍写“00 是两类 seed schema/producer/fixture 的唯一 owner”，而 v6 已拆为 00a owner schema/runtime、00b owner producer/provider；它还写 real local preflight exit 0 输出 `GATE CONTINUE`，随后另一条才写只有 `GATE CONTINUE_PUBLIC` 可进入 01。另有旧 `env-preflight/v1` 名称，与当前 `seed/v1` artifact / `env_pass` ref 分层不一致。PLAN/PLAN-history 中“原 00”作为历史来源没有问题，问题仅在这些仍会指导后序 spec 的活跃决策文本。
- **影响：** 新 00a/00b 起草 requirements 时会同时得到互斥的 owner、artifact 名和推进门，可能重新引入 local seed 解锁 public chain 或共同修改同一文件。
- **建议：** 追加明确的 PLAN v6 superseding decisions，逐条覆盖 schema/runtime owner、provider/ref owner、artifact/ref kind 和 public-only gate；或给被替代的旧 00 条目标记“已由 v6 某条替代”，保留历史但取消规范效力。

### 次要

#### M1 — `1000–1200` headline 与 sizing 表的区间算术不一致，但不影响原 00 超过 800 的结论

- **位置：** `sizing-prototype.md:3-12`；`PLAN.md:9`；`PLAN-history.md:44`。
- **依据：** 对表内区间做保守区间运算，原 00 范围应为 `610–730 + 620–820 - 240–340 = 890–1310`，不是 `1000–1200`。即使取最小 890 仍超过 800，所以 replan 触发本身有效。
- **建议：** 将 headline 改为由表可复算的 `890–1310`，或说明 `1000–1200` 是另一个点估计/置信区间及其推导，避免后续审查把未说明的区间收窄当作精确 sizing。

## 00a/00b P1–P5 复核

| spec | P1 独立验收 | P2 独立回滚 | P3 独立产出 | P4 ≤15 | P5 <1h |
|---|---|---|---|---|---|
| 00a | ✅ `verify-seed` fixture/fault matrix 可独立执行 | ❌ 撤回 runtime 会使已合入 consumer capability 不存在，缺精确缺席命令 | ✅ 固定 schema/digest/store/ref runtime 能力 | ✅ 0 个新增问题 | ✅ 当前估算 `610–730`，高位低于 800；仍需 tasks estimate 守门 |
| 00b | ⚠️ real public PASS 或 terminal knowledge 均可验，但 gate 输出层级冲突 | ✅ 撤回 00b 不改 00a，00a fixture 能力保留 | ✅ real seed/ref 或 terminal report | ✅ 0 个新增问题 | ❌ 表中高位 820，且共享扣减未按片分配 |

结论：P1/P3/P4 和依赖方向支持这条切口；P2/P5 尚不满足“五条全满足”，因此 v6 不能通过门①增量 review。

## 受影响一致性复核

- **切口：** schema/canonical digest/store/ref/dispatcher 与 Repo/resource/namespace/trace/lunch provider 之间是已冻结 ABI 上的稳定水平切口；不存在需要 00a/00b 往返修改 schema 的新证据。切口方向成立，但 I2/I4/I5 使 owner/rollback 边界尚未闭合。
- **依赖：** `00a → 00b → 01` 在 spec 表和依赖图中一致且无环；实现类仍串行，资源冲突识别充分。
- **产出/消费：** 00b 消费 00a runtime、发布 public/local seed/terminal ref，02 读取 public descriptor ref，主链方向一致；但 `PLAN.md:84` 所称消费 00a “direct recovery ABI”不够准确，真正消费的是 versioned schema/store/publisher runtime，`preflight` direct ABI 本身属于 00b。修复 I2 时应一并把签名写清。
- **整体目标：** 00a fixture-first、00b real-environment-first 仍保持最早排除环境单点失败，没有改变公开 `services` 范围或 01–05 顺序。
- **历史文字：** PLAN/PLAN-history 中“原 00”作为触发证据或历史版本引用不构成矛盾；`DECISIONS.md` 中仍被后序消费的 owner/gate 口径构成实际矛盾，见 I5。

## 最小修订顺序

1. 先补逐片 sizing，把 00b 高位压到 800 以内或继续拆分。
2. 固定 00a rollback 后所有 consumer 的可执行缺席协议，重新证明 P2。
3. 分开 preflight exact stdout 与 control-plane `GATE CONTINUE_PUBLIC`，把 public gate 放进整体验收。
4. 修正 01 的 CLI owner 文案，并在 `DECISIONS.md` 明确 v6 对旧 00 owner/gate 的替代关系。

VERDICT: FAIL
