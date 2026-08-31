# 02-offline-quality-gate requirements review — round 2

## 结论

- 最终结论：`NEEDS_CHANGES`。
- 上一轮闭环：1 个阻断、7 个重要、2 个次要中，6 项已闭合，4 项部分闭合；没有原项完全未处理，但 I3 的剩余部分仍允许秘密检查为空操作。
- 本轮 findings：阻断 1、重要 4、次要 1。
- 机械检查：按任务约束未重跑 `check-req`、`check-criteria`、`check-analyze`；本轮只做 requirements、PLAN、DECISIONS、research/raw evidence、round-1 finding 与仓库事实的只读复核。

## 上一轮 findings 闭环

| round 1 项 | 结论 | round 2 证据 |
|---|---|---|
| B1 offline 缺 Python 3/rg | ✅ | R2 明列 `python3`、`rg` 和其余 8 个命令；第 52 行要求十个缺失 case。 |
| I1 受管集合/bash syntax 负向 | ✅ | 第 20 行定义工作树、排除目录、普通文件、后缀/shebang、symlink 与 C locale；第 50 行有 gate、自身无扩展 Bash、新根测试和语法错误负向。 |
| I2 baseline 可扩增 | ⚠️ | 锚点、固定摘要、重复/乱序/畸形/非锚点与追加当前 pair 的拒绝均已加入；但“经批准集合”的具体成员或规范化生成规则及摘要仍未在 requirements 锁定，见 I2。 |
| I3 Gitleaks argv/config/错误码 | ⚠️ | argv、扫描根、显式 config、两个环境变量清除和“执行后任意非零归一为 1”已闭合；`.gitleaks.toml` 的有效规则集与正向泄漏样例仍无判据，见 B1。 |
| I4 CLI/CI/COVERAGE 负向 | ⚠️ | CI 三 trigger、runner、摘要及 COVERAGE 五列/非空/active 已闭合；CLI 仅以 R9 的“CLI 错误”统称，人工清单没有逐项锁定无参数、未知参数和额外参数，见 I1。 |
| I5 来源与 DECISIONS | ⚠️ | versions/dependencies/baseline 已写 DECISIONS；R1、R3、R8 仍把 PLAN 未给出的默认细节整体标为 `[计划]`，且若干新默认未入 DECISIONS，见 I3。 |
| I6 `<BASE>`/预算伪命令 | ✅ | requirements 已删除占位符和无效统计命令，并明确预算仍由 PLAN/review package 承担。实现规模是否实际可行是新的独立风险，见 I4。 |
| I7 shfmt 数字/flags | ✅ | 不可复现的 1835 行陈述已删除；固定为 `shfmt -d -i 2 -ci -bn`，fake 需断言参数。 |
| M1 locale/输出 | ✅ | 术语、R1 和 fixture 均固定 `LC_ALL=C`；失败 stdout/stderr 各有唯一 marker、精确一次并验证短路。 |
| M2 CURRENT_FEATURE 比较 | ✅ | 第 62 行改为 gate 前后保存并逐字比较三个 `git hash-object` 输出。 |

## R1–R9 逐条复核

| 需求 | 结论 | 来源与行为 | 验收覆盖 |
|---|---|---|---|
| R1 | ⚠️ | offline 语法→根测试顺序、C locale、PASS 末行与 CLI 语义清楚；但无参数/未知参数/额外参数属于新增默认，不是 PLAN 原文。 | 语法、顺序、短路均有强负向；CLI 三类错误没有在清单中逐项出现。 |
| R2 | ⚠️ | Python 3/rg 冲突已消除，十个命令集合明确。 | 十个缺失 case 已要求，但清单只断言“测试前”返回，未证明 R2 要求的“任何语法或测试执行前”。 |
| R3 | ⚠️ | 工作树自动发现、不硬编码与失败短路符合 PLAN；原样转发是合理默认但误标为纯 `[计划]`。 | 非字典序、stdout/stderr marker、失败短路均闭合。 |
| R4 | ✅ | offline 不探测三种可选工具及不触达外部环境，与 PLAN 02/全局约束一致。 | poison PATH、Git 协议限制和真实 offline 入口给出可失败证据。 |
| R5 | ⚠️ | 三工具版本、缺失/错版本返回 2 已进 DECISIONS。 | 每工具缺失/错版本均覆盖，但清单同样只说“测试前”，未证明语法也未先运行。 |
| R6 | ❌ | 静态 flags、baseline、Gitleaks argv/env 和非零映射大体明确；显式 `.gitleaks.toml` 却没有任何规则语义。 | fake 只验证 argv/非零传播；空规则或全局 allowlist 仍可让真实秘密扫描永久为绿，见 B1。baseline 的初始批准输入也未完全锁定，见 I2。 |
| R7 | ✅ | 三 trigger、`ubuntu-24.04` x86_64、官方固定资产和单次 gate 调用一致。三个 SHA-256 经官方 GitHub release API 只读复核均正确。 | 第 55 行逐项覆盖 trigger、runner、tag/asset/digest 和单次调用。 |
| R8 | ⚠️ | 矩阵、禁止数字覆盖率与 PLAN 一致；精确列 schema/`active` 是新增默认而非 PLAN 原文。 | 两个当前根测试、自动发现全集、唯一行、五列非空和状态值均可机械判定。 |
| R9 | ❌ | fixture/fake、无下载/外部服务方向正确，但聚合了大量未完全展开的 contract。 | 未锁定 CLI 三类错误逐项、预检必须早于 syntax、真实 Gitleaks canary；在 400 行硬上限内覆盖全部列表也缺少可信规模证据。 |

## Findings

### 阻断（1）

#### B1. Gitleaks 的“固定 config”没有固定任何检测规则，允许秘密检查为空操作

- R6 只要求显式使用 `<repo>/.gitleaks.toml`，R9/清单只让 fake 断言 argv、环境变量清除和非零传播。
- requirements 没有要求该配置 `extend` Gitleaks 默认规则、包含任何最小 rule，也没有在临时 fixture 放入一个已知测试秘密并证明真实 Gitleaks 返回 `1`。
- 因此，一个空规则配置、全局 allowlist 或等价的永不匹配配置，可以同时满足精确 argv、环境清除、fake 非零传播、workflow 和所有当前清单，却完全不实现 PLAN 第 76 行的“有限秘密扫描”。这是核心目标的假绿色，不是单纯设计细节。
- 必须固定可信规则口径，例如 `.gitleaks.toml` 明确继承该版本内置默认规则并禁止全局放行；验收至少要有一个不会污染仓库的临时 canary，在 CI 已安装的真实 Gitleaks 上命中并返回 gate `1`。offline contract 仍可用 fake，不需要下载工具。

### 重要（4）

#### I1. 十个缺失依赖和 CI 工具预检没有证明发生在 Bash syntax 之前；CLI 错误矩阵仍可少测

- R2/R5 都要求预检发生在“任何语法或测试执行前”。第 52、53 行只断言“测试前”，没有用 fake `bash`/syntax marker 证明 `bash -n` 调用数为 0。
- R1 明列无参数、未知参数、额外参数三类错误；R9 只有“CLI 错误”统称，清单没有逐项事实。只测未知参数也能被解释为满足 R9。
- 应把十个 offline 缺失 case、六个 CI 缺失/错版本 case 都绑定“syntax marker=0、root-test marker=0”，并在清单逐项列无参数、未知参数、额外参数均返回 2、stderr 有诊断、无成功末行。

#### I2. baseline 的锚点存在且可重建，但“获批集合”本身仍是实现阶段才决定的循环输入

- 锚点 `b143821925e279401334d09a788ba9a969df5c7c` 是有效 commit，且当前非 `.spec` 工作树与该锚点没有 diff。
- 按第 20 行定义对锚点树枚举，可得到 30 个候选入口；若“全部锚点入口”按 `path<TAB>blob\n`、C locale 排序，候选 SHA-256 为 `62211b0b05c8ada6e48e408696244a655e1b0cb728c3a5406b601fc0af074a5f`。
- 但文档没有说获批的是全部 30 个、仅 ShellCheck/shfmt 失败项，还是其他子集，也没有写初始 baseline 的规范化摘要。实现者可以先任选锚点子集，再把所选文件 hash 同时写入 gate/test；“两处一致”不能证明这就是 requirements 批准的集合。
- 应在 requirements 锁定生成规则和预期条目数/摘要，或直接附 canonical baseline。若 gate 运行时要读取锚点对象，还要让 workflow 获取该历史 commit；若只校验固定文件摘要，则明确无需 CI checkout 历史，避免 shallow checkout 行为分叉。

#### I3. 来源标记和 DECISIONS 只完成了一半

- DECISIONS 第 18–19 行已记录 offline 依赖、三个版本、runner/assets、错误码和 baseline 主方案，这是实质改进。
- 但 R1 把 CLI 错误码，R3 把 stdout/stderr 原样转发，R8 把五列英文 schema、非空与 `active` 值混在 `[计划]` 中；这些具体值在 PLAN 第 74–76 行并不存在。
- Gitleaks 的精确 argv/config/env、shfmt 全部 flags、CLI 三类错误和 COVERAGE schema 也未作为本 spec 新默认进入 DECISIONS；frontmatter 第 8 行却声称“新增默认口径已……写入 DECISIONS”。
- 应拆分混合来源 R，或按其主要新决定改成 `[默认]`，并把承重默认及猜错代价补入 DECISIONS。无需重问用户，autopilot 授权足以裁定。

#### I4. 8 文件可行，400 行在新增验收范围下已是高概率超限，尚无可信拆片依据

- 预期至少 6 个非生成文件：gate、baseline、Gitleaks config、workflow、COVERAGE、contract test，文件数低于 8。
- baseline 若覆盖全部锚点入口本身约 30 行；workflow、config、COVERAGE 和 gate 还未计入时，contract test 已需覆盖 CLI、10 个 offline 缺失、6 个 CI 缺失/错版本、受管集合、syntax、排序/双流/短路、13 类 poison、baseline 多类变异、两个静态工具、Gitleaks、workflow、coverage 和 CURRENT_FEATURE。
- 当前 `tests/test-device-safety.sh` 已有 268 行，而本 spec 的 fixture 矩阵明显更宽。即便大量复用 helper，gate + test + workflow + 30 行 baseline 在 400 行新增+删除内完成属于高风险假设。
- PLAN 第 53 行要求超限必须在实施前回 PLAN 拆片。进入 design 前至少应给出逐文件行预算和可复用 helper 方案；若不能可信压到 400，应拆 spec，而不是靠密集的一行多断言规避 review-package 指标。

### 次要（1）

#### M1. 资产摘要正确，但 canonical asset 名称与本地证据没有落盘

- 只读查询官方 release API 已确认三组值正确：ShellCheck `shellcheck-v0.11.0.linux.x86_64.tar.xz`、shfmt `shfmt_v3.14.0_linux_amd64`、Gitleaks `gitleaks_8.30.1_linux_x64.tar.gz` 分别对应 requirements 第 77 行的三个 SHA-256。
- requirements 只写“x86_64 tar.xz / amd64 / x64 tar.gz”，第 55 行却要求测试精确比对 asset；本地 research/raw 也没有保存这些新证据。
- 建议写出三个完整文件名和 release URL，或在 raw evidence 中保存官方 API 的 asset/digest 对照，避免实现者和测试各自推断文件名。

## 文档质量

- ✅ frontmatter、目标、术语、R1–R9、主验证、7 项清单、3 项不变量、超出范围和 autopilot 裁定齐全；验收方式仍为已确认的混合判定。
- ✅ 上轮未绑定 `<BASE>` 与不可复现 shfmt 数字已移除；shfmt flags、locale、stdout/stderr marker、CURRENT_FEATURE 内容 hash 已变成可执行事实。
- ✅ CI 顺序在需求层没有自相矛盾：先工具预检，再 syntax/root tests，再 ShellCheck/shfmt，最后 Gitleaks；workflow 安装工具后仅调用一次真实 `--ci`。缺口在验收没有证明“预检早于 syntax”，不是顺序文本互相冲突。
- ✅ baseline 技术上可实现：锚点有效、当前产品树与锚点一致、30 个入口可确定枚举。缺口是批准输入未锁定，而不是 Git 对象不存在。
- ✅ 3 个 release tag、asset digest 均真实；未发现新伪事实。
- ⚠️ `<repo>` 是可理解的运行时元变量，但术语未明确其为仓库绝对根；这不单列 finding。
- ❌ 混合来源标签、DECISIONS 完整性、Gitleaks 规则有效性和 400 行规模仍不足以让两个独立实现者得到同一且不可假绿的结果。

## 最终判定

`NEEDS_CHANGES`

先关闭 B1；同时锁定 baseline 初始集合/摘要、把预检顺序与 CLI 三类错误写进可失败清单，并修正来源/DECISIONS。随后在 design 前给出可信的逐文件行预算；若无法压入 400 行，按 PLAN 返回拆片。
