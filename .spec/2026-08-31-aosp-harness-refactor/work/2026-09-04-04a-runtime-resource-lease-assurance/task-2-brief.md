# 任务 2: 安装默认发现的完整 assurance

> 这是你的需求。数值、签名、命令一律照抄，不要自己发挥。
> 你只做这一个任务，不要顺手做别的。不要派 subagent。

---

## 任务相关上下文

下面只包含当前任务关联的需求、设计和上游契约。需要额外信息时返回
`NEEDS_CONTEXT`，不要猜测，也不要扩大任务范围。

### Requirements（当前 R + 验收契约）

> 用户原话：“$spec review 这套 aosp harness 工程，有哪些欠缺的地方，进行重构和完善”；并确认后续按 autopilot 执行。PLAN v5.9 要求本片在任何租约消费者前闭合 04 已暴露的 deadline 最后一轮缺口，并以默认发现 assurance 穷举 mutation、I/O、并发和 adapter 反证。

## 目标

交付 `resource-lease-assurance-v1`：在不改变 `resource-leases-v1` public API、状态格式、文档与基础测试的前提下，替换 provider 的 deadline 相邻两行，使资源扫描后首次观测 deadline 到达时立即进入最后一次无 sleep `flock` 尝试，并由既有锁后检查在读取 record 或发布前返回 3；新增默认发现、fixed-shfmt 的 `tests/test-resource-leases-assurance.sh`，以 repo root 外的 `mktemp` 隔离树复制 provider，只替换唯一 `HARNESS_RESOURCE_LEASE_TEST_SEAM`，穷举输入、状态、I/O、并发、等待、adapter 与 mutant 矩阵。dependency-present 成功唯一摘要为 `RESULT PASS  resource lease assurance`；provider 物理缺席时走同摘要的零 active case inert 路径，但 inert PASS 不得解除 05/06/08 顺序门。

## 需求

R3. [计划] 当运行 assurance 入口时，系统必须从顶层 `tests/` 自身路径解析 repo root，并把默认 provider 精确解析为该 root 下 `common/.harness/lib/resource-leases.sh` 的普通非 symlink 文件；只接受无参数、`all`或唯一 `--dependency-absent`，unknown、extra 或 flag 带值返回 1 且 stdout/stderr 均空。repo-layout 外的 provider 物理缺席 surface 必须显式清除任何 provider override，默认、`all`与 `--dependency-absent`真实执行同一零 active case inert oracle并逐字输出固定摘要、stderr空；provider 存在但为目录/其他非普通文件、symlink、语法失败、source非零、两个 public API 任一不齐或 seam 缺失/重复时，默认 active 入口必须 fail closed返回1、stdout空且stderr逐字为`FAIL provider validation\n`。
R4. [计划] 当 dependency-present active 矩阵验证 request、状态根与同 owner 行为时，系统必须逐项覆盖空文件、缺 LF、空行、CR、NUL、列数、非法 domain/mode 对、unsafe android ID、missing workspace、workspace realpath 控制字节与别名重复、request 非普通文件；覆盖相对/普通文件/symlink/非0700 root 与默认 XDG root；覆盖逆序完整重入同 token、换 session、子集、超集、部分重叠、同键异 mode、不相交 bundle 与 release 后 inventory。每项必须逐字核对 `0|2|3`、token/空双流或固定错误双流。
R5. [计划] 在不同逻辑 owner 与组合 bundle 并发期间，系统必须证明同键同 mode、同键异 mode 与正值等待均不抢占存活 holder；反向双资源 waiter 在 holder 释放前阻塞，任一可见 active record 的规范 request 始终含完整两行，释放后 waiter 成功且最终 inventory 除可选 `.lock` 外为空。两个假 adapter 对同一 `android-instance-id` 使用不同 serial/CVD name 时必须零执行竞争方命令并返回 3；改变 instance ID 的 adapter mutant 必须被 oracle 杀死。
R6. [计划] 如果发生 active 状态含 duplicate JSON key、非法/非规范 stored request、全局 key overlap、record 非普通文件，或 `version/token/nonce/owner/session/hash/request` 任一字段错误、字段缺失/额外、文件名不匹配，系统必须在任意新 acquire 前返回 2 与固定 operation-failed 双流且不得发布新 bundle；PID starttime 不匹配必须整体 stale 回收并生成新 token，之后 release 成功且 inventory 无 active/tmp/trash 或未知资产。
R7. [计划] 如果发生伪 Python worker、伪 `mktemp`/`rm`、伪 mktemp 返回既有 victim、capture 路径消失、closed stdout、root/lock owner 身份变化，或 seam 注入 `flock/open/write/fsync/replace/unpublish/unlink` I/O 错误，系统必须收敛为 R6 固定 rc2 双流且不修改 victim、不留下未发布 active/tmp；unpublish 失败时原 active 必须仍存在，unlink 失败必须只留下不可见 tombstone，下一次受锁操作必须恢复并最终清空 tombstone。
R8. [计划] 系统必须检查顶层 `mktemp -d` 成功及所得路径为 repo root 外、EUID自有0700、普通空目录；失败路径的 EXIT cleanup 必须把删除失败收敛为rc1，成功路径必须在打印摘要前删除临时树并验证路径物理缺席。入口只在该树中复制 candidate provider，只把唯一 `HARNESS_RESOURCE_LEASE_TEST_SEAM` 替换为确定性 fault/mutation/clock 实现，且每个承重 fixture 的创建、改写和清理、holder/waiter/clock readiness marker 与 adapter fixture 改写失败都必须立即以专属失败退出收口；原 tracked provider、docs与基础测试在每次测试前后 SHA-256 不变。入口必须内置 overlap 检查、真实 unpublish `os.replace(path, trash)`状态转换、bundle完整规范化三类 production mutant和一类fake-adapter key-selection fixture mutant；每个 production mutant 必须先机械证明目标 anchor 恰一次、只作预期替换且变异 provider 可静默 source，adapter fixture provider 必须与 candidate 逐字相同。四者必须非零、stdout空、stderr分别逐字为其专属首个失败标签且不得含固定PASS摘要，未修改candidate文件或外部状态。

## 验收标准

主验证命令: bash ./tests/test-resource-leases-assurance.sh
期望输出: dependency-present时退出码为 `0`、stderr空，stdout逐字节精确为 `RESULT PASS  resource lease assurance\n`，且完整矩阵与四类 mutant 自反证全部执行

验收清单:

- [ ] BASE..HEAD exact 两文件：provider 只替换 deadline 相邻两行且 numstat `2/2`，assurance `396/0`，新增+删除`2+2+396=400/400`；public API、状态格式、docs、基础测试与 seam occurrence 不变。
- [ ] 确定性 monotonic 场景逐字返回 rc3/unavailable、seam 日志恰两次 `flock` 且第二次前无 sleep；锁后检查保证到期后零 record 读取、零 stale 回收、零 publish；wait=0/无竞争路径不回归。
- [ ] CLI六形态逐字核对invalid双流空；default/all先核provider精确位于repo内默认普通文件再执行active矩阵；provider absent surface清除override后三入口逐字同摘要/空stderr；damaged provider的目录/非普通文件/symlink/语法/source/API/seam缺失或重复全部核对rc1、空stdout与固定单行FAIL；inert PASS不计dependency-present验收证据。
- [ ] request/root/self-overlap 矩阵覆盖 R4 的全部形态，逐项核对 canonical key、token、`0|2|3`与固定双流，最终 inventory 无 active/tmp/trash/未知资产。
- [ ] live holder 同/异 mode、正值超时、反向 bundle barrier 与双 adapter alias 全部反证；visible record 从不含 partial bundle，竞争 adapter 命令计数为零。
- [ ] duplicate/noncanonical/global-overlap/nonregular 与全 record 字段矩阵均 fail closed；PID reuse stale reclaim 生成新 token并可释放。
- [ ] fake helper、capture/closed-output、root/lock identity 与全部 I/O seam 逐项收敛 rc2；victim不变，unpublish 保留 active，unlink 只留 tombstone且后序恢复清零。
- [ ] 顶层临时树创建后核repo外/EUID自有0700/普通空目录，失败EXIT cleanup可把删除失败变rc1，成功摘要只在已删除且物理缺席后打印；readiness marker与所有承重fixture构造/改写/清理均显式失败收口；三类production mutant逐一核唯一anchor/预期diff/source健康，fake-adapter fixture provider逐字未变，四者均非零、stdout空、stderr逐字匹配各自专属失败标签且无固定PASS；tracked provider/docs/base-test在assurance前后hash不变。
- [ ] candidate/full/depth-1 的默认入口与 offline 全 PASS，offline 发现恰一次，depth-1 commit-count=1且 shallow marker非空；fixed tools、exact2/400、manifest、diff-check与clean全部通过。
- [ ] rollback exact 恢复 provider 两行并删除 assurance 后，04基础测试、03e生命周期与offline全绿且本入口发现0次；05的spec/ref/worktree/BASE/dispatch在依赖证据前全部缺席。

不变量（不许劣化，2-4项）:

- `resource-leases-v1` public API/状态格式/docs/基础测试变化数 ≤ `0`，验证: source surface probe、`git diff "$BASE" "$HEAD" -- docs/resource-leases.md tests/test-resource-leases.sh`与 provider exact hunk。
- deadline 到达后读取 record、回收 stale 或发布 active bundle 的次数 ≤ `0`，验证: monotonic/final-flock seam 日志、到期 rc3 固定双流与最终 state inventory。
- assurance 任一攻击修改 victim、candidate tracked provider 或外部状态的次数 ≤ `0`，验证: 前后 SHA-256/指纹与所有 fixture 的 repo-root 外 `mktemp` 路径核对。
- 既有 04 lease、03e lifecycle 与 offline 门禁失败数 ≤ `0`，验证: candidate 与 rollback checkout 分别运行 `bash ./tests/test-resource-leases.sh`、`bash ./tests/test-claude-session-lifecycle.sh`和 `bash ./scripts/check.sh --offline`。

## 超出范围

- 不改变 `harness_lease_acquire/release`签名、`0|2|3`协议、request/state JSON格式、token算法、owner定义、错误文本、docs或04基础测试；provider只允许R1的两行替换。
- 不新增运行时 API、环境 capability marker或adapter实现；假adapter只验证同一instance ID不会因serial/CVD name不同而绕过lease key。
- 不调用真实ADB、CVD、AOSP build、设备、网络或Claude/Codex客户端；不把inert PASS当成active保证。
- 不创建05/06/08的真实spec、分支、worktree、execution BASE或dispatch，不push，不清理其他项目、spec或已有worktree。

### Design

# 2026-09-04-04a-runtime-resource-lease-assurance 设计

## 概述

以一个相邻控制流修复和一个默认发现的 Bash assurance 入口交付 `resource-lease-assurance-v1`：provider 在扫描后首次发现 deadline 到达时进入最后一轮无 sleep 锁尝试；assurance 在 repo 外临时树内用唯一 seam、真实并发和语义 mutant 穷举租约安全边界。

- 选择只替换 provider deadline 分支的相邻两行，因为既有锁后 deadline 检查已经位于 tombstone 恢复、active record 读取和 publish 之前；让扫描后到期路径 `continue` 即可复用该检查。放弃新增状态、重写等待循环或新公开 API，因为它们扩大已验收 04 的行为面。
- 选择单个 396 行、顶层默认发现的 assurance 脚本，内部复制 provider 并只替换唯一 `HARNESS_RESOURCE_LEASE_TEST_SEAM`，因为故障矩阵必须确定、可离线运行且不能修改 tracked 文件。放弃把矩阵塞回 04 基础测试、直接修改生产 provider 注入故障或拆成额外 helper，避免越过 exact2/400 和独立回滚边界。
- 选择“真实运行 + 专属失败标签 + mutant 自反证”的 oracle：每个承重 fixture 显式收口，每个 production mutant 先证明唯一预期 diff 和 source 健康。放弃只看最终 PASS、接受任意 `FAIL` 或删 no-op seam 的伪变异，因为这些路径已在 requirements review 中被实证可假绿。

## 需求映射

| 组件 | 实现的需求 |
|---|---|
| provider deadline 相邻修复 | R1, R2 |
| assurance CLI、provider route 与 inert/damaged surface | R3 |
| request/root/self-overlap 矩阵 | R4 |
| live holder、barrier 与 adapter 矩阵 | R5 |
| strict record、PID reuse 与 stale 矩阵 | R6 |
| helper、capture、identity 与 I/O fault 矩阵 | R7 |
| fixture 生命周期、唯一 seam 与四类 mutant 自反证 | R8 |
| controller 静态、candidate/full/depth-1 与 manifest 门 | R9 |
| rollback 与 05/06/08 顺序门 | R10 |

## 架构

```mermaid
graph TB
  C[future 05/06/08 consumers] -->|unchanged public API| P[resource-leases.sh]
  P --> W[embedded Python worker]
  W --> L[short nonblocking flock loop]
  L --> S[strict active bundle store]
  D[deadline two-line patch] --> L
  A[test-resource-leases-assurance.sh] -->|source candidate| P
  A --> T[repo-external 0700 temp tree]
  T --> PC[provider copy]
  A -->|replace one private seam| PC
  A --> F[fault and clock matrix]
  A --> M[3 production mutants]
  A --> K[fake-adapter fixture mutant]
  G[scripts/check.sh offline] -->|default discovery once| A
```

边界保持在两个源码文件内。provider 继续拥有既有两个 public Bash 函数、状态格式、错误双流和唯一私有 no-op seam；本片只改变扫描后到期分支，不改变锁后到期检查。assurance 是测试消费者，不发布运行时函数、marker、adapter 或持久数据，也不调用真实 ADB/CVD/build/network。05/06/08 只在本片 dependency-present 验收证据入库后解除门禁。

技术栈沿用 04：Linux、Bash 4.4+、Python 3.8+、Git/coreutils；静态门固定 shfmt `v3.14.0` 与 ShellCheck version field `0.11.0`。并发场景只使用本机进程、文件和 `flock`，所有可变状态位于 `/tmp/aosp-harness-lease-assurance.XXXXXX` 且在 PASS 前删除。

## 组件与接口

### 消费契约（frontmatter `消费`，逐字）

`resource-leases-v1：common/.harness/lib/resource-leases.sh 的 harness_lease_acquire <session-id> <wait-seconds> <request-tsv>、harness_lease_release <lease-token>、唯一 HARNESS_RESOURCE_LEASE_TEST_SEAM anchor、0|2|3 双流协议，以及 tests/test-resource-leases.sh 的 dependency-present PASS 证据`

### 产出契约（frontmatter `产出`，逐字）

`resource-lease-assurance-v1：provider 保持原 public API/状态格式但闭合 deadline 到达后的最后一次无 sleep 锁尝试；新增 tests/test-resource-leases-assurance.sh 默认发现入口，dependency-present 成功唯一输出 RESULT PASS  resource lease assurance；不新增运行时 API 或 capability marker`

### provider deadline 相邻修复

- 职责：把扫描后的 `not occupied|wait=0|deadline` 合并退出拆成 `not occupied|wait=0` 退出与 `deadline` 立即 `continue`；下一轮无 sleep 执行第二次 `flock`，拿锁后由既有检查返回 3。
- 对外接口：`harness_lease_acquire <session-id> <wait-seconds> <request-tsv>`；`harness_lease_release <lease-token>`，签名、`0|2|3` 双流和状态格式均不变。
- 依赖：既有 `time.monotonic()`、短非阻塞 `fcntl.flock` 循环与锁后 deadline 检查；不新增依赖。

### assurance CLI 与 provider route

- 职责：只接受无参数、`all`、`--dependency-absent`；从顶层 `tests/` 解析 repo root，dependency-present 时在进入矩阵前确认默认 provider 是 repo 内精确路径上的普通非 symlink 文件。内部 absent surface 使用同构 `tests/`/`common/` 布局并显式清除 provider override；damaged provider 七类均 fail closed。
- 对外接口：`bash ./tests/test-resource-leases-assurance.sh [all|--dependency-absent]`；active 或 inert 成功均为 rc0、stdout 逐字 `RESULT PASS  resource lease assurance\n`、stderr 空，invalid CLI 为 rc1 双流空，damaged provider 为 rc1、stdout 空、stderr 逐字 `FAIL provider validation\n`。
- 依赖：Bash、`mktemp/find/stat/sha256sum/cmp` 与 candidate provider；`HARNESS_ASSURANCE_*` 只用于脚本递归 fixture，不是运行时 capability marker。

### fixture 与 fault matrix

- 职责：在自有临时树创建 request/root/state/record/helper/并发 fixture，复制 provider 后把唯一 seam 改为 fault/mutation/clock 实现；验证输入、record、等待、I/O、输出、tombstone、PID reuse、bundle barrier 与 adapter 行为。每次创建、改写和清理都有即时专属失败；holder/waiter/clock readiness 写失败令 child 非零并由父级 startup 标签收口。
- 对外接口：无运行时接口；内部 `invoke <label> <wanted-rc> <stream-shape> <command...>` 对每个 case 逐字检查 rc/stdout/stderr。
- 依赖：repo 外 EUID 自有 0700 临时树、既有唯一 seam、独立 Bash child 与 Python 标准库。tracked provider/docs/base test 只读并在前后比较 SHA-256。

### mutant self-proof

- 职责：构造 overlap 检查、真实 unpublish `os.replace(path, trash)` 状态转换、bundle 完整规范化三类 production mutant，以及 provider 文本不变的 fake-adapter key-selection fixture mutant。production mutant 必须先断言 anchor 恰一次、只替换该 anchor并通过 provider source 健康检查；child 只能命中对应专属失败标签。
- 对外接口：无；四个内部结果依次为 `FAIL stored overlap rc=0`、`FAIL disjoint release rc=2`、`FAIL same owner subset rc=0`、`FAIL adapter command count`，且 stdout 空、无 PASS。
- 依赖：candidate provider 副本、Python 精确文本替换、`provider_state` 与递归 child。

### controller 验收与顺序门

- 职责：检查 exact2/400、固定静态工具、review manifest、candidate/full/depth-1/offline/clean；在隔离 rollback checkout 恢复 provider 两行并删除 assurance，验证前序回归与本入口发现数为 0；在 accepted 证据前检查 05 五类资产物理缺席。
- 对外接口：`bash ./scripts/check.sh --offline` 与 Git 验收命令；不进入最终源码。
- 依赖：Git、隔离临时 checkout、固定工具目录和 spec ledger。

## 测试策略

| 层 | 范围 | 工具/判据 |
|---|---|---|
| 控制流单元 | deadline到期后恰两次flock、第二次前无sleep、锁后零record/stale/publish；wait=0与无竞争不回归 | 唯一 seam 的 monotonic/flock 日志、固定 rc3 双流、state inventory |
| 输入与状态集成 | R4 的 TSV/root/self-overlap 全矩阵；R6 的 duplicate/noncanonical/global overlap/nonregular/全部字段/PID reuse | `invoke`逐case核`0|2|3`及token/空/固定错误双流，结束核完整 inventory |
| 并发集成 | live holder同/异mode、positive timeout、反向bundle barrier、双adapter同instance ID | 独立 Bash进程、readiness marker、visible record解码、命令计数与有界等待 |
| 故障与 mutation | helper/capture/closed-output、root/lock identity、flock/open/write/fsync/replace/unpublish/unlink；三production mutant+一fixture mutant | provider副本唯一seam、精确mutation、source健康、专属stderr与空stdout |
| CLI/surface | 六种CLI；真实absent三入口；七类damaged provider；default/all必须先证明active route | capture文件逐字比较与运行时长/route guard，不以摘要单独证明active |
| 端到端 | candidate、完整历史checkout、真实depth-1 clone的默认入口与offline；自动发现恰一次 | `bash ./tests/test-resource-leases-assurance.sh`、`bash ./scripts/check.sh --offline`、Git shallow marker |
| 回滚/顺序 | rollback exact两文件后04基础、03e lifecycle、offline绿且入口0；05五类资产在验收前缺席 | 隔离rollback branch、Git name-only/numstat、路径/ref/worktree/ledger/dispatch检查 |
| 静态/sizing | provider `2/2`、assurance `396/0`、总churn400；manifest连续PASS；clean/diff-check | shfmt3.14.0、ShellCheck0.11.0、`bash -n`、Git/awk |
| 性能 | 不设吞吐SLO；只证明正值等待有界、到期不额外sleep | monotonic确定性clock + 外层宽容timeout |

### Runnable fixed-format prototype evidence

| 原型文件 | fixed-shfmt 后行数/差异 | 已证明 |
|---|---:|---|
| `prototypes/common/.harness/lib/resource-leases.sh` | 相对accepted provider `2/2` | deadline相邻修复，public surface/状态格式/seam不变 |
| `prototypes/tests/test-resource-leases-assurance.sh` | `396/0` | default/all真实active约30秒、dependency-absent、七damaged surface、完整矩阵和四mutant均PASS |
| **合计** | **`2+2+396=400/400`** | **exact2边界可实施** |

固定 shfmt/ShellCheck/bash-n与四项规格检查全绿。额外生命周期 fault probe 证明：顶层`mktemp`失败为rc1/空stdout/专属错误；成功前cleanup失败为rc1/空stdout/无PASS。熔断融合 reviewer 已独立复核 route、readiness、cleanup和四个专属 mutant oracle为PASS（0/0/0）。

验收资产（不纳入源码文件清单）：`prototypes/`、requirements三轮及熔断融合报告、固定工具与故障日志、逐任务red/green/review证据、六列review manifest、candidate/full/depth-1/offline/rollback/NEXT门日志、accepted HEAD与execution BASE记录。

## 文件清单

| 文件 | 创建/修改 | 职责（一句话） |
|---|---|---|
| `common/.harness/lib/resource-leases.sh` | 修改 | 以deadline相邻两行保证扫描后到期路径执行最后一次无sleep锁尝试，并复用锁后安全拒绝 |
| `tests/test-resource-leases-assurance.sh` | 创建 | 默认发现的完整输入/状态/I/O/并发/等待/adapter/mutant assurance 与固定摘要 |

### 上游任务契约

#### 任务 1: 闭合 deadline 最后一轮锁尝试

文件: 修改 `common/.harness/lib/resource-leases.sh`
产出: `resource-lease-final-attempt-v1`

---

## 你的任务

文件: 创建 `tests/test-resource-leases-assurance.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/task-2-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-2-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-2-static.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-2-default.out` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-2-default.err` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-2-all.out` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-2-all.err` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-2-lifecycle-faults.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/task-2-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-2-package.tsv` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/review-manifest.tsv`
消费: `resource-lease-final-attempt-v1`
产出: `resource-lease-assurance-v1`
需求: R3, R4, R5, R6, R7, R8
必需: 是

- [ ] 步骤 1: 生成task brief；运行 `cmp -s tests/test-resource-leases-assurance.sh "$SPEC/prototypes/tests/test-resource-leases-assurance.sh"`，确认红阶段因目标入口缺席返回非零并写red证据。
- [ ] 步骤 2: 设`TASK_BASE=$(git rev-parse HEAD)`并核其为任务1 HEAD、工作树clean；机械复制prototype到`tests/test-resource-leases-assurance.sh`，不编辑或拆出第三个源码文件。
- [ ] 步骤 3: 运行 `cmp -s tests/test-resource-leases-assurance.sh "$SPEC/prototypes/tests/test-resource-leases-assurance.sh"`、`test "$(wc -l <tests/test-resource-leases-assurance.sh)" = 396`、固定shfmt/ShellCheck/bash-n；核默认provider route为repo内普通非symlink、tracked provider/docs/base-test前后hash相同与临时树repo外属性，写`task-2-static.log`。
- [ ] 步骤 4: 捕获default/all到`task-2-{default,all}.out/.err`，逐字核rc0、stderr空、唯一固定摘要且两路均真实运行完整active矩阵；分别核六种CLI、三种真实absent surface、七类damaged provider、同owner异mode、record/request/root/concurrency/barrier/PID reuse/I/O/helper/output/adapter矩阵和四个专属mutant oracle全部执行。
- [ ] 步骤 5: 用只在repo外临时目录创建的伪`mktemp`与伪`rm`运行 `bash ./tests/test-resource-leases-assurance.sh --dependency-absent`，确认创建失败和成功前cleanup失败都为rc1、stdout空、stderr专属且无PASS；清理由controller逐字核验目标前缀后删除，命令/结果写`task-2-lifecycle-faults.log`。
- [ ] 步骤 6: 提交只含assurance入口的清晰本地commit；固定`TASK_HEAD`，核本提交exact一个文件、numstat`396/0`；核`BASE_SHA..TASK_HEAD` exact为`EXACT2`且总churn`2+2+396=400`、工作树clean。
- [ ] 步骤 7: 写green报告/evidence package并交独立diff review；PASS后追加manifest第2行（`TASK_BASE -> TASK_HEAD`），mark任务2、写ledger、sync-ledger。

## 报告契约

完整报告写进控制器指定的 `task-N-report.md`（路径由控制器给出）。

返回控制器的只有：
- **Status**：`DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED`
- **Commits**：本任务产生的 commit 列表
- **一行测试摘要**：例如 `Ran 12 tests, OK`
- **顾虑**：如有


