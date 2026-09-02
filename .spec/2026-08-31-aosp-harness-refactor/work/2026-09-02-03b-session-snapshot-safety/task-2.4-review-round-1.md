# 任务 2.4 独立 review（round 1）: 验证exact rollback

- 审查对象: spec 2026-09-02-03b-session-snapshot-safety 任务 2.4（需求 R9），纯验证任务
- 审查输入: task-2.4-brief.md、task-2.4-report.md、evidence/task-2.4-evidence.tsv 及全部日志
- ACCEPTED_HEAD: `ab1e870ece16bbc24e1a86f84110366f84aae0d9`
- 审查方式: 只读日志核对 + 全量 evidence 哈希/字节核对 + implementation worktree 只读状态核对；未重跑实现者已跑过的验证

## 结论

**PASS** — 阻断 0 / 重要 0 / 次要 3

## ① 规格符合性（步骤 1–4 实现者部分逐项）

| 检查项 | 结论 | 依据 |
|---|---|---|
| 红证据六行 schema + assertion | ✅ | `evidence/task-2.4-red.txt` 恰为 task=/command=/expected=/rc=/stdout_sha256=/stderr_sha256= 六行加 assertion=；rc=1 与 red.rc 一致，双流 sha256 均为空串哈希 e3b0c44…，与 red.stdout/red.stderr 0 字节一致 |
| clone HEAD=ACCEPTED_HEAD | ✅ | `rollback-head.txt` 逐字 `ab1e870ece16bbc24e1a86f84110366f84aae0d9`；clone.stderr 目标路径与 tmpdir.txt 一致 |
| rollback commit name-status 恰好两个 D 且 parent=ACCEPTED_HEAD | ✅ | `name-status.txt` 恰两行 `D\tcommon/.harness/lib/session-state-snapshot.sh`、`D\ttests/test-session-snapshot.sh`；`rollback-parent.txt` 逐字=ACCEPTED_HEAD；commit.stdout 显示 `2 files changed, 400 deletions(-)`（208+192，与 blob 门一致）及两行 delete mode |
| rollback 中 test-session-path.sh 绿 | ✅ | path.rc=0、path.stderr 0B、path.stdout 单行 `RESULT PASS  session path safety`（与测试脚本仅向 stdout 打印 SUMMARY 一行一致） |
| rollback 中 race-driver self-test 绿 | ✅ | selftest.rc=0、stderr 0B、stdout `RESULT PASS  session path race driver` |
| rollback 中 test-session-path-races.sh 绿 | ✅ | races.rc=0、stderr 0B、stdout `RESULT PASS  session path race assurance` |
| rollback 中 offline 绿 | ✅ | offline.rc=0、stderr 0B、末行 `RESULT PASS  aosp-harness offline quality gate` |
| offline 中 snapshot 摘要 0 次 | ✅ | 复核 `grep -ci snapshot offline.stdout` = 0 |
| 两目标物理缺席 | ✅ | 无独立 `test ! -e` 日志，但 git-rm.stdout 两行 rm、name-status 两个 D、commit delete mode 与 clean 状态构成完整旁证链（见次要 finding 1） |
| rollback checkout clean | ✅ | clean.txt 0 字节（`git status --porcelain` 0 行） |
| evidence package 三列 schema | ✅ | TSV 33 行全部 NF=3；33/33 文件 sha256 与 bytes 全量核对一致 |
| 临时 checkout 已删除 | ✅ | `/tmp/task-2.4-rollback.Af0fG7` 不存在，/tmp 无 task-2.4 残留 |
| implementation worktree 未被污染 | ✅ | HEAD 逐字=`ab1e870e…`（ACCEPTED_HEAD）、`git status --porcelain` 0 行、无 stash；`git cat-file -t 6c90230d…` 失败、`git branch --contains` 报 no such commit——rollback commit 对象不在仓库中，无 stray commit |

## ② 质量

- **是否做了简报没要求的事**: 无。实现者未在 implementation worktree 创建 commit；review-manifest.tsv 仍为 5 行（task-1.1…2.3），第 6 行按契约留给控制器在 review PASS 后追加；步骤 5 的 mark/ledger/sync 未越权执行。
- **验证是不是真的在验**: 是。每个命令 rc/stdout/stderr 分离落盘，evidence TSV 的 sha256+bytes 全量复核 33/33 一致，日志内容与报告声称逐条吻合；红阶段 rc=1 且双流为空哈希，非伪造通过。单行 stdout 与各测试脚本只向 stdout 打印 SUMMARY 一行的行为一致，不是截断或过滤后的假象。
- **错误路径处理**: 红阶段正确验证「报告缺席」这一失败前提；前置条件（HEAD=ACCEPTED_HEAD + clean）写入 assertion；rollback commit 只存在于已删除的临时 clone，对象未泄漏进仓库，验证的隔离性是真实的。

## Findings

### 阻断（0）

无。

### 重要（0）

无。

### 次要（3）

1. 步骤 3 的「两目标物理缺席」没有独立的 `test ! -e` 日志文件，仅靠 git-rm/name-status/clean 旁证；临时 clone 已删除无法补验，但旁证链完整且互相一致。
2. 前置条件（implementation HEAD=ACCEPTED_HEAD 且 clean）只出现在 red.txt 的 assertion 文本中，无独立日志文件；本 reviewer 直接复核当前状态一致，不影响结论。
3. clone 的来源与 `--no-local` 参数在日志中不可见（clone.stderr 只含目标路径）；clone 后 HEAD 逐字等于 ACCEPTED_HEAD，一致性成立，仅属日志完整性建议。
