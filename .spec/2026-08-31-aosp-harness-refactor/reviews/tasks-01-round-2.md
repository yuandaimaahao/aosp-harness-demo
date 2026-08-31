# 01-device-safety tasks review — round 2

## 结论

- **① 规格符合性：NEEDS_CHANGES。** 五字段、编号、R1–R7 并集、文件边界、前后任务签名和最终产出签名均通过，`check-tasks.py` 退出 `0`；上一轮 I1 的逐文件 `bash -n` 问题已修复。不过 skill oracle 只枚举 fenced `bash` block，当前 `build-sepolicy` 的两条真机 ADB 命令却位于行内代码，任务又没有要求目标块计数、转换该段为 fenced block 或逐 skill mutation，因此 R3/R6 仍可能在 sepolicy 完全未被检查时绿灯。任务 1 的合法 serial 日志判据也没有继承 requirements 要求的精确 `adb -s <serial> ` 前缀。
- **② 质量：NEEDS_CHANGES。** 任务顺序是先红灯 oracle、再分组件实现，范围未越过 PLAN/spec 文件清单，也没有引入后续 runtime/lease/common 收敛；但任务 1 的红阶段同时要求当前缺陷代码产生空 fake-ADB 日志，和源码事实矛盾，无法按文字完成。由 2 个任务拆为 5 个是改进，但任务 1、2 仍各自包含多个明显超过 2–5 分钟的步骤，单任务 review 也难以稳定控制在 10 分钟内。
- 共发现 **0 个阻断、4 个重要、1 个次要**问题。
- **最终结论：NEEDS_CHANGES。**

## Findings

### 阻断（0）

无。

### 重要（4）

#### I1. fenced-only skill oracle 会漏掉当前 `build-sepolicy` 真机命令，R3/R6 可空跑通过

- `tasks.md:27` 要求“逐 fenced `bash` code block”提取且只检查其中的 ADB 真机块。
- 当前 `claude-code/features/.harness/skills/build-sepolicy/SKILL.md:34-38` 的唯一 fenced `bash` block 只有构建命令；真正的 `adb shell dmesg` 和 `adb shell service list` 位于 `:41` 的 Markdown 行内代码，不属于 fenced block。
- `tasks.md:28` 的两个 mutation 没有规定逐 skill/逐目标块执行，`tasks.md:32` 的预期首错也只锁定 services skill。因此实现者可以只让 services block 被发现并完成两种 mutation，而 sepolicy 零目标块、零 mutation 仍然整体通过。
- 这违背 `requirements.md:43` 对两个 Claude skill 每个真机代码块的验收，也没有落实 `ledger.md:20` 要求的块级 oracle 防假阳性挂账。
- 应明确目标清单/计数，并规定 sepolicy 的处理方式：要么任务 5 明确把行内验证改为 fenced `bash` block，要么 oracle 同时覆盖该行内真机段；原文件和 mutation 均应逐 skill、逐目标块取证，零目标块必须失败。

#### I2. 任务 1 的红阶段要求与当前源码矛盾，无法取得所写证据

- `tasks.md:17` 不仅要求首错为 `expected rc=2`，还要求 Claude 缺少 serial case 的 fake ADB 日志为空。
- 当前 Claude verifier 在没有任何 serial preflight 的情况下从 `claude-code/features/dev-sidebar/verify-sidebar.sh:52` 调用裸 `adb shell`，并在 `:78` 调用裸 `adb logcat`。按 `tasks.md:11` “逐参数记录 argv”的 fake adb 约定，该红阶段日志必然非空。
- 红阶段应证明“期望空日志的断言也失败”或明确断言现状日志非空，而不能要求缺陷修复前已经满足零调用。否则执行者只能伪造/清空日志或无法完成任务 1。

#### I3. 合法 serial 的日志 oracle 没有继承 requirements 的精确前缀

- `requirements.md:42` 要求 fake ADB 每条记录精确以对应 `adb -s <serial> ` 开头。
- `tasks.md:12` 只要求每行以 `-s <serial>` 开头；结合 `tasks.md:11` 仅记录 fake executable 收到的 argv，实现可以不把命令名 `adb` 写入日志，仍按 tasks 通过，却不能勾选 requirements 的精确验收项。
- 应让 fake 记录明确包含命令名，并逐行断言精确 `adb -s <serial> ` 前缀，或先修改 requirements/design 统一为只验证 argv 的 `-s <serial>`；tasks 不能自行放宽。

#### I4. 拆分后任务 1、2 仍未满足原子步骤与快速 review 判据

- `tasks.md:11-15` 在一个任务内同时搭建 fake adb 协议、实现 12 个 Claude serial case、4 个跨入口 flag case、2 个 Demo fixture、scope/失败汇总；步骤 1 和步骤 2 各自都包含多种动作，明显不是单个 2–5 分钟动作。
- `tasks.md:27-30` 又把 Markdown block 提取与顺序判定、两种 mutation、三套旧回归聚合、scope 编排集中在同一测试任务。仅审查 extractor、mutation 是否真实命中以及 legacy 隔离，就难以满足单任务 `< 10 分钟`。
- 从上一轮 2 个任务拆到 5 个消除了 verifier/skill 实现的整体回滚问题，但测试侧仍应继续拆出“fixture/helper”“verifier matrix”“skill oracle/mutations”“legacy/final aggregator”等可独立验证、可快速 review 的片段；若连续修改同一文件，用确切 helper 签名串起消费/产出。

### 次要（1）

#### M1. 任务 1 仍漏记它实际验证的 R7

- `tasks.md:14` 明确断言两个 verifier 路径可执行，这是 R7 的验收内容，但 `tasks.md:8` 仅列 `R1, R2, R4, R5, R6`。
- R7 已由任务 2/3/4 的需求字段覆盖，所以需求并集没有缺口；问题仍是 isolated task 的追溯不准确。任务 1 若保留该可执行性断言，应把 R7 加入需求字段。

## 上一轮 I1/I2/I3/M1 闭合核对

| 上一轮 finding | 状态 | 本轮证据 |
|---|---|---|
| I1 多文件 `bash -n` 静默漏检 | **已闭合** | `tasks.md:46`、`:74` 均改为逐文件循环，任一文件失败即非零；任务 1/2 对新脚本也分别执行单文件 `bash -n`。 |
| I2 行为 oracle/红阶段不确定 | **部分闭合，未闭合** | `tasks.md:12-14` 已写出各矩阵的 rc、stderr、末行和日志 oracle，`:17`、`:32`、`:42`、`:57`、`:70` 也给出确定失败标签；但 `:17` 的“红阶段日志为空”与当前裸 ADB 源码矛盾，见本轮 I2，合法 serial 日志前缀亦被放宽，见 I3。 |
| I3 两任务粒度过大 | **部分闭合，未闭合** | verifier、Codex flag 和两个 skill 已拆成独立实现任务；但测试任务 1/2 仍不满足 2–5 分钟原子步骤和 `< 10 分钟` review，见本轮 I4。 |
| M1 测试任务需求映射不准 | **部分闭合，未闭合** | 根测试被拆后，任务 1/2 的需求并集覆盖 R1–R7；但任务 1 自身仍验证 verifier 路径可执行却漏列 R7，见本轮 M1。 |

另核对设计阶段 `ledger.md:20` 的同名 M1：**未闭合**，因为当前 fenced-only oracle 可漏掉 sepolicy 行内 ADB，见本轮 I1。

## ① 规格符合性复核

| 检查项 | 结论 | 依据 |
|---|---|---|
| 五字段 | ✅ | 5 个任务均有 `文件 / 消费 / 产出 / 需求 / 必需`。 |
| 编号层级 | ✅ | 平铺任务 1–5，无重复、无三级编号，符合任务数 ≤5 的规则。 |
| R1–R7 全集 | ✅ | 所有需求字段并集恰为 R1–R7，无额外 R。 |
| 消费/产出签名 | ✅ | 任务 2 消费逐字匹配任务 1 产出；任务 3–5 消费逐字匹配任务 2 产出；最终测试签名与 requirements frontmatter/design 接口逐字一致。 |
| 无孤儿产出 | ✅ | helper 被任务 2 消费；最终 test 被任务 3–5 消费且是 spec 终产出；三个实现接口均对应验收行为。 |
| 文件清单 | ✅ | tasks 仅涉及 design 文件清单中的六个文件，无越界或遗漏。 |
| 验证继承 | ❌ | sepolicy oracle 可空跑，合法 serial 日志精确前缀被放宽；见 I1、I3。 |
| 红阶段 | ❌ | 已有确定失败标签，但任务 1 同时要求当前日志为空，证据不可取得；见 I2。 |
| 无占位符 | ✅ | 未发现 TBD/TODO、模糊错误处理或未定义引用。 |
| 机械检查 | ✅ | `python3 .../scripts/check-tasks.py tasks.md` 退出 `0`；`check-req.py`、`check-criteria.py` 也退出 `0`，上述均为机械检查未覆盖的语义问题。 |

## ② 质量复核

- **顺序：** 先建立 verifier matrix，再补 skill/legacy oracle，随后依次改 Claude、Codex、skills；核心红灯前置且没有未来依赖。
- **范围/YAGNI：** 六文件与 design 完全一致；未引入公共 command runtime、lease、common verifier 修改、真实设备、网络或 AOSP build。
- **错误路径：** serial 缺失/非法、flag 优先级、Demo SKIP、fake ADB 未知命令、旧回归失败均有明确方向；但红阶段日志要求自相矛盾。
- **oracle 真实性：** verifier 行为矩阵显著改善；skill oracle 因 fenced-only 与零目标计数缺失仍可产生假绿，合法 serial 日志文字也低于验收精度。
- **粒度/回滚：** 三个生产责任边界已可独立回滚；两个测试任务仍过密，未达到 spec 的步骤和 review 时限。

## 审查范围与只读证据

已完整读取 `tasks.md`、同 spec 的 `requirements.md`、`design.md`、`ledger.md`，项目 `PLAN.md`、`config.yml`、`DECISIONS.md`、上一轮 `reviews/tasks-01-round-1.md`，以及六个涉及文件的当前源码/文档、三套旧回归中与 ADB/verifier/隔离有关的调用点和适用 `AGENTS.md`。

执行的机械/只读检查：

- `check-tasks.py tasks.md`：退出 `0`；
- `check-req.py requirements.md`：退出 `0`；
- `check-criteria.py requirements.md`：退出 `0`；
- `rg`/逐行核对：确认 sepolicy ADB 位于 fenced block 外、Claude 当前缺 serial 时会调用裸 ADB、任务签名/需求并集/文件边界。

未运行真实 ADB、CVD、AOSP build、网络或尚不存在的 `tests/test-device-safety.sh`；未修改 tasks、requirements、design、ledger 或实现源码。

## 最终判定

**NEEDS_CHANGES**
