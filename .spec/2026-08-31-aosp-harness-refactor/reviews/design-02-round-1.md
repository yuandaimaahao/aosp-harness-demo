# 02-offline-quality-gate design review — round 1

## 结论

- **① 规格符合性：NEEDS_CHANGES。** 八节与文件清单齐全，R1–R9 全覆盖，`产出`/`消费` 两条签名均在组件接口中逐字出现，三幅 Mermaid 图语法闭合，文件边界也没有越出 PLAN 的 `02`。但错误处理表把 baseline 错误与 config 错误合并成“静态检查均未运行”，和 requirements 及本设计时序中的 `static -> config` 顺序直接冲突。
- **② 质量：NEEDS_CHANGES。** round 3 唯一挂账 M1 已正确关闭：canary 位于仓库外，两次 Gitleaks 调用仅 target 不同，固定 options/config 相同，且 canary 在工作树扫描前由显式清理加 trap 保底。NUL/C-locale/不跟随软链、nested contract、immutable baseline、shallow checkout 与 387 行预算的主方案均可行；仍需锁定 workflow 安装产物向 gate 暴露的跨 step 接口，并增强两个不会由普通 ASCII fixture 暴露的 oracle。
- **findings：阻断 0、重要 2、次要 2。最终结论：`NEEDS_CHANGES`。**

## Findings

### 阻断（0）

无。

### 重要（2）

#### I1. config 校验失败时“静态检查是否已运行”在错误表与既定时序中互相矛盾

- requirements R6（`requirements.md:35`）固定顺序为 core syntax/tests → ShellCheck/shfmt → config 校验 → canary → 工作树 Gitleaks；设计时序也按该顺序画在 `design.md:137-144`。
- 但错误表把 “Baseline/config 摘要或格式错” 合并后写成“不运行静态/秘密扫描”（`design.md:159`）。这对 baseline 错成立，因为 baseline 在 static 前校验；对 config 错不成立，因为 static 已经执行。
- 两种实现都能从当前 design 找到依据：实现者可以把 config 提前到 static 前，也可以遵循时序在 static 后校验。前者违反 R6 的固定顺序，后者违反错误表，任务与 contract oracle 会因此分叉。
- 应拆成两行：baseline 协议错返回 `2` 且 static/secret 均零调用；config 协议错返回 `2`，已完成的 core/static 不回滚，只保证 canary/工作树 Gitleaks 零调用。

#### I2. workflow 到 gate 的工具安装接口没有锁定，`RUNNER_TEMP` 中的二进制不天然跨 step 可见

- `design.md:67-69` 只写“安装到 `RUNNER_TEMP`，随后调用 gate”，没有说明三个命令怎样进入 gate 的 `PATH`。若下载/安装与质量 gate 是不同的 Actions step，前一步里的普通 `export PATH=...` 不会传到后一步，结果会被 gate 的 CI preflight 判成工具缺失。
- 同一段也没有在 design 内列出 requirements 已固定的三组完整 asset 文件名、摘要及安装形态：ShellCheck 是 `.tar.xz`、shfmt 是单文件、Gitleaks 是 `.tar.gz`。版本在 `design.md:42` 锁定了，但 artifact → executable 的边界仍留给任务阶段临时决定。
- 官方 release 元数据确认三组既定值真实且一一对应：[`shellcheck-v0.11.0.linux.x86_64.tar.xz`](https://api.github.com/repos/koalaman/shellcheck/releases/tags/v0.11.0)、[`shfmt_v3.14.0_linux_amd64`](https://api.github.com/repos/mvdan/sh/releases/tags/v3.14.0)、[`gitleaks_8.30.1_linux_x64.tar.gz`](https://api.github.com/repos/gitleaks/gitleaks/releases/tags/v8.30.1)，摘要与 requirements 第 91 行一致。
- design 应明确一种唯一边界：例如都安装为 `$RUNNER_TEMP/bin/{shellcheck,shfmt,gitleaks}`，安装 step 写入 `$GITHUB_PATH` 后由单独 quality step 唯一一次调用 gate；或者安装与唯一 gate 调用在同一个 `run` step 并使用该 step 内的显式 `PATH`。同时把三组完整 filename/SHA-256 写入 workflow 组件，而不是只写“固定资产”。

### 次要（2）

#### M1. NUL、symlink 与 locale 的实现边界写清了，但测试策略没有锁定能击穿错误实现的路径样例

- `design.md:42,51` 已规定仓库绝对根、普通文件、不跟随软链、NUL 分隔和 `LC_ALL=C sort -z`，架构选择本身正确。
- `design.md:169` 只以 “managed discovery/syntax、排序” 概括 contract。只使用普通 ASCII 文件名时，换行分隔实现、跟随 symlink 的实现以及继承宿主 locale 的实现仍可能通过。
- 建议在同一表驱动 fixture 中明确加入至少一个含空格或 LF 的受管文件、一个指向受管/语法错误目标的 symlink，以及一组在非 C locale 下排序可能不同的名称；分别断言每个普通文件只出现一次、symlink 零次、实际顺序仍是 C-locale 字节序。这可复用现有 case 表，不要求新增文件或放宽 200 行预算。

#### M2. canary 已 fail-closed，但“默认规则可识别”的具体字节仍留给实现者试错

- `design.md:98-99` 正确规定运行时两段拼接、仓库外目录、两次调用仅 target 不同；真实 Gitleaks 必须精确返回 `1`，因此错误 canary 不会假绿。
- 但 Gitleaks 8.30.1 的 `aws-access-token` 默认规则还包含字符集、16 字符长度、entropy 下限和 `EXAMPLE` allowlist；仅写“AWS access key”仍允许实现者选择低熵或被 allowlist 排除的字符串，造成 CI 稳定失败后再试值。
- 建议 design 固定两段片段或至少固定最终模式（不在任一被跟踪单段中出现完整 token），并明确两个 `GITLEAKS_CONFIG*` 环境变量在 canary 和工作树两次调用上都被清除。该项不改变 round 3 M1 已闭合的判断。

## ① 规格符合性复核

### 八节、需求映射与接口

| 检查项 | 结论 | 依据 |
|---|---|---|
| 八节顺序 | ✅ | 概述、需求映射、架构、组件与接口、数据模型、数据流、错误处理、测试策略依次位于 `design.md:3-175`，随后是文件清单。 |
| 关键决策 | ✅ | 三条均包含选择、原因和放弃方案：自动发现、immutable blob baseline、固定 config + 真实 canary（`design.md:7-11`）。 |
| R1–R9 覆盖 | ✅ | 映射表 `design.md:15-21` 覆盖 R1–R9，无遗漏；R6 分配给 gate 与两个 artifact，R7 分配给 workflow，R9 分配给 contract 回归。 |
| `消费` 逐字一致 | ✅ | requirements frontmatter 第 4 行的完整 `tests/test-device-safety.sh ...` 签名在 `design.md:56` 原样出现一次。 |
| `产出` 逐字一致 | ✅ | requirements frontmatter 第 5 行的完整 `scripts/check.sh --offline\|--ci ...` 签名在 `design.md:49` 原样出现一次。 |
| 文件清单 | ✅ | 6 个非生成文件与 requirements 逐文件预算完全一致，没有修改后续 session/lease/verifier/runtime/registry/adapter 文件。 |

### R1–R9 逐条核对

| 需求 | 结论 | 设计落点 |
|---|---|---|
| R1 | ✅ | 唯一 mode、preflight → syntax → C-order root tests、精确 PASS 与失败短路均在组件、offline 时序和错误表中闭合。 |
| R2 | ✅ | 10 个 required command 的 fail-fast/rc `2` 和 syntax/test 零调用进入时序、错误表及 contract 矩阵。 |
| R3 | ✅ | 工作树自动发现、不硬编码 provider、双流直接继承和首错短路均明确。 |
| R4 | ✅ | Offline 层不查找三种可选工具；poison PATH、`GIT_ALLOW_PROTOCOL=file` 与真实入口组成端到端边界。 |
| R5 | ✅ | 三个精确版本及缺失/错版本在 core 前失败明确；workflow 可见性缺口见 I2。 |
| R6 | ⚠️ | baseline、静态 argv、固定 config、外部 canary、两次 Gitleaks 和退出码映射主体完整；config 错误的 static 调用语义与时序冲突，见 I1。 |
| R7 | ⚠️ | 三 trigger、runner、官方资产、摘要校验和单次 gate 均有设计；安装结果跨 step 暴露方式未锁定，见 I2。 |
| R8 | ✅ | 五列表头、每个根测试唯一 active 行和禁止数字覆盖率宣称均进入组件/数据模型/contract。 |
| R9 | ✅ | CLI、两层 preflight、发现、排序、双流、隔离、baseline/config、静态、Gitleaks、workflow、coverage 均进入表驱动 contract；路径边界 oracle 可按 M1 加强。 |

### Mermaid 与 PLAN/DECISIONS

- 架构图使用 `graph TB`；两张时序图使用 `sequenceDiagram`，唯一 `loop` 有匹配 `end`，三段 fenced block 均闭合，节点/箭头/标签是 Mermaid 支持的标准形式。未发现渲染级语法错误。
- PLAN 的 02 边界是 root gate、CI workflow、coverage 与 gate test；baseline/config 是 gate 的配套数据文件。设计的 6 文件没有漫游后续 spec。
- DECISIONS 第 18–21 行的 offline 依赖、固定版本、baseline、config/canary、coverage 与 shallow-CI 口径均未被反转。

## ② 质量复核

### 组件、数据模型、时序和错误映射

- Gate 是唯一行为入口，workflow 不复制质量逻辑；core 与 CI 扩展层通过 `quality_run_core` / `quality_run_ci` 分离，职责清楚。
- Baseline 用 canonical `path<TAB>blob` 外部 oracle，而不是 gate/test 两处自行协商；摘要先验、exact pair 豁免和不提供更新命令共同阻断 baseline 扩增绕过。
- 唯一内部冲突是 I1。其余主要错误映射一致：CLI/依赖/版本/baseline/config/canary 协议错为 `2`，syntax/test/static/工作树 secret finding 为 `1`，失败均无总 PASS。

### Canary 与 nested self-test

- requirements round 3 的 M1 已完整进入 `design.md:98-99,140-148`：canary 在仓库外；两次调用固定 flags/config 相同且仅 target 分别为 canary 目录和 repo root；第一次必须精确 `1`；显式清理并 disarm trap 后才进行最终扫描，异常路径仍由 trap 保底。
- Nested 流程可闭合：正常根 gate 在 marker 未设置时执行完整 contract；外层 contract 仅对其内部真实 gate 调用设置 `QUALITY_GATE_NESTED=1`；内部 gate 再发现 contract 时只得到 child marker，返回外层后继续完成全套断言。`design.md:79,170` 已表达这一层次，没有要求用户在正常入口设置 marker，也不会无限递归。

### NUL discovery、baseline/config 与 shallow CI

- 工作树发现固定从绝对根进行，排除 `.git/.spec`，仅普通文件、不跟随软链，NUL 分隔并 `LC_ALL=C sort -z`；这能正确承载空格/LF 路径，测试加强项见 M1。
- 独立只读重建锚点得到 30 行，SHA-256 为 `62211b0b05c8ada6e48e408696244a655e1b0cb728c3a5406b601fc0af074a5f`；两行 config 摘要为 `27630a96d6c55755cc37620f3933d5cab94b1eb78a726a32e11212972525d76e`，均与 requirements 一致。
- Gate 运行时只校验固定 baseline 并对当前工作树执行 `git hash-object`，不读取锚点 commit；因此默认 shallow checkout 不需要 `fetch-depth: 0`，设计边界正确。

### 真实工具、文件预算与可审查性

- 三个版本/tag/asset/digest 均由官方 release 元数据确认存在；问题不是资产真实性，而是 I2 的 artifact-to-PATH 接口没有在 design 锁死。
- 预算算术正确：`105 + 30 + 2 + 42 + 8 + 200 = 387`，共 6 个非生成文件，低于 PLAN 的 8 文件/400 行门，保留 13 行总余量。
- 在设计层面属于“紧但可实现”：gate 已拆出 discovery/core/CI 边界，contract 明确 fixture/helper、表驱动 case 与复合断言三层；矩阵型的 10 依赖、6 工具 case 和 mutation case 可用一行一数据行复用 helper，而不必把多条独立判据塞进单行。`design.md:175` 又明确禁止以不可定位的一行压缩换预算，超 400 必须回 PLAN 拆片。因此本轮不把紧预算升级为 finding；tasks 仍需维持每文件上限，不能把 13 行总余量解释成任一文件可越过自己的上限。

## 审查范围与证据

已读取目标 `design.md`、同目录 `requirements.md`、项目 `PLAN.md`、`DECISIONS.md`、`config.yml`、ledger 以及 requirements 三轮 review；只读核对了 canonical baseline/config 摘要、现有测试体量和三份官方 release 元数据。遵照任务约束，没有重跑 requirements 的三项机械检查，没有读取后续 spec 内容，没有修改 requirements、design 或源码，也没有运行尚不存在的实现验证。

## 最终判定

**NEEDS_CHANGES**

先修 I1 的错误映射矛盾，并在 workflow 组件中锁定 I2 的 artifact-to-executable/PATH 边界；M1/M2 可在同轮补强而无需扩大文件清单或预算。
