# 任务 2.6 Review Round 1: 收敛manifest、ledger与终交付（实现者部分，步骤 1–2）

审查对象: `task-2.6-report.md`（green）、`acceptance/acceptance-report.md`、`evidence/task-2.6-red.txt`、`evidence/task-2.6-evidence.tsv`。无源码 diff，只审汇总报告是否真实反映前序任务证据。全部核对为只读，未重跑任何前序验证命令。

## 结论

**NEEDS_CHANGES** — 阻断 0 / 重要 1 / 次要 2

汇总主体真实：抽查的 9 条承重声称中 8 条在源任务报告或日志中找到逐字出处，evidence package 哈希全部实测一致，worktree HEAD/clean 实测属实。唯一实质性问题是验收报告把 `rg -i fallback` 零匹配声称三处独立核验，其中 task-2.1 这一处无出处（报告与日志均无该检查）。修正该引用即可转 PASS。

## ① 规格符合性

### 步骤 1（红证据）

| 项 | 判定 | 依据 |
|---|---|---|
| 红命令为 acceptance 报告缺席（`test -s acceptance/acceptance-report.md`） | ✅ | `evidence/task-2.6-red.txt` 第 2 行逐字为该命令，`red.rc` 文件内容 `1`，与简报步骤 1 一致 |
| 六行 schema（task/command/expected/rc/stdout_sha256/stderr_sha256）+ assertion | ✅ | red 文件恰为六行 + 末行 assertion；stdout/stderr sha256 均为空流 e3b0c4...，与 `red.stdout`/`red.stderr` 0B 日志一致 |
| 前置：HEAD=ACCEPTED_HEAD 且 clean | ✅ | `impl-head.txt` = `ab1e870ece16bbc24e1a86f84110366f84aae0d9`、`impl-clean.txt` 0B；本 reviewer 在 worktree 实测 `git rev-parse HEAD` 逐字相同、`git status --porcelain` 0 行 |

### 步骤 2（green 报告 / acceptance 报告 / evidence package）

| 项 | 判定 | 依据 |
|---|---|---|
| green 报告六节（task/base/head/files/commands/results） | ✅ | `task-2.6-report.md` 六节齐全，内容与本任务实际范围（步骤 1–2）一致，未越权声称步骤 3–6 |
| acceptance 报告： accepted HEAD | ✅ | `ab1e870...` 与 manifest 行 2 head、行 3–7 base/head、worktree 实测 HEAD 一致 |
| acceptance 报告： execution BASE | ✅ | `3d15a0d76c2a2e6c8541c5d47001a55f0ca18649` 与 `execution-base.env` 的 BASE_SHA 逐字一致 |
| acceptance 报告： exact2 208+192=400 | ✅ | task-1.1（208 行、numstat 208 0）、task-1.2（192 行、208+192=400）、task-2.1（numstat 400<=400）三处报告一致；`task-2.1-logs/step3/diff-numstat.txt` 实测为 `208 0` / `192 0` 两行 |
| acceptance 报告： 八 anchor 各精确一次 | ✅ | task-1.1（grep -c 表）、task-1.2（rg -c）、task-2.1（步骤 3）三处一致；`task-2.1-logs/step3/anchors.txt` 实测八行全为 1 |
| acceptance 报告： active 摘要（default/all rc0 逐字摘要、offline 恰一次） | ✅ | task-2.1 results 表逐字支持；`task-2.1-logs/step2/offline.stdout` 实测 `grep -c 'RESULT PASS  session snapshot safety'` = 1；task-1.2 提交前后 offline 亦恰 1 次 |
| acceptance 报告： signal 协议 | ⚠️ | 机制描述（handler 先于 temp 安装、first_signal 锁存、ownership 转移、cleanup 不遮蔽 129/130/143）出处为 design 文本，报告已明确标注引 design 且划定 03b1 边界；测试实证部分（真实 Python PID/TEMP barrier/首信号锁存 case PASS）有 task-1.2 步骤 4 出处；「重复 3 次 rc0 且摘要逐字节相同」经 `task-1.2-logs/step4/repeat-{1,2,3}.stdout` md5 实测逐字节一致。措辞见次要 finding 2 |
| acceptance 报告： 五个验证任务证据 | ✅ | 逐节与 task-2.1/2.2/2.3/2.4/2.5 报告比对一致；rollback commit `6c90230d...` 与 exact 两个 D 有 `task-2.4-logs/name-status.txt`（恰两行 D）佐证；depth-1 count=1 有 `depth1-count.txt` 佐证 |
| acceptance 报告： manifest 7 行全 PASS | ✅ | 本 reviewer 实测 `review-manifest.tsv` 恰 7 行、六列、seq 1–7、首行 base=BASE_SHA、行 2 head=ACCEPTED_HEAD、行 3–7 base=head=ACCEPTED_HEAD、reviewer 非空（opus/kimi）、第 6 列全 PASS；与 `task-2.6-logs/manifest-rows.txt` 快照逐字一致 |
| acceptance 报告： R1–R9 映射 | ✅（附次要 finding 1） | 九行映射的出处文件均存在且方向一致；R2/R3/R5 行的具体 rc 细节超出 task-1.2 报告字面粒度，见次要 finding 1 |
| acceptance 报告： 顺序门 rg 零匹配 | ✅ | task-2.5 报告 results 表逐项支持；`task-2.5-logs/03b1-rg.rc`、`03c-rg.rc` 实测均为 1（零匹配） |
| evidence package 三列 schema（path/sha256/bytes） | ✅ | 10 行 TSV 三列；本 reviewer 逐行重算 sha256 与字节数，全部一致；覆盖 brief、green 报告、验收报告、red 文件与全部 5 个新日志 |

### 承重声称抽查记录（9 条）

1. exact2=400 → 三处报告 + numstat 日志 ✓
2. offline 摘要恰一次 → task-2.1 报告 + offline.stdout 实测 grep=1 ✓
3. rollback 两个 D → task-2.4 报告 + name-status.txt 实测恰两行 D ✓
4. 顺序门 rg 零匹配 → task-2.5 报告 + rg rc 文件实测 ✓
5. 八 anchor → 三处报告 + anchors.txt 实测 ✓
6. depth-1 count=1/shallow 非空 → task-2.3 报告 + depth1-count.txt ✓
7. BASE_SHA → execution-base.env 实测 ✓
8. worktree HEAD=ACCEPTED_HEAD 且 clean → 本 reviewer 实测 ✓
9. 测试矩阵重复 3 次逐字节相同非 flaky → repeat-{1,2,3}.stdout md5 实测一致 ✓

**发现 1 条部分无出处声称**（验收报告第 14 行）：「`rg -i fallback` 对两文件零匹配（task-1.1、task-1.2 步骤 4、task-2.1 步骤 3 三次独立核验一致）」——task-2.1 报告全文无 `fallback` 提及（本 reviewer 以大小写不敏感搜索确认），`task-2.1-logs/step3/` 也无对应日志文件；task-1.1 实际做的是 `os.rename/replace/link/shutil` 模式核对而非字面 `rg -i fallback`。字面 `rg -i fallback` 零匹配只有 task-1.2 步骤 4 一处出处。「三次独立核验」对该特定检查不成立。底层事实（无 fallback）仍由 task-1.1 的模式核对与 task-1.2 的 rg 双重支持，故不定为编造事实，定为引用失真。

## ② 质量

- **超出简报要求的事**: 未发现。`evidence/task-2.6-logs/`（红命令日志、HEAD/clean 前置、manifest 快照）属证据留底的合理范围，与前序任务做法一致；未追加 manifest 第 8 行、未跑 awk 核验、未触碰 mark/ledger，步骤 3–6 正确留给控制器。
- **「应该是」写成「证据是」**: signal 协议段落总体处理得当——机制描述明确标注引 design 且声明「完整 provider-copy 动态信号矩阵属 03b1，本片只交付 anchor 与基础证明」，未把 03b1 的未做事项冒充本片证据。但段内把 design 机制句与测试实证句连排，个别句子（如「cleanup 错误不遮蔽已锁存信号码（129/130/143）」）在本片只有 design 出处、无测试实证，读起来接近交付证据（次要 finding 2）。
- **错误路径**: 本任务为只读汇总，适用错误路径有限；红命令、HEAD/clean 前置、manifest 快照留底均到位，green 报告如实声明「本任务不产生 commit，步骤 3–6 交控制器」。无未处理的错误路径。

## Findings

### 阻断（0）

无。

### 重要（1）

1. **验收报告 fallback 核验次数失真（acceptance/acceptance-report.md 第 14 行）**: 声称 `rg -i fallback` 零匹配经 task-1.1/task-1.2/task-2.1「三次独立核验一致」，但 task-2.1 报告与日志中不存在该检查（报告全文无 fallback 提及，step3 日志无对应文件），task-1.1 做的是 rename/replace/link/shutil 模式核对而非字面 `rg -i fallback`；该特定检查只有 task-1.2 步骤 4 一处出处。修复：把引用改为「task-1.2 步骤 4 的 `rg -i fallback` 零匹配 + task-1.1 的 fallback 路径模式核对」两处，删去 task-2.1 这一无出处引用。

### 次要（2）

1. **R2/R3/R5 映射行引用粒度超出源报告字面（acceptance-report.md R1–R9 表）**: 「同值重写 0、异值重写 3、并行异值恰一 0 余 3」「leaf 缺席 3」「arity/非法 feature/path rc 表与 held capture 结构 case」等具体断言归于 `task-1.2-report.md`，但该报告只泛称这些 case 类别编译在单次测试运行内并 PASS，未逐字列举各 rc 值；实质有测试 blob 与 3 次重复 PASS 支撑，建议措辞弱化为「编译在测试内的 … case 全 PASS」或改引测试 blob 行号。
2. **signal 协议段落机制句与实证句混排（acceptance-report.md 第 15 行）**: 「cleanup 错误不遮蔽已锁存信号码（129/130/143）」「close 前转移 fd ownership」等在本片仅有 design 出处，基础测试只实证真实 Python PID 与首信号锁存；虽已注明 03b1 边界，建议在机制句后显式标注「（design 契约，本片基础测试覆盖 PID 与首信号锁存子集）」，避免把设计意图读成交付证据。

## 复核建议

仅需修正重要 finding 1 的引用（顺带处理两条次要更佳）；acceptance 报告为纯文本资产，修正不涉及任何验证重跑。修正后交全新 reviewer re-review。
