# design review: 2026-09-02-03b1-session-snapshot-assurance round 1

- 审查对象：`specs/2026-09-02-03b1-session-snapshot-assurance/design.md`
- 对照：同目录 requirements.md（R1–R10/判据/不变量）、03b design+requirements、PLAN.md 03b1 节与全局约束、DECISIONS.md（含「上游六文件」裁定）、main 的 `common/.harness/lib/session-state-snapshot.sh`、prototype `cbdbdde:.../prototype/snapshot-assurance-r1.sh` 及同目录 `round3-assurance-sizing-evidence.md`
- 审查人：独立 design reviewer（与起草者/控制器无关）

## 结论

**NEEDS_CHANGES** — 阻断 0 / 重要 1 / 次要 3

## 规格符合性（R1–R10 逐条）

- R1 ✅ CLI 四态、repo root 自解析、unknown/extra/flag 带值 rc1 无 PASS，组件与错误表、测试策略三处一致。
- R2 ✅ inert 三种调用同一零 case 固定摘要 rc0；fail-closed 七类触发条件（非普通文件/symlink/`bash -n`/source/三 export/anchor 次数/`renameat2` 次数）与 R2 逐字对应。
- R3 ✅ 注入前静态核对八 marker 各精确一次、`renameat2` 精确一次、无 `os.replace/link/rename` fallback；原 provider SHA-256 运行前后不变；副本与 state root 均在 `mktemp` 隔离目录。（措辞张力见次要 2。）
- R4 ✅ held capture 同名重建：canonical 发布、重建文件逐字节等于攻击者写入、temp=0；prototype 对应机制真实存在（`ASSURANCE_CAPTURE` 注入 CAPTURE_READY anchor）。
- R5 ✅ managed 三层×link/inode/missing×read/write=18 行 + snapshot leaf 6 行；link/inode rc2、missing rc1 与 provider 实际代码（`Unsafe`→2、`Failed`→1）逐条核对一致；delta oracle 覆盖 winner 完整指纹/victim/换入 identity 与 shape/temp。
- R6 ✅ wrong-owner 4 行 rc2（EUID 偏移注入真实存在于 prototype `managed_euid/snapshot_euid`）、short-read rc0 且 stdout hex 精确（prototype `min(1, 130-total)` 注入真实存在）、EIO 2 行 rc1（OS_ERROR anchor 注入真实存在，provider `except (OSError, Failed, AttributeError)`→1 核对一致）。
- R7 ✅ symbol/ENOSYS rc1 无 fallback；EEXIST same/different/unsafe/disappear rc 0/3/2/1；same/different 在 winner 首次 name-stat 前拒残留 temp 的注入点（`os.unlink(temp)` 与 `read_snapshot` 之间）在 prototype 真实存在；eexist-missing→`Failed`→1 与 provider 代码核对一致。
- R8 ⚠️ 三真实信号（barrier 后 `ps` 证实 Python PID、rc 129/130/143、第二信号不改码）与四 provider-copy 窗口（post-close、cleanup-close 五次 close、rename 未提交/已提交）机制均在 prototype 真实存在且与 provider `close_all` 五次遍历核对一致；但「rename 已提交窗口旧 temp 名只得到 `ENOENT`」没有任何机械 oracle（见重要 1）。
- R9 ✅ candidate/full/depth-1/offline、offline 发现恰好一次、depth-1 commit-count=1 与 shallow marker、上游六文件 SHA-256、固定版本逐字验证后 exact 单文件 shfmt/ShellCheck/`bash -n`、exact1/numstat≤400、六列 manifest、`git diff --check`/clean 全部覆盖且与判据逐字对齐；六文件清单与 DECISIONS.md 2026-09-02「03b1 上游集合裁定」逐字一致。
- R10 ✅ 隔离 rollback commit exact 只删本入口、clean checkout 03b 基础测试+offline 全绿、发现 0 次；03c 四类资产以 `test ! -e`/`git show-ref --verify --quiet` 反值/`git worktree list --porcelain`/`rg` 机械查缺席；inert PASS 不解除门。

## 文档质量

- 结构：概述/需求映射/架构/组件与接口/数据模型（不适用且带理由）/数据流/错误处理/测试策略/文件清单九节齐全。
- 需求映射表 10/10，无遗漏。
- 组件「对外接口/消费接口」与 requirements frontmatter 的产出/消费**逐字一致**（已 diff 级比对）。
- 四张 mermaid（1 graph TB + 3 sequenceDiagram）语法逐张检查可渲染：`-.text.->`、`<br/>`、`alt/else/end`、participant 别名均合法。
- 无占位符/TODO/TBD。
- 错误处理表覆盖 requirements 全部错误类：CLI、inert、fail-closed 七类、注入失败、EIO、ENOENT 窗口、EEXIST 四态、symbol/ENOSYS、信号锁存、rename 已提交、wrong-owner、short-read、case 聚合；rc 语义与 provider 源码逐条核对一致。
- 测试策略与判据主验证命令（`bash ./tests/test-session-snapshot-assurance.sh`）、`bash ./scripts/check.sh --offline`、`shfmt -d -i 2 -ci -bn`、`shellcheck -x --severity=warning`、`bash -n`、shfmt `v3.14.0`/ShellCheck `0.11.0` 逐字对齐。
- 文件清单 exact1 + 验收资产字段齐全。
- sizing 可信：prototype 实测 308 行（`wc -l` 复核相符）；「240 项断言」独立按用例矩阵复算（10+5+12+108+36+5+4+4+28+13+15=240）精确相符；抽查的四处承重声称（`ASSURANCE_*` 注入、EEXIST temp 清理时序、wrong-owner EUID 偏移、五次 close）全部真实存在；剩余 92 行装 CLI/inert/fail-closed/摘要计数/结构注释余量合理。
- 专项核：main 的 provider 实际 export 恰好为 `_harness_session_snapshot_worker`/`_harness_session_snapshot_write_core`/`_harness_session_snapshot_read_core` 三个，八个 anchor 名与 design 列表逐字一致、各出现精确一次、`renameat2` 字符串精确一次、无 rename/link/replace fallback。
- 与 PLAN v5.7 03b1 节、全局 400 行/exact 门、DECISIONS.md（含上游六文件口径）无冲突。

## Findings

### 阻断

无。

### 重要

1. **R8「旧 temp 名只得到 `ENOENT`」无机械 oracle**：design 在组件与错误表中两处声称 rename 已提交窗口「旧 temp 名只得到 `ENOENT`」，但未给出任何验证机制；prototype（design 自称注入集与之「一一对应」）对该行只核 rc143、winner shape、temp=0——由于此时 `first_signal` 已锁存，provider 的 `finally` unlink 即使抛出非 `FileNotFoundError` 也会被同样吞掉且 rc 不变，测试在现有注入集下无法区分 ENOENT 与其他 errno。要么在 design 中补一个 exact-once 注入的 unlink errno 记录点（与 `ASSURANCE_CLEANUP_LOG` 同手法），要么把该声称收窄到可观测面（锁存 rc + winner 完整指纹 + temp=0 + 不回滚），避免执行期对一个无法证明的声称扯皮或假绿。

### 次要

1. **92 行预算两处口径不一致**：概述第三条说剩余约 92 行「只用于 inert 分流、CLI 解析、固定摘要与计数、controller 面向的结构注释」，漏列 fail-closed 七类检查；测试策略 sizing 段则写「inert/fail-closed 分流、CLI 解析、固定摘要与 failures/checks 计数、repo root 解析……」。以测试策略为准修订概述一句即可。
2. **「八 anchor 注入」与实际注入集的措辞张力**：概述/架构称「在八个无副作用 anchor 注入攻击」，但组件的注入机制（与 prototype 一一对应）另含六处非 anchor 的 exact-once 文本点（short-read 的 `os.read` chunk、cleanup-close 故障、post-close 信号、latch 后第二信号、caught 文件、EEXIST temp 存活检查）——这些恰是 R6/R8 强制要求的，并不违规，但建议在组件节一句话澄清「注入点 = 八 anchor + 少量 exact-once 文本点」，免得被读成与 R3「在八个 anchor 处注入」冲突。
3. **sizing 证据引用路径含糊**：文件清单写「同目录 `round3-assurance-sizing-evidence.md`」，该文件在 prototype commit `cbdbdde` 树的 `work/2026-09-02-03b-session-snapshot-safety/prototype/` 下（不在 main、也不在本规格目录），且其正文记录的是较早的 293 行/236 断言状态，最终 308/240 由 `cbdbdde` 提交本身承载。建议写全 commit:path 并注明以 cbdbdde 实测为准。
