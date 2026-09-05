# 2026-09-04-05-verifier-contract 实现计划

本片只机械安装门③已审的 exact3 prototype，固定规模 `202+67+102=371/400`；完整矩阵仍由05a独占。每任务由单个执行者一次完成，有确定命令、单提交可回滚且review不超过10分钟。普通清晰提交即可，不套组织模板。

固定变量：`PROJECT=.spec/2026-08-31-aosp-harness-refactor`，`SPEC=$PROJECT/specs/2026-09-04-05-verifier-contract`，`WORK=$PROJECT/work/2026-09-04-05-verifier-contract`，`TOOLS=/tmp/aosp-harness-tools-04`，`EXACT3='common/.harness/bin/verify-sidebar.sh docs/verifier-contract.md tests/test-verifier-contract.sh'`。controller在门④后建立隔离worktree并记录40位`BASE_SHA`；每任务生成brief、red证据、green报告和独立diff review，PASS后追加六列review manifest、mark done并sync ledger。

### 任务 1: 安装默认发现的 base contract test

文件: 创建 `tests/test-verifier-contract.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/task-1-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/evidence/task-1-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/task-1-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/review-manifest.tsv`
消费: 无
产出: `verifier-base-test-v1`（`bash tests/test-verifier-contract.sh`成功唯一stdout为`RESULT PASS  verifier contract\n`）
需求: R7, R10
必需: 是
状态: 完成

- [ ] 步骤 1: 生成brief；运行`bash tests/test-verifier-contract.sh`，确认红阶段因入口缺席返回127且无PASS，把命令、rc和双流sha256写入red证据。
- [ ] 步骤 2: 核HEAD=`BASE_SHA`且clean；机械复制`$SPEC/prototypes/tests/test-verifier-contract.sh`到目标并保持100755，不手改runner、argv oracle或cleanup门。
- [ ] 步骤 3: 运行目标与prototype的`cmp -s`、`wc -l`=102、fixed shfmt `-d -i 2 -ci -bn`、ShellCheck 0.11 warning和`bash -n`；再次运行测试，确认因provider缺席rc1、stderr为`FAIL provider`且无PASS。
- [ ] 步骤 4: 只提交该文件，提交消息`test(harness): add verifier base contract`；写报告并独立diff review，PASS后manifest第1行、mark 1、ledger与sync-ledger。

### 任务 2: 安装 canonical verifier provider

文件: 创建 `common/.harness/bin/verify-sidebar.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/task-2-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/evidence/task-2-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/task-2-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/review-manifest.tsv`
消费: `verifier-base-test-v1`
产出: `verifier-provider-v1`
需求: R1, R2, R3, R4, R5, R6
必需: 是
状态: 完成

- [ ] 步骤 1: 生成brief；运行`cmp -s common/.harness/bin/verify-sidebar.sh "$SPEC/prototypes/common/.harness/bin/verify-sidebar.sh"`，确认红阶段因目标缺席失败并写red证据。
- [ ] 步骤 2: 核HEAD为任务1 HEAD且clean；机械复制provider prototype到目标并保持100755，不改embedded Python或seam preflight。
- [ ] 步骤 3: 运行provider `cmp -s`、`wc -l`=202、fixed shfmt、ShellCheck warning、`bash -n`及`bash tests/test-verifier-contract.sh`；逐字核rc0、stderr空、stdout仅固定摘要。
- [ ] 步骤 4: 只提交provider，消息`feat(harness): add canonical verifier provider`；写报告并独立diff review，PASS后manifest第2行、mark 2、ledger与sync-ledger。

### 任务 3: 安装 verifier contract 文档

文件: 创建 `docs/verifier-contract.md`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/task-3-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/evidence/task-3-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/task-3-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-05-verifier-contract/review-manifest.tsv`
消费: `verifier-base-test-v1`, `verifier-provider-v1`
产出: `verifier-contract-v1`
需求: R8
必需: 是
状态: 完成

- [ ] 步骤 1: 生成brief；运行`cmp -s docs/verifier-contract.md "$SPEC/prototypes/docs/verifier-contract.md"`，确认红阶段因目标缺席失败并写red证据。
- [ ] 步骤 2: 核HEAD为任务2 HEAD且clean；机械复制doc prototype到目标，运行doc `cmp -s`与`wc -l`=67。
- [ ] 步骤 3: 只提交doc，消息`docs(harness): define verifier contract`；提交后运行三个prototype-to-final `cmp -s`、exact3 name-only及BASE..HEAD numstat总和371。
- [ ] 步骤 4: 写报告并独立diff review；PASS后manifest第3行、mark 3、ledger与sync-ledger。

### 任务 4: 审计 candidate 并固定 accepted HEAD

文件: 无
验收资产（不纳入源码文件清单）: 创建 `$WORK/task-4-brief.md` / 创建 `$WORK/evidence/task-4-red.txt` / 创建 `$WORK/task-4-report.md` / 修改 `$WORK/review-manifest.tsv`
消费: `verifier-contract-v1`
产出: `verifier-accepted-head-v1`
需求: R9, R10
必需: 是
状态: 完成

- [ ] 步骤 1: 运行`test -s "$WORK/task-4-report.md"`，确认报告缺席而失败并写red证据；核HEAD为任务3 HEAD且clean。
- [ ] 步骤 2: 在candidate运行fixed tools、base test、offline gate、`git diff --check`、exact3/371与clean，核两个固定摘要并写报告。
- [ ] 步骤 3: 对任务3 HEAD到自身的零源码diff做独立review；PASS后固定`ACCEPTED_HEAD`，manifest第4行、mark 4、ledger与sync-ledger。

### 任务 5: 验证 full 与 depth-1 checkout

文件: 无
验收资产（不纳入源码文件清单）: 创建 `$WORK/task-5-brief.md` / 创建 `$WORK/evidence/task-5-red.txt` / 创建 `$WORK/task-5-report.md` / 修改 `$WORK/review-manifest.tsv`
消费: `verifier-accepted-head-v1`
产出: `verifier-checkout-v1`
需求: R9, R10
必需: 是
状态: 完成

- [ ] 步骤 1: 运行`test -s "$WORK/task-5-report.md"`，确认报告缺席而失败并写red证据；核HEAD=`ACCEPTED_HEAD`且clean。
- [ ] 步骤 2: 在repo外临时目录做完整历史clone和真实`git clone --depth 1 file://...`，核HEAD一致、depth-1 count=1/shallow marker；两者运行base/offline并核exact3/clean，显式清理clone。
- [ ] 步骤 3: 写报告并对`ACCEPTED_HEAD`到自身零源码diff独立review；PASS后manifest第5行、mark 5、ledger与sync-ledger。

### 任务 6: 验证 rollback、NEXT 与终收敛

文件: 无
验收资产（不纳入源码文件清单）: 创建 `$WORK/task-6-brief.md` / 创建 `$WORK/evidence/task-6-red.txt` / 创建 `$WORK/evidence/task-6-green.txt` / 创建 `$WORK/task-6-report.md` / 修改 `$WORK/review-manifest.tsv` / 创建 `$WORK/acceptance/acceptance-report.md`
消费: `verifier-checkout-v1`
产出: `bash ./tests/test-verifier-contract.sh`
需求: R9, R10
必需: 是
状态: 完成

- [ ] 步骤 1: 运行`test -s "$WORK/task-6-report.md"`，确认报告缺席而失败并写red证据；核HEAD=`ACCEPTED_HEAD`且clean。
- [ ] 步骤 2: 隔离rollback clone删除exact3并提交，核相对BASE零diff；运行01/02/04/04a与三个旧verifier demo并核全PASS后显式清理。
- [ ] 步骤 3: 从controller主工作树而非rollback clone检查05a源码与05a/06/07/08/09/10的spec branch、worktree、execution BASE、dispatch五类资产缺席；运行check-converge和requirements全部机械检查。
- [ ] 步骤 4: 写报告/acceptance草案并独立review；PASS后manifest第6行并核六行六列首尾连续、reviewer非空、全PASS；mark 6、ledger/sync-ledger后进入accept。
