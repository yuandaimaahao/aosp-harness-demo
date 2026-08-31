# 02-offline-quality-gate requirements review — round 1

## 结论

- 最终结论：`NEEDS_CHANGES`。
- 规格符合性：R2 的自动发现主行为、R3 的可选工具隔离、R4 的固定版本预检、R6 的单一 CI 入口和 R7 的需求→测试矩阵方向均与 PLAN 一致；但 R1 的离线依赖声明与已消费测试直接冲突，R5 的 baseline/Gitleaks 边界尚可绕过，若干 `[计划]` 条目混入了 PLAN 未确认的默认值。
- 文档质量：章节齐全，EARS 句式和 2–4 项不变量数量合规；发现 1 个阻断、7 个重要、2 个次要问题。存在一个未绑定占位符 `<BASE>`、一个不可复现的 shfmt 诊断数，以及多项需求无对应可失败判据。
- 机械检查：按任务约束未重跑 `check-req`、`check-criteria`、`check-analyze`；本审查只做文档、源码、已有证据与官方 release 的只读核对。

## Findings

### 阻断（1）

#### B1. R1 声明 offline 只需 Bash/Git/coreutils，但它必跑的现有测试还硬依赖 Python 3 和 ripgrep

- R1 要求 `--offline` “只使用仓库与基础 Bash/Git/coreutils 能力”。frontmatter 又明确消费无参数的 `tests/test-device-safety.sh`。
- `tests/test-device-safety.sh:238-245` 的默认 `all` 路径必跑三套 legacy 回归；其中 `codex/tests/test-harness.sh:445-476`、`:531-547`、`:563-575` 等多处直接执行 `python3`，`claude-code/features/.harness/tests/test-harness.sh:73-76` 直接执行 `rg`。
- raw evidence E00 只记录当前环境有 Python 3；quality findings 的“平台兼容与测试可诊断性”也明确说现有测试依赖 Bash、Git、Python、`rg`。它没有证明 Python/`rg` 属于 coreutils，E01 也没有把两者列成由 gate 安装或预检的工具。
- 因此，在严格满足 R1 所声明依赖集的环境中，主验收必然因现有 consumer 缺工具失败；在保留原测试和 spec 02 文件边界的前提下无法同时满足 R1 与主验证。
- 必须二选一：把 Python 3 和 ripgrep 明确列为 offline 必需基础依赖并给缺失时的稳定语义/CI 保证，或在有权修改相应旧回归的规格中先移除这两个依赖。不能靠继承开发机 `PATH` 静默满足。

### 重要（7）

#### I1. “受管 Shell 入口”没有集合定义，且 R1 的 `bash -n` 没有任何负向验收

- raw evidence E02 使用的是 `find claude-code codex common -type f ( -name '*.sh' -o -path '*/bin/*' )`，当时得到 29 个文件；requirements 的 autopilot 裁定称“当前 30 个”，显然又纳入了 `tests/test-device-safety.sh`。文档没有说明将来是否还包含 `scripts/check.sh`、`tests/test-quality-gate.sh`、可执行 shebang 文件、未跟踪文件或 symlink。
- 同一个未定义集合同时承载 R1 的 Bash 语法检查、R5 的 ShellCheck/shfmt 和 baseline，两个实现可以选择不同子集而都声称满足“全部”。
- 验收清单没有放入一个可发现但语法错误的 Shell 文件，因此完全省略 `bash -n` 的 gate 仍可能通过所有清单项。
- 应给出唯一、可机械枚举的集合算法（根、Git tracked/working-tree 口径、文件名/shebang/可执行位、symlink 处理、排序 locale），并用 fixture 证明 gate 自身、新根级测试和一个语法错误入口都会被发现；语法错误必须返回 `1` 且无总成功行。

#### I2. `path + blob` 只防“旧记录命中变化内容”，没有防“把新 blob 加进 baseline”这一直接绕过

- R5 和清单能证明：baseline 不变时，同路径内容变化或新增路径不会命中旧 pair。
- 但“历史 baseline”的授权来源、初始快照、允许的增删规则均未定义。实现者或后续改动可以把新/变化文件的当前 blob 追加到 baseline，使它再次跳过 ShellCheck/shfmt；现有 fixture 仍会通过，因为它只测试固定 baseline。
- 这与超出范围中的“精确 blob 豁免只允许旧内容继续存在，后续任何修改都必须通过静态检查”直接冲突。精确 pair 本身不足以提供这一性质。
- 需要把 baseline 锚定到明确的批准快照/固定条目集，并给 baseline 变更规则；contract test 至少要尝试给新增文件及变化文件追加当前 pair，并证明 gate 拒绝该扩增或仍执行两个工具。否则可以形成绿色，但不能宣称“无绕过”。

#### I3. Gitleaks 的扫描/config/failure semantics 未闭合，并与 frontmatter 的退出码分类有歧义

- R5 只写 “redacted working-tree 扫描”，没有锁定等价于 `gitleaks dir --redact ...` 的命令、扫描根、配置来源或需要清除/覆盖的环境配置。Gitleaks 官方文档说明配置优先级包含显式 `--config`、`GITLEAKS_CONFIG`、`GITLEAKS_CONFIG_TOML` 和目标目录 `.gitleaks.toml`；当前要求允许环境或后来加入的仓库配置改变/清空规则集。
- 清单只要求 fake Gitleaks“被调用”和非零传播，未要求 fake 校验确切 argv/config，也没有证明扫描的是 working tree 而非 Git history 或某个子目录。
- frontmatter 规定“协议/工具错误返回 2，检查失败返回 1”，但第 46 行又规定 ShellCheck/shfmt/Gitleaks “任一工具返回非零”一律 gate `1`。真实工具的 usage/config/internal error 同样可能非零；当前文档无法判断它属于工具错误 `2` 还是检查失败 `1`。
- 应固定扫描命令和可信 config 口径，fake 必须断言 argv；并明确退出码映射，例如“只有缺失/版本错/无效 gate 参数为 2，工具执行后的任意非零均归一为 1”，或列出可区分的 finding 与 infrastructure code。二者择一，frontmatter、R4/R5 和清单必须一致。

#### I4. CLI 协议、CI 触发器和 COVERAGE 内容都有需求，但没有对应可失败判据

- frontmatter 的 `scripts/check.sh --offline|--ci` 和“协议错误返回 2”没有测试无参数、未知 mode、同时给两个 mode 或额外参数；实现可接受任意参数并默认 offline。
- R6 要求 `push`、`pull_request`、手工三种触发，但第 47 行只比对 runner、tag、版本和一次 gate 调用，完全没有断言三种 trigger。R6 也没有给出“固定 Linux runner”的确切 label/架构，无法决定 `ubuntu-latest` 是否应被拒绝以及该下载哪个 release asset。
- R7 要求每行含所保护规格/行为、离线边界与状态；第 48 行只检查两个路径和“每个路径一次”，空的行为/边界/状态列也能通过。
- 应补 CLI 错误矩阵、workflow `on` 三触发与固定 runner/arch 判据，并对 COVERAGE 的列头及每个根测试的非空字段做结构检查。

#### I5. 多个 `[计划]` R 混入默认决策，来源标记与确认依据不诚实，且新口径未写入 DECISIONS

- PLAN 02 确认的是 offline/CI 分流、固定版本策略、字典序自动发现、CI 安装后跑 `--ci`、矩阵和非数字覆盖率；它没有指定三个具体版本号、push/PR/manual 触发组合、runner、release tag 下载方式或 baseline 方案。
- R4 把具体版本嵌进 `[计划]`，R6 把触发器/runner/release tag 嵌进 `[计划]`，R8 又把属于 R5 `[默认]` 的 baseline 验证嵌进 `[计划]`。autopilot 段虽把版本和 baseline 称作“已定告知”，却没有修正每条 R 的来源。
- `DECISIONS.md` 最后一条仅记录“02 选择 requirements-first + autopilot”，没有记录版本 pin、baseline 或它们的错误代价；requirements 却已经写 `已由用户确认: true`。这不符合 requirements 细则“本 spec 新确认口径写入 DECISIONS”的完成条件。
- 应拆分混合来源条款或改成准确的 `[默认]`/`[推断]`，保留 autopilot 裁定依据，并在进入下一阶段前把稳定新口径写入 DECISIONS。

#### I6. 8 文件/400 行不变量含未绑定 `<BASE>`，所列命令也不会断言阈值

- `<BASE>` 是文档中未替换的占位符；任何执行者都不知道相对哪个提交统计。
- `git diff --name-only <BASE>..HEAD` 和 `git diff --numstat <BASE>..HEAD` 通常只打印结果并退出 `0`，即使已经 9 个文件或 401 行；`..HEAD` 还漏掉未提交工作区改动。
- PLAN 第 51–58 行已经把该预算定义为 review package 的机械门和实施前拆片条件。requirements 要么继续由 PLAN/review package 承担并移除这个伪验收项，要么绑定精确 base/ref、包含工作区并给超限非零的断言命令。
- 可行性判断：以 gate、约 30 行 baseline、workflow、`tests/COVERAGE.md`、gate contract test 计，5–6 个文件内实现是可能的；但全面 fixture 与安装逻辑会使 400 行非常紧。当前命令不能证明实际实现仍在预算内。

#### I7. “shfmt 产生 1835 行 diff”不可复现，R5 也没有固定 shfmt 格式参数

- 对当前同一组 30 个入口做只读复核：数量为 30，ShellCheck `0.11.0` 默认输出确为 836 行；但 shfmt `3.14.0 -d` 输出 8120 行，`-i 2 -d` 输出 2362 行，均不是 1835。raw quality evidence 只证明调研时本机没有 shfmt，并不含 1835 的原始命令/输出；ledger 只是重复该数字，不能替代证据。
- R5 只说“shfmt diff 检查”，默认 tab 缩进和 `-i 2` 等项目风格会给出不同结果，新/变化脚本究竟要满足哪套格式不可执行判定。
- 应附上可复现的原始命令/输出并固定 shfmt flags；若 1835 只是过时或错误的观察，应删除精确数字。baseline 的必要性可以由“当前非零历史债务 + 预算”支持，无需伪精度。

### 次要（2）

#### M1. “字典序”和“原样转发失败输出”仍有可移植性歧义

- R1/R2 没有指定 `LC_ALL=C` 或其他稳定 collate；大小写、非 ASCII 名在不同 locale 下可能顺序不同。当前三个 ASCII fixture 可能碰巧无法暴露差异。
- 第 44 行没有放入唯一失败 marker 并同时核对 stdout/stderr，因此 gate 吞掉、重排或改写失败输出仍可能通过。
- 应锁定排序 locale，并让失败测试分别写 stdout/stderr marker，验收二者各精确出现一次且后续 marker 不出现。

#### M2. “前后各跑 git diff”不是 CURRENT_FEATURE 内容不变的直接比较

- 如果进入 gate 前这三个文件已经有工作区改动，两次 `git diff --exit-code` 都只会失败，不能说明 gate 是否进一步改变了内容；清单也未要求比较前后摘要。
- 使用 gate 前后的 blob/hash/字节快照直接比较更符合“内容变化数为 0”的不变量；是否要求入口工作区初始 clean 应另行明示。

## R1–R8 规格符合性

| 需求 | 结论 | 来源/边界 | 验收覆盖 |
|---|---|---|---|
| R1 | ❌ | 根 gate、Bash syntax、自动运行 root tests 的方向来自 PLAN/quality evidence；“只需 Bash/Git/coreutils”与已消费测试冲突，受管集合未定义 | 成功末行有；`bash -n` 发现/失败无验收，见 B1、I1 |
| R2 | ⚠️ | 自动发现、不硬编码 provider、失败短路来自 PLAN 02 和依赖契约 | 乱序/短路/无成功行有；locale 和失败输出原样未闭合，见 M1 |
| R3 | ⚠️ | offline 不探测可选工具、无网络/设备/客户端来自 PLAN 02 与全局约束 | 可选工具及若干高风险命令有 poison；允许的 `git` 仍可发起网络，`ssh` 等未覆盖，零网络只得到有限证据 |
| R4 | ⚠️ | 固定版本/缺工具立即失败来自 PLAN；三个具体版本属于默认裁定 | 缺失/错版本、测试前退出、stderr 和无成功行基本完整；工具错误与 finding 错误码仍冲突，见 I3、I5 |
| R5 | ❌ | 增量 baseline 是诚实标注的 `[默认]`，且能解决当前历史债务 | 固定 baseline 的 path+blob 正反例有；baseline 扩增、受管集合、shfmt flags、Gitleaks config/argv 和错误分类未闭合，见 I1–I3、I7 |
| R6 | ⚠️ | CI 安装 pin 并只跑 `--ci` 来自 PLAN；触发器、runner、release 下载细节是默认值 | tag/版本/单次入口有；三 trigger、runner/arch 和安装资产完整性无判据，见 I4、I5 |
| R7 | ⚠️ | 矩阵和禁止伪装数字覆盖率直接来自 PLAN/report | 路径唯一性有；规格/行为、离线边界、状态的非空/有效性无结构判据，见 I4 |
| R8 | ⚠️ | mktemp fixture/mock 和无外部环境来自全局约束；大部分 contract 用例由 R1–R7 推导 | 主路径覆盖较广；缺 bash syntax、baseline 扩增、确切 Gitleaks argv/config、CLI 错误、CI triggers/COVERAGE 字段等回归 |

## 验收清单与不变量复核

### 验收清单

| 项 | 结论 | 说明 |
|---|---|---|
| poison offline | ⚠️ | 可证明不调用三种可选工具和列出的高风险命令；与 Python/`rg` 依赖冲突，且不能穷尽 `git` 网络等路径 |
| 字典序/短路 | ⚠️ | 核心行为可判；缺稳定 locale 和失败 stdout/stderr 原样断言 |
| CI 版本预检 | ✅ | 三工具的缺失、错版本、正确版本、测试前拒绝和 expected-version 信息均可构造 |
| baseline/静态/Gitleaks | ❌ | 固定 baseline 的 stale pair 可判；不能阻止 baseline 扩增，且 Gitleaks argv/config 与错误码分类不明 |
| workflow 比对 | ⚠️ | 可比对 tag、gate version 与单次入口；没有 trigger 判据，runner 也无预期值/架构 |
| COVERAGE | ⚠️ | 能判两个当前路径和唯一性；不能判 R7 要求的其余列内容 |

### 不变量

| 不变量 | 结论 | 说明 |
|---|---|---|
| 零网络/设备/build/客户端调用 | ⚠️ | fake/poison 提供有限证据，但“零网络”仍有未拦截通道；新回归不访问外部服务的方向正确 |
| 三套旧回归 + device safety 零失败 | ✅ | `test-device-safety.sh` 默认 `all` 明确聚合三套 legacy，根 gate 自动发现后可闭合；但需补足 B1 的依赖声明 |
| 三个 CURRENT_FEATURE 零变化 | ⚠️ | 路径正确；验证方式不是前后内容比较，见 M2 |
| 8 文件/400 行 | ❌ | 来源是 PLAN 硬门，但 `<BASE>` 未绑定且命令不做阈值断言，见 I6 |

## 文档质量核对

### 章节与结构

- ✅ frontmatter、用户原话、目标、R1–R8、主验证、人工清单、4 项不变量、超出范围和 autopilot 裁定均存在。
- ✅ 验收方式为经确认的混合判定，没有误用纯人工。
- ✅ 未提前修改 session/lease/verifier/runtime/registry/adapter，文件边界仍指向 spec 02 的 root gate、CI、coverage、gate test；baseline 可作为 gate 的配套数据，但必须补 I2 的授权边界。
- ❌ `<BASE>` 是明确占位符；shfmt 1835 行是缺原始证据且当前不可复现的伪精确事实。

### 随机来源/事实核对（至少 3 条）

1. ✅ PLAN 总目标及整体验收确实要求单一 `./scripts/check.sh --offline`、退出 `0`、精确统一 PASS 末行；R1 的主产出没有漂移。
2. ✅ PLAN 02 详情确实要求 offline 不检测/跳过可选工具、CI 固定版本且少工具立即失败、字典序发现 `tests/test-*.sh`、产出 CI 与 `tests/COVERAGE.md`；R2/R3/R7 的主方向有直接来源。
3. ✅ raw evidence E02–E05 证明调研时 29 个旧 Shell 入口语法和三套离线回归为绿；当前加入 `tests/test-device-safety.sh` 后按相同扩展口径为 30 个。ShellCheck 836 行可复现。
4. ❌ raw evidence E01 明确当时 shfmt 缺失，未提供 1835 行输出；当前官方 shfmt `3.14.0` 的常见调用也复现不出该数字，见 I7。
5. ✅ `tests/test-device-safety.sh` 的默认路径确实聚合 Claude/Codex/common 三套旧回归；但其中 Python/`rg` 依赖反证了 R1 的依赖声明，见 B1。
6. ✅ 官方 release 页面确认 [ShellCheck v0.11.0](https://github.com/koalaman/shellcheck/releases/tag/v0.11.0)、[shfmt v3.14.0](https://github.com/mvdan/sh/releases/tag/v3.14.0)、[Gitleaks v8.30.1](https://github.com/gitleaks/gitleaks/releases/tag/v8.30.1) 都是真实 tag；固定 Linux x86 runner 从官方资产安装在技术上可行。版本存在性本身不是 finding。

### `[推断]` / `[默认]`、占位符与伪事实

- R5 的 baseline 方案标为 `[默认]`，且 autopilot 段写了取舍与猜错代价，这部分披露是诚实的。
- R4/R6/R8 的混合来源未诚实拆分，具体版本/runner/触发器/baseline 回归不能整体标成 `[计划]`；见 I5。
- requirements 没有未处理的显式 `[推断]`；但新默认尚未进入 DECISIONS。
- 除 `<BASE>` 外未发现其他模板占位符；设计/tasks 的模板不属于本次主审 requirements，不据此判 requirements 失败。
- 30 个入口和 ShellCheck 836 行成立；shfmt 1835 行缺可复现口径，不能作为已证事实。

## 8 文件/400 行与绿色/绕过专项判断

- 绿色可行性：`有条件可行`。30 个旧入口以精确历史 blob baseline 豁免，新建 gate 和 contract test 从第一天满足 ShellCheck/shfmt，再由 CI 安装三个固定版本，技术上能得到绿色。
- 规模可行性：预期 5–6 个文件，低于 8；baseline 约 30 行，但 gate、三工具安装与全面 fixture 的总行数非常接近 400。必须由有效 review-package 统计确认，不能用当前 `<BASE>` 命令宣称已满足。
- 无绕过性：`当前不成立`。baseline 可扩增、受管集合未定义、Gitleaks config/argv 未固定，三者任一都可让新增/变化内容不受预期检查。
- CI 安装：三个官方 tag/对应 Linux 资产均存在；只要固定 runner label/arch、下载明确资产并由 gate 复核版本，版本漂移可以机械防住。是否校验 release checksum 是可增强项，不是 PLAN 明示要求，因此本轮不单独升级为 finding。
- failure semantics：缺失/版本错在测试前返回 `2` 已闭合；检查 finding 返回 `1` 已有方向；工具运行/配置错误落 `1` 还是 `2` 尚冲突，必须在设计前修正。

## 最终判定

`NEEDS_CHANGES`

先解决 B1；随后至少闭合受管集合与 bash syntax 验收、baseline 扩增防绕过、Gitleaks/config/错误码、CLI/CI/COVERAGE 判据、来源与 DECISIONS、有效规模统计及 shfmt 口径，才适合进入 design。
