# 01-device-safety tasks review — round 3

## 结论

- **① 规格符合性：NEEDS_CHANGES。** 8 个任务均具备五字段，采用两级编号且无重复；需求并集恰为 R1–R7，文件范围与 design 的六项清单一致，既有产出没有孤儿，已声明的消费/产出签名也能逐字匹配，三个机械检查器均退出 `0`。上一轮 I1、I2、I3、M1 以及 design ledger M1 已闭合。但当前任务卡的代码步骤全部只有行为描述，没有按 tasks 细则给出代码块；且任务 1.5、2.3 的消费栏漏列其步骤实际依赖的前序签名，尚不满足可独立派发的五字段语义。
- **② 质量：NEEDS_CHANGES。** 红灯标签、合法/非法 serial、flag 优先级、Demo SKIP、skill 目标计数和逐 skill mutation 已成为真实可失败 oracle，现有源码也支持所写红阶段；实现范围没有越过 PLAN/spec。不过上一轮 I4 仅部分闭合：任务 1.4 仍把 fenced-block 解析、顺序/regex/逐命令静态判定和四个 mutation 集中在一个任务，任务 1.2 的十组非法矩阵也仍是单个实现步骤，无法合理满足每步 2–5 分钟和单任务人工 review `< 10 分钟`。
- 共发现 **0 个阻断、3 个重要、0 个次要**问题。
- **最终结论：NEEDS_CHANGES。**

## Findings

### 阻断（0）

无。

### 重要（3）

#### I1. 所有代码实现步骤仍只有 prose，没有 tasks 细则要求的可执行代码块

- tasks 细则将“描述做什么但不给怎么做的步骤（代码步骤必须给代码块）”列为禁止项，并要求验证内容直接给出；但 `tasks.md:14-16`、`:27-29`、`:40-42`、`:53-56`、`:67-68`、`:83-85`、`:98`、`:111-112` 全部只描述要实现的 Bash 函数、fixture、parser、mutation 或生产补丁，没有任何代码块。
- 这在任务 1.1/1.4 尤其承重：任务 1.1 没给 fake ADB 对 boot、system_server、btime、logcat、service、package 的确切响应和完整期望日志；任务 1.4 没给 fenced-block 提取、顺序判定、完整 regex 绑定及“恰好改动一处”的 mutation 实现。执行者仍需自行设计测试框架和解析算法，任务卡不能独立决定实现与 oracle。
- 应在代码步骤直接给出最小 Bash 代码或精确 patch 片段；至少要把 fake ADB 的 argv/响应表、scope dispatch、skill block 提取与每个 mutation 的构造和断言写成可落盘代码，而不是继续用“实现/增加/制作”概括。

#### I2. 任务 1.5 和 2.3 的消费栏没有声明步骤实际依赖的前序产出

- `tasks.md:62` 的任务 1.5 只消费三个矩阵/checker 签名，但 `:67-68` 要新增并注册 `legacy`、`all` scope，实际还依赖任务 1.1 产出的 `device_safety_register_scope <scope> <function>`；若 legacy 共用已安装的私有 fake ADB，还应明确是否消费 `device_safety_fake_adb_install <fixture> <serial>`。
- `tasks.md:105` 的任务 2.3 只消费最终测试入口，但 `:114-115` 要对四个 shell 文件做最终语法检查并跑默认 `all`，其绿灯建立在任务 2.1 的 Claude CLI 和任务 2.2 的 Codex CLI 已完成之上；这两个确切签名均未列入消费栏。
- 五字段的目的正是让隔离执行者只从消费栏学习接口与顺序。当前已声明的签名都逐字一致，但依赖集合不完整，会把 1.5/2.3 表述成可在其必要前序尚未完成时执行。应把实际使用的前序签名逐字补全。

#### I3. 上一轮粒度问题仍未闭合，任务 1.4 不能在一次快速 review 内可靠判定

- `tasks.md:53-57` 的任务 1.4 同时要求：解析所有 fenced Bash block、按两个 skill 固定目标计数、证明 preflight 位于首条 ADB 前、识别唯一 target 变量、枚举五类 ADB 子命令、制作并验证四个 mutation、稳定首错文案。步骤 1–3 每个都包含多个实现和断言动作，不是 2–5 分钟步骤；reviewer 也必须同时审核 parser 是否漏块、顺序检查是否恒真、mutation 是否确实命中唯一位置，明显难以稳定控制在 `< 10 分钟`。
- `tasks.md:27` 还把 10 个缺失/非法 serial case 的构造、执行、rc/stderr/零日志断言合成一个步骤；即使最终写成表驱动，任务卡也没有给出该表驱动代码，执行和审查成本仍不可预测。
- 应至少把 1.4 拆成“块提取与每 skill 目标计数”“preflight/逐命令静态判定”“逐 skill mutation 证明”三个可独立验收的小任务；任务 1.2 则拆开非法矩阵与合法 serial 正向矩阵，或直接提供足够短的表驱动实现，使每个步骤能按 2–5 分钟执行、每个任务能在 10 分钟内 review。

## 上一轮 I1–I4/M1 闭合核对

| 上一轮 finding | 状态 | 本轮证据 |
|---|---|---|
| I1 fenced-only oracle 漏掉 sepolicy 行内 ADB | **已闭合** | `tasks.md:53-57` 为两个 skill 固定目标计数 `1/1`，零目标明确失败；`:112` 又明确把 sepolicy 行内命令转换成唯一 fenced Bash block，并对两个 skill 各做两类 mutation。design `ledger.md:20` 的 M1 也由此闭合。 |
| I2 红阶段要求当前缺陷代码产生空日志 | **已闭合** | `tasks.md:30`、`:43`、`:82` 已区分“oracle 期望修复后零调用”和“当前原始日志非空/结果码错误”的红阶段证据，不再要求缺陷代码先满足零调用。 |
| I3 合法 serial 日志前缀被放宽 | **已闭合** | `tasks.md:15` 明确 fake 日志以命令名开头，`:28` 逐行要求精确 `adb -s <serial> ` 前缀，与 `requirements.md:42` 一致。 |
| I4 测试任务粒度过大 | **部分闭合，未闭合** | 原 5 个任务已拆为 8 个、测试骨架/serial/flag/skill/聚合和三个生产责任边界已分开；但 1.4 及 1.2 的步骤仍超过 2–5 分钟，1.4 仍超过 `< 10 分钟` review 粒度，见本轮 I3。 |
| M1 测试任务漏记 R7 | **已闭合** | 可执行入口断言现位于任务 1.3 的 `tasks.md:42`，其需求栏 `:37` 已包含 R7；任务 1.1 不再承担该断言。 |

## ① 规格符合性复核

| 检查项 | 结论 | 依据 |
|---|---|---|
| 五字段 | ✅ | 8 个任务均有非空 `文件 / 消费 / 产出 / 需求 / 必需`。消费字段的依赖完整性另见 I2。 |
| 编号层级 | ✅ | 使用两组二级编号 `1.1–1.5`、`2.1–2.3`，无重复、无三级。 |
| R1–R7 全集 | ✅ | 各任务需求并集恰为 R1、R2、R3、R4、R5、R6、R7，无遗漏或范围外 R。 |
| 无孤儿产出 | ✅ | fixture/helper 均被后续测试任务使用；最终测试是 requirements/design 的唯一 spec 产出；三个生产接口均为 design 明列终交付物。 |
| 签名逐字一致 | ✅ | 所有已写入消费栏的签名均可在更早产出逐字找到；最终测试、两个 verifier CLI 和 `device_serial` 与 requirements/design 对应签名一致。I2 是漏列依赖，不是已列签名拼写不一致。 |
| 文件清单 | ✅ | tasks 只创建/修改 design `:150-155` 的六个文件，无遗漏、无越界。 |
| 真实可失败 oracle | ✅ | 每个任务都有具体命令/事实；红阶段指定确切首错，绿阶段指定 rc/末行/日志/目标计数或 mutation 失败原因。当前源码确实仍为 Claude 裸 ADB、Codex serial 先于 flag、services 裸 ADB、sepolicy 零 fenced device block，能触发所写红灯。 |
| 红/绿证据链 | ✅ | 1.1 用文件不存在→fixture scope 绿；1.2–1.5 以确定的预期缺口红；2.1–2.3 分别先复现对应红灯，再跑局部 scope 和最终 all 绿。 |
| 代码步骤自包含 | ❌ | 所有代码步骤均无代码块，复杂 helper/oracle 的实现仍留给执行者设计，见 I1。 |
| 2–5 分钟步骤 / `<10` 分钟 review | ❌ | 任务 1.4 明显超限，任务 1.2 步骤 1 也非原子动作，见 I3。 |
| 无占位符 | ✅ | 未出现 TBD/TODO/“实现后补”等字面占位符；I1 是缺少必需实现代码，不是字面占位符。 |
| 机械检查 | ✅ | `check-tasks.py`、`check-req.py`、`check-criteria.py` 均退出 `0`；上述缺陷属于机械检查未覆盖的语义项。 |

## ② 质量复核

- **顺序：** fixture → serial → flag/Demo → skill oracle → 聚合 → Claude → Codex → skills，核心风险先证伪，生产责任边界顺序合理；但消费字段需补全真实顺序依赖。
- **范围/YAGNI：** 与 PLAN 的 `01-device-safety` 边界一致；未提前引入公共 runtime、lease、timeout/retry、common verifier 收敛、真实设备或 AOSP build。
- **oracle：** 上一轮的空跑、红灯矛盾和前缀放宽均已修复。固定每 skill 一个 device block、逐 skill 两类 mutation、零目标失败及精确日志前缀，能够防止主要假绿。缺少具体测试实现代码仍使复杂 parser/mutation 的正确性无法仅从任务卡保证。
- **错误路径：** 缺失/非法 serial、flag 优先级、未知 fake ADB serial/命令、未知 scope、Demo SKIP、旧回归失败和最终成功末行均有明确结果语义。
- **回滚：** 三个生产修改责任边界已独立；测试文件连续小步修改也有 helper 签名串联。任务 1.4 内部仍把三个可独立回滚的测试机制合在一起。

## 审查范围与只读证据

已完整读取本 spec 的 `requirements.md`、`design.md`、`ledger.md`、当前 `tasks.md`，项目 `PLAN.md`、`config.yml`、`DECISIONS.md`，前两轮 `reviews/tasks-01-round-1.md`、`tasks-01-round-2.md`，两个 verifier、两个 Claude skill、Claude/Codex/common 三套旧回归及适用的 `AGENTS.md`。

执行的机械/只读验证：

- `check-tasks.py tasks.md`、`check-req.py requirements.md`、`check-criteria.py requirements.md`：均退出 `0`；
- 对本 spec 现有三个 shell 文件逐文件 `bash -n`：退出 `0`；
- Claude、Codex、common 三套当前旧回归：均退出 `0`，末行分别为既有 PASS；
- `rg`/逐行核对：确认当前 Claude verifier 仍裸调用 `adb shell/logcat`，Codex 仍先校验 serial，services skill 仍有裸 ADB，sepolicy 真机命令仍位于 fenced block 外；确认当前红阶段假设成立。

未运行真实 ADB、CVD、AOSP build、网络或尚不存在的 `tests/test-device-safety.sh`；除本 review 报告外未修改 tasks、requirements、design、ledger 或实现源码。

## 最终判定

**NEEDS_CHANGES**
