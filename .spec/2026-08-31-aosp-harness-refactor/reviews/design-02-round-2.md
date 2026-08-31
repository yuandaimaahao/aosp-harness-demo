# 02-offline-quality-gate design review — round 2

## 结论

- **① 规格符合性：PASS。** 八个规定章节及文件清单齐全，R1–R9 均有实现组件和可失败测试落点；`产出`/`消费` 签名逐字一致，三幅 Mermaid 图闭合，设计未越出 PLAN/DECISIONS 的 02 文件与行为边界。
- **② 质量：PASS。** round 1 的 0 个阻断、2 个重要、2 个次要 finding 均已闭合；baseline/config 错误顺序、workflow 跨 step PATH、三资产安装映射、特殊路径/locale oracle、固定 canary 片段和清理时序现在彼此一致。nested contract、immutable baseline、shallow CI 与 387 行预算没有新增矛盾。
- **findings：阻断 0、重要 0、次要 0。最终结论：`PASS`。**

## Round 1 findings 闭环

| Round 1 项 | 结论 | Round 2 证据 |
|---|---|---|
| I1 baseline/config 错误顺序矛盾 | ✅ 闭合 | CI 时序固定为 core → baseline → static → config → canary → 工作树 Gitleaks（`design.md:145-152`）；错误表已拆为 baseline 错不运行 static/secret（第 167 行）与 config 错发生在 core/static 已完成后、只阻止两次 Gitleaks（第 169 行）。两处不再互相授权不同实现。 |
| I2 `$RUNNER_TEMP` 工具跨 step 不可见 | ✅ 闭合 | workflow 统一安装到 `$RUNNER_TEMP/aosp-harness-quality/bin/{shellcheck,shfmt,gitleaks}`，安装 step 仅在全部成功后写 `$GITHUB_PATH`，独立 quality step 因而可从 PATH 找到工具（第 67、77 行）。第 71–75 行同时锁定三份完整资产名、摘要、解包/单文件来源和最终 executable 名。 |
| M1 空格/LF/symlink/locale oracle 不够具体 | ✅ 闭合 | 发现算法继续固定普通文件、不跟随软链、NUL 边界和 `LC_ALL=C sort -z`（第 42 行）；contract 的 managed-discovery fixture 现在强制包含空格路径、实际 LF 路径和指向仓库外非法脚本的 symlink，并以 fake-sort 断言宿主 locale 被覆盖为 C（第 178 行）。这些样例会分别击穿按空白/换行切分、跟随链接和漏设 sort locale 的实现。 |
| M2 canary 字节留给实现者试错 | ✅ 闭合 | 第 106 行固定为分别跟踪的 `AKIA` 与 `ABCDEFGHIJKLMNOP` 两片段，运行时才连接成 20 字符 AWS access-key 值；第 105、107 行固定唯一 config 来源及两次调用相同 options/config、仅 target 不同。只读全仓检索未发现拼接后的完整值。 |

## ① 规格符合性复核

### 结构、接口与边界

| 检查项 | 结论 | 依据 |
|---|---|---|
| 八节顺序 | ✅ | 概述、需求映射、架构、组件与接口、数据模型、数据流、错误处理、测试策略依次位于 `design.md:3-184`，随后是文件清单。 |
| 关键决策 | ✅ | 自动发现、immutable blob baseline、固定 config + 真实 canary 三项均写明选择、原因与放弃方案（第 7–11 行）。 |
| R1–R9 覆盖 | ✅ | 映射表第 15–21 行覆盖全部九项；R6 分配到 gate/artifacts，R7 到 workflow，R8 到 coverage，R9 到 contract。 |
| `消费` 逐字一致 | ✅ | requirements frontmatter 第 4 行的完整 `tests/test-device-safety.sh` 签名在 `design.md:56` 原样出现。 |
| `产出` 逐字一致 | ✅ | requirements frontmatter 第 5 行的完整 `scripts/check.sh --offline\|--ci` 签名在 `design.md:49` 原样出现。 |
| PLAN/DECISIONS | ✅ | 六个非生成文件均属于 PLAN 的 02 边界；offline 依赖、固定工具、canonical baseline、config/canary、coverage 与 shallow-CI 口径均未反转 DECISIONS 第 18–21 行。 |

### R1–R9

| 需求 | 结论 | 设计闭环 |
|---|---|---|
| R1 | ✅ | 唯一 mode、十依赖预检、全受管 Shell syntax、C-order 根测试、精确 PASS 和 CLI `2` 均进入组件/时序/错误表。 |
| R2 | ✅ | 必需命令在 discovery/syntax/test 前 fail-fast，错误表和十缺失 contract case 对齐。 |
| R3 | ✅ | 工作树自动发现、原样双流、首错短路和不硬编码 provider 均明确。 |
| R4 | ✅ | offline 层不查三个可选工具；poison PATH、`GIT_ALLOW_PROTOCOL=file` 与真实 offline 入口组成边界 oracle。 |
| R5 | ✅ | 三工具精确版本在 core 前预检；缺失/错版时 syntax/test 零调用，workflow 安装结果通过 `$GITHUB_PATH` 可见。 |
| R6 | ✅ | core → baseline → static → config → external canary → repo scan 的顺序、固定 argv/config、环境第二配置来源拒绝、canary 精确 `1` 与退出码归一均闭合。 |
| R7 | ✅ | 三 trigger、`ubuntu-24.04`、三官方资产/摘要/安装映射及唯一一次 CI gate 调用均确定。 |
| R8 | ✅ | 五列、每个根测试唯一 active 行、字段非空和禁止数字覆盖率宣称均进入组件、数据模型和 contract。 |
| R9 | ✅ | CLI/preflight/discovery/order/streams/offline 隔离/baseline/static/Gitleaks/workflow/coverage 全部进入离线 fixture/fake/static oracle；round 1 指出的特殊路径样例已补齐。 |

### Mermaid 与逐字契约

- 架构图使用 `graph TB`；两张时序图使用 `sequenceDiagram`，`loop` 有匹配 `end`，三段 fenced block 均闭合，未见 Mermaid 语法或流程方向矛盾。
- 组件接口中的两条签名保留 requirements 的命令、参数、退出码和精确末行语义；未以设计层改写弱化上游契约。

## ② 质量复核

### 时序与错误映射

- CI preflight 在 core 前；baseline 在 static 前；config 在 static 后；canary 在 config 后；工作树 secret scan 最后执行。错误表分别记录各阶段已经发生和必须保持零调用的后续阶段，未再出现 round 1 的合并歧义。
- CLI/依赖/版本/baseline/config/canary 协议错映射为 `2`；syntax/test/static/工作树 Gitleaks 检查失败映射为 `1`；所有失败均禁止总 PASS，和 requirements 一致。

### Nested recursion 与 canary trap

- 正常根 gate 不设置 marker，因而会完整执行 contract；外层 contract 仅在它发起内层真实 gate 时设置 `QUALITY_GATE_NESTED=1`，内层再次发现 contract 时只得到 child marker，返回后外层继续全部断言（`design.md:87,178-181`）。该层次不会无限递归，也不会让正常入口跳过 R9。
- Canary 位于仓库外临时目录；两次 Gitleaks 仅 target 不同。第一次必须精确返回 `1`，之后显式删除 canary 并 disarm trap，再扫描仓库；异常路径仍由 trap 保底（第 147–156 行）。因此 canary 不会污染最终扫描，失败也不能假绿。
- 固定片段分别出现但完整 token 不落入仓库；config 不接受环境第二来源，contract 继续覆盖两次调用的 argv/env/canary/失败传播要求。

### 发现模型、baseline 与预算

- 绝对根、普通文件、排除 `.git/.spec`、不跟随软链、NUL 分隔和 C-locale 排序构成一致的数据边界；新增特殊路径 fixture 能对错误切分和 locale 泄漏给出反例。
- Baseline 仍是固定 30 行 `path<TAB>blob`、完整摘要先验和 exact-pair 豁免；运行时只 hash 当前文件而不读锚点对象，默认 shallow checkout 可行。Config 同样由精确字节与完整摘要约束。
- 行预算算术正确：`105 + 30 + 2 + 42 + 8 + 200 = 387`，共 6 个非生成文件，低于 PLAN 的 8 文件/400 行硬门并保留 13 行。设计继续要求超限前回 PLAN 拆片，未把总余量挪作单文件越界授权。

## Findings

### 阻断（0）

无。

### 重要（0）

无。

### 次要（0）

无。

## 审查范围与证据

本轮完整读取目标 `design.md`、同目录 `requirements.md`、项目 `DECISIONS.md`、PLAN 中 02/规模边界和 round 1 design review，并只读检索 canary 完整值。遵照任务约束，没有重跑 requirements 的机械检查，没有修改 design/requirements/源码，也没有执行尚不存在的实现验证。

## 最终判定

**PASS**
