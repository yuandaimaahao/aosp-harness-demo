# 01-device-safety tasks review — round 1

## 结论

- **① 规格符合性：NEEDS_CHANGES。** `tasks.md` 具备两级以内编号和五个必填字段，R1–R7 的需求并集完整，任务间消费/产出签名逐字一致，六个实现文件也与 `design.md` 文件清单完全一致；`check-tasks.py` 退出 `0`。但任务 2 的 `bash -n file1 file2 ...` 命令实际上只解析第一个脚本，其余路径会成为该脚本的位置参数，不能证明 requirements 要求的“本 spec 修改的 shell 文件全部通过 `bash -n`”。任务 1 的行为矩阵与任务 2 的红阶段也没有逐项写出可独立判定的期望结果。
- **② 质量：NEEDS_CHANGES。** 顺序遵循“先建立能证伪方案的红灯测试，再做最小实现”，范围没有越过本 spec，且没有引入 runtime、lease、重试或 common verifier 收敛；但两个任务都超过了“一步一个 2–5 分钟动作 / 人 review < 10 分钟”的粒度，尤其任务 1 同时承载 fake ADB 协议、约 20 组行为 fixture、Markdown fenced-block 解析、两类 mutation oracle 和三套完整旧回归聚合。当前拆分不足以可靠派给一次小任务并独立快速审查。
- 共发现 **0 个阻断、3 个重要、1 个次要**问题。
- **最终结论：NEEDS_CHANGES。** 修正验证命令、把红阶段和行为 oracle 写成确定性判据，并重新拆细任务后再审。

## Findings

### 阻断（0）

无。

### 重要（3）

#### I1. `bash -n` 验证命令静默漏掉后三个脚本，测试 oracle 不真实

- `tasks.md:29` 使用：

  ```bash
  bash -n ./claude-code/features/dev-sidebar/verify-sidebar.sh ./codex/features/dev-sidebar/verify-sidebar.sh ./claude-code/features/.harness/tests/test-harness.sh ./tests/test-device-safety.sh
  ```

- Bash 只把 `-n` 后的第一个文件作为脚本读取，后续路径作为该脚本的 `$@`；它们不是待解析文件。实测 `bash -n /dev/null /definitely/not/a/script` 仍退出 `0`，证明该命令会对不存在、甚至语法错误的后续脚本静默放行。
- 这直接不满足 `requirements.md:46` 的“`bash -n` 对本 spec 修改的 shell 文件全部退出 `0`”，也不满足 tasks review 的“命令真实判定成败”。即使主回归通常会执行这些文件，也不能把另一种执行路径等同于明确要求的逐文件静态语法验收。
- 应改成逐文件循环或逐条 `bash -n`，并保留任一文件失败即整体非零的语义，例如明确列出四个路径逐个检查。

#### I2. 行为测试和红阶段没有写出逐项期望，执行者仅看任务无法实现可靠 oracle

- `tasks.md:12` 只列出输入集合：“10 个缺失/非法 serial、2 个合法 serial、四个 flag/serial 组合、两个 Demo SKIP”，但没有在任务内重复写清每组的退出码、stderr、stdout 末行和 fake ADB 日志断言。
- 这些判据在 `requirements.md:41-45` 中是承重语义：非法 serial 要 `exit 2`、stderr 含 `ANDROID_SERIAL`、日志为空；真实 `--allow-skip` 要先报精确 flag 错误、stderr 不含 `ANDROID_SERIAL`、日志为空；合法 serial 要所有调用固定前缀且末行为 `RESULT PASS`；Demo SKIP 要有 `SKIP  ` 明细、精确末行和 `exit 0`。任务格式明确要求测试内容直接给出，执行者可能乱序只读单任务，不能依赖回看 requirements 猜 oracle。
- `tasks.md:15` 将首次红灯描述为“verifier serial/flag 或 skill block 断言处”任一失败，`tasks.md:25` 又只要求保存“首个失败断言”。这不是确定性的红阶段：测试自身解析/fixture 错误、错误的矩阵顺序或任一非目标故障也能满足该文字，不能证明当前源码恰因预期缺口而红。
- 应把每类 case 的输入、期望 rc、精确/包含输出和日志状态写入任务，并给任务 1、任务 2 各指定至少一个确定的首要红灯（例如当前 Claude 缺失 serial 未在零 ADB 前返回 2，或当前 Codex 对真实 `--allow-skip` 先报 serial 错而非 flag 错）。

#### I3. 两个任务均未达到 tasks 标准的原子粒度和快速 review 上限

- `tasks.md:11-13` 的三个“步骤”分别包含搭建完整 fake ADB 协议、实现约 20 组跨入口 fixture、运行三套旧回归，以及编写 fenced-block 解析器并做至少两类 mutation 验证；每项本身都明显超过单个 2–5 分钟动作。
- 任务 1 预期会生成本 spec 最大、逻辑最密集的文件。一个 reviewer 必须同时审查命令白名单、逐参数日志、污染隔离、所有结果矩阵、Markdown 块级顺序判定、mutation 的确切命中和旧回归聚合，无法合理满足 `< 10 分钟` 的单任务 review 判据。
- `tasks.md:26-28` 的任务 2 也把两个 verifier 的不同改动、两个 skill 的所有真机代码块和 Claude legacy fake fixture 合成一个实现任务；任一部分失败时只能整体回滚五个文件，不能按独立行为边界小步回滚。
- 建议至少按“根测试基础设施与确定性行为矩阵”“skill 块级/mutation oracle”“verifier 前置层”“两个 skill 与 Claude legacy fixture”拆分，并让每片有自己的确定性红/绿命令。若继续修改同一个测试文件，应用明确的 helper/section 产出签名串起依赖，避免并行或乱序实施。

### 次要（1）

#### M1. 任务 1 的需求字段与 design 的组件映射不一致

- `design.md:18` 明确将“根级 device-safety 隔离回归”映射到 `R1, R2, R3, R4, R5, R6, R7`；任务 1 正是在创建该回归，行为矩阵也覆盖全部七条需求，但 `tasks.md:8` 只写 `R6`。
- 两个任务需求栏的并集仍严格等于 R1–R7，所以不是全集缺口；不过单任务追溯会把 R1–R5、R7 的测试交付错误归到实现任务，而不是实际落盘验证它们的任务。拆分时应让测试任务列出它实际验证的需求，避免 isolated task review 误判范围。

## ① 规格符合性复核

| 检查项 | 结论 | 依据 |
|---|---|---|
| 五字段 | ✅ | 两个任务均有 `文件 / 消费 / 产出 / 需求 / 必需`，没有空字段。 |
| 编号层级 | ✅ | 仅有平铺任务 `1`、`2`，无重复、无三级编号；任务数 ≤ 5，符合规则。 |
| R1–R7 全集 | ✅ | 任务 1 为 R6；任务 2 为 R1、R2、R3、R4、R5、R7；并集恰为 R1–R7，无额外 R。M1 是单任务映射精度问题，不影响并集。 |
| 消费/产出签名 | ✅ | 任务 2 的消费可在更早任务 1 的产出中逐字找到；该签名也与 `requirements.md:5` 的唯一 spec 产出逐字一致。 |
| 无孤儿产出 | ✅ | 任务 1 产出被任务 2 消费且是 spec 终交付物；任务 2 的 Claude CLI 是 R1/R2/R4/R5/R7 和 design 组件接口中的终行为入口。 |
| 文件清单一致 | ✅ | tasks 共涉及 `tests/test-device-safety.sh` 加五个修改文件，与 `design.md:150-155` 六项完全一致，无新增、遗漏或越界文件。 |
| 每任务具体验证 | ❌ | 两个任务都有验证命令，但任务 2 的多文件 `bash -n` 是静默漏检；行为矩阵缺逐项期望。见 I1、I2。 |
| 每任务红阶段 | ❌ | 两个任务文字上都包含“失败”，能通过软门检查；但实际允许任意首错，不是能证明目标缺口的确定性红灯。见 I2。 |
| 无占位符 | ✅ | 未发现 TBD/TODO/“实现后补”或未定义接口。 |
| 机械检查 | ✅ | `python3 .../scripts/check-tasks.py tasks.md` 退出 `0`；I1/I2 属于机械检查未覆盖的语义缺陷。 |

## ② 质量复核

### 顺序与依赖

- 先写安全回归、确认红灯，再修改 verifier/skill/legacy fixture，符合“先验证核心、坏消息前置”。
- 任务 2 对任务 1 的消费签名确切，未引用未来任务或未定义 API。
- 复杂度从“大型综合测试任务”直接跳到“五文件综合实现任务”，中间缺少可单独验收的组件级小片；见 I3。

### 可独立回滚

- 新测试文件与生产修改分成两次交付，方向正确；回退任务 2 不会删除任务 1 的安全判据。
- 但任务 2 内部五文件涵盖三个不同责任边界，失败时无法只回退 Codex flag、Claude ADB adapter、skill 文档或 legacy fixture 中的单一部分；这弱于 tasks 标准要求的独立回滚粒度。

### 测试 oracle 真实性

- fake ADB 的私有 `PATH`、分离参数日志、命令白名单、拒绝路径零调用、合法 serial 正向路径，以及块级 mutation 思路都是正确方向；尤其 `tasks.md:13` 已落实上一轮 design review 的 M1，没有退化成全文件关键词存在性检查。
- 当前源码证据支持预期红灯：Claude verifier 仍在真实模式裸调用 `adb shell`/`adb logcat`（`claude-code/features/dev-sidebar/verify-sidebar.sh:52,78`），且没有 serial/flag 前置层；Codex verifier 在 `codex/features/dev-sidebar/verify-sidebar.sh:47-54` 先校验 serial，尚未先拒绝真实 `--allow-skip`；两个 Claude skill 仍有裸 ADB（`build-services-jar/SKILL.md:30-33`、`build-sepolicy/SKILL.md:41`）。
- 但是准确的源码缺口并不能补偿 tasks 中缺失的期望断言；验证实现者必须从任务本身知道什么才算红、什么才算绿。I1 的 `bash -n` 误用也必须修复。

### YAGNI 与实现明确性

- 没有引入公共 ADB runtime、timeout/retry、lease、common verifier 修改、真实设备或 AOSP build，严格留在 `01` 的 PLAN 边界内。
- `ADB=(adb -s "$serial")`、flag 校验顺序、skill 中的 `device_serial` 和 legacy fake argv 剥离都有明确实现方向，不需要额外架构设计。
- 实现动作描述覆盖了所有已知热点，但单步聚合过多，且行为测试期望未自包含；因此“做什么”清楚，“如何证明每个小片做对”仍不够明确。

## 审查范围与证据

已完整读取：

- 本 spec 的 `requirements.md`、`design.md`、`ledger.md`、`tasks.md`；
- 项目 `PLAN.md`、`config.yml`、`DECISIONS.md`；
- 前一轮 `reviews/design-01-round-1.md`；
- 两个 verifier、两个 Claude skill、Claude/Codex/common 三套旧回归，以及适用的 `AGENTS.md`。

执行的只读/机械验证：

- `python3 /home/zzh0838/.agents/skills/spec/scripts/check-tasks.py .../tasks.md`：退出 `0`；
- `bash -n /dev/null /definitely/not/a/script`：退出 `0`，用于证明多路径 `bash -n` 的静默漏检；
- `rg`/逐行源码核对：确认当前红灯热点、文件边界和现有测试 fake ADB 模式。

未运行真实 ADB、网络、AOSP build 或尚不存在的 `tests/test-device-safety.sh`；未修改源码、requirements、design、ledger 或 tasks。

## 最终判定

**NEEDS_CHANGES**
