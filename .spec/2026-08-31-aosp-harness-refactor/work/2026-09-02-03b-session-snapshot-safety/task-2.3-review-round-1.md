# 任务 2.3 独立 Review（Round 1）: 验证真实depth-1 checkout

- 审查对象: spec 2026-09-02-03b-session-snapshot-safety / task-2.3（需求 R8），ACCEPTED_HEAD=`ab1e870ece16bbc24e1a86f84110366f84aae0d9`
- 审查性质: 纯验证任务，无源码 diff；只读核对 brief / report / evidence package / 日志与 implementation worktree 现状，未重跑实现者已有日志证据的验证，未修改任何文件
- 审查输入: `task-2.3-brief.md`、`task-2.3-report.md`、`evidence/task-2.3-evidence.tsv`（22 项，全量核对 sha256+bytes）、`evidence/task-2.3-red.txt`、`evidence/task-2.3-logs/`（19 个日志全读）

## 结论

**PASS** — 阻断 0 / 重要 0 / 次要 1

## ① 规格符合性（步骤 1–4 实现者部分逐项）

| 项 | 结论 | 依据 |
|---|---|---|
| 红证据六行 schema + assertion= | ✅ | `evidence/task-2.3-red.txt` 逐字为 `task=/command=/expected=/rc=/stdout_sha256=/stderr_sha256=` 六行加 `assertion=`；`red.rc`=1，`red.stdout`/`red.stderr` 均为空 sha（e3b0c44…），与日志一致 |
| depth-1 clone HEAD=ACCEPTED_HEAD | ✅ | `depth1-head.txt` 与 `depth1-head-after.txt` 均逐字 `ab1e870ece16bbc24e1a86f84110366f84aae0d9`；`clone.rc`=0，`clone.stderr` 为 git 正常的 "Cloning into '/tmp/task-2.3-depth1.uXeSad/depth1'..."（53B，证明真实 clone 发生） |
| rev-list count=1（落盘日志） | ✅ | `depth1-count.txt` 内容为 `1`（2 bytes，独立落盘） |
| .git/shallow 非空（落盘日志） | ✅ | `depth1-shallow.txt` 为 shallow 文件内容拷贝，恰含 ACCEPTED_HEAD 一行（41B）——比 `test -s` 更强的证据 |
| 四上游 SHA before/after | ✅ | `upstream-sha-before.txt` 与 `upstream-sha-after.txt` 逐字节一致（425B，diff IDENTICAL），且四行 SHA 与 implementation worktree 当前 `sha256sum` 实测值逐一相符 |
| default 固定摘要 | ✅ | `default.rc`=0、`default.stderr` 0B、`default.stdout` 37B，`cat -A` 确认逐字 `RESULT PASS  session snapshot safety\n`（单 `$`，恰 1 次） |
| offline 摘要恰一次且末行 PASS | ✅ | `offline.rc`=0、`offline.stderr` 0B；`offline.stdout` 中 `RESULT PASS  session snapshot safety` grep 计数=1，末行逐字 `RESULT PASS  aosp-harness offline quality gate` |
| after SHA / diff / status clean | ✅ | after 清单与 before 一致；`clean.txt` 0B；HEAD 测试后不变（head-after 相同） |
| evidence package 三列 schema | ✅ | TSV 22 行均为 `path<TAB>sha256<TAB>bytes`；全部 22 项的 sha256 与 bytes 实测全量核对通过；磁盘上 task-2.3 evidence 文件集合与 TSV 条目精确一致（除 TSV 自身），无漏列无多列 |
| checkout 已删除 | ✅ | `tmpdir.txt` 记录 `/tmp/task-2.3-depth1.uXeSad`，实测 `test -e` 不存在，无 `/tmp/task-2.3-depth1.*` 残留 |

补充只读核对：implementation worktree 当前 HEAD 逐字等于 ACCEPTED_HEAD、`git status --porcelain` 0 行，与 red.txt assertion 中声称的前置一致。

## ② 质量

- **范围纪律**: 实现者只做步骤 1–4 的实现者部分；未追加 manifest 行、未 mark/ledger/sync（正确留给控制器），未创建 commit、未触碰 implementation worktree 与源码。除步骤 1 自带的 HEAD+clean 前置核对（与 task-2.2 同型，合理）外无简报外动作。
- **验证真实性**: clone stderr 证明真实 `git clone --depth 1 file://...` 发生；depth-1 三项结构证据（HEAD / count=1 / shallow 内容）均有独立落盘日志；摘要按字节核对（37B 精确）而非模糊匹配；offline 用 grep 计数与末行断言双重核对。验证是真的在验。
- **错误路径**: 红阶段 rc1+双流空证据齐备；每步分离保存 rc/stdout/stderr，任何一步失败都会在日志中显形；本任务为只读验证，无生产错误路径需处理。

## Findings

### 阻断

无。

### 重要

无。

### 次要

1. `clean.txt`（0B）是 status 与 diff 的合并证据，无法从单一空文件区分 `git status --porcelain` 与 `git diff --stat` 是否都实际执行；结论可信度由 head-after 不变、四上游 SHA 不变和 offline 全绿旁证支撑，不影响 PASS，后续任务可考虑分文件落盘。
