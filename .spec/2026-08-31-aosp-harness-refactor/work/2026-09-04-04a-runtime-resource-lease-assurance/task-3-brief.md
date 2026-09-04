# 任务 3: 验证 candidate、完整历史、depth-1 与 rollback

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

R1. [计划] 系统必须只修改 `common/.harness/lib/resource-leases.sh` 与新增 `tests/test-resource-leases-assurance.sh` 两个源码文件：provider 的唯一合法改动是把扫描后 `not occupied|wait=0|deadline` 合并退出分支替换成 `not occupied|wait=0` 退出与 `deadline` 立即 continue 两行，不得修改 public 函数、状态格式、文档、基础测试或唯一 seam；execution BASE 到 accepted HEAD 的 provider numstat 必须为 `2/2`、assurance 为 `396/0`，新增与删除合计 `2+2+396=400/400`。
R3. [计划] 当运行 assurance 入口时，系统必须从顶层 `tests/` 自身路径解析 repo root，并把默认 provider 精确解析为该 root 下 `common/.harness/lib/resource-leases.sh` 的普通非 symlink 文件；只接受无参数、`all`或唯一 `--dependency-absent`，unknown、extra 或 flag 带值返回 1 且 stdout/stderr 均空。repo-layout 外的 provider 物理缺席 surface 必须显式清除任何 provider override，默认、`all`与 `--dependency-absent`真实执行同一零 active case inert oracle并逐字输出固定摘要、stderr空；provider 存在但为目录/其他非普通文件、symlink、语法失败、source非零、两个 public API 任一不齐或 seam 缺失/重复时，默认 active 入口必须 fail closed返回1、stdout空且stderr逐字为`FAIL provider validation\n`。
R7. [计划] 如果发生伪 Python worker、伪 `mktemp`/`rm`、伪 mktemp 返回既有 victim、capture 路径消失、closed stdout、root/lock owner 身份变化，或 seam 注入 `flock/open/write/fsync/replace/unpublish/unlink` I/O 错误，系统必须收敛为 R6 固定 rc2 双流且不修改 victim、不留下未发布 active/tmp；unpublish 失败时原 active 必须仍存在，unlink 失败必须只留下不可见 tombstone，下一次受锁操作必须恢复并最终清空 tombstone。
R8. [计划] 系统必须检查顶层 `mktemp -d` 成功及所得路径为 repo root 外、EUID自有0700、普通空目录；失败路径的 EXIT cleanup 必须把删除失败收敛为rc1，成功路径必须在打印摘要前删除临时树并验证路径物理缺席。入口只在该树中复制 candidate provider，只把唯一 `HARNESS_RESOURCE_LEASE_TEST_SEAM` 替换为确定性 fault/mutation/clock 实现，且每个承重 fixture 的创建、改写和清理、holder/waiter/clock readiness marker 与 adapter fixture 改写失败都必须立即以专属失败退出收口；原 tracked provider、docs与基础测试在每次测试前后 SHA-256 不变。入口必须内置 overlap 检查、真实 unpublish `os.replace(path, trash)`状态转换、bundle完整规范化三类 production mutant和一类fake-adapter key-selection fixture mutant；每个 production mutant 必须先机械证明目标 anchor 恰一次、只作预期替换且变异 provider 可静默 source，adapter fixture provider 必须与 candidate 逐字相同。四者必须非零、stdout空、stderr分别逐字为其专属首个失败标签且不得含固定PASS摘要，未修改candidate文件或外部状态。
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

### 上游任务契约

#### 任务 2: 安装默认发现的完整 assurance

文件: 创建 `tests/test-resource-leases-assurance.sh`
产出: `resource-lease-assurance-v1`

---

## 你的任务

文件: 无
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/task-3-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-3-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-3-candidate-offline.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-3-full.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-3-depth1.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-3-rollback.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/task-3-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-3-package.tsv` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/review-manifest.tsv`
消费: `resource-lease-assurance-v1`
产出: `resource-lease-assurance-checkouts-v1`
需求: R1, R3, R7, R8, R9, R10
必需: 是

- [ ] 步骤 1: 运行 `test -s "$WORK/task-3-report.md"`，确认红阶段因报告缺席失败并写red证据；核implementation HEAD为任务2 HEAD且clean，并固定为`ACCEPTED_HEAD`候选。
- [ ] 步骤 2: 在candidate核fixed tools、两个final文件分别与prototype byte-identical、`git diff "$BASE_SHA" "$ACCEPTED_HEAD"`只有provider deadline相邻`2/2`与assurance`396/0`、总churn400、public surface/docs/base-test不变；记录两个交付blob及docs/base-test的SHA-256。运行默认assurance与 `bash ./scripts/check.sh --offline`，核摘要恰一次、offline末行PASS、`git diff --check`与clean，写`task-3-candidate-offline.log`。
- [ ] 步骤 3: 在repo外临时根运行 `git clone --no-local "$IMPLEMENTATION_WORKTREE" full`，核full HEAD=`ACCEPTED_HEAD`；在full重跑`BASE_SHA..ACCEPTED_HEAD` name-only/numstat，逐字核exact两文件与总churn400；运行默认assurance与offline到`task-3-full.log`，核固定摘要、发现恰一次与checkout clean。
- [ ] 步骤 4: 运行真实 `git clone --depth 1 "file://$IMPLEMENTATION_WORKTREE" depth1`，核HEAD=`ACCEPTED_HEAD`、commit count=1、`.git/shallow`非空；不得引用shallow图中不存在的`BASE_SHA`，改以 `cmp -s` 分别核两个交付文件与只读prototype逐字相同、`sha256sum`核docs/base-test及两个交付blob等于步骤2的candidate记录，再运行默认assurance与offline到`task-3-depth1.log`，核固定摘要、发现恰一次与`git status --porcelain`为空。
- [ ] 步骤 5: 从`ACCEPTED_HEAD`建立隔离rollback分支，恢复provider为`BASE_SHA`版本并删除assurance后提交；核rollback commit exact为provider`2/2`反向与assurance删除、rollback HEAD相对`BASE_SHA`源码diff为空。运行04基础测试、03e lifecycle与offline到`task-3-rollback.log`，核全绿、本入口发现0、`UPSTREAM`相对BASE无差异与checkout clean；删除full/depth1/rollback临时树和分支。
- [ ] 步骤 6: 写零源码delta green报告/evidence package并交独立diff review；PASS后追加manifest第3行（任务2 HEAD到自身），mark任务3、写ledger、sync-ledger。

## 报告契约

完整报告写进控制器指定的 `task-N-report.md`（路径由控制器给出）。

返回控制器的只有：
- **Status**：`DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED`
- **Commits**：本任务产生的 commit 列表
- **一行测试摘要**：例如 `Ran 12 tests, OK`
- **顾虑**：如有


