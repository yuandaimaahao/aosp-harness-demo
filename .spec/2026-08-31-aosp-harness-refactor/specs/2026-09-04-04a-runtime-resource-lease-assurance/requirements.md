---
id: 2026-09-04-04a-runtime-resource-lease-assurance
依赖: [2026-09-04-04-runtime-resource-leases]
消费: "resource-leases-v1：common/.harness/lib/resource-leases.sh 的 harness_lease_acquire <session-id> <wait-seconds> <request-tsv>、harness_lease_release <lease-token>、唯一 HARNESS_RESOURCE_LEASE_TEST_SEAM anchor、0|2|3 双流协议，以及 tests/test-resource-leases.sh 的 dependency-present PASS 证据"
产出: "resource-lease-assurance-v1：provider 保持原 public API/状态格式但闭合 deadline 到达后的最后一次无 sleep 锁尝试；新增 tests/test-resource-leases-assurance.sh 默认发现入口，dependency-present 成功唯一输出 RESULT PASS  resource lease assurance；不新增运行时 API 或 capability marker"
验收方式: 混合判定
已由用户确认: true
确认依据: 用户已授权后续按 autopilot 执行；DECISIONS.md 的 04 验收行证明 dependency-present active、exact3/400、七行全 PASS manifest 与顺序门已入库；PLAN v5.9 由本片起草前真实失败触发，round2修复目标布局/fixture/mutant假绿后的fixed-shfmt exact2原型上default/all真实active与dependency-absent三路逐字PASS，provider 2增2删与assurance 396增0删的新增+删除合计400行
---

> 用户原话：“$spec review 这套 aosp harness 工程，有哪些欠缺的地方，进行重构和完善”；并确认后续按 autopilot 执行。PLAN v5.9 要求本片在任何租约消费者前闭合 04 已暴露的 deadline 最后一轮缺口，并以默认发现 assurance 穷举 mutation、I/O、并发和 adapter 反证。

## 目标

交付 `resource-lease-assurance-v1`：在不改变 `resource-leases-v1` public API、状态格式、文档与基础测试的前提下，替换 provider 的 deadline 相邻两行，使资源扫描后首次观测 deadline 到达时立即进入最后一次无 sleep `flock` 尝试，并由既有锁后检查在读取 record 或发布前返回 3；新增默认发现、fixed-shfmt 的 `tests/test-resource-leases-assurance.sh`，以 repo root 外的 `mktemp` 隔离树复制 provider，只替换唯一 `HARNESS_RESOURCE_LEASE_TEST_SEAM`，穷举输入、状态、I/O、并发、等待、adapter 与 mutant 矩阵。dependency-present 成功唯一摘要为 `RESULT PASS  resource lease assurance`；provider 物理缺席时走同摘要的零 active case inert 路径，但 inert PASS 不得解除 05/06/08 顺序门。

## 需求

R1. [计划] 系统必须只修改 `common/.harness/lib/resource-leases.sh` 与新增 `tests/test-resource-leases-assurance.sh` 两个源码文件：provider 的唯一合法改动是把扫描后 `not occupied|wait=0|deadline` 合并退出分支替换成 `not occupied|wait=0` 退出与 `deadline` 立即 continue 两行，不得修改 public 函数、状态格式、文档、基础测试或唯一 seam；execution BASE 到 accepted HEAD 的 provider numstat 必须为 `2/2`、assurance 为 `396/0`，新增与删除合计 `2+2+396=400/400`。

R2. [计划] 当正值等待的资源扫描结束后首次观测 monotonic deadline 已到时，系统必须不 sleep 而立即进入最后一轮并执行一次锁尝试；如果取得锁，系统必须由既有锁后 deadline 检查在读取 active record、回收 stale 或发布 bundle 前返回 3 与固定 unavailable 双流。该确定性场景的 seam 日志必须恰有两次 `flock`；`wait=0` 仍只尝试一次，无竞争正值请求仍可在 deadline 前成功，不得在 deadline 后发布 active bundle。

R3. [计划] 当运行 assurance 入口时，系统必须从顶层 `tests/` 自身路径解析 repo root，并把默认 provider 精确解析为该 root 下 `common/.harness/lib/resource-leases.sh` 的普通非 symlink 文件；只接受无参数、`all`或唯一 `--dependency-absent`，unknown、extra 或 flag 带值返回 1 且 stdout/stderr 均空。repo-layout 外的 provider 物理缺席 surface 必须显式清除任何 provider override，默认、`all`与 `--dependency-absent`真实执行同一零 active case inert oracle并逐字输出固定摘要、stderr空；provider 存在但为目录/其他非普通文件、symlink、语法失败、source非零、两个 public API 任一不齐或 seam 缺失/重复时，默认 active 入口必须 fail closed返回1、stdout空且stderr逐字为`FAIL provider validation\n`。

R4. [计划] 当 dependency-present active 矩阵验证 request、状态根与同 owner 行为时，系统必须逐项覆盖空文件、缺 LF、空行、CR、NUL、列数、非法 domain/mode 对、unsafe android ID、missing workspace、workspace realpath 控制字节与别名重复、request 非普通文件；覆盖相对/普通文件/symlink/非0700 root 与默认 XDG root；覆盖逆序完整重入同 token、换 session、子集、超集、部分重叠、同键异 mode、不相交 bundle 与 release 后 inventory。每项必须逐字核对 `0|2|3`、token/空双流或固定错误双流。

R5. [计划] 在不同逻辑 owner 与组合 bundle 并发期间，系统必须证明同键同 mode、同键异 mode 与正值等待均不抢占存活 holder；反向双资源 waiter 在 holder 释放前阻塞，任一可见 active record 的规范 request 始终含完整两行，释放后 waiter 成功且最终 inventory 除可选 `.lock` 外为空。两个假 adapter 对同一 `android-instance-id` 使用不同 serial/CVD name 时必须零执行竞争方命令并返回 3；改变 instance ID 的 adapter mutant 必须被 oracle 杀死。

R6. [计划] 如果发生 active 状态含 duplicate JSON key、非法/非规范 stored request、全局 key overlap、record 非普通文件，或 `version/token/nonce/owner/session/hash/request` 任一字段错误、字段缺失/额外、文件名不匹配，系统必须在任意新 acquire 前返回 2 与固定 operation-failed 双流且不得发布新 bundle；PID starttime 不匹配必须整体 stale 回收并生成新 token，之后 release 成功且 inventory 无 active/tmp/trash 或未知资产。

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
