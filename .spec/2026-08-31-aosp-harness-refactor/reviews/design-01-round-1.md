# 01-device-safety design review — round 1

## 结论

- **① 规格符合性：PASS。** `design.md` 具备固定顺序的八节和文件清单；R1–R7 全部进入需求映射；frontmatter 的唯一产出签名在组件接口中逐字一致；三幅 Mermaid 图的声明、分支和闭合关系完整；六个文件均落在 PLAN 的 `01` 安全补丁边界内，且未越界引入公共 runtime、lease、重试或 verifier 断言收敛。
- **② 质量：PASS。** 方案用就地 fail-closed 前置层先关闭最高风险，再把公共化留给 `05/06/09`，取舍符合 YAGNI；flag/serial 优先级、零 ADB、查询失败、SKIP、fake ADB 异常及旧回归失败路径均已设计；测试矩阵能对退出码、stderr、精确末行和分离 argv 形成可失败判据。发现 0 个阻断、0 个重要、1 个次要问题。
- **最终结论：PASS。** 次要项不影响进入下一阶段，但应在任务拆分或实现验收时显式锁定，避免静态 oracle 弱化。

## Findings

### 阻断（0）

无。

### 重要（0）

无。

### 次要（1）

#### M1. skill 静态检查的目标写清了，但 oracle 的抗误报方式还可再锁紧

- `design.md:131,139` 已要求按“每个真机代码块”检查取值、完整 regex、固定变量、首条 ADB 前顺序及禁裸调用，因此不是覆盖缺口。
- 但工具只写成 `awk/grep/sed` 静态检查，尚未明确采用“逐 fenced block 提取后逐块断言”或负向 mutation fixture。仓库现有 Claude `check-process-layer` 只是全文件字符串存在性检查（`claude-code/features/.harness/bin/check-process-layer:9-31`），照搬该模式会允许“安全片段存在于别处、目标代码块仍有裸 ADB”的假阳性。
- 仓库已有可复用的强判据模式：Codex 回归会复制 skill、定点替换 serial pin / pinned ADB 为不安全形式，并断言 checker 失败（`codex/tests/test-harness.sh:2572-2603`）。任务或实现应采用逐代码块作用域检查，或至少加入等价 mutation fixture；无需新增生产文件，也不改变当前设计边界。

## ① 规格符合性复核

### 八节、需求映射与接口

| 检查项 | 结论 | 依据 |
|---|---|---|
| 八节顺序 | ✅ | 概述、需求映射、架构、组件与接口、数据模型、数据流、错误处理、测试策略依次位于 `design.md:3-144`；数据模型和性能均以理由明确标为不适用。 |
| 关键决策完整 | ✅ | 三条决策均写明选择、原因和放弃方案（`design.md:7-9`）。 |
| R1–R7 覆盖 | ✅ | 映射表 `design.md:13-19` 覆盖 R1、R2、R3、R4、R5、R6、R7，无遗漏或额外 R。 |
| frontmatter 产出逐字一致 | ✅ | `requirements.md:5` 的 `tests/test-device-safety.sh —— 无参数；全部通过时退出 0 且 stdout 末行为 RESULT PASS  device safety，任一断言失败时退出非零` 在 `design.md:66` 原样出现。 |
| frontmatter 消费 | ✅ | `消费: 无`；本设计未声明或引入其他 spec provider。现有 verifier、skill 和旧回归是仓库内依赖，不是跨 spec 消费接口。 |
| 组件接口确切性 | ✅ | 两个 verifier 的现有 CLI、skill 的 `device_serial`/regex/ADB 前缀、根测试入口及旧回归入口均有明确签名或行为约束（`design.md:44-74`）。 |

### R1–R7 逐条核对

| 需求 | 结论 | 设计落点与源码相符性 |
|---|---|---|
| R1 | ✅ | Claude adapter 固定 `ADB=(adb -s "$serial")`，覆盖真实 `shell/logcat`（`design.md:46-49`）；当前源码确有裸 `adb shell` 和裸 `adb logcat` 两处，改动热点准确。 |
| R2 | ✅ | 缺失/非法 serial 在构造 argv 前退出 2、不写 ADB 日志，并要求 stderr 含 `ANDROID_SERIAL`（`design.md:49,128`）。 |
| R3 | ✅ | 两个 Claude skill 共用确切安全 regex 和 `adb -s "$device_serial"` 前缀（`design.md:57-61`）；文件清单覆盖 services.jar 部署和 sepolicy 真机验证两处。 |
| R4 | ✅ | 两个 verifier 均在 serial 前拒绝非 demo `--allow-skip`，错误文本、退出 2、零 ADB 和四组合取证都已映射（`design.md:46,53,127,139`）。 |
| R5 | ✅ | Demo 应用缺失仍保留 `SKIP  ` 明细、精确成功末行和退出 0（`design.md:130,139`）。 |
| R6 | ✅ | 根测试以私有 `PATH` 首位 fake adb 记录分离 argv；拒绝路径空日志、成功路径固定 serial，且所有设备测试禁用系统 adb（`design.md:65-68,113-120,132,144`）。 |
| R7 | ✅ | 两个 verifier 原路径不变；根测试聚合三套旧回归，文件清单只对受影响的 Claude fixture 做兼容修改（`design.md:70-74,141,150-155`）。 |

### Mermaid、文件边界与 PLAN

- 架构图使用 `graph TB`，节点/条件边闭合；两张时序图均使用 `sequenceDiagram`，`alt/else/end` 成对，围栏闭合。图表达的前置顺序与错误表一致。
- 文件清单共 6 个文件，低于 PLAN 的 8 个非生成文件上限；5 个现有路径均存在，根级测试是唯一新文件。
- 边界与 PLAN `01` 一致：Claude verifier + 两个流程 skill、Codex verifier flag、device-safety test，并只补受影响旧 fixture。没有触及 common verifier、公共 command runtime、租约、CI 或文档收敛文件。
- `config.yml` 的 design reviewer 为 `both`；本报告承担其中独立 agent review 部分。`DECISIONS.md` 中 canonical-core、显式设备标识和本 spec 采用 autopilot 的既定口径均未被设计反转。

## ② 质量复核

### 架构与 YAGNI

- 就地重复两段小型 preflight 是有意识的过渡选择：当前即可关闭错设备/真实 SKIP 风险，同时不抢跑后续公共 dispatcher。复制风险由同一根级矩阵覆盖，且 `09` 已声明替换点。
- 未加入公共库、timeout/retry、lease、stderr 诊断、common verifier 收敛或真实设备验证，范围与 `requirements.md:54-58`、PLAN 分片一致。
- 数组 argv 而非字符串拼接，避免 shell 重解析；安全 serial 首字符限制也阻断选项注入，架构选择与当前 Codex verifier 模式一致。

### 错误路径与兼容性

- 错误表覆盖 flag 组合、serial、ADB 查询、Demo SKIP、skill 文档缺陷、fake adb 协议异常及旧回归失败；每项均给出恢复、校验点、日志和用户可见结果。
- `--allow-skip` 先于 serial 的顺序在架构图、组件约束、时序图和错误表中一致，没有互相打架。
- 保留两个 verifier 和三套旧回归路径；Claude 现有导出 shell 函数 fake adb fixture 是唯一已知受 argv 前缀影响的旧 fixture，设计已纳入兼容修改。

### 测试判据真实性

- 非法 serial 包含前导标点、分隔符、空格、斜杠、实际 LF 和 `+`；合法 serial 同时覆盖普通值及全部允许标点。退出码、stderr、ADB 日志和精确末行同时断言，不是只跑不验。
- R4 对 Claude/Codex 各测 serial 缺失与 `-bad`，共四组，并要求 stderr 不含 `ANDROID_SERIAL`，可以真实证明优先级而非只证明两种错误都存在。
- fake adb 对 argv、serial 和命令白名单 fail closed；旧回归聚合和 `bash -n`/`git diff --check` 提供兼容及卫生检查。
- 唯一保留意见是 M1：实现时需保证 Markdown 静态检查是块级 oracle，不退化为全文件存在性 grep。

## 审查范围与证据

已读取 `requirements.md`、`design.md`、项目 `PLAN.md`、`config.yml`、`DECISIONS.md`，并核对两个 verifier、两个 Claude skill、Claude 旧回归、Codex/common 旧回归及现有 process checker。未修改设计或源码，未运行真实 ADB、网络、AOSP build 或实现验证。

## 最终判定

**PASS**
