# 2026-09-05-05a-verifier-contract-assurance 实现计划

quick执行固定为三个串行任务：任务1机械交付已审331行blob；任务2验证candidate/full/depth-1；任务3验证rollback/NEXT并收敛manifest。个人项目只要求清晰本地commit，不使用组织模板。

固定变量：

```bash
PROJECT=.spec/2026-08-31-aosp-harness-refactor
SPEC=$PROJECT/specs/2026-09-05-05a-verifier-contract-assurance
WORK=$PROJECT/work/2026-09-05-05a-verifier-contract-assurance
PROTO=$SPEC/prototypes/tests/test-verifier-contract-assurance.sh
TARGET=tests/test-verifier-contract-assurance.sh
MANIFEST=$WORK/review-manifest.tsv
TOOLS=/home/zzh0838/.cache/aosp-harness-tools-04/bin
```

门④后controller建立单一implementation worktree并记录40位`BASE_SHA`。每任务生成brief、red证据、report和独立diff review；review PASS后追加六列`seq<TAB>task-id<TAB>base<TAB>head<TAB>reviewer<TAB>PASS`，再mark done、写ledger并sync。零源码任务的base=head。修复必须更新report/manifest并由原reviewer增量复审。

### 任务 1: 机械交付完整 assurance

文件: 创建 `tests/test-verifier-contract-assurance.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/task-1-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/evidence/task-1-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/task-1-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/review-manifest.tsv`
消费: 无
产出: `tests/test-verifier-contract-assurance.sh`
需求: R1, R2, R3, R4, R5, R6, R7, R8
必需: 是
状态: 完成

- [ ] 步骤 1: 生成brief；运行`cmp -s "$TARGET" "$PROTO"`，确认红阶段失败且原因是目标物理缺席，记录命令、rc和缺席断言为red。
- [ ] 步骤 2: 核worktree HEAD=`BASE_SHA`且clean；用apply_patch把prototype逐字复制到TARGET并设0755，不重新设计、不修改05 exact3。
- [ ] 步骤 3: 核`cmp -s`、`wc -l=331`、SHA=`88f3abcd...c92ba`，固定shfmt/ShellCheck/bash-n全绿；`git diff --name-only "$BASE_SHA"`逐字仅TARGET、numstat`331/0`、05 exact3前后hash相同。
- [ ] 步骤 4: 运行TARGET default，核rc0、stdout 41 bytes固定摘要、stderr空；运行complete-absent fixture的default/all/flag和present flag拒绝，核child marker、264 IDs、41 surface、80 service与四mutant由入口内部全执行，temp物理缺席。
- [ ] 步骤 5: 提交只含TARGET的清晰commit，核commit exact1、331/0、worktree clean；写report并交独立diff review，PASS后写manifest第1行与ledger完成锚点。

### 任务 2: 验证 candidate、full 与 depth-1

文件: 无
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/task-2-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/evidence/task-2-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/evidence/task-2-green.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/task-2-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/review-manifest.tsv`
消费: `tests/test-verifier-contract-assurance.sh`
产出: `verifier-contract-assurance-checkouts-v1`
需求: R1, R2, R3, R8, R9
必需: 是
状态: 完成

- [ ] 步骤 1: 生成brief；运行`test -s "$WORK/evidence/task-2-green.txt"`，确认红阶段失败且原因是green证据缺席；固定任务1 HEAD为`ACCEPTED_HEAD`候选且clean。
- [ ] 步骤 2: candidate核TARGET与PROTO逐字、exact1=331/0、fixed tools、05保护hash、diff-check与clean；串行运行assurance、05 base和offline，捕获rc/双流/末行到green。
- [ ] 步骤 3: 在repo外`git clone --no-local`完整历史checkout，核HEAD=`ACCEPTED_HEAD`、BASE..HEAD exact1；串行运行assurance、05 base和offline并核clean，追加green。
- [ ] 步骤 4: 在repo外真实`git clone --depth 1 file://...`，核HEAD、commit-count=1、shallow marker、TARGET/PROTO blob hash；串行运行assurance、05 base和offline并核clean，追加green；物理清理两个clone。
- [ ] 步骤 5: 写零源码delta report并交独立diff review，PASS后manifest第2行base=head=`ACCEPTED_HEAD`，mark/ledger/sync。

### 任务 3: 验证 rollback、NEXT 与终门

文件: 无
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/task-3-brief.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/evidence/task-3-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/evidence/task-3-green.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/task-3-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/review-manifest.tsv` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-05-05a-verifier-contract-assurance/acceptance/acceptance-report.md`
消费: `verifier-contract-assurance-checkouts-v1`
产出: `RESULT PASS  verifier contract assurance`（终交付摘要）
需求: R1, R8, R9, R10
必需: 是
状态: 完成

- [ ] 步骤 1: 生成brief；运行`test -s "$WORK/acceptance/acceptance-report.md"`，确认红阶段失败且原因是验收报告缺席；核HEAD=`ACCEPTED_HEAD`且clean。
- [ ] 步骤 2: 从accepted HEAD建立repo外rollback checkout，精确删除TARGET并提交；核rollback tree与`BASE_SHA`零diff、assurance发现0，串行运行05/01/04/04a/03e/offline和三个旧demo回归，全绿写green并物理清理。
- [ ] 步骤 3: 核06与09的规范spec目录、`spec/`branch/worktree、execution BASE和dispatch五类资产均缺席；`rg`只接受真实rc1为无命中，rc0或rc>1失败。核candidate fixed tools、exact1、converge、diff-check、clean。
- [ ] 步骤 4: 写report/acceptance草稿并交独立diff review；PASS后manifest第3行base=head，核三行六列、首尾绑定、相邻连续、reviewer非空、全PASS。
- [ ] 步骤 5: mark/ledger/sync并重跑主验证、offline和机械门，全部通过才进入accept；inert PASS不得替代active证据，06/09仍不得提前创建。
