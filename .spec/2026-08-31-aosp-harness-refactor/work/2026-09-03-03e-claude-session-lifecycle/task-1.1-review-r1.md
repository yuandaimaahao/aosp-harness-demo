# Review: task 1.1 (cc04996e..4ceca2bf) round 1

verdict: NEEDS_CHANGES
阻断: 2 / 重要: 1 / 次要: 4

## ① 规格符合性

- **R1（guard 三合取才消费 v1）… ✅** — 三个 hook 的 guard 逐字含 `source … session-state.sh 2>/dev/null`、`[[ "${HARNESS_SESSION_STATE_PROVIDER_VERSION:-}" == 1 ]]`、`declare -F` 五名单条核对，且是真合取。实测隔离验证：aggregator 缺席、missing-foundation/path/snapshot/signals/remove 五类、marker 篡改为 `2`、以及「marker=1 + 只有 4/5 API」的桩 aggregator，三 hook 一律 rc0 + compat 恰 1；把第 5 个 API 补齐后三 hook 立刻转 v1（compat=0）。第三个合取项不是摆设。
- **R2（任一 partial → legacy + marker 恰一次 + rc0，不形成 partial capability）… ❌** — 七类 fixture、非法 `source`、非法 `reason`、错事件名、malformed JSON、provider 设计外错误码（`HARNESS_STATE_ROOT` 指向 0755 目录触发 rc2）全部实测 rc0 + compat 计数恰 1，三 hook 文本内字面量各恰 1 处。但「`session_id` 非法」这一条不成立：含 TAB 或 LF 的 `session_id` 不落 legacy，反而被截断成合法前缀后按 v1 继续（见 B2），compat 计数为 0。
- **R3（SessionStart 按 source 分级建/读基线，五 source 永不覆盖）… ❌** — 正常路径全对：startup 建基线（`state/<64位小写hex>/<sid>/feature` == feature、`$TMPDIR` 无 legacy 快照）、重复调用幂等、基线在场时改 `CURRENT_FEATURE` 后 resume 不改写、compact 缺基线只 stderr 一行且不创建、`sync_feature_link` 与两条 stdout 文案逐字保留。但 B2 使 `{"session_id":"sess-evil\tcompact","source":"compact"}` 这一「compact + 基线缺席」输入**创建了基线**（`state/<pid>/sess-evil/feature`），直接违反「compact 缺失报错且不创建基线」。
- **R4（UPS 漂移 exit 2 阻止 prompt，缺席/一致静默 rc0）… ❌** — 主路径全对：无漂移 stdout 0 字节 rc0、基线缺席 rc0 静默、漂移 rc2 且两行告警与现状措辞逐字一致、不写 JSON。但 `session_id` 为 `"s1\n"`（非法）时被截断为 `s1`，读到**别的 session** 的基线并以 **exit 2 阻断了 prompt**，而 R2 要求这种输入落 legacy rc0（见 B2）。
- **R5（SessionEnd 校验后幂等清理 + settings.json 注册）… ❌** — 逻辑本身全对：五个合法 reason 均 rc0 静默清理、重复调用仍 rc0、事件名/session ID/reason 三类非法各自 compat 恰一次 + rc0 + 零删除（v1 状态与预置 legacy 快照均在场）、legacy 路径 compat 一次后幂等 `rm -f` 全局快照（缺席重复调用仍 rc0）；settings.json python3 json 解析通过、SessionEnd 指向 `${CLAUDE_PROJECT_DIR}/.claude/hooks/session-end.sh`、既有两事件未动。但 `session-end.sh` 以 **mode 100644 入库**，settings.json 是把它当 `command` 执行的，真实运行下必然 `Permission denied`（实测 rc126），注册在实机上是空的（见 B1）。
- **R6（legacy 段行为逐字不变，v1 不读写 legacy 全局文件）… ✅** — legacy surface 实测：SessionStart 覆盖写 `${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot` 内容 == feature、rc0；UPS 漂移仍是纯文本两行 + rc0 不阻断（与 v1 的 exit 2 形成对照）、无漂移静默；v1 路径下 `$TMPDIR` 始终无该文件、legacy 路径下 `$HARNESS_STATE_ROOT` 始终不存在。两处重定向空格改动经 `git diff -w` 核为纯空白、零行为变更（下详）。

## ② 质量

- **YAGNI**：干净。BASE..HEAD 恰为简报点名的四文件，无多余文件、无新公共 API、无 `.harness` 下其他文件改动、上游十二文件零变更（`git diff --name-only … -- $UPSTREAM12` 空）。逐文件 numstat 41/48/45/3，各自在 ≤42/≤52/≤52/≤6 内，合计 137 ≤152。
- **验证是不是真的在验**：红阶段证据是真红，不是事后补写。`git cat-file -e BASE:…/session-end.sh` 在 BASE 缺席、`BASE:settings.json` 中 `SessionEnd` 计数为 0，两条都可从 BASE 机械复现；证据里的 `stdout_sha256` 就是空串哈希 `e3b0c4…`，`stderr_sha256` 我用 `printf 'bash: claude-code/features/.harness/hooks/session-end.sh: No such file or directory\n' | sha256sum` 复算得 `b92823cb…`，与记录逐字节相同。报告的命令表也不是空断言。**但**本任务的结构自查存在一个系统性盲区：步骤 1 与步骤 5 都用 `bash <hook>` 调 hook，而实机与 `run-demo.sh:27` 都是直接执行（`.claude/hooks/load-feature.sh`），`scripts/check.sh` 的 core 阶段也只跑 `bash -n`——三道口子都绕开了可执行位，于是 B1 全程无人发现。这属于「只跑不验」的一种。
- **逻辑块逐字复制**：`check-branch-drift.sh:36-40` 的漂移判定 + 两行告警与 `:50-52` 的 legacy 段逐字重复；三 hook 各自的 5 行 guard 与 1 行 `compat_legacy` 三份重复。两者都是 design 明写的取舍（R6 要求 legacy 段逐字保留、R4 要求 v1 沿用同一措辞；exact 六文件约束使公共 guard 无处可放），不判缺陷，记 S3 备案。
- **错误路径**：整体处理得当——所有 provider rc 都以 `|| rc=$?` 显式捕获进分支表，v1 函数在 `if`/AND-OR 条件位调用以抑制 `set -e`，没有被 `set -e` 截断的隐式出口，任一语义路径 SessionStart/SessionEnd 都 rc0。三个缺口：write 的 rc3（异值冲突）被静默吞掉、design 明确要求的 stderr 报错缺失（I1）；`python3` 不可用被并进「输入非法」（S4）；「未找到 feature 上下文」早退路径丢掉了 stdin 排水（S1）。

## findings

### B1（阻断）`claude-code/features/.harness/hooks/session-end.sh`（整文件，git 索引 mode）

新增的 `session-end.sh` 以 **mode 100644** 提交（`git ls-files -s` 显示 `100644 7efafb6c…`），而同目录 `load-feature.sh` / `check-branch-drift.sh` 与 `codex/.codex/hooks/session-start.sh` 等所有「被调用」的 hook 一律 100755；100644 在本仓只用于纯 source 的 `feature-common.sh`。

为什么是缺陷：`settings.json` 把它注册成 `{"type":"command","command":"${CLAUDE_PROJECT_DIR}/.claude/hooks/session-end.sh"}`，Claude Code 以 shell 执行该 command，非可执行文件直接 `Permission denied`。实测 `./claude-code/features/.harness/hooks/session-end.sh </dev/null` 与 `sh -c './…/session-end.sh'` 均 rc126。也就是说 R5 要求的「settings.json 注册 SessionEnd 指向 session-end.sh」在实机上是一条永远失败的注册，SessionEnd 的幂等清理一次也不会发生。`claude-code/features/install-harness.sh` 全文无 `chmod`，软链不会补回权限位；`scripts/check.sh` 的 core 阶段只 `bash -n`，静态阶段只 shellcheck/shfmt，都不查执行位，所以 offline 全绿并不能证伪本条。

建议修法：`chmod 755 claude-code/features/.harness/hooks/session-end.sh` 后 `git update-index --chmod=+x …` 重新提交（mode 变更不计入 numstat，预算不受影响）；并在任务 1.3 的结构核对里补一条 `test -x` 断言，把这条盲区永久堵上。

### B2（阻断）`claude-code/features/.harness/hooks/load-feature.sh:36-38`（并及 `check-branch-drift.sh:27-29`）

```
print(sid + "\t" + src)
')" || return 1
  IFS=$'\t' read -r sid src <<<"$out"
```

python 侧只校验了 `isinstance(sid, str)`，没有校验 `sid` 的**形态**，却用 TAB 把两个字段打包成一行再交给 bash 拆分。于是含 TAB 或 LF 的 `session_id` 会被静默截断成第一个分隔符之前的前缀，而**送进 `harness_validate_feature_name` 的是这个截断后的前缀，不是 payload 里的真值**——R3 写的「`session_id` 须经 `harness_validate_feature_name` 安全单组件校验」在这里被绕过了。

实测（payload 由 `json.dumps` 生成写文件，排除 shell 转义歧义）：

| payload | 应有行为 | 实际 |
|---|---|---|
| `{"session_id":"sess-evil\tcompact","source":"compact"}`，基线缺席 | R2 落 legacy + compat 1；退一步按 R3 compact 也必须「报错且不创建基线」 | rc0、compat **0**、**创建了** `state/<pid>/sess-evil/feature`；`src` 被拆成 `compact<TAB>startup` 之外的残值，compact 分支被整个绕过 |
| `{"session_id":"sessnl\ninjected","source":"startup"}` | R2 落 legacy + compat 1 | rc0、compat **0**、创建了 `state/<pid>/sessnl/feature` |
| `check-branch-drift.sh` 收到 `{"session_id":"s1\n"}` | R2/R4 落 legacy rc0 | 截断成 `s1`，读到**别的 session** 的基线，**exit 2 阻断了 prompt** |

（`check-branch-drift.sh` 是 `print(sid)` + `$(...)` 吞尾随换行导致的同类截断；`session-end.sh:24` 因为在 python 里做了 `re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", sid)`，同样输入被正确拒绝——三个 hook 自己就不一致。）

为什么是缺陷：这是「非法输入不落 legacy、反而被改写成合法输入后按 v1 执行」，同时命中 R2（非法 session_id 必须落 legacy 且 marker 恰一次）、R3（compact 缺基线不得创建）与 R4（非法 session_id 不得走 v1、更不得 exit 2 阻断 prompt）。任务 1.3 的矩阵若只喂良性 session_id 也发现不了。

建议修法：把 `session-end.sh` 已有的 `re.fullmatch` 形态校验搬到另外两个 hook 的 python 段里（同一条规则、同一份 foundation 语义），非法即 `sys.exit(1)`；或把 `load-feature.sh` 的双字段输出改成 NUL 分隔并用 `IFS= read -r -d ''` 读取。两者都是 python 段内几行，不会撑破 ≤52/≤42 预算。

### I1（重要）`claude-code/features/.harness/hooks/load-feature.sh:46-47`

```
    harness_session_state_write "$project_id" "$sid" "$feature" >/dev/null 2>&1 || rc=$?
    [[ $rc == 0 || $rc == 3 ]] || return 1
```

design「`load-feature.sh` v1 SessionStart 流程」的 write rc 分支表写的是「rc3 → 异值冲突，**stderr 报错**、不改写（五 source 永不覆盖），继续 rc0」，简报「候选文件权威结构」也逐字复述了「rc3 异值冲突只报错不改写」。实现把 rc3 与 rc0 合并成一条静默成功路径，既无 stderr 也无任何可观测量。

为什么是缺陷：rc3 是 read 与 write 之间出现竞态、基线已被别人以**不同值**写入的唯一信号；吞掉它之后，「基线与本次 feature 不一致」这一真实错误对用户和对任务 1.3 的断言都完全不可见，与紧邻的 compact 分支（rc3 时明确 `echo … >&2`）自相矛盾。R3 的「发生错误时系统必须只保证不创建/注入状态**并报错**」在这条路径上没有落地。

建议修法：把 `[[ $rc == 0 || $rc == 3 ]] || return 1` 拆成 `if [[ $rc == 3 ]]; then echo "error: [load-feature] 会话基线已存在且值不同，未改写。" >&2; elif [[ $rc != 0 ]]; then return 1; fi`（+2 行，48→50，仍 ≤52）。

### S1（次要）`claude-code/features/.harness/hooks/load-feature.sh:20-23`

BASE 把 `cat >/dev/null 2>&1 || true` 放在第 9 行、即「未找到 feature 上下文」早退分支**之前**；HEAD 把排水移进了 `else` 分支（第 59 行），于是这条早退路径不再消费 stdin。

为什么是缺陷：design 说这条分支是「两路径共用现状逻辑，逐字保留」，而它的可观测行为变了。实测同一 fixture、300KB payload：BASE `writer_rc=0`，HEAD `writer_rc=141`（SIGPIPE）。真实 hook payload 通常小于管道缓冲，影响有限，故记次要。

建议修法：在 `if [[ -z "$target" ]]` 块内 `exit 0` 之前补一行 `cat >/dev/null 2>&1 || true`，或把排水移回第 9 行位置（后者会让 v1 段的 python3 读不到 stdin，需选前者）。

### S2（次要）`claude-code/features/.harness/hooks/check-branch-drift.sh:43`

```
[[ $use_v1 == 1 ]] && v1_drift || true
```

简报「候选文件权威结构」与 design 架构节都写的是「v1 逻辑收进**在 `if` 条件中调用**的函数」，`load-feature.sh:55` 也确实是 `if [[ … ]] && v1_baseline; then`。这里用了 `a && b || c` 形态。

为什么是缺陷：功能上等价（`|| true` 在最后，`v1_drift` 内 errexit 同样被抑制，实测七类 fixture 与非法输入全部 rc0 落 legacy），但偏离了权威结构描述，且 `a && b || c` 是易踩的惯用陷阱——后续若有人把 `true` 换成实际动作，语义会静默改变。两个 sibling hook 形态不一致也增加阅读成本。

建议修法：改成 `if [[ $use_v1 == 1 ]] && v1_drift; then :; fi`，或直接 `if [[ $use_v1 == 1 ]]; then v1_drift || true; fi`。

### S3（次要）`check-branch-drift.sh:36-40` vs `:50-52`；三 hook 各自 guard 5 行 + `compat_legacy` 1 行

漂移判定条件与两行告警文本在 v1 段与 legacy 段逐字重复；guard 与 compat helper 三份复制。

为什么记录：这是简报要求我核的「逻辑块被逐字复制」项，事实成立。但 design「概述」第 1 条已明确论证过（exact 六文件 + 不改 `feature-common.sh` + 不新增 `.harness` 下文件 ⇒ 公共 guard 无处可放，「接受三份 ~6 行重复」），R6 又要求 legacy 段逐字保留、R4 要求 v1 沿用同一措辞。**不建议在本片修改**，记录备案，供 08 片合并 wrapper 时一并收敛。

### S4（次要）`claude-code/features/.harness/hooks/session-end.sh:17-29`

```
sid="$(python3 -c '…')" || sid=""
if [[ -z "$sid" ]]; then compat_legacy; exit 0; fi
```

「python3 不可用 / 解释器自身失败」与「stdin 输入非法」共用同一个 `sid=""` 哨兵，因而共用「零删除」出口。

为什么是缺陷：对非法输入，零删除正是 R5 要的；但 python3 缺席时，hook 打印 `compat: session-provider=legacy` 宣称走了 legacy，却**从不执行 legacy 的 `rm -f` 全局快照清理**——marker 与实际行为不符，legacy 快照永久残留。R2 把「provider 不可用」和「输入非法」列为两类触发因，此处被合并了。另外两个 hook 无此问题（它们的 legacy 段不依赖解析结果）。

建议修法：把 python 的退出码与「解析成功但校验失败」区分开（例如校验失败退 3、其他非零视为解释器故障走完整 legacy 清理），或在 guard 阶段加一次 `command -v python3` 判定。

## 核对记录

工作区 `…/work/2026-09-03-03e-claude-session-lifecycle/worktree`，全部只读操作，未修改任何文件、未提交。

| # | 命令 | 结果 |
|---|---|---|
| 1 | `git status --porcelain` | 空（控制器已把验收资产移出，worktree clean，实现者顾虑 3 已消解） |
| 2 | `git rev-parse HEAD` | `4ceca2bfe61208ded9a1569ea2345c62c52210c8`，与 review 包一致 |
| 3 | `git diff --name-only BASE HEAD` | 恰四文件（check-branch-drift / load-feature / session-end / settings.json） |
| 4 | `git diff --numstat BASE HEAD` | 38+3=41 ≤42、45+3=48 ≤52、45+0=45 ≤52、3+0=3 ≤6；`awk` 合计 **137** ≤152 |
| 5 | `git diff --name-only BASE HEAD -- $UPSTREAM12`（十二文件全列） | 空输出，上游零变更 |
| 6 | `git diff --raw BASE HEAD` | `:000000 100644 … A session-end.sh` ← **B1 的直接证据** |
| 7 | `git ls-files -s`（全仓 hooks/bin） | 所有被调用 hook/bin 均 100755，仅 `codex/.codex/hooks/feature-common.sh` 与本次新增 `session-end.sh` 是 100644 |
| 8 | `./…/session-end.sh </dev/null`、`sh -c './…/session-end.sh'` | 均 **rc126 Permission denied** |
| 9 | `grep -n chmod claude-code/features/install-harness.sh` | 无匹配（安装器不补执行位） |
| 10 | `"$TOOLS/shfmt" --version` / `"$TOOLS/shellcheck" --version` | `v3.14.0` / `version: 0.11.0`，逐字符合 |
| 11 | `shfmt -d -i 2 -ci -bn` 三 hook | rc0 无输出 |
| 12 | `shellcheck -x --severity=warning` 三 hook | rc0 无警告 |
| 13 | `bash -n` ×3、`git diff --check BASE HEAD` | 全 rc0 |
| 14 | `python3 -c 'json.load(open("…/settings.json"))'` | rc0；三事件 schema 一致，SessionEnd 指向 `${CLAUDE_PROJECT_DIR}/.claude/hooks/session-end.sh` |
| 15 | `( set -e; for h in …; do compat 计数==1; grep marker; grep declare -F 五名; done )` | **LOOP_RC=0**，三 hook 各恰 1 处字面量 |
| 16 | `bash ./scripts/check.sh --offline` | **rc0**，13 行全 PASS（含 demo、Codex、shared regression、五个 session-* 入口）。注：`quality_run_static` 因两 hook 的 blob 已偏离 `scripts/shell-quality-baseline.tsv` 锚点而对它们真跑了 shellcheck/shfmt，仍全绿；baseline 自身摘要与 30 行数未变，无需改动 |
| 17 | 七类 fixture（absent / missing-foundation,path,snapshot,signals,remove / marker 篡改为 2） | 三 hook × 7 类 = 21 次，一律 rc0 + compat 恰 1 + v1 状态树缺席 |
| 18 | 桩 aggregator：marker=1 + 4/5 API（缺 `harness_session_state_path`） | 三 hook 全 legacy（compat=1）；补齐第 5 个 API 后三 hook 全转 v1（compat=0）→ 三合取为真合取 |
| 19 | v1 SessionStart 矩阵（startup 建基线 / 重复幂等 / 基线在场 resume 不改写 / compact 缺基线 stderr 一行不创建 / 非法 source / malformed JSON） | 全部符合 R3；project-id 实测为 64 位小写 hex，v1 路径下 `$TMPDIR` 无 legacy 快照 |
| 20 | v1 UPS 矩阵（无漂移 0 字节 rc0 / 基线缺席 rc0 / 漂移 rc2 两行逐字 / 非法 sid、malformed JSON 落 legacy） | 除 B2 外符合 R4 |
| 21 | v1 SessionEnd 矩阵（五 reason 全合法 rc0 静默 / 重复 rc0 / bad reason、bad event、bad sid 各 compat 1 + 零删除且预置 legacy 快照仍在） | 符合 R5 逻辑 |
| 22 | legacy surface（无 lib 副本）三 hook 全矩阵 | SessionStart 写全局快照内容 == feature；UPS 漂移两行 rc0 不阻断、无漂移静默；SessionEnd 幂等 `rm -f`、重复仍 rc0；`$HARNESS_STATE_ROOT` 全程不存在 |
| 23 | `json.dumps` 构造含 TAB / LF 的 session_id 三例 | **B2 复现**（见上表） |
| 24 | `git show BASE:…/{load-feature,check-branch-drift}.sh` 单独跑同一 shfmt | **两处 diff 完全一致**，实现者顾虑 2 属实：`> "` / `< "` 的非规范形态**继承自 BASE**，非本次引入 |
| 25 | `git diff -w BASE HEAD -- check-branch-drift.sh` 对 `tr -d` 行 | 无输出 ⇒ 该行改动**纯空白**；配合 #22 的 legacy 全矩阵行为一致，零行为变更 |
| 26 | `git cat-file -e BASE:…/session-end.sh`；`git show BASE:…/settings.json \| grep -c SessionEnd` | rc128（缺席）；计数 0 ⇒ 红阶段可从 BASE 机械复现，是真红 |
| 27 | `printf 'bash: …session-end.sh: No such file or directory\n' \| sha256sum`；`printf '' \| sha256sum` | `b92823cb…` / `e3b0c442…`，与 evidence 记录的 `stderr_sha256` / `stdout_sha256` 逐字节相同 |
| 28 | `grep -n '^红阶段证据: ' task-1.1-report.md \| cat -A`；`grep -c` | 第 42 行，全文恰 1 处，`…task-1.1-red.txt$` ⇒ 独占一行、行尾零尾随字符 |
| 29 | BASE vs HEAD、无 target fixture、300KB payload，`cat file \| bash <hook>` | BASE `writer_rc=0` / HEAD `writer_rc=141` ⇒ **S1 复现** |

对实现者三条自报顾虑的独立结论：

1. **步骤 7 未做** —— 确属控制器职责，未纳入本次审查。
2. **两处 shfmt 重定向空白改动** —— 说法属实（#24、#25）：BASE 原文本身就不是 shfmt v3.14.0 canonical 形态，改动经 `git diff -w` 核为纯空白，legacy 全矩阵行为逐条不变。R6 的「逐字不变」约束的是行为（快照路径、字符串不等判定、纯文本两行告警、rc0 不阻断），四项全部保持；步骤 2 的锚定字面量是自查辅助而非需求，实现者已如实记录替换后的锚定并复核通过。**不判缺陷。**
3. **`git status --porcelain` 非空** —— 复核为**已消解**：当前 worktree `git status --porcelain` 输出为空（#1）。
