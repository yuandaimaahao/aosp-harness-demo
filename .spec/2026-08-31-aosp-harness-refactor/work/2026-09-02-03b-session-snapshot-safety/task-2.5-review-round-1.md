# 任务 2.5 独立 Review（Round 1）: 验证03b1与03c顺序门

审查对象: spec 2026-09-02-03b-session-snapshot-safety 任务 2.5（需求 R9），实现者报告 `task-2.5-report.md` 与证据包 `evidence/task-2.5-evidence.tsv`。
审查方式: 全新上下文只读复跑，未创建/删除任何文件；全部缺席核对为幂等只读操作。

## 结论

**PASS** — 阻断 0 / 重要 0 / 次要 2

## ① 规格符合性（步骤 1–5 实现者部分逐项）

| 检查项 | 结论 | 依据 |
|---|---|---|
| 步骤 1 红证据六行 schema（task=/command=/expected=/rc=/stdout_sha256=/stderr_sha256= + assertion=） | ✅ | `evidence/task-2.5-red.txt` 逐字六行+assertion；rc=1、两流 sha256 均为空流值，与 `red.rc=1` 及空 stdout/stderr 日志一致 |
| 步骤 2 NEXT1/NEXT2 specs/work 目录 `test ! -e` 缺席 | ✅ | 独立复跑：两 id 的 `specs/`、`work/` 路径 `test ! -e` 均 rc0 |
| 步骤 2 补充 symlink 检查（`test ! -L`） | ✅ | 独立复跑两 id 四路径 `test ! -L` 均 rc0；`test ! -e` 对悬空 symlink 会误判缺席，实现者补 `-L` 是正确加固，非漏域 |
| 步骤 2 `git show-ref --verify --quiet refs/heads/spec/<id>` rc1 | ✅ | 独立复跑两 id 均 rc1；日志 `03b1/03c-branch-absent.rc=1`、双流空 |
| 步骤 3 `git worktree list --porcelain` 双重缺席（branch 行 + 约定绝对路径） | ✅ | 独立复跑 porcelain 输出对 `03b1|03c|snapshot-assurance|write-interrupts` 全文零命中；日志含完整 `worktree-list.txt` 及 per-id 三个 rc=0（未命中） |
| 步骤 4 rg 搜索域恰为规定存在文件集合 | ✅ | 独立枚举 `specs/*/ledger.md`（7 个）与 `work/*/{dispatch.tsv,execution-base.env}` 存在文件（dispatch.tsv 全仓库不存在，execution-base.env 4 个，含 symlink 测试），与 `rg-files.txt` 排序后 `diff` 完全一致——无漏域、无越域 |
| 步骤 4 禁止模式 `dispatch.*$id\|execution BASE.*$id\|spec/$id` 零匹配 | ✅ | 用逐字相同 pattern 对同一文件集合独立复跑 rg：两 id 均 rc1、stdout/stderr 均 0 字节 |
| 步骤 4 未搜索 PLAN/requirements 合法规划文字 | ✅ | 搜索域只含 ledger.md 与 execution-base.env，不含任何 PLAN/requirements/tasks/design 文件 |
| 步骤 5 evidence package 三列 schema `path<TAB>sha256<TAB>bytes` | ✅ | 54 行全量核对：sha256 与 bytes 全部匹配（mismatches=0）；相对 work 目录；覆盖 brief/report/red/全部日志 |

## ② 质量

- **简报外的事**: 仅多出 implementation worktree HEAD=ACCEPTED_HEAD 且 clean 的前置核对（`impl-head.txt`/`impl-clean.txt`，纯只读）。这超出步骤 1 字面范围但属于无害的合理性前置，不构成范围蔓延。
- **验证是不是真的在验**: 是。我独立复跑了全部四类缺席核对（目录含 symlink、分支、worktree porcelain、限定域 rg），结论与实现者完全一致；evidence TSV 54 项哈希全量匹配，日志 rc 值语义逐一核对无误（红=1、show-ref=1、rg=1、缺席类 test=0、wt 未命中=0）。
- **错误路径**: rg 以 rc1=零匹配为通过、rc2 才为错误，日志记录的是逐命令 rc 而非笼统成功，fail-closed 语义保持；`test ! -e` 的 symlink 盲区被 `test ! -L` 覆盖；worktree 核对除 branch 行/约定路径外还有 `grep -F "$id"` 全文兜底。

## Findings

### 阻断

无。

### 重要

无。

### 次要

1. worktree 三个 per-id 核对（`*-wt-*.rc`）只保存了 rc 文件、未保存对应的 grep 双流文件；虽然底层输入 `worktree-list.txt` 已完整落盘且 grep 命中判断语义明确，审计链略弱于其他核对（rc+stdout+stderr 三件式）。
2. 步骤 1 的 implementation HEAD/clean 前置核对未在简报步骤 1 中明示要求；结果正确且只读，仅提示报告未注明这是实现者自加的加固项。
