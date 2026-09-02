# 2026-09-02-03b-session-snapshot-safety 实现计划

三轮tasks review证明逐函数拼装中间Python会制造未定义import、截断builder与假红。熔断裁定改为两个固定blob机械落地任务，再把candidate/full/depth-1/rollback/order/terminal拆成六个小型controller任务；共八个任务严格串行。实现提交使用普通Conventional Commit。每个任务均保存red记录、green报告和evidence package，交全新独立agent review；Blocking/Important修复后必须由另一全新agent re-review。

固定变量与blob门：

```bash
PROJECT=.spec/2026-08-31-aosp-harness-refactor
SPEC=$PROJECT/specs/2026-09-02-03b-session-snapshot-safety
WORK=$PROJECT/work/2026-09-02-03b-session-snapshot-safety
TASKS=$SPEC/tasks.md
LEDGER=$SPEC/ledger.md
MANIFEST=$WORK/review-manifest.tsv
PROTO_SHA=a708ce6f0979c6644292b58b4a7b0d4afcdf821d
PROTO_ROOT=$PROJECT/work/2026-09-02-03b-session-snapshot-safety/prototype
PROTO_CORE=$PROTO_ROOT/snapshot-core-r2.sh
PROTO_TEST=$PROTO_ROOT/snapshot-test-prototype.sh
test "$(git show "$PROTO_SHA:$PROTO_CORE" | wc -l)" -eq 208
test "$(git show "$PROTO_SHA:$PROTO_TEST" | wc -l)" -eq 192
```

red记录固定六行：`task=`、`command=`、`expected=`、`rc=`、`stdout_sha256=`、`stderr_sha256=`，末加`assertion=`；green报告固定含task/base/head/files/commands/results。evidence package为TSV三列`path<TAB>sha256<TAB>bytes`，列出brief、report和全部日志；reviewer拿这三个路径，而不是依赖base=head的空diff。

manifest固定六列`seq<TAB>task-id<TAB>base<TAB>head<TAB>reviewer<TAB>PASS`。每个任务独立review PASS后先追加本行，再分别执行：

```bash
python3 /home/zzh0838/.agents/skills/spec/scripts/mark-task-done.py "$TASKS" TASK_ID
# controller用apply_patch向ledger增加：- 任务 TASK_ID: 完成 commits=[TASK_HEAD]
python3 /home/zzh0838/.agents/skills/spec/scripts/sync-ledger.py "$LEDGER" --repo "$IMPLEMENTATION_WORKTREE"
```

### 任务 1.1: 机械落地完整snapshot runtime

文件: 创建 `common/.harness/lib/session-state-snapshot.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/evidence/task-1.1-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/task-1.1-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/review-manifest.tsv`
消费: 无
产出: session-snapshot-runtime-v2
需求: R1, R2, R3, R4, R5, R6, R7
必需: 是
状态: 完成

外部接口：`harness_validate_feature_name <name>`合法0/双流空、非法或arity错2/stdout空/stderr逐字`error: invalid feature name\n`，worker抑制其双流并映射2；`_harness_session_path_core <project-id> <session-id>`成功path+LF/0、OS错双流空/1、安全错双流空/2；03a2 accepted ledger的37/37与九类PASS门。

- [ ] 步骤 1: 运行`test ! -e common/.harness/lib/session-state-snapshot.sh`后尝试source目标，确认红阶段失败为文件缺席；按固定schema写`$WORK/evidence/task-1.1-red.txt`并核`test -s`。
- [ ] 步骤 2: 用apply_patch创建目标文件，内容与`git show "$PROTO_SHA:$PROTO_CORE"`逐字相同；将blob落临时文件后运行`cmp -s "$tmp_core" common/.harness/lib/session-state-snapshot.sh`和`wc -l`=208。
- [ ] 步骤 3: 将prototype test blob落到implementation根下临时文件，只设置绝对`SNAPSHOT_CORE`为目标runtime并运行；要求rc0、stdout逐字`RESULT PASS  session snapshot safety\n`、stderr0B，结束后删除临时文件。
- [ ] 步骤 4: 运行固定shfmt/ShellCheck、bash-n、`git diff --check`、八anchor exact1、无fallback、source四态与assurance sizing hash只读核对；按固定schema写task报告。
- [ ] 步骤 5: 对untracked runtime运行`git add -N`核working-tree name-only exact1/numstat208，再提交`feat(session): add snapshot runtime`；设置`TASK_HEAD=$(git rev-parse HEAD)`并核`TASK_BASE..TASK_HEAD`exact1、clean、上游四文件SHA不变。
- [ ] 步骤 6: 生成task brief/report、`review-package.sh TASK_BASE TASK_HEAD`及evidence package，取得独立diff review PASS；有fix则更新`TASK_HEAD`、重跑步骤3–5并交全新reviewer。
- [ ] 步骤 7: 运行`printf '1\ttask-1.1\t%s\t%s\t%s\tPASS\n' "$TASK_BASE" "$TASK_HEAD" "$REVIEWER" >>"$MANIFEST"`；随后分别mark 1.1、apply_patch写ledger锚点、sync-ledger。

### 任务 1.2: 机械落地默认基础测试

文件: 创建 `tests/test-session-snapshot.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/evidence/task-1.2-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/task-1.2-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/review-manifest.tsv`
消费: session-snapshot-runtime-v2
产出: snapshot-default-matrix-v1
需求: R1, R2, R3, R4, R5, R6, R7
必需: 是
状态: 完成

- [ ] 步骤 1: 运行`test ! -e tests/test-session-snapshot.sh && bash tests/test-session-snapshot.sh`，确认红阶段失败rc127/no-PASS；按固定schema写red文件并核非空，runtime的prototype test前置仍PASS。
- [ ] 步骤 2: 用apply_patch创建目标test；内容只对prototype blob做唯一转换：`core=${SNAPSHOT_CORE:-$here/snapshot-core-prototype.sh}`替换为`core=${SNAPSHOT_CORE:-$repo/common/.harness/lib/session-state-snapshot.sh}`，其余逐字相同。以机械转换生成临时expected并`cmp -s`目标，核192行。
- [ ] 步骤 3: 运行argv全表、dependency-present default/all、隔离provider-absent default/flag、source四态、failure-stdout/source-rc self-disproof；每次分离保存rc/stdout/stderr，成功摘要逐字且失败rc1/no-PASS。
- [ ] 步骤 4: 运行同/异值并发、managed/snapshot攻击、真实Python PID与基础首信号表，核八anchor exact1、strict misuse零state、无fallback、winner/victim/temp delta；写green报告。
- [ ] 步骤 5: 对untracked test运行`git add -N`，执行固定工具、bash-n、default/all/offline、diff-check和working-tree exact2/numstat<=400；提交`test(session): add snapshot safety matrix`，设置并验证`TASK_HEAD`、clean和上游SHA不变。
- [ ] 步骤 6: 生成brief/report/diff/evidence package并取得独立review PASS；fix后更新head、全量重跑并交全新reviewer。
- [ ] 步骤 7: 运行`printf '2\ttask-1.2\t%s\t%s\t%s\tPASS\n' "$TASK_BASE" "$TASK_HEAD" "$REVIEWER" >>"$MANIFEST"`；随后分别mark 1.2、apply_patch写ledger锚点、sync-ledger。

### 任务 2.1: 审计candidate并固定accepted HEAD

文件: 测试 `common/.harness/lib/session-state-snapshot.sh` / 测试 `tests/test-session-snapshot.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/evidence/task-2.1-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/task-2.1-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/review-manifest.tsv`
消费: snapshot-default-matrix-v1
产出: snapshot-accepted-head-v1
需求: R8
必需: 是
状态: 完成

- [ ] 步骤 1: 运行`test -s "$WORK/task-2.1-report.md"`确认红阶段失败为报告缺席，按固定schema写red文件；implementation必须clean且HEAD为任务1.2 head。
- [ ] 步骤 2: 保存四上游文件before SHA，核固定工具版本，只对exact两文件跑shfmt/ShellCheck/bash-n/default/all/offline，分别保存日志并核offline中的snapshot摘要恰一次，再`cmp` after SHA清单。
- [ ] 步骤 3: 核`BASE_SHA..HEAD`exact两文件、numstat<=400、diff-check、八anchor/surface、clean并生成green报告和evidence package；若发现源码缺陷则回流任务1.1或1.2修复/re-review，不在本任务改变HEAD。
- [ ] 步骤 4: 交独立reviewer审brief/report/evidence package并取得PASS，把当前40位clean HEAD固定为`ACCEPTED_HEAD`。
- [ ] 步骤 5: 运行`printf '3\ttask-2.1\t%s\t%s\t%s\tPASS\n' "$TASK_HEAD" "$TASK_HEAD" "$REVIEWER" >>"$MANIFEST"`；随后分别mark 2.1、apply_patch写ledger锚点、sync-ledger。

### 任务 2.2: 验证完整历史checkout

文件: 测试 `common/.harness/lib/session-state-snapshot.sh` / 测试 `tests/test-session-snapshot.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/evidence/task-2.2-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/task-2.2-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/review-manifest.tsv`
消费: snapshot-accepted-head-v1
产出: snapshot-full-checkout-v1
需求: R8
必需: 是
状态: 完成

- [ ] 步骤 1: 运行`test -s "$WORK/task-2.2-report.md"`确认红阶段失败为报告缺席并写red文件；核implementation HEAD=`ACCEPTED_HEAD`。
- [ ] 步骤 2: 创建临时目录，运行`git clone --no-local "$IMPLEMENTATION_WORKTREE" "$tmp/full"`并核full HEAD逐字等于`ACCEPTED_HEAD`。
- [ ] 步骤 3: 在full中保存四上游SHA before，分别运行default与offline到独立日志；核default固定摘要一次、offline日志snapshot摘要恰一次且末行offline PASS，再比较after SHA、diff/status clean。
- [ ] 步骤 4: 写green报告/evidence package并删除full checkout；独立review PASS后运行`printf '4\ttask-2.2\t%s\t%s\t%s\tPASS\n' "$ACCEPTED_HEAD" "$ACCEPTED_HEAD" "$REVIEWER" >>"$MANIFEST"`。
- [ ] 步骤 5: 分别mark 2.2、apply_patch写ledger锚点、sync-ledger。

### 任务 2.3: 验证真实depth-1 checkout

文件: 测试 `common/.harness/lib/session-state-snapshot.sh` / 测试 `tests/test-session-snapshot.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/evidence/task-2.3-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/task-2.3-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/review-manifest.tsv`
消费: snapshot-full-checkout-v1
产出: snapshot-depth1-checkout-v1
需求: R8
必需: 是
状态: 完成

- [ ] 步骤 1: 运行`test -s "$WORK/task-2.3-report.md"`确认红阶段失败为报告缺席并写red文件。
- [ ] 步骤 2: 运行`git clone --depth 1 "file://$IMPLEMENTATION_WORKTREE" "$tmp/depth1"`，核HEAD=`ACCEPTED_HEAD`、`git rev-list --count HEAD`=1及`.git/shallow`非空。
- [ ] 步骤 3: 保存四上游SHA before，分别运行default/offline到独立日志，逐个核固定摘要与offline snapshot恰一次/末行PASS；比较after SHA、diff/status clean。
- [ ] 步骤 4: 写green报告/evidence package并删除depth checkout；独立review PASS后运行`printf '5\ttask-2.3\t%s\t%s\t%s\tPASS\n' "$ACCEPTED_HEAD" "$ACCEPTED_HEAD" "$REVIEWER" >>"$MANIFEST"`。
- [ ] 步骤 5: 分别mark 2.3、apply_patch写ledger锚点、sync-ledger。

### 任务 2.4: 验证exact rollback

文件: 测试 `common/.harness/lib/session-state-snapshot.sh` / 测试 `tests/test-session-snapshot.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/evidence/task-2.4-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/task-2.4-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/review-manifest.tsv`
消费: snapshot-depth1-checkout-v1
产出: snapshot-rollback-v1
需求: R9
必需: 是
状态: 完成

- [ ] 步骤 1: 运行`test -s "$WORK/task-2.4-report.md"`确认红阶段失败为报告缺席并写red文件。
- [ ] 步骤 2: 从implementation clone rollback并核HEAD=`ACCEPTED_HEAD`；运行`git rm common/.harness/lib/session-state-snapshot.sh tests/test-session-snapshot.sh`后提交普通rollback commit，核其name-status exact两个D。
- [ ] 步骤 3: 在rollback运行`bash tests/test-session-path.sh`、`python3 tests/lib/session-path-race-driver.py self-test common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh`、`bash tests/test-session-path-races.sh`与offline；核全绿、offline中snapshot摘要0、两目标物理缺席且clean。
- [ ] 步骤 4: 写green报告/evidence package并删除rollback；独立review PASS后运行`printf '6\ttask-2.4\t%s\t%s\t%s\tPASS\n' "$ACCEPTED_HEAD" "$ACCEPTED_HEAD" "$REVIEWER" >>"$MANIFEST"`。
- [ ] 步骤 5: 分别mark 2.4、apply_patch写ledger锚点、sync-ledger。

### 任务 2.5: 验证03b1与03c顺序门

文件: 测试 `common/.harness/lib/session-state-snapshot.sh` / 测试 `tests/test-session-snapshot.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/evidence/task-2.5-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/task-2.5-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/review-manifest.tsv`
消费: snapshot-rollback-v1
产出: snapshot-order-gate-v1
需求: R9
必需: 是
状态: 完成

- [ ] 步骤 1: 运行`test -s "$WORK/task-2.5-report.md"`确认红阶段失败为报告缺席并写red文件。
- [ ] 步骤 2: 定义完整ID`NEXT1=2026-09-02-03b1-session-snapshot-assurance`、`NEXT2=2026-09-02-03c-session-write-interrupts`；对两者逐一`test ! -e "$PROJECT/specs/$id"`、`test ! -e "$PROJECT/work/$id"`，并要求`git show-ref --verify --quiet "refs/heads/spec/$id"`返回1。
- [ ] 步骤 3: 对两者逐一核`git worktree list --porcelain`不含`branch refs/heads/spec/$id`及约定worktree绝对路径；若未来work目录缺席则execution-base/manifest/task-brief自然缺席，若存在任何同名或symlink立即失败。
- [ ] 步骤 4: 仅对`$PROJECT/specs/*/ledger.md`与`$PROJECT/work/*/{dispatch.tsv,execution-base.env}`存在文件运行rg，禁止匹配`dispatch.*$id|execution BASE.*$id|spec/$id`；不得搜索PLAN/requirements中的合法规划文字。
- [ ] 步骤 5: 写green报告/evidence package并取得独立review PASS；运行`printf '7\ttask-2.5\t%s\t%s\t%s\tPASS\n' "$ACCEPTED_HEAD" "$ACCEPTED_HEAD" "$REVIEWER" >>"$MANIFEST"`。
- [ ] 步骤 6: 分别mark 2.5、apply_patch写ledger锚点、sync-ledger。

### 任务 2.6: 收敛manifest、ledger与终交付

文件: 测试 `common/.harness/lib/session-state-snapshot.sh` / 测试 `tests/test-session-snapshot.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/evidence/task-2.6-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/task-2.6-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/review-manifest.tsv` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/acceptance/acceptance-report.md`
消费: snapshot-order-gate-v1
产出: session-snapshot-core-v2
需求: R8, R9
必需: 是
状态: 完成

- [ ] 步骤 1: 运行`test -s "$WORK/acceptance/acceptance-report.md"`确认红阶段失败为报告缺席并写red文件；核HEAD=`ACCEPTED_HEAD`与clean。
- [ ] 步骤 2: 汇总candidate/full/depth/rollback/order日志到green与acceptance报告，生成evidence package并取得独立review PASS。
- [ ] 步骤 3: 运行`printf '8\ttask-2.6\t%s\t%s\t%s\tPASS\n' "$ACCEPTED_HEAD" "$ACCEPTED_HEAD" "$REVIEWER" >>"$MANIFEST"`。
- [ ] 步骤 4: 运行以下完整manifest核验：

  ```bash
  awk -F '\t' -v base="$BASE_SHA" -v head="$ACCEPTED_HEAD" '
    BEGIN { split("task-1.1 task-1.2 task-2.1 task-2.2 task-2.3 task-2.4 task-2.5 task-2.6", ids, " ") }
    NF != 6 || $1 != NR || $2 != ids[NR] || $3 !~ /^[0-9a-f]{40}$/ || $4 !~ /^[0-9a-f]{40}$/ || $5 == "" || $6 != "PASS" { bad=1 }
    NR == 1 && $3 != base { bad=1 }
    NR > 1 && $3 != prev { bad=1 }
    { prev=$4 }
    END { exit bad || NR != 8 || prev != head }
  ' "$MANIFEST"
  ```

- [ ] 步骤 5: mark任务2.6完成；用apply_patch写ledger完成锚点及accepted HEAD、active摘要、八anchor、signal协议、exact2/400、full/depth/rollback/order证据，再运行sync-ledger。
- [ ] 步骤 6: 重跑check-tasks/check-req/check-criteria/check-analyze、candidate default/offline、diff-check、clean与顺序门；全部通过才进入accept，任何inert PASS不得解除后序门。
