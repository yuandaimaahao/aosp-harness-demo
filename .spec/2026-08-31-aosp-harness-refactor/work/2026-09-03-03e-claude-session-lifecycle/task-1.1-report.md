# task-1.1 报告：一次性交付三 hook 与 settings.json 注册

## task

task-1.1（03e-claude-session-lifecycle 八个串行任务的第一个）：把 `load-feature.sh`（SessionStart）、
`check-branch-drift.sh`（UserPromptSubmit）接到 v1 session-state provider 上，新增
`session-end.sh`（SessionEnd）并在 `settings.json` 注册该事件。需求 R1-R6。

## base / head

- TASK_BASE = `cc04996e1e405c00e16be3b57d3ef62d90cd7fd1`
- TASK_HEAD = `4ceca2bfe61208ded9a1569ea2345c62c52210c8`
- commit: `feat(claude): route session hooks through provider guard`

## files

BASE..HEAD name-only（git tree 序，逐字四文件）：

```
claude-code/features/.harness/hooks/check-branch-drift.sh
claude-code/features/.harness/hooks/load-feature.sh
claude-code/features/.harness/hooks/session-end.sh
claude-code/features/.harness/settings.json
```

`git diff --numstat` 逐文件（BASE..HEAD）：

| 文件 | added | deleted | 合计 | 预算 |
|---|---|---|---|---|
| check-branch-drift.sh | 38 | 3 | 41 | ≤42 |
| load-feature.sh | 45 | 3 | 48 | ≤52 |
| session-end.sh | 45 | 0 | 45 | ≤52 |
| settings.json | 3 | 0 | 3 | ≤6 |
| **合计** | | | **137** | **≤152** |

`git show --stat HEAD`（等价确认）：`4 files changed, 131 insertions(+), 6 deletions(-)` = 137，与上表一致。

上游十二 tracked 文件：`git diff --name-only "$TASK_BASE" "$TASK_HEAD" -- $UPSTREAM12` 输出为空（未改动任何一个）。

## 红阶段证据

红阶段证据: .spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03e-claude-session-lifecycle/evidence/task-1.1-red.txt

（路径相对工作区根 `<worktree>/`；`cat -A` 自查上一行行尾无尾随字符，见下方「结构自查」小节。）

## M2 纪律：实际起止行号与行数

- `session-end.sh` stdin 校验解析段（`sid="$(python3 -c '` 到 `')" || sid=""`）：第 **17-29 行**，共 **13 行**。
- `settings.json` SessionEnd 注册块：新增纯注册块第 **10-12 行**（3 行：`"SessionEnd": [` / hooks command 行 / `]`），配合第 **9 行**由 `]` 改为 `],`（1 行修改，为承接第三事件所需的语法改动）。注册块净新增 3 行，触达 4 行（含第 9 行的逗号改动）。

## commands / results

以下命令均在 worktree 根（`/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03e-claude-session-lifecycle/worktree`）下实际执行，非凭阅读判断。

### 步骤 1：红阶段

| 命令 | rc | 关键输出 |
|---|---|---|
| `bash claude-code/features/.harness/hooks/session-end.sh </dev/null` | 127 | stderr: `bash: claude-code/features/.harness/hooks/session-end.sh: No such file or directory`；stdout 空（sha256 `e3b0c4...`，即空串哈希，无 compat marker） |
| `rg -q 'SessionEnd' claude-code/features/.harness/settings.json` | 1 | 无匹配（settings.json 当时仅注册 SessionStart/UserPromptSubmit） |

红阶段证据文件已按固定 schema（`task=`/`command=`/`expected=`/`rc=`/`stdout_sha256=`/`stderr_sha256=`/`assertion=`）写入，`test -s` 确认非空。

### 步骤 2：交付候选 + 结构核对

- `TASK_BASE=$(git rev-parse HEAD)` = `cc04996e1e405c00e16be3b57d3ef62d90cd7fd1`，核对逐字等于门④固定 execution BASE，通过。
- 一次性写入四文件候选（Edit/Write 工具，非逐段拼装）。
- `test "$(wc -l <claude-code/features/.harness/hooks/session-end.sh)" -le 52` → 实测 45 行，rc0 通过。
- 三 hook compat marker 恰一次 + guard 锚定（`( set -e; for h in ...; do ...; done )` 子 shell 结构，判定循环整体 rc）：**LOOP_RC=0**，三文件（load-feature.sh / check-branch-drift.sh / session-end.sh）逐一通过：
  - `rg -oF 'compat: session-provider=legacy' "$h" | wc -l` == 1
  - `rg -q 'HARNESS_SESSION_STATE_PROVIDER_VERSION' "$h"` rc0
  - `rg -q 'declare -F harness_validate_feature_name harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove' "$h"` rc0
- legacy 段逐字保留锚定：
  - `rg -qF "printf '%s' \"\$feature\" >\"\${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot\"" load-feature.sh` → rc0（**注：空格形态改为 shfmt 规范无空格形态，原因见下方「与简报字面量的偏离」**）
  - `rg -qF '⚠️ [分支漂移]' check-branch-drift.sh` → rc0
  - `rg -qF "tr -d '[:space:]'" check-branch-drift.sh` → rc0

### 步骤 3：settings.json 核验

| 命令 | rc | 结果 |
|---|---|---|
| `python3 -c 'import json; json.load(open("claude-code/features/.harness/settings.json"))'` | 0 | JSON 解析通过 |
| `rg -qF '${CLAUDE_PROJECT_DIR}/.claude/hooks/session-end.sh' claude-code/features/.harness/settings.json` | 0 | SessionEnd 指向本片新 hook |
| `rg -q 'load-feature.sh' claude-code/features/.harness/settings.json` | 0 | SessionStart 未动 |
| `rg -q 'check-branch-drift.sh' claude-code/features/.harness/settings.json` | 0 | UserPromptSubmit 未动 |

### 步骤 4：固定工具版本 + 静态门

| 命令 | 结果 |
|---|---|
| `"$TOOLS/shfmt" --version` | `v3.14.0`，`test "$(...)" = "v3.14.0"` rc0 |
| `"$TOOLS/shellcheck" --version \| rg -q '^version: 0.11.0$'` | rc0 |
| `"$TOOLS/shfmt" -d -i 2 -ci -bn load-feature.sh check-branch-drift.sh session-end.sh` | **rc0，无输出**（详见下方偏离说明：中途发现并修复了两处继承自 BASE 的 pre-existing 重定向空格问题） |
| `"$TOOLS/shellcheck" -x --severity=warning load-feature.sh check-branch-drift.sh session-end.sh` | rc0，无警告 |
| `bash -n` ×3（load-feature.sh / check-branch-drift.sh / session-end.sh） | 均 rc0 |
| `git diff --check` | rc0，无空白错误 |

### 步骤 5：smoke 抽查

在 `mktemp -d` 私有 fixture（`tree/claude-code/`、`tree/common/.harness/lib/` 副本）下，以
`CLAUDE_PROJECT_DIR=$tmp/tree/claude-code TMPDIR=$tmp/tmp HARNESS_STATE_ROOT=$tmp/state` 调真实三 hook：

**v1 例（fixture 含 lib 副本）**
- SessionStart（`{"session_id":"sess-001","source":"startup"}`）：rc=0；`$tmp/state/<64位小写hex>/sess-001/feature` 内容 `dev-sidebar`（== feature）；`$tmp/tmp` 下无 legacy 快照文件；stdout 无 compat marker（grep 计数 0）。project-id `8638496c91098740fb82f2db82b3be76b7441197f17a4ecb05351dff3439e9c3` 经 `wc -c`=64 且 `grep -qE '^[a-f0-9]+$'` 通过，确认为 64 位小写 hex。
- UserPromptSubmit 无漂移（`{"session_id":"sess-001"}`，当前 feature 仍为 dev-sidebar）：rc=0，stdout 0 字节。
- UserPromptSubmit 漂移（切 CURRENT_FEATURE 为 dev-next 后重跑）：rc=2，stdout 两行告警逐字匹配设计文案。
- SessionEnd（`reason=clear`）：rc=0，静默；`$tmp/state` 整树被幂等 prune 至消失；重复调用仍 rc=0（幂等）；`reason=bogus`（非法值）：rc=0，stdout 恰一次 compat marker（校验失败零删除路径）。

**legacy 例（fixture 无 lib 副本）**
- SessionStart：rc=0；stdout compat marker 恰一次；`$tmp/tmp/.aosp-harness-demo.feature-snapshot` 内容 `dev-sidebar`（legacy 写入）；`$tmp/state` 不存在（v1 状态树缺席）。

fixture 用完 `rm -rf --` 清理，`test ! -e` 确认已删除。

### 步骤 6：提交

- `git add -N` 四文件后 `git diff --name-only` 恰为四文件（git tree 序），逐文件 numstat 见上表，均在预算内。
- `git add`（真实 add，非 intent-to-add）四文件后 `git status --porcelain` 显示 `M /M /A /M` 四行（无 `AN` 标记），确认非 intent-to-add 残留。
- `git commit -m "feat(claude): route session hooks through provider guard"`（含 Co-Authored-By 与 Claude-Session trailer）→ `4ceca2b`。
- `TASK_HEAD=$(git rev-parse HEAD)` = `4ceca2bfe61208ded9a1569ea2345c62c52210c8`。
- `git diff --name-only "$TASK_BASE" "$TASK_HEAD"` 恰为四文件；`awk` numstat 合计 137 ≤152；`-- $UPSTREAM12` 为空；`git status --porcelain` **非空**（详见下方偏离说明）。

## 与简报字面量的偏离（两处，均已核实为安全且必要）

### 1. 两处 legacy 段重定向空格：shfmt 规范 vs 步骤 2 锚定字面量

步骤 4 的 `shfmt -d` 首次运行发现两处输出差异，均落在我"逐字保留"的 legacy 段重定向语句上
（`load-feature.sh` 的 `printf ... > "..."` 与 `check-branch-drift.sh` 的 `tr -d ... < "..."`）。
经核实：**这是继承自 BASE 提交本身的 pre-existing 不一致**——用
`git show cc04996...:.../load-feature.sh` 取出未改动的原始内容单独跑同一 shfmt，同样报同一处 diff
（`> "..."` → `>"..."`，`< "..."` → `<"..."`）。也就是说 BASE 提交的这两行原文本就不是 shfmt v3.14.0
canonical 形态，不是本任务引入的回归。

步骤 2 的锚定命令字面量（`rg -qF "printf '%s' \"\$feature\" > \"\${TMPDIR...` 含空格）是照抄 BASE 原文写的，
与 shfmt 规范（默认去掉重定向符后的空格）互斥：满足其一必破另一。给定「静态门 shfmt 全绿」是验收清单
第 46 行的正式门（"固定版本断言后...运行shfmt/ShellCheck/bash-n全绿"），我判定其优先于步骤 2 自查锚定的
精确空格，遂把这两行改为 shfmt 规范形态（去空格），语义/行为零变化（同一重定向目标、同一写入内容）。
调整后用去空格形态重新核对锚定（`rg -qF` 换成无空格 pattern）rc0 通过，`tr -d '[:space:]'` 与
`⚠️ [分支漂移]` 两条锚定文本本身不含该空格，不受影响、原样通过。

### 2. `git status --porcelain` 非空

步骤 6 末尾 `git status --porcelain` 按字面执行结果为非空：唯一一行是
`?? .spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03e-claude-session-lifecycle/`
——即步骤 1 产出的 `evidence/task-1.1-red.txt` 与本报告文件所在目录。这两个文件是简报「验收资产（不纳入
源码文件清单）」明确列出的产出，且步骤 6 前半段反复要求 `git diff --name-only "$TASK_BASE" "$TASK_HEAD"`
"恰为该四文件"——若把 evidence/report 也提交进同一 commit，则会破坏"恰为四文件"这个更早、更具体的断言。
两者字面冲突时我选择保留"四文件精确 commit"（更具体、被重复三次的约束），未提交验收资产文件，
如实报告 `git status --porcelain` 的非空结果而非силой清空它。除这一个目录外，working tree 无其他改动
（无残留 staged/modified 的 tracked 文件）。

## 结构自查（本报告「红阶段证据: 」行的行尾）

```
$ grep -n '^红阶段证据: ' task-1.1-report.md | cat -A
42:M-gM-:M-"M-iM-^XM-6M-fM-.M-5M-hM-/M-^AM-fM-^MM-.: .spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03e-claude-session-lifecycle/evidence/task-1.1-red.txt$
```
（`cat -A` 把 UTF-8 中文字节转成 `M-x` 转义序列，属预期显示；关键是整行只有一个行尾 `$`，其前无空格/制表符等
尾随字符。）该行第 42 行、独占一行、行尾零尾随字符。

## fix round 1（独立 diff review r1：NEEDS_CHANGES，阻断 2 / 重要 1 / 次要 4）

review 报告：`task-1.1-review-r1.md`（对 commit `4ceca2bfe61208ded9a1569ea2345c62c52210c8`）。本节记录对
B1、B2、I1、S1、S2、S4 六条 finding 的改法与验证；S3 按 reviewer 结论不改（design 已论证的三份 ~6 行 guard/
compat 重复，备案不算缺陷）。新提交：

- fix commit: `b73676ba1607c2a7a6c642c2f2ff80249bef7050`
  （`fix(claude): close session-id truncation and legacy-cleanup gaps in hooks`，独立提交而非 amend）
- BASE..新 HEAD 仍恰为原四文件：`check-branch-drift.sh` / `load-feature.sh` / `session-end.sh` / `settings.json`
- `git diff --numstat "$TASK_BASE" "$TASK_HEAD"`：41 / 49 / 47 / 3，合计 **140 ≤152**（较 fix 前 137，净增 3；
  mode-only 的 B1 变更不计入 numstat）
- 上游十二文件 diff 仍为空；三 hook 静态门（shfmt -d / shellcheck / bash -n / git diff --check / settings.json
  json 解析）全部重跑，全绿（见下方「重跑步骤 2-6」）

### B1（阻断）session-end.sh 以 100644 入库，SessionEnd 注册实机 rc126

改法：`chmod +x claude-code/features/.harness/hooks/session-end.sh` 后 `git update-index --chmod=+x` 重新提交。

验证（修复前 / 修复后对照，均实测非凭阅读）：

| 状态 | 命令 | rc | 说明 |
|---|---|---|---|
| 修复前（commit `4ceca2b` 的 blob） | 取出该 blob（`git show 4ceca2b:…session-end.sh`）设为 644 后 `sh -c '<path>'` | **126** | `Permission denied`，复现 reviewer 实测 |
| 修复后（工作区） | `git ls-files -s claude-code/features/.harness/hooks/session-end.sh` | — | `100755 …`（三 hook 现在与 `load-feature.sh`/`check-branch-drift.sh` 一致） |
| 修复后 | `sh -c "./claude-code/features/.harness/hooks/session-end.sh </dev/null"` | **0** | 不再 Permission denied |
| numstat 影响 | `git diff --cached --numstat` （仅 chmod 时） | `0 0 …` | mode-only 变更不计入 numstat，与 reviewer 预告一致 |

### B2（阻断）TAB/LF 在 `session_id` 里被截断成合法前缀后按 v1 执行

改法：在 `load-feature.sh` 与 `check-branch-drift.sh` 的 python 解析段里加入
`re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", sid)` 形态校验（与 `session-end.sh` 原有规则同源），
使含 TAB/LF 的 `session_id` 在 python 侧就被拒绝（`sys.exit(1)`），不会被后续的 TAB 拆分动作截断成合法前缀。

验证（用 `json.dumps` 构造 payload，排除 shell 转义歧义，与 reviewer 用例逐字一致）：

| payload | rc | compat 计数 | 状态树 | 结论 |
|---|---|---|---|---|
| `{"session_id":"sess-evil\tcompact","source":"compact"}`，基线缺席 | 0 | **1** | `state/<pid>/sess-evil/` **不存在** | 落 legacy，未创建基线（修复前：compat=0、创建了 `sess-evil` 基线） |
| `{"session_id":"sessnl\ninjected","source":"startup"}` | 0 | **1** | `state/<pid>/sessnl/` **不存在** | 落 legacy（修复前：compat=0、创建了 `sessnl` 基线） |
| `check-branch-drift.sh` 收到 `{"session_id":"s1\n"}`，且真实 `s1` 会话已有 `dev-next` 基线 | **0**（非 2） | **1** | 未读取 `s1` 基线 | 落 legacy，不再截断读到别的 session 并 exit 2 阻断 prompt |

### I1（重要）load-feature.sh:46-47 把 write 的 rc3（异值冲突）与 rc0 合并成静默成功

改法：把 `[[ $rc == 0 || $rc == 3 ]] || return 1` 拆成
`if [[ $rc == 3 ]]; then echo "error: [load-feature] 会话基线已存在且值不同，未改写。" >&2; elif [[ $rc != 0 ]]; then return 1; fi`
（+2 行，48→49，仍 ≤52；连同 B2 的行数变化后实测 49 行）。

由于 rc3 只在 read 与 write 之间出现真实竞态时才会被 write 触发（design/reviewer 已论证），无法在单进程内
决定性复现该竞态本身（本机尝试了 80 组并发 `load-feature.sh` 配对race无一命中，判定环境下 read+write 窗口
太短难以稳定交错，已记录不作为反例来源）。为不牺牲验证的确定性，采用两步独立验证：

1. **确认 rc3 是 provider 的真实、可达结果**：直接调用 `harness_session_state_write` 对同一
   project_id/session_id 连续写入两个不同值，第二次调用 `rc=3`（`异值冲突`），且存储值仍为第一次写入的
   值（未被覆盖）——证明 rc3 不是假设，是真实可达的 rc。
2. **对提交文本本身做逻辑级验证**：用 `awk` 从 fix 前（`4ceca2b`）与 fix 后（工作区）的
   `load-feature.sh` 里逐字提取 `v1_baseline()` 函数体，各自 `source` 进一个打桩驱动脚本
   （桩：`harness_validate_feature_name` 恒成功、`harness_session_state_read` 恒返回 3、
   `harness_session_state_write` 恒返回 3，模拟"read 说缺席、write 说冲突"这一竞态结果），driving
   payload `{"session_id":"race-sid","source":"startup"}`：

   | 版本 | stderr | v1_baseline 返回码 |
   |---|---|---|
   | 修复前（`4ceca2b` 提取） | （无相关诊断行） | 0（静默吞掉 rc3，缺陷复现） |
   | 修复后（工作区提取） | `error: [load-feature] 会话基线已存在且值不同，未改写。` | 0（诊断可见，且仍不阻断） |

   两次运行的函数体是从各自提交的**真实文件文本**里逐字抽取的，不是重新誊写的等价实现。

### S1（次要）load-feature.sh 早退路径丢失 stdin 排水，300KB payload 下 SIGPIPE

改法：在 `if [[ -z "$target" ]]` 块内 `exit 0` 之前补回 `cat >/dev/null 2>&1 || true`（+1 行）。

验证（`cat 300KB文件 | bash <hook>`，读 `${PIPESTATUS[0]}` 判定 writer 是否被 SIGPIPE 杀死；fixture 为无
`features/`/`CURRENT_FEATURE` 的 tree，确保命中「未找到 feature 上下文」分支）：

| 版本 | writer_rc（`${PIPESTATUS[0]}`） | hook_rc |
|---|---|---|
| 修复前（`4ceca2b`，同目录配 `feature-common.sh`） | **141**（SIGPIPE） | 0 |
| 修复后（工作区） | **0** | 0 |

两次均正确落到「未找到 feature 上下文」stderr 分支，唯一差异是 writer 端是否被杀，与 reviewer #29 的复现方法一致。

### S2（次要）check-branch-drift.sh:43 用 `a && b || c` 而非权威结构要求的 `if` 形态

改法：`[[ $use_v1 == 1 ]] && v1_drift || true` 改为 `if [[ $use_v1 == 1 ]] && v1_drift; then :; fi`（同 1 行，
numstat 不变）。验证：`rg -q '^if \[\[ \$use_v1 == 1 \]\] && v1_drift; then :; fi$' check-branch-drift.sh` rc0；
`shfmt -d` 对该行无输出；独立 bash 单测确认 `v1_drift` 内部 `return 1`（guard 通过但解析/校验失败）与
`exit 0`/`exit 2`（v1 成功路径）两类出口在新形态下行为与旧形态逐一一致（不阻断、不误吞 exit）。

### S4（次要）session-end.sh 把「python3 不可用」并入「输入非法」的零删除出口，marker 与实际行为不符

改法：python 解析段的校验失败分支从 `sys.exit(1)` 改为 `sys.exit(3)`，bash 侧用 `prc=0; sid="$(python3 -c
'...')" || prc=$?` 捕获真实退出码：`prc==3` 时仍是零删除出口（不变）；`prc` 为其他非零值（含 `python3`
自身启动失败、解释器崩溃）时不再走零删除，而是 `[[ $prc == 0 ]] || use_v1=0` 强制落到既有 `else`（legacy）
分支，复用其中已有的 `compat_legacy` + `rm -f` 全局快照清理逻辑（+2 行：`prc=0` 与该判定行，未新增重复的
清理代码块）。

验证（`PATH` 前置一个恒 `exit 9` 的假 `python3`，模拟解释器不可用/崩溃；预置 legacy 全局快照文件观察是否被清理）：

| 版本 | rc | stdout | legacy 快照文件（清理前已预置） |
|---|---|---|---|
| 修复前（`4ceca2b`） | 0 | `compat: session-provider=legacy` | **仍残留**（YES-LEAKED，marker 与行为不符） |
| 修复后（工作区） | 0 | `compat: session-provider=legacy` | **已删除**（no-cleaned-up-GOOD，marker 与行为一致） |

### 重跑步骤 2-6（fix round 1 之后）

| 项 | 命令 | 结果 |
|---|---|---|
| 三 hook compat 恰一次 + guard 锚定 | 同步骤 2 的 `( set -e; for h in …; done )` 结构 | **LOOP_RC=0** |
| legacy 段逐字锚定（去空格形态，见前述偏离说明） | 三条 `rg -qF` | 均 rc0 |
| settings.json | `python3 -c 'json.load(...)'`；`rg -qF '.../session-end.sh'` | 均 rc0 |
| 固定工具版本 | `shfmt --version` / `shellcheck --version` | `v3.14.0` / `version: 0.11.0` |
| `shfmt -d -i 2 -ci -bn` 三 hook | | **rc0，无输出** |
| `shellcheck -x --severity=warning` 三 hook | | **rc0，无警告** |
| `bash -n` ×3 | | 全 rc0 |
| `git diff --check` | | rc0 |
| 四文件 name-only（`$TASK_BASE`..新 `$TASK_HEAD`） | `git diff --name-only` | 恰四文件 |
| 逐文件 numstat | `git diff --numstat` | 41/49/47/3，各自 ≤42/≤52/≤52/≤6 |
| 合计 numstat | `awk` | **140 ≤152** |
| 上游十二文件 | `git diff --name-only … -- $UPSTREAM12` | 空 |
| 执行位 | `git ls-files -s` 三 hook | 均 `100755` |
| `git status --porcelain`（worktree，验收资产已由控制器移出） | | 空 |

停手条件核对：六条待修 finding 修完后合计 140、逐文件 41/49/47/3，均在预算内，未触发 BLOCKED。

## fix round 2（独立增量复查 r2：PASS，阻断 0 / 重要 0 / 次要 2）

review 报告：`task-1.1-review-r2.md`（对 fix round 1 提交 `4ceca2bfe61208ded9a1569ea2345c62c52210c8..b73676ba1607c2a7a6c642c2f2ff80249bef7050`）。round 1 六条（B1/B2/I1/S1/S2/S4）reviewer 独立复验全部真实闭合，R1-R6 全 ✅。控制器裁定新出现的两条次要（S5、S6，均只在 `session-end.sh`）现在就修，而非挂账到 1.3；S3（guard 与漂移告警在 v1/legacy 段重复）按此前裁定不动，本轮零改动，未触碰。

- fix commit: `b2fab1905278fd523134a8ac656fa152a0824669`
  （`fix(claude): treat unverifiable SessionEnd input as zero-deletion`，独立提交，未 amend）
- BASE..新 HEAD 仍恰为原四文件；本轮只改 `session-end.sh` 一个文件
- `git diff --numstat "$TASK_BASE" "$TASK_HEAD"`：41 / 49 / 47 / 3，合计仍为 **140 ≤152**（`session-end.sh` 本身内容替换是 2 增 2 删，净行数不变，仍 47 行 ≤52；此次改动落在已属"新增"区域内，未改变该文件相对 TASK_BASE 的 add/del 计数）

### 改法（S5、S6 用同一处改动一并关闭）

把

```
if [[ $prc == 3 ]]; then
  compat_legacy
  exit 0
fi
[[ $prc == 0 ]] || use_v1=0
```

改为

```
if [[ $prc != 0 ]]; then
  cat >/dev/null 2>&1 || true
  compat_legacy
  exit 0
fi
```

没有采用 reviewer 建议的方案 (a)（guard 阶段 `command -v python3` 前置判定），原因：reviewer 自己的 S5/S6
复现手段用的是一个**真实存在于 PATH、但恒 `exit 9`** 的假 `python3`——`command -v python3` 本身找得到这个
可执行文件，并不能拦住它，真正需要处理的是"调用了但退出码既不是 0 也不是 3"这一后果，而不是"找不到
命令"这一前提。于是选择把判定收窄到唯一真正相关的信号——**parser 的退出码**：`prc==3`（校验运行完但拒绝）
与`prc` 为其他任何非零值（解释器缺席、崩溃、被杀等，命令替换本身失败）现在合并进同一个分支，视为
design 错误处理表里同一种结果——「无法确认输入合法，零删除」，不再是文档之外的第三/第四种语义；
原来专门把 `use_v1` 强制置 0 再借用 `else` 分支执行 `rm -f` 的路径整段删除，改用与校验失败**完全相同**的
出口（连 `compat_legacy` 调用点都共享，未新增第二处 marker 字面量）。分支合并顺带把这条判定从两行
（`if…fi` + 独立的 `use_v1=0` 赋值）压成同样两行（`if…fi`，多出的一行是新增的 `cat >/dev/null`），文件
总行数不变（47→47）。同时把 `cat >/dev/null 2>&1 || true` 放进这个统一出口，使该路径不再是全文件唯一
不消费 stdin 的早退点。

### S5（session-end.sh:35 `[[ $prc == 0 ]] || use_v1=0` 让解释器故障 fail-open 成删除）

验证（假 `python3` 恒 `exit 9`，前置于 `PATH`；预置 legacy 全局快照）：

| payload | 版本 | rc | stdout | 快照结局 |
|---|---|---|---|---|
| `{"hook_event_name":"NotSessionEnd","session_id":"../evil","reason":"bogus"}`（非法：事件名/session_id/reason 三项全错） | 修复前（`b73676b`） | 0 | `compat: session-provider=legacy` | **NO-WRONGLY-DELETED**（缺陷复现，与 reviewer 实测一致） |
| 同上 | 修复后（工作区） | 0 | `compat: session-provider=legacy` | **YES-CORRECTLY-KEPT** |
| `{"hook_event_name":"SessionEnd","session_id":"s1","reason":"clear"}`（本身合法，但假 python3 下无法验证） | 修复后 | 0 | `compat: session-provider=legacy` | **YES-KEPT**（"无法校验"统一按零删除处理，即使 payload 本身合法也不例外，这是刻意的保守默认） |

对照 sanity（确认没有把正常闸门也弱化）：真 `python3` + 同一条非法 payload → 快照保留（R5 的零删除闸门在
正常路径本来就完好，本轮验证其仍然完好）；真 `python3` + 合法 `clear` payload → 快照正常删除。

### S6（session-end.sh 全文无 stdin 排水，python3 故障路径 writer_rc=141）

验证（300KB payload，`cat file | bash <hook>`，假 python3 恒 `exit 9`，读 `${PIPESTATUS[0]}`）：

| 版本 | writer_rc | hook_rc | stdout |
|---|---|---|---|
| 修复前（`b73676b`；另行复验 `4ceca2b` 的 blob 同样为 141，确认非本轮回退） | **141**（SIGPIPE） | 0 | `compat: session-provider=legacy` |
| 修复后（工作区） | **0** | 0 | `compat: session-provider=legacy` |

sanity：真 `python3` + 300KB（非法 JSON 内容）payload → `writer_rc=0`，确认正常路径未受影响、也没有因为
python3 提前 `sys.exit(3)` 而在读取全部 300KB 之前退出导致 SIGPIPE。

### 重跑静态门与 numstat（fix round 2 之后）

| 项 | 命令 | 结果 |
|---|---|---|
| guard/compat 锚定 | 同前述 `( set -e; for h in …; done )` | **LOOP_RC=0** |
| `shfmt -d -i 2 -ci -bn` 三 hook | | rc0，无输出 |
| `shellcheck -x --severity=warning` 三 hook | | rc0，无警告 |
| `bash -n` ×3 | | 全 rc0 |
| `git diff --check` | | rc0 |
| settings.json | `python3 -c 'json.load(...)'` | rc0 |
| 四文件 name-only（`$TASK_BASE`..新 `$TASK_HEAD`） | `git diff --name-only` | 恰四文件 |
| 逐文件 numstat | `git diff --numstat` | 41/49/47/3，各自 ≤42/≤52/≤52/≤6 |
| 合计 numstat | `awk` | **140 ≤152**（较 fix round 1 后不变） |
| 上游十二文件 | `git diff --name-only … -- $UPSTREAM12` | 空 |
| 执行位 | `git ls-files -s` 三 hook | 均 `100755` |
| `git status --porcelain` | | 空 |

停手条件核对：S5+S6 合并为一处改动后 `session-end.sh` 仍 47 行（预算 52，剩 5 行未用满即已满足，实际未增行）、
合计仍 140（预算 152），未触发 BLOCKED。
