# 任务 4: 收敛顺序门、manifest 与终验收

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

R9. [计划] 当本片进入验收时，系统必须在 candidate、完整历史 checkout 与真实 `git clone --depth 1 file://...` 中分别运行默认 assurance 与 `bash ./scripts/check.sh --offline`，自动发现本入口恰好一次；controller 必须先逐字验证 shfmt `v3.14.0`与 ShellCheck version field `0.11.0`，再只对本片两个 shell 文件运行 `shfmt -d -i 2 -ci -bn`、`shellcheck -x --severity=warning`与 `bash -n`。execution BASE 到 accepted HEAD 必须 exact 为 R1 两文件且numstat新增+删除`2+2+396=400`，六列 review manifest 必须与 tasks 一一对应、首尾/相邻连续、reviewer 非空且全 PASS，`git diff --check`与各 checkout clean 必须通过。
R10. [计划] 当验证独立回滚与顺序时，系统必须从 accepted HEAD 建立隔离临时分支，提交 exact 使 assurance 入口物理缺席并把 provider 两行恢复到 execution BASE 的 rollback commit；该 clean checkout 中 04 基础测试、03e 生命周期与 offline 必须全绿，本入口发现 0 次。controller 只有在 04a accepted HEAD、dependency-present active 矩阵、exact2/400、full/depth-1/rollback 与全 PASS manifest 入 ledger 后，才可创建规范 ID `05-verifier-contract`（日期前缀由创建日决定）的 spec 目录、同名 `spec/`分支/worktree、ledger execution BASE 或 dispatch 记录；此前五类资产必须物理缺席，任何 inert PASS 不得作为验收证据或解除 05/06/08 门禁。

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

### 上游任务契约

#### 任务 3: 验证 candidate、完整历史、depth-1 与 rollback

文件: 无
产出: `resource-lease-assurance-checkouts-v1`

---

## 你的任务

文件: 无
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/task-4-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-4-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-4-next-gates.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/task-4-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-4-package.tsv` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/review-manifest.tsv` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/acceptance/acceptance-report.md`
消费: `resource-lease-assurance-checkouts-v1`
产出: `RESULT PASS  resource lease assurance`（终交付摘要）
需求: R9, R10
必需: 是

- [ ] 步骤 1: 运行 `test -s "$WORK/acceptance/acceptance-report.md"`，确认红阶段因报告缺席失败并写red证据；核implementation HEAD=`ACCEPTED_HEAD`且clean。
- [ ] 步骤 2: 在启用`set -e`且未启用nullglob的独立Bash中检查规范ID`05-verifier-contract`的日期前缀spec目录、同名`spec/`branch与worktree均物理缺席；搜索全部ledger/`execution-base.env`/`dispatch.tsv`，只允许`rg` rc1表示无05 execution BASE或dispatch，rc0命中与rc>1工具错误均失败。把命令、捕获路径和rc写`task-4-next-gates.log`。
- [ ] 步骤 3: 汇总candidate/full/depth1/rollback、default/all/absent、fixed tools、lifecycle faults、四mutant、exact2/400与NEXT五类证据到green/acceptance报告并交独立diff review；PASS后追加manifest第4行（`ACCEPTED_HEAD -> ACCEPTED_HEAD`）。
- [ ] 步骤 4: 运行以下manifest核验，要求四行、六列、首尾绑定、相邻连续、reviewer非空、全PASS：

  ```bash
  awk -F '\t' -v base="$BASE_SHA" -v head="$ACCEPTED_HEAD" '
    BEGIN { split("task-1 task-2 task-3 task-4", ids, " ") }
    NF != 6 || $1 != NR || $2 != ids[NR] || $3 !~ /^[0-9a-f]{40}$/ || $4 !~ /^[0-9a-f]{40}$/ || $5 == "" || $6 != "PASS" { bad=1 }
    NR == 1 && $3 != base { bad=1 }
    NR > 1 && $3 != prev { bad=1 }
    { prev=$4 }
    END { exit bad || NR != 4 || prev != head }
  ' "$MANIFEST"
  ```

- [ ] 步骤 5: mark任务4，apply_patch写ledger完成锚点与accepted HEAD，运行sync-ledger；重跑check-tasks/check-req/check-criteria/check-analyze/check-design、candidate默认assurance/offline、fixed tools、exact2/400、git diff --check、clean与步骤2顺序门，全部通过才进入accept。inert PASS不得替代dependency-present证据，也不得提前创建05/06/08资产。

## 报告契约

完整报告写进控制器指定的 `task-N-report.md`（路径由控制器给出）。

返回控制器的只有：
- **Status**：`DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED`
- **Commits**：本任务产生的 commit 列表
- **一行测试摘要**：例如 `Ran 12 tests, OK`
- **顾虑**：如有


