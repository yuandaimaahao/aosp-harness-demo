# Task 1.2 独立 diff Review（Round 1）

- 审查对象：spec `2026-09-02-03b-session-snapshot-safety` 任务 1.2「机械落地默认基础测试」
- diff 范围：`192fa1e133c50625ac5a6d1ce14f9a5df8502f72..ab1e870ece16bbc24e1a86f84110366f84aae0d9`（恰好 1 个 commit，只新增 `tests/test-session-snapshot.sh`，192 行，mode 100755）
- 审查输入：task-1.2-brief.md、task-1.2-report.md、review-192fa1e1-ab1e870e.md、evidence/task-1.2-evidence.tsv、实现 worktree（只读）

## 结论

**PASS** — 阻断 0 / 重要 0 / 次要 3

任务 1.2 的核心约束（步骤 2「唯一转换」）经独立机械验证成立：prototype blob 经规定 sed 替换后与交付文件 `cmp` 逐字节一致，仅第 13 行 `core=` 赋值一处差异；192 行数、sha256、numstat/exact2/400 门、红绿证据均与报告和 evidence TSV 吻合。测试内容本身为 spec 固定的 prototype blob 逐字落地，断言真实有效，无 YAGNI，无空转验证。

## 机械验证记录（本 reviewer 独立重跑）

在实现 worktree（HEAD=`ab1e870e`，`git status` clean）执行：

1. `git log 192fa1e1..ab1e870e` → 恰好 1 个 commit `ab1e870 test(session): add snapshot safety matrix`。
2. `git show a708ce6f:$PROTO_TEST` → 192 行；经规定 sed 替换生成 expected；`diff proto expected` 仅第 13 行 `core=${SNAPSHOT_CORE:-$here/snapshot-core-prototype.sh}` → `core=${SNAPSHOT_CORE:-$repo/common/.harness/lib/session-state-snapshot.sh}` 一处差异；`cmp expected tests/test-session-snapshot.sh` 逐字节一致（步骤 2「唯一转换」约束 ✅）。临时文件已删除。
3. `sha256sum tests/test-session-snapshot.sh` = `725358357555df4c...`，与报告及 TSV 中 `expected-target.sh` 一致；`proto-test-blob.sh` 日志 sha 与 `git show` 重取 blob 逐字节一致。
4. evidence TSV 抽查 6 项（brief/report/red/review 包/proto-blob/expected-target）sha256 全部匹配；rc 日志内容核对：`argv-none.rc`=`0`、`argv-unknown.rc`=`1`；`postcommit-offline.stdout` 中 `RESULT PASS  session snapshot safety` 恰好 1 次、末行为 offline PASS。
5. `git diff --numstat BASE_SHA(3d15a0d7)..ab1e870e` = 208+192=400，name-only exact 两文件；`git diff --check 192fa1e1 ab1e870e` 通过。

## ① 规格符合性（逐 R）

注：简报中并不存在字面的「## R→E 映射」节；最接近的是 design 的「## 需求映射」表（brief 第 88–97 行），据此映射逐条核对。本任务对 R1–R7 的责任是「默认基础测试」层，完整动态矩阵按 spec 属 03b1。

- **R1 ✅**（E: diff 第 10–19 行 + step3 日志）：四态 source（none/validate/path/both）在隔离 subshell 逐字比较两个依赖函数体、`declare -F` inventory（剔除三个合法新增 export）、`export -p`、provider marker 缺席、source rc=0、双流空；三个 snapshot export 仅在 both 态出现；四个 public API 恒缺席。provider-absent 隔离仓 default/flag/all 三者 stdout 逐字节相同（iso-absent-* 日志 + `cmp` 声称，sha 链一致）。
- **R2 ✅**（E: diff 第 69–78、181–185、208–214 行）：worker/core arity（`nope`/缺 feature/多 extra/缺 session）→2；非法 feature `'../bad'`→2；path core rc1/2 原样透传；held capture 结构经 CAPTURE_READY 探针断言「名字已缺席 + /proc fd 为 0600:nlink0」；`check_rc` 强制失败双流空、write_core 任何结果 stdout 空；`path_from_fd` exact-once 断言对应「不得按 pathname reopen」。
- **R3 ✅**（E: diff 第 88–92、141–152 行）：leaf 缺席 read→3 且不建 leaf；成功 read 以 `od` hex 逐字节证明 `alpha\n`（唯一 LF）；九类损坏内容表（空文件、129-byte+LF、非 ASCII、无 LF、多 LF、LF 后额外字节、`.bad\n`、`a b\n`、`a/b\n`）逐项 read/write 均→2 且 tree/victim/temp 不变。
- **R4 ✅（基础范围）**（E: diff 第 87、123–140、195–206 行）：攻击/信号后 `temp_count==0` 与 session 目录空证明 owned-temp cleanup；TEMP barrier 后 `ps` 见同 PID 已为 `python3`、首 TERM 锁存 143、barrier 窗口内第二 HUP 不改结果、无 winner 无 temp 残留。rename 已提交窗口、post-close 等完整信号分支按 spec 属 03b1，不在本任务。
- **R5 ✅**（E: diff 第 99–122 行）：6 并行同值 writers 全 0 且 winner=same；幂等重写前后完整 `tree_state`（含 dev/inode/mode/nlink/size/hash）不变；6 并行异值恰 `1×0 + 5×3`、winner∈请求集、session 目录恰好 1 条目；第二波 loser 前后 winner 指纹与内容不变。
- **R6 ✅**（E: diff 第 123–193 行）：snapshot symlink/hardlink/directory/wrong-mode/content 五类 + managed 三层×symlink/file/wrong-mode/missing(→1) 静态表全部 fail closed 且不触 victim、无 temp；managed 后缀不匹配→2；八 anchor 对 core 文本各 exact-once。wrong-owner、short-read、动态 swap 按 R6 原文属 03b1 anchor 反证，非本任务缺口。
- **R7 ✅**（E: diff 第 3–8、16、18–19 行 + step3 argv 全表日志）：无参数/`all`/`--dependency-absent` 三分支，unknown/extra/flag 带值/双 flag/空参数+all 均 rc1 无 PASS；成功摘要逐字 `RESULT PASS  session snapshot safety\n`（日志 stdout 37 bytes、sha 一致）；inert 分流（flag 或真实 provider 缺席）落在同一 surface 检查后 exec 固定摘要。

## ② 质量

- **YAGNI**：无。diff 与 prototype blob 仅一处规定替换，不存在简报之外的任何新增内容（机械证明，见上）。
- **验证是否真在验**：是。断言非空、非恒真：并发结果按字节串精确比较（`'      6 0'`、`1×0/5×3`）、read 成功用 hex 逐字节、winner 指纹用 `find -printf`+`sha256sum` 全树比较、失败用 rc+双流同时约束；self-disproof 日志（broken-source-rc / broken-stdout 均 rc1 无 PASS）独立证明测试能检出 R1 违约，非空转。
- **逐字复制的逻辑块**：无。`attack`/`content_attack`/`managed_attack` 尾部三行断言相似但参数化合理，属可接受的局部重复，非整块复制。
- **错误路径**：argv 拒绝在 `mktemp -d` 之前（零 state 副作用）；`trap rm -rf $tmp EXIT`；`managed_attack` 末尾 `eval "$real_path"` 恢复真 path core 且无 `set -e` 提前中断风险；probe_core 生成用 Python `assert count==1` 防止替换漂移。

## Findings

### 阻断

无。

### 重要

无。

### 次要

1. **【次要｜过程偏差】** 简报步骤 2 写明「用 apply_patch 创建目标 test」，实现者实际用 `sed` 生成 expected 后 `cp` 落地（report 步骤 2 自述）。结果经 `cmp` 与规定转换逐字节一致，无功能影响，仅记录偏差。
2. **【次要｜证据缺口】** report 声称的 shfmt/ShellCheck 版本逐字核对、两个 `bash -n`、misuse 零 state 计数（254）与「提交后上游 SHA 比对」在 evidence TSV 中无对应日志文件（仅有 before-commit SHA 清单，无 after 文件）。主交付物（sha256/cmp/numstat/离线日志）均可独立复核，不影响结论；建议后续任务把版本与 after-SHA 输出落盘。
3. **【次要｜设计注记】** PID/首信号验证针对注入探针的 `probe_core` 副本而非 pristine 生产文件；这是 prototype blob 的既定设计（R6 要求生产模块不读测试环境变量，barrier 只能存在于副本），属 spec 层决策而非本 diff 引入，仅在此标注其证据强度边界。
