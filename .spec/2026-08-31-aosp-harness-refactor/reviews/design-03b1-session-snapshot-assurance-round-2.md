# design review: 2026-09-02-03b1-session-snapshot-assurance round 2（范围受限 re-review）

- 审查对象：`specs/2026-09-02-03b1-session-snapshot-assurance/design.md`（fix round 1 后稿）
- 范围：round 1（NEEDS_CHANGES，重要 1 / 次要 3）的四项是否闭合、修复是否引入新问题、R8 ⚠️ 可否转 ✅
- 对照：同目录 requirements.md、03b design、prototype `cbdbdde:.../prototype/snapshot-assurance-r1.sh`、main 的 `common/.harness/lib/session-state-snapshot.sh`
- 审查人：独立 design reviewer（与起草者/控制器/round 1 reviewer 无关）

## 结论

**PASS** — 阻断 0 / 重要 0 / 次要 0

## 1. 重要 1（R8 ENOENT 无机械 oracle）是否闭合：已闭合

- design 在「child signal 窗口矩阵」组件节新增专段（design.md:90）：新增 exact-once 非 anchor 文本注入点，逐字替换 finally 中 owned temp 的 unlink 调用点；设 `ASSURANCE_UNLINK_LOG` 时副本把该次 unlink 结果（`success` 或具体 errno 名）追加到日志文件；替换要求原文精确一次、否则注入自身 rc1；rename 已提交窗口行核对日志唯一一行恰为 `ENOENT`，非 ENOENT 或意外 success 均使该行 FAIL 而非被 finally 静默吞掉。
- 可行性实证：main provider 的 finally unlink 点为 `                try: os.unlink(temp, dir_fd=dir_fd)`（session-state-snapshot.sh:148），与 EEXIST 分支的 `os.unlink(temp, dir_fd=dir_fd); temp = None`（:137）文本可区分，`count == 1` 逐字替换成立；该点正是 round 1 指出的盲区（first_signal 锁存后非 FileNotFoundError 被吞、rc 不变）。
- 与 prototype 同构性：cleanup-close 注入（prototype :66-74）同为「env 门控 + 包裹 os 调用 + 追加 `ASSURANCE_*_LOG` 日志 + 行数/内容 oracle（:282 `wc -l` 核 5 次）」；unlink errno 记录点手法完全一致（env 门控、日志文件、唯一一行内容核对），同构成立。
- 与 R8 兼容性：未收窄——「旧 temp 名只得到 `ENOENT`」声称原样保留（组件节、错误表、数据流图三处），只是补上了机械 oracle；无降级为可观测面子集。
- 预算：注入替换 + 一行 oracle 核对合计约 8 行，明确计入剩余约 92 行整合预算（概述第三条 design.md:9、测试策略 sizing 段 design.md:202）；308+8≈316，exact1 与 numstat ≤400 承诺原文保留，仍成立。
- 错误表（design.md:186）与 child signal sequenceDiagram（design.md:168 `T->>T: 已提交窗口另核unlink日志唯一一行恰为ENOENT`）同步更新，三处口径一致。

## 2. 三条次要是否修复：均已修复

1. **92 行预算口径**：概述第三条（design.md:9）已补列「fail-closed 七类检查」，与测试策略 sizing 段（含「fail-closed 七类检查的逐类 fixture」）口径一致。
2. **两层注入措辞**：概述第一条（design.md:7）明确「注入集不止八个 marker anchor：R3 的静态核对只针对八 marker 与 `renameat2`，而动态矩阵还在 short-read chunk、cleanup-close、post-close 信号、latch-second、caught barrier、unlink errno 记录等 exact-once 非 anchor 文本点做逐字替换，这些点不进入 R3 的 marker 计数」；架构节（design.md:41）以「注入替换分两层」重述同一划分。虽未出现「与 R3 无冲突」字样的独立声明句，但 R3 的适用范围（静态 marker 核对）与非 anchor 点的定位已被界定清楚，且 R6/R8 本就强制这些点，澄清充分，张力消除。
3. **sizing 证据路径**：测试策略（design.md:202）与文件清单（design.md:210）均写全 `cbdbdde0e1e3ff4ceb2dc0279b1db83127a0ea9e:.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/prototype/round3-assurance-sizing-evidence.md`，并注明 293 行/236 项为修复旧 close 顺序 mutant 之前的早期测量、现行口径以 308/400 行 240 项为准。

## 3. 是否引入新问题：未发现

- 与 requirements 一致性：R8 声称逐字保留（requirements.md:33 对照 design.md:89-90、168、186）；R3 静态核对范围未被新注入点稀释（不计入 marker 计数已显式声明）；R9 的 exact1/≤400、frontmatter 产出/消费接口、需求映射表、验收资产清单均无变动。
- 与 03b 契约一致性：03b design :67/:86/:170/:191 的「rename 线性化点已提交则旧 temp 名 ENOENT 且 winner 绝不回滚」与 03b1 新 oracle 方向相同，无冲突。
- mermaid：四张图复查，新增的一行 `T->>T:` 为合法 sequenceDiagram 自消息，其余图未动，均可渲染。
- 注入机制一致性：`inject_copy` 的「每处替换要求原文出现且仅出现一次，否则注入自身失败 rc1」契约（design.md:69）覆盖新注入点，错误表注入失败行语义不变。

## 4. R8 裁决

⚠️ → **✅**：三真实信号与四 provider-copy 窗口机制维持 round 1 的实证结论，唯一缺口（rename 已提交窗口 ENOENT 无机械 oracle）已由 `ASSURANCE_UNLINK_LOG` 注入点闭合，机制可行、与 prototype 同构、未收窄承诺、预算内。
