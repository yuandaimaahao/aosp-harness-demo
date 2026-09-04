# 2026-09-04-04a-runtime-resource-lease-assurance 实现计划

本片只交付 provider 的 deadline 相邻修复与一个 assurance 入口。门③原型已用固定工具证明 provider `2/2`、assurance `396/0`，新增+删除恰 `400/400`；任务 1–2 只安装这两个已审 blob，任务 3–4 只产出验收证据，不在执行期扩展源码范围。

每个任务均满足：单个执行者一次上下文可完成；有确定命令判定；失败可按本任务单提交或零源码 delta 独立回滚；机械 blob 比对使人工 review 可在 10 分钟内完成。本个人项目只要求提交内容清晰，不套用组织 commit 模板。

固定变量与工具门：

```bash
PROJECT=.spec/2026-08-31-aosp-harness-refactor
SPEC=$PROJECT/specs/2026-09-04-04a-runtime-resource-lease-assurance
WORK=$PROJECT/work/2026-09-04-04a-runtime-resource-lease-assurance
TASKS=$SPEC/tasks.md
LEDGER=$SPEC/ledger.md
MANIFEST=$WORK/review-manifest.tsv
TOOLS=/tmp/aosp-harness-tools-04
EXACT2='common/.harness/lib/resource-leases.sh tests/test-resource-leases-assurance.sh'
UPSTREAM='docs/resource-leases.md tests/test-resource-leases.sh tests/test-claude-session-lifecycle.sh'
test "$("$TOOLS/shfmt" --version)" = 'v3.14.0'
"$TOOLS/shellcheck" --version | rg -q '^version: 0.11.0$'
```

controller 在门④后建立隔离 implementation worktree，并在任务1前固定 clean 40位 `BASE_SHA`。每个任务用 `task-brief.py` 生成简报；red证据含 `task/command/expected/rc/stdout_sha256/stderr_sha256/assertion`；green报告含 `task/base/head/files/commands/results`；evidence package 为 `path<TAB>sha256<TAB>bytes`。每次独立diff review PASS后才追加六列manifest行 `seq<TAB>task-id<TAB>base<TAB>head<TAB>reviewer<TAB>PASS`，再运行 `mark-task-done.py`、apply_patch写ledger完成锚点、`sync-ledger.py`。修复后必须更新HEAD、报告和package并由原reviewer增量复审，不复用陈旧hash。

### 任务 1: 闭合 deadline 最后一轮锁尝试

文件: 修改 `common/.harness/lib/resource-leases.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/task-1-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-1-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-1-static.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/task-1-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-1-package.tsv` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/review-manifest.tsv`
消费: 无
产出: `resource-lease-final-attempt-v1`
需求: R1, R2
必需: 是
状态: 完成

- [ ] 步骤 1: 生成task brief；用固定`/tmp/aosp-harness-lease-assurance-task1.XXXXXX`创建repo外临时树，先核绝对前缀与不在repo内，再按真实顶层布局放入当前production provider、prototype assurance、当前accepted`docs/resource-leases.md`与`tests/test-resource-leases.sh`四文件并安装cleanup trap；运行 `bash tests/test-resource-leases-assurance.sh`，确认红阶段失败、首个专属错误逐字 `FAIL monotonic attempt count`且诊断seam日志只有一次`flock`，按固定schema写`task-1-red.txt`并删除且核临时树物理缺席。
- [ ] 步骤 2: 核 `git rev-parse HEAD`=`BASE_SHA`且clean；把`$SPEC/prototypes/common/.harness/lib/resource-leases.sh`机械复制到production路径，不改public函数、状态格式、docs、基础测试或唯一seam。
- [ ] 步骤 3: 运行 `git diff --numstat "$BASE_SHA" -- common/.harness/lib/resource-leases.sh`，确认逐字为`2<TAB>2<TAB>common/.harness/lib/resource-leases.sh`；运行`cmp -s`核production与prototype逐字相同，固定shfmt/ShellCheck/bash-n全绿，source surface仍恰两个public API且seam marker恰一处，记录到`task-1-static.log`。
- [ ] 步骤 4: 重新创建并核repo外边界的同构树，按步骤1同样复制修复后production provider、prototype assurance、当前accepted docs与基础测试四文件；运行 `bash tests/test-resource-leases-assurance.sh`，确认rc0、stderr空、stdout逐字固定摘要，并从seam oracle证明恰两次`flock`且锁后零record/stale/publish；删除且核临时树物理缺席。
- [ ] 步骤 5: 提交只含provider的清晰本地commit；固定`TASK_HEAD`，核该提交exact一个文件、numstat`2/2`与工作树clean。
- [ ] 步骤 6: 写green报告/evidence package并交独立diff review；PASS后追加manifest第1行（`BASE_SHA -> TASK_HEAD`），mark任务1、写ledger、sync-ledger。

### 任务 2: 安装默认发现的完整 assurance

文件: 创建 `tests/test-resource-leases-assurance.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/task-2-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-2-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-2-static.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-2-default.out` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-2-default.err` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-2-all.out` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-2-all.err` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-2-lifecycle-faults.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/task-2-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-2-package.tsv` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/review-manifest.tsv`
消费: `resource-lease-final-attempt-v1`
产出: `resource-lease-assurance-v1`
需求: R3, R4, R5, R6, R7, R8
必需: 是
状态: 完成

- [ ] 步骤 1: 生成task brief；运行 `cmp -s tests/test-resource-leases-assurance.sh "$SPEC/prototypes/tests/test-resource-leases-assurance.sh"`，确认红阶段因目标入口缺席返回非零并写red证据。
- [ ] 步骤 2: 设`TASK_BASE=$(git rev-parse HEAD)`并核其为任务1 HEAD、工作树clean；机械复制prototype到`tests/test-resource-leases-assurance.sh`，不编辑或拆出第三个源码文件。
- [ ] 步骤 3: 运行 `cmp -s tests/test-resource-leases-assurance.sh "$SPEC/prototypes/tests/test-resource-leases-assurance.sh"`、`test "$(wc -l <tests/test-resource-leases-assurance.sh)" = 396`、固定shfmt/ShellCheck/bash-n；核默认provider route为repo内普通非symlink、tracked provider/docs/base-test前后hash相同与临时树repo外属性，写`task-2-static.log`。
- [ ] 步骤 4: 捕获default/all到`task-2-{default,all}.out/.err`，逐字核rc0、stderr空、唯一固定摘要且两路均真实运行完整active矩阵；分别核六种CLI、三种真实absent surface、七类damaged provider、同owner异mode、record/request/root/concurrency/barrier/PID reuse/I/O/helper/output/adapter矩阵和四个专属mutant oracle全部执行。
- [ ] 步骤 5: 用只在repo外临时目录创建的伪`mktemp`与伪`rm`运行 `bash ./tests/test-resource-leases-assurance.sh --dependency-absent`，确认创建失败和成功前cleanup失败都为rc1、stdout空、stderr专属且无PASS；清理由controller逐字核验目标前缀后删除，命令/结果写`task-2-lifecycle-faults.log`。
- [ ] 步骤 6: 提交只含assurance入口的清晰本地commit；固定`TASK_HEAD`，核本提交exact一个文件、numstat`396/0`；核`BASE_SHA..TASK_HEAD` exact为`EXACT2`且总churn`2+2+396=400`、工作树clean。
- [ ] 步骤 7: 写green报告/evidence package并交独立diff review；PASS后追加manifest第2行（`TASK_BASE -> TASK_HEAD`），mark任务2、写ledger、sync-ledger。

### 任务 3: 验证 candidate、完整历史、depth-1 与 rollback

文件: 无
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/task-3-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-3-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-3-candidate-offline.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-3-full.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-3-depth1.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-3-rollback.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/task-3-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-3-package.tsv` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/review-manifest.tsv`
消费: `resource-lease-assurance-v1`
产出: `resource-lease-assurance-checkouts-v1`
需求: R1, R3, R7, R8, R9, R10
必需: 是
状态: 完成

- [ ] 步骤 1: 运行 `test -s "$WORK/task-3-report.md"`，确认红阶段因报告缺席失败并写red证据；核implementation HEAD为任务2 HEAD且clean，并固定为`ACCEPTED_HEAD`候选。
- [ ] 步骤 2: 在candidate核fixed tools、两个final文件分别与prototype byte-identical、`git diff "$BASE_SHA" "$ACCEPTED_HEAD"`只有provider deadline相邻`2/2`与assurance`396/0`、总churn400、public surface/docs/base-test不变；记录两个交付blob及docs/base-test的SHA-256。运行默认assurance与 `bash ./scripts/check.sh --offline`，核摘要恰一次、offline末行PASS、`git diff --check`与clean，写`task-3-candidate-offline.log`。
- [ ] 步骤 3: 在repo外临时根运行 `git clone --no-local "$IMPLEMENTATION_WORKTREE" full`，核full HEAD=`ACCEPTED_HEAD`；在full重跑`BASE_SHA..ACCEPTED_HEAD` name-only/numstat，逐字核exact两文件与总churn400；运行默认assurance与offline到`task-3-full.log`，核固定摘要、发现恰一次与checkout clean。
- [ ] 步骤 4: 运行真实 `git clone --depth 1 "file://$IMPLEMENTATION_WORKTREE" depth1`，核HEAD=`ACCEPTED_HEAD`、commit count=1、`.git/shallow`非空；不得引用shallow图中不存在的`BASE_SHA`，改以 `cmp -s` 分别核两个交付文件与只读prototype逐字相同、`sha256sum`核docs/base-test及两个交付blob等于步骤2的candidate记录，再运行默认assurance与offline到`task-3-depth1.log`，核固定摘要、发现恰一次与`git status --porcelain`为空。
- [ ] 步骤 5: 从`ACCEPTED_HEAD`建立隔离rollback分支，恢复provider为`BASE_SHA`版本并删除assurance后提交；核rollback commit exact为provider`2/2`反向与assurance删除、rollback HEAD相对`BASE_SHA`源码diff为空。运行04基础测试、03e lifecycle与offline到`task-3-rollback.log`，核全绿、本入口发现0、`UPSTREAM`相对BASE无差异与checkout clean；删除full/depth1/rollback临时树和分支。
- [ ] 步骤 6: 写零源码delta green报告/evidence package并交独立diff review；PASS后追加manifest第3行（任务2 HEAD到自身），mark任务3、写ledger、sync-ledger。

### 任务 4: 收敛顺序门、manifest 与终验收

文件: 无
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/task-4-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-4-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-4-next-gates.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/task-4-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/evidence/task-4-package.tsv` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/review-manifest.tsv` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04a-runtime-resource-lease-assurance/acceptance/acceptance-report.md`
消费: `resource-lease-assurance-checkouts-v1`
产出: `RESULT PASS  resource lease assurance`（终交付摘要）
需求: R9, R10
必需: 是
状态: 完成

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
