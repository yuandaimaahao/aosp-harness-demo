# 2026-09-04-04-runtime-resource-leases 实现计划

本片按 PLAN v5.8 只交付 runtime、协议文档与基础合同测试三个文件。design 已用 runnable fixed-format prototype 证明 exact3=`336+7+57=400/400`；任务 1.1–1.3 只机械安装并逐字比对这三个已审 blob，不在执行期临时扩机制。完整 mutation/I/O/concurrency/adapter assurance 仍由后序 04a 独占，本片只保留其 sizing prototype，不把它复制到最终测试目录。

每个任务均满足：单个执行者一次上下文可完成；有确定命令判定；失败可按本任务单提交独立回滚；机械 blob 比对或零源码 delta 使人工 review 可在 10 分钟内完成。实现提交使用普通 Conventional Commit。

固定变量与工具门：

```bash
PROJECT=.spec/2026-08-31-aosp-harness-refactor
SPEC=$PROJECT/specs/2026-09-04-04-runtime-resource-leases
WORK=$PROJECT/work/2026-09-04-04-runtime-resource-leases
TASKS=$SPEC/tasks.md
LEDGER=$SPEC/ledger.md
MANIFEST=$WORK/review-manifest.tsv
TOOLS=/tmp/aosp-harness-tools-04
EXACT3='common/.harness/lib/resource-leases.sh docs/resource-leases.md tests/test-resource-leases.sh'
UPSTREAM03E='claude-code/features/.harness/hooks/load-feature.sh claude-code/features/.harness/hooks/check-branch-drift.sh claude-code/features/.harness/hooks/session-end.sh claude-code/features/.harness/settings.json claude-code/run-demo.sh tests/test-claude-session-lifecycle.sh'
test "$("$TOOLS/shfmt" --version)" = 'v3.14.0'
"$TOOLS/shellcheck" --version | rg -q '^version: 0.11.0$'
```

controller 在门④后建立隔离 implementation worktree，并在任务 1.1 前固定 clean 40 位 `BASE_SHA`。每个任务先生成 `task-brief.py` 简报；red 证据含 `task/command/expected/rc/stdout_sha256/stderr_sha256/assertion`；green 报告含 `task/base/head/files/commands/results`；evidence package 为 `path<TAB>sha256<TAB>bytes`。每次独立 diff review PASS 后才由 controller 追加六列 manifest 行 `seq<TAB>task-id<TAB>base<TAB>head<TAB>reviewer<TAB>PASS`，再用 `mark-task-done.py`、apply_patch ledger 完成锚点、`sync-ledger.py` 收敛。若有 fix，更新 HEAD、报告/package 后复审，不复用陈旧哈希。

## 1. 交付已审 exact3 blob

### 任务 1.1: 安装资源租约 runtime provider

文件: 创建 `common/.harness/lib/resource-leases.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/task-1.1-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.1-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.1-static.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.1-source.out` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.1-source.err` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/task-1.1-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.1-package.tsv` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/review-manifest.tsv`
消费: 无
产出: `resource-leases-runtime-v1`（source 后仅公开 `harness_lease_acquire <session-id> <wait-seconds> <request-tsv>` 与 `harness_lease_release <lease-token>`）
需求: R1, R2, R3, R4, R5, R6, R7
必需: 是
状态: 完成

- [ ] 步骤 1: 生成 task brief；运行 `cmp -s common/.harness/lib/resource-leases.sh "$SPEC/prototypes/common/.harness/lib/resource-leases.sh"`，确认红阶段因目标文件缺席返回非零，并按固定 schema 写 `task-1.1-red.txt`。
- [ ] 步骤 2: 核 `git rev-parse HEAD`=`BASE_SHA` 且 clean；机械复制 prototype 到 `common/.harness/lib/resource-leases.sh`，不得手工重排或删减 embedded Python、唯一 `HARNESS_RESOURCE_LEASE_TEST_SEAM` no-op anchor、capture preflight/rollback 与 bundle 状态机。
- [ ] 步骤 3: 运行 `cmp -s common/.harness/lib/resource-leases.sh "$SPEC/prototypes/common/.harness/lib/resource-leases.sh"`、`test "$(wc -l <common/.harness/lib/resource-leases.sh)" = 336`、固定 `shfmt -d -i 2 -ci -bn`、ShellCheck warning级与 `bash -n`，命令/结果写入 `$WORK/evidence/task-1.1-static.log`；另在隔离Bash中source并把双流写入 `$WORK/evidence/task-1.1-source.out/.err`，核source静默、全部 `harness_*` 函数排序结果逐字只有两个public API、session marker缺席、seam marker恰一处。
- [ ] 步骤 4: `git add common/.harness/lib/resource-leases.sh && git commit -m "feat(harness): add resource lease runtime"`；固定 `TASK_HEAD`，核本提交 exact 只新增该文件且 numstat 336、工作树 clean。
- [ ] 步骤 5: 写 green 报告/evidence package并交独立 diff review；PASS 后追加 manifest 第1行（`BASE_SHA -> TASK_HEAD`），mark 1.1、写 ledger、sync-ledger。

### 任务 1.2: 安装 resource-leases-v1 协议文档

文件: 创建 `docs/resource-leases.md`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/task-1.2-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.2-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.2-doc-check.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/task-1.2-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.2-package.tsv` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/review-manifest.tsv`
消费: `resource-leases-runtime-v1`
产出: `resource-leases-contract-v1`（`docs/resource-leases.md`）
需求: R8
必需: 是
状态: 完成

- [ ] 步骤 1: 生成 task brief；运行 `cmp -s docs/resource-leases.md "$SPEC/prototypes/docs/resource-leases.md"`，确认红阶段因目标文件缺席返回非零并写 red 证据。
- [ ] 步骤 2: 设 `TASK_BASE=$(git rev-parse HEAD)` 并核其为任务1.1 HEAD、工作树 clean；机械复制 prototype 到 `docs/resource-leases.md`。
- [ ] 步骤 3: 运行 `cmp -s docs/resource-leases.md "$SPEC/prototypes/docs/resource-leases.md"`、`test "$(wc -l <docs/resource-leases.md)" = 7`；用逐项 `rg -F` 核两函数签名、四个合法pair、android-instance-id非serial/CVD、状态根/EUID 0700、owner/PID reuse/command substitution、规范bytes/SHA-256、完全独占/重入、bundle、monotonic/stale、tombstone与 `0|2|3` 固定协议均在正文出现，命令/结果写入 `$WORK/evidence/task-1.2-doc-check.log`。
- [ ] 步骤 4: `git add docs/resource-leases.md && git commit -m "docs(harness): document resource lease protocol"`；固定 `TASK_HEAD`，核本提交 exact 只新增该文件且 numstat 7、工作树 clean。
- [ ] 步骤 5: 写 green 报告/evidence package并独立 review；PASS 后追加 manifest 第2行（`TASK_BASE -> TASK_HEAD`），mark 1.2、写 ledger、sync-ledger。

### 任务 1.3: 安装默认发现的基础合同测试

文件: 创建 `tests/test-resource-leases.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/task-1.3-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.3-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.3-static.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.3-default.out` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.3-default.err` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.3-all.out` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.3-all.err` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.3-invalid.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.3-absent.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/task-1.3-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.3-package.tsv` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/review-manifest.tsv`
消费: `resource-leases-runtime-v1`, `resource-leases-contract-v1`
产出: `resource-leases-base-matrix-v1`（default/all 固定摘要 `RESULT PASS  resource leases\n`）
需求: R9, R10
必需: 是
状态: 完成

- [ ] 步骤 1: 生成 task brief；运行 `bash ./tests/test-resource-leases.sh`，确认红阶段因入口缺席返回 rc127 且无 PASS，并写 red 证据。
- [ ] 步骤 2: 设 `TASK_BASE=$(git rev-parse HEAD)` 并核其为任务1.2 HEAD、工作树 clean；机械复制 prototype 到 `tests/test-resource-leases.sh`，不得把 `prototypes/assurance/` 复制到最终 `tests/`。
- [ ] 步骤 3: 运行 `cmp -s tests/test-resource-leases.sh "$SPEC/prototypes/tests/test-resource-leases.sh"`、`test "$(wc -l <tests/test-resource-leases.sh)" = 57`、固定 shfmt/ShellCheck/bash-n并把命令/结果写入 `$WORK/evidence/task-1.3-static.log`；分别捕获 default/all 到对应 `.out/.err` 并逐字核唯一摘要、stderr 0B，把 `all extra`/unknown/flag带值的rc与双流哈希写入 `$WORK/evidence/task-1.3-invalid.log`，在只含测试入口的临时surface验证provider缺席rc1且无PASS并写入 `$WORK/evidence/task-1.3-absent.log`。
- [ ] 步骤 4: 核基础矩阵真实执行 source exact surface、33-byte framing、逆序同token、换session rc2、异owner rc3、不相交、stale、空request、自洽非法stored record、tombstone、假Python与完整inventory；运行 `wc -l` 核 exact3=`336+7+57=400`，再运行三个 prototype-to-final `cmp -s`。
- [ ] 步骤 5: `git add tests/test-resource-leases.sh && git commit -m "test(harness): add resource lease contract"`；固定 `TASK_HEAD`，核 `git diff --name-only "$BASE_SHA" "$TASK_HEAD"` 的C排序结果逐字等于 `EXACT3`、numstat总和400、三文件均新增、工作树clean。
- [ ] 步骤 6: 写 green 报告/evidence package并独立 review；PASS 后追加 manifest 第3行（`TASK_BASE -> TASK_HEAD`），mark 1.3、写 ledger、sync-ledger。

## 2. Controller 零源码 delta 验收

### 任务 2.1: 审计 candidate 并固定 accepted HEAD

文件: 无
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/task-2.1-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.1-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.1-static.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.1-default.out` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.1-default.err` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.1-all.out` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.1-all.err` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.1-invalid.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.1-offline.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/task-2.1-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.1-package.tsv` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/review-manifest.tsv`
消费: `resource-leases-base-matrix-v1`
产出: `resource-leases-accepted-head-v1`
需求: R9, R10
必需: 是
状态: 完成

- [ ] 步骤 1: 运行 `test -s "$WORK/task-2.1-report.md"`，确认红阶段因报告缺席失败并写red证据；核 implementation HEAD为任务1.3 HEAD且clean。
- [ ] 步骤 2: 逐字核固定工具版本；只对provider/base test跑固定shfmt、ShellCheck、bash-n；核三个final文件与prototype分别byte-identical、exact3及BASE..HEAD numstat都是400，BASE..HEAD name-only exact为三文件，且最终路径 `tests/test-resource-leases-assurance.sh` 缺席；命令/结果写入 `$WORK/evidence/task-2.1-static.log`。
- [ ] 步骤 3: 分别运行default/all到 `$WORK/evidence/task-2.1-{default,all}.out/.err`，核rc0、stderr空、stdout逐字固定摘要；逐个运行extra/unknown/flag带值并把rc/双流哈希写入 `$WORK/evidence/task-2.1-invalid.log`，核rc1双流空。运行 `bash ./scripts/check.sh --offline` 到 `$WORK/evidence/task-2.1-offline.log`，核本入口摘要恰出现1次且末行是offline gate PASS；运行 `git diff --check` 与clean。
- [ ] 步骤 4: 写green报告/evidence package并独立review；PASS后把当前clean 40位HEAD固定为 `ACCEPTED_HEAD`，追加manifest第4行（任务1.3 HEAD到自身），mark 2.1、写ledger、sync-ledger。

### 任务 2.2: 验证完整历史与真实 depth-1 checkout

文件: 无
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/task-2.2-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.2-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.2-full-default.out` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.2-full-default.err` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.2-full-offline.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.2-depth1-default.out` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.2-depth1-default.err` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.2-depth1-offline.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/task-2.2-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.2-package.tsv` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/review-manifest.tsv`
消费: `resource-leases-accepted-head-v1`
产出: `resource-leases-checkout-v1`
需求: R10
必需: 是
状态: 完成

- [ ] 步骤 1: 运行 `test -s "$WORK/task-2.2-report.md"`，确认红阶段因报告缺席失败并写red证据；核implementation HEAD=`ACCEPTED_HEAD`且clean。
- [ ] 步骤 2: 在 `mktemp -d` 下运行 `git clone --no-local "$IMPLEMENTATION_WORKTREE" full`，核full HEAD=`ACCEPTED_HEAD`；在full分别跑默认lease test到 `$WORK/evidence/task-2.2-full-default.out/.err` 与offline gate到 `$WORK/evidence/task-2.2-full-offline.log`，核固定摘要、offline发现恰1次、三文件存在且git status/diff clean。
- [ ] 步骤 3: 运行真实 `git clone --depth 1 "file://$IMPLEMENTATION_WORKTREE" depth1`，核depth1 HEAD=`ACCEPTED_HEAD`、commit count=1、`.git/shallow`非空；在depth1重复默认lease test到 `$WORK/evidence/task-2.2-depth1-default.out/.err`、offline到 `$WORK/evidence/task-2.2-depth1-offline.log` 及 exact三文件/clean断言。
- [ ] 步骤 4: 写green报告/evidence package，列入full/depth1四份运行日志后删除临时clone；独立review PASS后追加manifest第5行（`ACCEPTED_HEAD -> ACCEPTED_HEAD`），mark 2.2、写ledger、sync-ledger。

### 任务 2.3: 验证 exact rollback 与 03e 回归

文件: 无
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/task-2.3-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.3-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.3-rollback-lifecycle.out` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.3-rollback-lifecycle.err` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.3-rollback-offline.log` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/task-2.3-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.3-package.tsv` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/review-manifest.tsv`
消费: `resource-leases-checkout-v1`
产出: `resource-leases-rollback-v1`
需求: R10
必需: 是
状态: 完成

- [ ] 步骤 1: 运行 `test -s "$WORK/task-2.3-report.md"`，确认红阶段因报告缺席失败并写red证据；核implementation HEAD=`ACCEPTED_HEAD`且clean。
- [ ] 步骤 2: clone implementation到隔离rollback分支，核HEAD=`ACCEPTED_HEAD`；`git rm` exact三文件并提交普通rollback commit，核该提交name-status恰三行 `D` 且路径集合等于 `EXACT3`，并核rollback HEAD相对 `BASE_SHA` 的diff为空。
- [ ] 步骤 3: 在rollback checkout运行 `bash tests/test-claude-session-lifecycle.sh` 到 `$WORK/evidence/task-2.3-rollback-lifecycle.out/.err`，核逐字 `RESULT PASS  claude session lifecycle\n` 与stderr 0B；运行offline gate到 `$WORK/evidence/task-2.3-rollback-offline.log`，核全绿且lease摘要出现0次、03e摘要恰1次；核三文件物理缺席、`UPSTREAM03E`相对 `BASE_SHA` 无差异、checkout clean。
- [ ] 步骤 4: 写green报告/evidence package并删除rollback checkout；独立review PASS后追加manifest第6行（`ACCEPTED_HEAD -> ACCEPTED_HEAD`），mark 2.3、写ledger、sync-ledger。

### 任务 2.4: 收敛 04a 顺序门、manifest 与终交付

文件: 无
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/task-2.4-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.4-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.4-next-specs.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.4-next-work.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.4-next-refs.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.4-next-worktrees.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.4-next-records.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/task-2.4-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.4-package.tsv` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/review-manifest.tsv` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/acceptance/acceptance-report.md`
消费: `resource-leases-rollback-v1`
产出: `tests/test-resource-leases.sh`（终交付锚点 `resource-leases-v1` 记入ledger与acceptance报告）
需求: R10
必需: 是
状态: 完成

- [ ] 步骤 1: 运行 `test -s "$WORK/acceptance/acceptance-report.md"`，确认红阶段因报告缺席失败并写red证据；核implementation HEAD=`ACCEPTED_HEAD`且clean。
- [ ] 步骤 2: 在未启用nullglob的 `bash -e` 子shell中设 `NEXT=04a-runtime-resource-lease-assurance`，并定义 `no_match() { set +e; rg "$@" >/dev/null; rc=$?; set -e; test "$rc" = 1; }`（rc0=命中失败，rc1=唯一允许的未匹配，rc>1=工具/I/O失败，禁止用会把rc2当成功的裸 `! rg`）；运行 `find "$PROJECT/specs" -mindepth 1 -maxdepth 1 -type d -name "*-$NEXT" -printf '%f\n' >"$WORK/evidence/task-2.4-next-specs.txt" || exit 1` 与对应的 `find "$PROJECT/work" -mindepth 1 -maxdepth 1 -type d -name "*-$NEXT" -printf '%f\n' >"$WORK/evidence/task-2.4-next-work.txt" || exit 1`，逐字核两个capture均为0B；运行 `git for-each-ref --format='%(refname)' refs/heads/spec >"$WORK/evidence/task-2.4-next-refs.txt" || exit 1` 后执行 `no_match -q -- "^refs/heads/spec/[0-9]{4}-[0-9]{2}-[0-9]{2}-$NEXT$" "$WORK/evidence/task-2.4-next-refs.txt"`；运行 `git worktree list --porcelain >"$WORK/evidence/task-2.4-next-worktrees.txt" || exit 1` 后执行 `no_match -q -- "^(branch refs/heads/spec|worktree .*)/[0-9]{4}-[0-9]{2}-[0-9]{2}-$NEXT$" "$WORK/evidence/task-2.4-next-worktrees.txt"`，核日期前缀branch/path均缺席。
- [ ] 步骤 3: 在独立 `bash -e` 子shell重新定义步骤2同一 `NEXT` 与 `no_match` helper；用命令组把 `find "$PROJECT/specs" -mindepth 2 -maxdepth 2 -type f -name ledger.md -print` 与 `find "$PROJECT/work" -type f \( -name dispatch.tsv -o -name execution-base.env \) -print` 合并写入 `$WORK/evidence/task-2.4-next-records.txt`，任一find非零即 `exit 1`，并正向断言清单非空；逐文件循环调用 `no_match -qF "$NEXT" "$record"`，使rg rc0或rc>1都令子shell失败，只允许rc1，分别证明ledger execution BASE/dispatch record缺席。搜索域不得包含PLAN/requirements/design/tasks中合法的NEXT规划文字。
- [ ] 步骤 4: 汇总candidate/full/depth1/rollback/NEXT、fixed tools、exact3=400、default/all/extra与基础矩阵证据到green/acceptance报告并独立review；PASS后追加manifest第7行（`ACCEPTED_HEAD -> ACCEPTED_HEAD`）。
- [ ] 步骤 5: 运行以下manifest核验，要求七行、六列、首尾绑定、相邻连续、reviewer非空、全PASS：

  ```bash
  awk -F '\t' -v base="$BASE_SHA" -v head="$ACCEPTED_HEAD" '
    BEGIN { split("task-1.1 task-1.2 task-1.3 task-2.1 task-2.2 task-2.3 task-2.4", ids, " ") }
    NF != 6 || $1 != NR || $2 != ids[NR] || $3 !~ /^[0-9a-f]{40}$/ || $4 !~ /^[0-9a-f]{40}$/ || $5 == "" || $6 != "PASS" { bad=1 }
    NR == 1 && $3 != base { bad=1 }
    NR > 1 && $3 != prev { bad=1 }
    { prev=$4 }
    END { exit bad || NR != 7 || prev != head }
  ' "$MANIFEST"
  ```

- [ ] 步骤 6: mark 2.4，apply_patch写ledger完成锚点与accepted HEAD，运行sync-ledger；重跑check-tasks/check-req/check-criteria/check-analyze、candidate default/offline、fixed tools、exact3、git diff --check、clean与步骤2–3顺序门，全部通过才进入accept。inert assurance PASS不得作为04验收证据，也不得提前创建04a五类真实资产。
