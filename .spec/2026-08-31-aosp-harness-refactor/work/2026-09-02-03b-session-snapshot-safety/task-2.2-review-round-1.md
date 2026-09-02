# 任务 2.2 独立 Review（round 1）

- 审查对象：spec 2026-09-02-03b-session-snapshot-safety 任务 2.2「验证完整历史checkout」（需求 R8，步骤 1–4 实现者部分）
- ACCEPTED_HEAD: `ab1e870ece16bbc24e1a86f84110366f84aae0d9`
- 审查输入：task-2.2-brief.md、task-2.2-report.md、evidence/task-2.2-evidence.tsv（21 项）及全部日志；implementation worktree 只读核对
- 本 review 未重跑实现者已有日志证据的验证，仅做日志核对、sha256/bytes 全量校验与 worktree 只读状态核对

## 结论

**PASS** —— 阻断 0 / 重要 0 / 次要 3

## ① 规格符合性（逐项）

| 要求 | 判定 | 依据 |
|---|---|---|
| 红证据六行 schema + assertion | ✅ | `evidence/task-2.2-red.txt` 恰为 `task=/command=/expected=/rc=/stdout_sha256=/stderr_sha256=` 六行加 `assertion=`；rc=1 与 `red.rc` 一致，双流 sha256 均为空文件哈希（e3b0c44…），与 `red.stdout/stderr`（各 0B）一致 |
| 前置：implementation HEAD=ACCEPTED_HEAD 且 clean | ✅ | 只读核对 worktree：`git rev-parse HEAD` = `ab1e870ece16bbc24e1a86f84110366f84aae0d9`，`git status --porcelain` 0 行 |
| `git clone --no-local` 且 full HEAD 逐字等于 ACCEPTED_HEAD | ✅ | `clone.rc`=0；`clone.stderr` 恰为 `Cloning into '/tmp/task-2.2-full.8rHgr8/full'...\n`（无 `done.`）。reviewer 在本机同版本 git 上做对照实验：默认本地 clone 的 stderr 带 `done.` 行，`--no-local` 恰为无 `done.` 的单行形态，与证据逐字吻合——命令照抄有日志支撑。`full-head.txt` = ACCEPTED_HEAD（40 位逐字） |
| 四上游 SHA before/after 一致 | ✅ | `upstream-sha-before.txt` 与 `upstream-sha-after.txt` `cmp` 一致（TSV 中两者 sha256 相同）；且四行哈希与 implementation worktree 当前实际文件 `sha256sum` 逐行一致，非编造 |
| default 固定摘要一次 | ✅ | `default.rc`=0、`default.stderr` 0B、`default.stdout` 恰 37 bytes，`od -c` 逐字节为 `RESULT PASS  session snapshot safety\n`（PASS 后两空格） |
| offline 日志 snapshot 摘要恰一次且末行 offline PASS | ✅ | `offline.rc`=0、`offline.stderr` 0B；`grep -c 'RESULT PASS  session snapshot safety' offline.stdout` = 1；末行逐字 `RESULT PASS  aosp-harness offline quality gate` |
| after SHA / diff / status clean | ✅ | after 清单 cmp 一致；`clean.txt` 0B（status/diff 合并输出）；`full-head-after.txt` = ACCEPTED_HEAD，测试后 HEAD 不变 |
| evidence package 三列 schema（path/sha256/bytes） | ✅ | TSV 21 行均为三列；reviewer 对全部 21 项实算 sha256 与字节数，全部一致；覆盖 brief、report、red 文件与 logs/ 下全部 19 个日志文件（目录无遗漏文件） |
| full checkout 已删除 | ✅ | `tmpdir.txt` 记录 `/tmp/task-2.2-full.8rHgr8`；reviewer 实测该路径不存在，`ls /tmp` 无任何 task-2.2 残留 |

无缺项、无 ⚠️。

## ② 质量

- 越界行为：无。报告范围严格限于步骤 1–4 实现者部分；未创建 commit、未改 implementation HEAD（HEAD 与 clean 由 reviewer 独立核实）；步骤 4 的 manifest 行与步骤 5 明确留给控制器，符合简报分工。
- 验证是否真在验：是。default stdout 按字节落盘（37B 精确摘要，非 command substitution 吞 LF）；offline 摘要计数与末行均落到日志可复核；四上游 SHA 不仅前后 cmp，且其值与真实文件一致；rc 文件分离保存且非空。无空断言、恒真断言或只跑不验。
- 错误路径：红阶段（报告缺席 rc1、双流空）按 schema 记录；每次运行的 stderr 单独落盘并全为 0B，失败信号不会被吞。
- 可复现性：日志含 tmpdir 路径、clone 目标、前后 HEAD 与 SHA 清单，链条完整可回溯。

## Findings

### 阻断（0）

无。

### 重要（0）

无。

### 次要（3）

1. 步骤 2/3 各命令的命令行文本未落日志（只有 rc/stdout/stderr），`--no-local` 仅靠 stderr 形态（无 `done.` 行）间接证明；若未来 git 版本改变 stderr 形态将不可回溯。建议后续 2.3/2.4 等同类任务把执行命令文本一并落日志。
2. `clean.txt` 是 `git status --porcelain` 与 `git diff --stat` 的合并输出（0B），无法从证据区分两者各自为空；分开落两个文件更严谨。
3. 删除 full checkout 无显式事后断言日志（如删除后 `test ! -e` 的记录）；本次由 reviewer 直接核实 `/tmp/task-2.2-full.8rHgr8` 不存在，结果成立，但证据链上删除动作本身不可回溯。

以上三条均不影响本次验收结论。

## 核对方法记录

- TSV 全量校验：对 21 行逐行实算 `sha256sum` 与 `stat -c%s`，21/21 一致。
- worktree 只读核对：`git rev-parse HEAD`、`git status --porcelain`、四上游文件 `sha256sum`、`git log -3`。
- 日志内容核对：`od -c` 逐字节核 default.stdout；`grep -c`/`tail -1` 核 offline.stdout；`cmp` 核 before/after。
- clone 形态实验：在临时目录构造小仓库，分别用默认与 `--no-local` clone，比较 stderr 形态后删除临时目录（未触碰 implementation worktree）。
