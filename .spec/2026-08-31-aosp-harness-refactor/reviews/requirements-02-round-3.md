# 02-offline-quality-gate requirements review — round 3

## 结论

- 最终结论：`PASS`。
- round 2 的 1 个阻断、4 个重要、1 个次要均已闭合；本轮未发现新的阻断或重要 finding。
- 本轮 findings：阻断 0、重要 0、次要 1。
- 机械检查：遵照任务约束，未重跑 `check-req`、`check-criteria`、`check-analyze`。本轮只读复核 requirements、PLAN、DECISIONS、research/raw、前两轮 review 与固定外部工具契约；仅独立重算了两个文档承重摘要和 canonical baseline。

## round 2 findings 闭环

| round 2 项 | 结论 | round 3 证据 |
|---|---|---|
| B1 Gitleaks config 可为空操作 | ✅ | R6 固定 `.gitleaks.toml` 为 `[extend]` / `useDefault = true` 两行、完整 SHA-256、两个配置环境变量清除、真实 AWS canary 必须精确返回 `1`，然后才扫描工作树；第 54 行还拒绝空规则、全局 allowlist 和 canary 返回 `0`。独立重算 config SHA-256 为文档值。 |
| I1 preflight 早于 syntax；CLI 三类 | ✅ | R9 和第 52–53 行逐项列出无参数、未知参数、额外参数，以及十个 offline 缺失 case、三工具各自缺失/错版本 case；全部绑定 `syntax/root-test marker = 0`、退出 `2`。 |
| I2 canonical baseline 未锁定 | ✅ | 术语锁定锚点的全部 30 个入口、`path<TAB>git-blob\n`、C locale、完整摘要和“运行时不读历史”；第 54 行覆盖追加、摘要、重复、乱序、畸形、非锚点等负向。独立从锚点 tree 重建得到 30 行及同一摘要。 |
| I3 来源与 DECISIONS 不完整 | ✅ | 混合来源条款已保守改标 `[默认]`，只有纯 PLAN 边界的 R4 保留 `[计划]`；DECISIONS 第 18–21 行记录依赖、版本/资产、CLI/顺序、静态 flags、Gitleaks 规则自检、COVERAGE schema、canonical baseline 与 shallow checkout 口径。 |
| I4 400 行无逐文件预算 | ✅ | requirements 第 73–85 行锁定 6 个非生成文件，逐项预算 `105+30+2+42+8+200=387`；同时明示若不能在 `tests/test-quality-gate.sh` 的 200 行内给出可审查的表驱动 fixture，实施前必须回 PLAN 拆片。 |
| M1 资产名未完整落盘 | ✅ | 第 91 行给出三个完整 asset 文件名、release URL 前缀和逐一对应的完整 SHA-256；三个 URL 当前均解析到同名官方资产。 |

## R1–R9 逐条复核

| 需求 | 结论 | 来源与行为 | 验收覆盖 |
|---|---|---|---|
| R1 | ✅ | 唯一 `--offline`、syntax→root tests、C locale、成功末行和 CLI 错误码均确定；新增细节诚实标为 `[默认]`。 | 第 50–52 行覆盖受管发现、syntax 失败、排序、双流转发、短路及三类 CLI 错误。 |
| R2 | ✅ | 十个 offline 必需命令与缺失语义明确，和现有 Python 3/ripgrep consumer 一致。 | 十个缺失 case 均要求 syntax/root-test 两类 marker 为 0，确实证明 preflight 先于二者。 |
| R3 | ✅ | working-tree 自动发现、不硬编码 provider、失败返回 `1`、原样转发和 fail-fast 均唯一。 | 非创建顺序 fixture、唯一 stdout/stderr marker 和后续 marker 缺席可失败。 |
| R4 | ✅ | offline 不探测可选工具、不访问网络/设备/build/客户端，直接来自 PLAN 与全局约束。 | poison PATH、`GIT_ALLOW_PROTOCOL=file` 和真实 offline 入口共同给出零调用证据。 |
| R5 | ✅ | 三工具版本、缺失/错版本诊断、返回 `2` 和 preflight 顺序确定。 | 每个工具各有缺失与错版本 case，均绑定 syntax/root-test marker 为 0。 |
| R6 | ✅ | 执行次序为完整 preflight→offline syntax/root tests→增量 ShellCheck/shfmt→config/canary→working-tree Gitleaks；协议/config/canary 错为 `2`，检查执行非零为 `1`。固定 config 与真实 canary 消除了上一轮秘密检查空操作。 | baseline 正反例、两个静态工具、config 变异、canary `0`、两次 Gitleaks argv/env/扫描根和工作树失败传播均覆盖。canary 可在仓库外临时目录运行，清理后不会污染最终工作树扫描。 |
| R7 | ✅ | 三 trigger、`ubuntu-24.04` x86_64、三个完整官方资产/摘要和单次 gate 调用确定。 | 第 55 行逐项比对；baseline 运行时不读锚点，因此默认 shallow checkout 不缺历史对象。 |
| R8 | ✅ | 五列 schema、根测试一一覆盖、字段非空、唯一 `active` 和禁止数字覆盖率宣称均明确。 | 第 56 行覆盖当前两项和未来自动发现全集。 |
| R9 | ✅ | contract 集合已展开到 CLI、两层 preflight、发现/顺序/双流/短路、offline 隔离、baseline、静态工具、Gitleaks、workflow、coverage，且禁止下载与外部服务。 | 第 50–56 行提供对应可失败事实；200 行预算要求“可审查的表驱动 fixture”，禁止靠不可审的一行压缩规避预算。 |

## 验收标准与不变量

### 验收标准

- ✅ 主验证命令、退出码和精确末行与 PLAN 总验收一致。
- ✅ 6 项清单分别承接 R1–R9；没有只运行不断言的核心行为。
- ✅ Gitleaks 的真实有效性不由 fake 自证：fake 只锁 argv/env/传播，CI 的真实 canary 每次证明固定规则确实命中。
- ✅ canonical baseline 的 30 行和摘要是 requirements 给出的外部 oracle，不是 gate/test 两处自行协商的循环输入。
- ✅ workflow 不需要 `fetch-depth: 0`：gate 只校验固定 baseline 文件并对当前 working-tree 内容计算 blob，明确不读取锚点对象。

### 不变量

| 不变量 | 结论 | 说明 |
|---|---|---|
| 网络/ADB/CVD/build/客户端调用数为 0 | ✅ | poison 日志、Git 协议限制和真实 offline 路径组合验证；范围与 PLAN 的离线边界一致。 |
| 三套 legacy + device-safety 失败数为 0 | ✅ | root 自动发现消费 `tests/test-device-safety.sh`，后者聚合旧回归；依赖预检已覆盖 Python 3/ripgrep。 |
| 三个 `CURRENT_FEATURE` 内容 hash 变化数为 0 | ✅ | 明确保存 gate 前后 `git hash-object` 输出并逐字比较，不依赖初始工作树 clean。 |

## 文档质量

- ✅ frontmatter、用户原话、目标、术语、R1–R9、主验证、验收清单、3 项带阈值不变量、超出范围、逐文件预算和 autopilot 裁定齐全。
- ✅ requirements 的新增默认均以 `[默认]` 标示并在 DECISIONS 形成承重口径；没有把未确认默认伪装成 `[计划]`。
- ✅ 无未绑定模板占位符；`<repo>`、`<TAB>` 是已定义的运行时/格式元记号。
- ✅ config 两行字节串的 SHA-256 为 `27630a96d6c55755cc37620f3933d5cab94b1eb78a726a32e11212972525d76e`。
- ✅ 从锚点按术语算法独立重建 canonical baseline 为 30 行，SHA-256 为 `62211b0b05c8ada6e48e408696244a655e1b0cb728c3a5406b601fc0af074a5f`。
- ✅ 6 文件预算算术为 387，低于 PLAN 的 8 文件/400 行硬门；测试预算虽然紧，但表驱动复用和超限前回 PLAN 的停止条件已经写入，未把风险伪装成既成事实。
- ✅ 三个完整资产名与 URL/摘要一一对应；未发现新的伪精确事实。

## Findings

### 阻断（0）

无。

### 重要（0）

无。

### 次要（1）

#### M1. R6 的“同一 config/argv”宜在 design 中消除字面歧义

- R6 同时要求真实 canary 与工作树扫描使用“同一 config/argv”，而第 53 行又要求分别断言两次调用的扫描根。若把 argv 理解为包含末尾 target 的完整向量，两次调用不可能既完全相同又使用不同扫描根。
- 这不造成假绿：可行且不污染的实现是把 canary 写入仓库外 `mktemp` 目录，两次调用使用完全相同的固定 flags/config，仅最后的扫描根分别为 canary 目录和仓库根，并用 trap 清理；最终工作树扫描不包含 canary。也可在仓库内短暂创建后先清理再扫描，但前者更直接。
- 建议 design 把“同一 argv”解释为“除 target 外固定选项完全相同”，并写出 canary 的外部临时目录与清理时点。无需回改 requirements。

## 假绿专项判断

- 固定 config + 固定摘要 + 清除 config 环境变量 + 真实可检出 canary，已经阻止空规则或全局 allowlist 冒充秘密扫描。
- Gitleaks 自带的精确 fingerprint `.gitleaksignore` 和行内 `gitleaks:allow` 仍属于默认规则集的显式局部抑制能力；PLAN 只承诺“有限秘密扫描”，本 requirements 也只禁止空规则/全局放行，因此本轮不把它升级为范围外 finding。若项目政策要“任何局部抑制也必须另行批准”，应由后续 PLAN/DECISIONS 新增口径，不能在 review 中反向扩 scope。
- baseline 摘要、config 摘要、CLI/preflight markers、真实 canary 与最终工作树扫描分别由不同 oracle 约束，未发现 gate/test 可以两处同时改成同一错误值仍满足当前 requirements 的路径。

## 最终判定

`PASS`

round 2 的 1 阻断、4 重要、1 次要已全部闭合；本轮仅留下一个 design 可消解、不会造成假绿的措辞级次要项。
