# 任务 3: 安装 verifier contract 文档

> 这是你的需求。数值、签名、命令一律照抄，不要自己发挥。
> 你只做这一个任务，不要顺手做别的。不要派 subagent。

---

## 任务相关上下文

下面只包含当前任务关联的需求、设计和上游契约。需要额外信息时返回
`NEEDS_CONTEXT`，不要猜测，也不要扩大任务范围。

### Requirements（当前 R + 验收契约）

> 用户原话：“$spec review 这套 aosp harness 工程，有哪些欠缺的地方，进行重构和完善”；并明确“后续所有流程走 autopilot 流程，不要再问我了”。PLAN v6.1 将本片定义为 04a 后、05a assurance 前的独立 canonical verifier core。

## 目标

交付 `verifier-contract-v1`：新增不被后序 adapter 改写的 `common/.harness/bin/verify-sidebar.sh` canonical physical provider，统一定义 boot、system_server、crash baseline、service、package 五项断言，以及查询失败、业务缺失、解析失败和 `PASS/FAIL/SKIP` 的聚合语义；新增完整 `docs/verifier-contract.md` 与代表性 `tests/test-verifier-contract.sh`，并提供私有逐查询 `HARNESS_VERIFIER_QUERY_RUNNER` transport seam，使 09 能在不改 provider 的前提下组合 06 runtime。穷举 oracle 由后序 05a 独占，在其 dependency-present 证据通过前不得开始 06/09。

## 需求

R8. [计划] 系统必须新增`docs/verifier-contract.md`作为CLI优先级、六条精确分离argv、private runner协议/信任边界、R4完整判定表、bytes/LF/CR规则、十二个demo fixture、五明细固定顺序/前缀、summary、terminal/rc映射和探索限制的单一契约。进入tasks/implementation前，门③必须在隔离临时工作树完成fixed ShellCheck/shfmt的runnable exact3 core prototype：完整provider/doc/base-test、真实执行R7并输出固定摘要，以`git diff --numstat`证明added+removed总量不超过400；05a穷举assurance另须在其自身门③证明exact1≤400。不得用未执行skeleton、预估行数或把R7基础oracle推迟放行。05不得修改三个旧verifier入口、创建05a源码或引入06/07/09实现。

## 验收标准

主验证命令: bash ./tests/test-verifier-contract.sh
期望输出: 退出码为`0`、stderr空，stdout逐字节精确为`RESULT PASS  verifier contract\n`，且canonical provider的demo/real、default/explicit baseline、runner与preflight基础合同全部执行

验收清单:

- [ ] canonical provider物理独立于三个旧入口；CLI拒绝优先级、三个flag重复、单独help/help组合、真实allow-skip、serial正则与全部ADB `-s` argv符合R1，所有前置错误零ADB且rc2。
- [ ] provider实现R3/R4完整grammar；基础测试以default/explicit baseline及代表query failure验证主链，05a负责逐格穷举与mutation自反证且在其验收前无consumer启动。
- [ ] private runner前置校验、六query key、`--`后分离ADB argv、stdout/继承stderr/rc协议与默认direct模式闭合；09无需改provider即可接06。
- [ ] FAIL、严格SKIP、严格PASS与demo探索PASS的末行/退出码逐字符合R5，只有严格`RESULT PASS`可作交付证据。
- [ ] base contract test逐字核demo与real主链、runner传输、代表preflight，并在repo外安全temp物理删除后才打印摘要；完整case manifest由05a单文件独占。
- [ ] `docs/verifier-contract.md`列出CLI/优先级、六query argv/runner seam、R4 bytes判定表、fixture、summary、terminal/rc与交付限制；门③runnable exact3 core prototype fixed-format、真实执行且churn≤400。
- [ ] BASE..HEAD exact三文件且churn≤400；固定静态工具、manifest、diff-check、clean、隔离converge与candidate/full/depth-1的contract/offline全部通过。
- [ ] rollback移除exact3后，01/02/04/04a与三个旧入口回归通过；后序09可按provider物理缺席走自有fallback而不覆盖其hunks，后序五片无提前执行资产。

不变量（不许劣化，2-4项）:

- 真实模式在参数、serial或runner校验完成前的query调用数 ≤ 0，验证: contract test的invalid CLI/serial/runner log。
- 每次完整verifier执行的逻辑断言数 = 5且断言缺失数 ≤ 0，验证: base test逐字输出与后序05a完整summary/coverage counters。
- strict INCOMPLETE或FAIL被误判为交付成功的次数 ≤ 0，验证: contract test对terminal+rc联合断言及`bash ./scripts/check.sh --offline`。
- 三个旧verifier及session/resource-lease public文件变化数 ≤ 0，验证: `git diff "$BASE" "$HEAD" -- common/.harness/features/dev-sidebar/verify-sidebar.sh claude-code/features/dev-sidebar/verify-sidebar.sh codex/features/dev-sidebar/verify-sidebar.sh common/.harness/lib tests/test-session-*.sh tests/test-resource-leases*.sh`。

## 超出范围

- 不调用真实设备、AOSP build、CVD、网络或外部客户端；真实模式只在隔离fake adb上验argv、输出和退出码。
- 不实现超时、重试、取消、租约、registry、dispatcher或client/session adapter；private seam只传输runner stderr/rc/stdout，runtime策略属于06，绑定属于09。
- 不改三个旧verifier，不做三入口parity、薄化或legacy fallback；09消费本片physical provider后完成。
- 不修改session/resource-lease provider、01/02既有测试、README/长文或后序spec，不push，不清理其他项目或已有worktree。

### Design

# 2026-09-04-05-verifier-contract 设计

## 概述

新增一个与三个旧 verifier 路径物理分离的 canonical CLI，由极薄 Bash 启动器 `exec python3 - "$@"` 承载 Python 3.8 标准库实现；同片新增完整契约文档和代表性基础隔离测试，三文件 runnable fixed-format core 原型实测 371/400 行并输出固定 PASS。完整矩阵由不改本片文件的后序 05a assurance 独占。

关键决策：

1. 选择新增 `common/.harness/bin/verify-sidebar.sh`，而不是修改任一旧入口。这样 09 可只消费、不改 provider，05 回滚是物理缺席，09 的 fallback/adapter hunk 不会被覆盖；放弃在 05 直接对齐三入口和在 09 再次改 common 的方案。
2. 选择 Bash 稳定路径加内嵌 Python 3.8：Bash 只保证现有调用形态，Python 用标准库完成无溢出的 epoch/nsec 比较、严格 regex、分离 argv 和查询 rc；放弃纯 Bash 的大整数/多行解析与额外 `.py` 文件，前者更难审且易受算术溢出影响，后者会扩大回滚面。
3. 选择同一 bytes 解析器消费 demo 数据、直接 `adb -s` 或 private runner stdout；query adapter 只替换取数方式。runner 以`query-key --`加完整分离ADB argv调用，stdout捕获、stderr继承、rc保留，使09可绑定06而无需改provider；未设置时维持direct与stderr抑制。放弃整进程runtime包装，因为它无法恢复逐query stderr/超时语义。
4. 依据round1的真实368/400弱oracle证据，把代表性base test留在05，把全grammar/CLI/argv/case-manifest/mutant矩阵拆到05a exact1。放弃向余32行压缩完整矩阵，避免以宽松断言换预算。

## 需求映射

| 组件 | 实现的需求 |
|---|---|
| CLI parser 与 serial preflight | R1、R7、R10 |
| direct/private-runner query adapter 与五断言 evaluator | R2、R3、R4、R6、R10 |
| result aggregator | R2、R5、R10 |
| contract 文档 | R1、R4、R5、R6、R8 |
| base contract test | R1、R2、R3、R5–R10 |
| 后序05a assurance边界 | R3、R4、R7–R10 |
| controller sizing/checkout/rollback gates | R8、R9、R10 |

## 架构

```mermaid
graph TB
  Caller[caller] --> Entry[canonical verify-sidebar.sh]
  Entry --> Parse[CLI and serial preflight]
  Parse --> Query{demo, direct or runner adapter}
  Query -->|demo data| Eval[five assertion evaluator]
  Query -->|direct adb -s argv| Eval
  Query -->|key -- adb argv| Runner[trusted 09/06 runner]
  Runner -->|stdout and rc| Eval
  Eval --> Aggregate[detail plus summary plus terminal]
  Contract[docs/verifier-contract.md] -. defines .-> Parse
  Contract -. defines .-> Eval
  Matrix[tests/test-verifier-contract.sh] --> Entry
  Matrix --> FakeRunner[isolated self-hosted runner]
```

分层只有三层：入口/前置层不产生 query 副作用；query 层返回 `(rc, bytes)` 而不解释业务；evaluator/aggregator 层按 R4 表产生恰五个状态和一个终态。技术下限为 Bash 4.3、Python 3.8、GNU coreutils 与现有 Android `adb` CLI；运行时只使用 Python 标准库 `os/re/stat/subprocess/sys`。09 把本文件当 physical provider，不解析内容或覆写它，并只把已验证的私有seam绑定到可信06 adapter。

## 组件与接口

### Canonical verifier provider

- 职责：解析稳定 CLI、执行六条查询、结算五项断言并输出固定协议。
- 对外接口：`verifier-contract-v1：docs/verifier-contract.md；canonical physical provider common/.harness/bin/verify-sidebar.sh [--demo] [--since <epoch[.nsec]>] [--allow-skip]；private HARNESS_VERIFIER_QUERY_RUNNER=<absolute-euid-owned-regular-executable> 接收 <query-key> -- adb -s <serial> <argv...> 并传回 stdout/stderr/rc；五项断言、受控末行与退出码 0|1|2；tests/test-verifier-contract.sh 默认发现基础入口`
- 依赖：Python 3.8 标准库；真实模式依赖 `adb -s <validated-serial>`；不依赖 04 lease runtime。

入口实现保持单文件：shebang 后 `exec python3 - "$@"`，quoted heredoc 防 shell 展开；Python 从 `sys.argv[1:]` 读分离参数。`query(key, value_key, default, argv)` 在demo读取命名fixture；direct real用`subprocess.run(["adb", "-s", serial] + argv, stdout=PIPE, stderr=DEVNULL)`；runner real先由preflight核绝对路径、lstat普通非symlink、EUID owner与X_OK，再执行`[runner, key, "--", "adb", "-s", serial] + argv`，捕获stdout、继承stderr且保留rc。所有路径均`shell=False`。runner是组合seam而非auth边界，因为调用者本就控制PATH；09只能传入自身可信adapter。runner缺席回direct、provider缺席由09 fallback，两者不混淆。

### Base contract test

- 职责：在 repo 外 0700 fixture 中证明逐字demo/real成功主链、default/explicit baseline、六/五条runner argv、stderr/rc及代表性CLI/serial/runner preflight；完整grammar矩阵由05a独占。
- 对外接口：`bash ./tests/test-verifier-contract.sh`；成功唯一 stdout 为 `RESULT PASS  verifier contract\n`、stderr 空、退出 0。
- 依赖：canonical provider、Bash、`mktemp/stat/grep/cmp`；测试入口自身的runner分支记录argv并注入stdout/stderr/rc，避免第四个源码文件。

### 05a assurance boundary

- 职责：后序单文件穷举R3/R4/CLI/runner/bytes边界、完整case manifest和四类mutant，不修改05 exact3。
- 对外接口：`tests/test-verifier-contract-assurance.sh`；dependency-present成功唯一摘要`RESULT PASS  verifier contract assurance`。
- 依赖：本片provider/doc/base test物理齐全；缺provider时inert，partial/damaged fail closed。其active证据入ledger前06/09均不得启动。

### Contract document

- 职责：给 09 与人类调用者提供 CLI/判定表/结果码单一真相源。
- 对外接口：`docs/verifier-contract.md` 的 `Verifier contract v1`。
- 依赖：requirements R1–R6；不引用未来 dispatcher 内部路径。

### 上游消费

- 消费：`02 的根级离线门禁 bash ./scripts/check.sh --offline 及 tests/test-*.sh 默认发现约定；resource-lease-assurance-v1：provider 保持原 public API/状态格式且其 dependency-present active、exact2/400、full/depth-1/rollback 与全 PASS manifest 顺序门证据已入库（无运行时 API）`
- 用法：测试文件名进入 02 字典序发现；04a 只作为 controller 启动顺序证据，不在运行时 source 或调用。

## 文件清单

| 文件 | 创建/修改 | 职责（一句话） |
|---|---|---|
| `common/.harness/bin/verify-sidebar.sh` | 创建 | 独立canonical physical provider与稳定CLI |
| `docs/verifier-contract.md` | 创建 | 五断言、CLI与终态协议单一文档 |
| `tests/test-verifier-contract.sh` | 创建 | 默认发现的代表性隔离base contract |

验收资产（不纳入源码文件清单）：`prototypes/common/.harness/bin/verify-sidebar.sh`、`prototypes/docs/verifier-contract.md`、`prototypes/tests/test-verifier-contract.sh`，以及 `reviews/` 下门③独立审查报告。execution BASE 到 accepted HEAD 必须exact上述三源码文件，prototype/review/ledger只随spec文档提交，不计入source diff。

### 上游任务契约

#### 任务 1: 安装默认发现的 base contract test

文件: 创建 `tests/test-verifier-contract.sh`
产出: `verifier-base-test-v1`（`bash tests/test-verifier-contract.sh`成功唯一stdout为`RESULT PASS  verifier contract\n`）

#### 任务 2: 安装 canonical verifier provider

文件: 创建 `common/.harness/bin/verify-sidebar.sh`
产出: `verifier-provider-v1`

---

## 你的任务

文件: 创建 `docs/verifier-contract.md`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/task-3-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/evidence/task-3-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/task-3-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/review-manifest.tsv`
消费: `verifier-base-test-v1`, `verifier-provider-v1`
产出: `verifier-contract-v1`
需求: R8
必需: 是

- [ ] 步骤 1: 生成brief；运行`cmp -s docs/verifier-contract.md "$SPEC/prototypes/docs/verifier-contract.md"`，确认红阶段因目标缺席失败并写red证据。
- [ ] 步骤 2: 核HEAD为任务2 HEAD且clean；机械复制doc prototype到目标，运行doc `cmp -s`与`wc -l`=67。
- [ ] 步骤 3: 只提交doc，消息`docs(harness): define verifier contract`；提交后运行三个prototype-to-final `cmp -s`、exact3 name-only及BASE..HEAD numstat总和371。
- [ ] 步骤 4: 写报告并独立diff review；PASS后manifest第3行、mark 3、ledger与sync-ledger。

## 报告契约

完整报告写进控制器指定的 `task-N-report.md`（路径由控制器给出）。

返回控制器的只有：
- **Status**：`DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED`
- **Commits**：本任务产生的 commit 列表
- **一行测试摘要**：例如 `Ran 12 tests, OK`
- **顾虑**：如有
