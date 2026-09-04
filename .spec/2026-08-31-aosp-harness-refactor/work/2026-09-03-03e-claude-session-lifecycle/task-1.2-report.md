# 任务 1.2 报告：一次性交付 run-demo.sh 私有 fixture 改造

**Status**: `DONE_WITH_CONCERNS`

| 项 | 值 |
|---|---|
| 需求 | R7（demo 成功/受控失败/信号退出时全部持久写入局限于自建 mktemp 子目录） |
| 交付文件 | `claude-code/run-demo.sh`（exact 1 文件） |
| execution BASE | `cc04996e1e405c00e16be3b57d3ef62d90cd7fd1` |
| TASK_BASE | `b2fab1905278fd523134a8ac656fa152a0824669`（= 任务 1.1 TASK_HEAD，相邻连续已核） |
| TASK_HEAD | `a8d03d1d59b42f2503a2dc3a2e906c9204efafb3` |
| commit message | `refactor(claude): confine demo writes to private mktemp tree` |
| 交付文件 sha256 | `100474fa668fc6607904c12fdea45655cfbafcd6c6f0ad75eb258f0f5e56a303` |
| 产出契约 | `claude-demo-private-fixture-v1` |
| 消费契约 | `claude-hook-lifecycle-contract-v1`（任务 1.1） |

---

## 步骤 1：行为红（不用文本代理红）

在 `git clone --no-local .` 出来的独立 clone 内、以私有 `TMPDIR` 跑现状
`claude-code/run-demo.sh`，证明现状 demo 会往 `${TMPDIR:-/tmp}` 写全局快照。

- clone 自 worktree HEAD `b2fab190`，`clone_HEAD` 逐字相同；clone 内与 worktree 内
  `claude-code/run-demo.sh` 的 sha256 同为 `8ed580c4261b7f74b4788fe9996897d2a45a1a00510d5c3fd1f9bfc3626e03b3`。
- **先 `mkdir -p "$tmp/demotmp"`**（不建这个目录，legacy 段的快照重定向会直接失败、demo 以 rc1 早死，
  红因就不是 R7 那件事了）。
- 主命令 `TMPDIR="$tmp/demotmp" bash claude-code/run-demo.sh`：rc=0、stderr 逐字空（0 字节）。
- 主断言：`$tmp/demotmp/.aosp-harness-demo.feature-snapshot` 存在，内容经 `cat -A` 核为
  `dev-sidebar` 无尾随 LF，sha256 `fe576e60...4562` 与 oracle `printf '%s' dev-sidebar | sha256sum` 逐字相等。
- 第二合取项（demo 期间树根 `CURRENT_FEATURE` 被改写后才由 `restore_feature` 还原）事后已被 EXIT
  trap 还原、不可观测，故按 brief 改为源码级观察：`rg -n 'echo "dev-next" > CURRENT_FEATURE'` 命中
  **39** 行、`rg -n 'trap restore_feature EXIT'` 命中 **17** 行，`rg -c` 均为 1。
- 双重隔离成立：真实 `/tmp/.aosp-harness-demo.feature-snapshot` 事后仍缺席。

证据：`evidence/task-1.2-red.txt`（六字段 schema，未增删行）与 `evidence/task-1.2-red-run.log`
（113 行全命令与逐段输出），两者 `test -s` 均通过。

## 步骤 2：候选结构核对

| 核对 | 结果 |
|---|---|
| `rg -c 'trap'` == 1（唯一 trap） | 1 ✓ |
| `rg -qF 'rm -rf -- "$DEMO_TMP_DIR"'` | 命中 ✓ |
| `! rg -q 'restore_feature'` | 已整段删除 ✓ |
| `rg -q 'HARNESS_STATE_ROOT'` | 命中 ✓ |
| `rg -qF 'common/.harness/lib'`（lib 副本段在场） | 命中 ✓ |
| `mktemp -d "${TMPDIR:-/tmp}/claude-harness-demo.XXXXXX"`（带前缀模板，裁定 10） | 命中 ✓ |

结构与 design「run-demo.sh 私有 fixture 与单 EXIT trap」节一致：单一 EXIT trap 只做
`rm -rf -- "$DEMO_TMP_DIR"`、无恢复动作（新设计对树根零写入，三退出路径共用同一清理点）；
fixture 为 `$DEMO_TMP_DIR/tree/claude-code/`（`CURRENT_FEATURE` + `features/dev-sidebar|dev-next/CLAUDE.md`）
+ `$DEMO_TMP_DIR/tree/common/.harness/lib/`（`cp` 仓库 `session-state*.sh` 副本）+ 私有
`TMPDIR="$DEMO_TMP_DIR/tmp"` 与 `HARNESS_STATE_ROOT="$DEMO_TMP_DIR/state"`；
install-harness、wrapper dry-run、分支一致性、流程层、verify、回归各节保留现状。

**v1 hook 演示段实际行数消耗（裁定 8 M2 纪律）**：单文件 `git diff --numstat` = `42 + 9 = 51`，
预算 ≤62，余量 11 行，未超预算。分解：mktemp+单 trap 2 行、私有树+lib 副本 8 行、`hook()` 转发 4 行、
v1 生命周期演示（SessionStart/state 树/无漂移/漂移 exit 2 断言/SessionEnd/清理后 state 树）17 行、
`sep()` 因 shfmt 展开净增 4 行（见「顾虑 3」）。

## 步骤 3：固定版本与静态门

| 项 | 结果 |
|---|---|
| `shfmt --version` == `v3.14.0` | 逐字相等 ✓ |
| `shellcheck --version` 含 `^version: 0.11.0$` | 命中 ✓ |
| `shfmt -d -i 2 -ci -bn claude-code/run-demo.sh` | 无输出、rc0 ✓ |
| `shellcheck -x --severity=warning claude-code/run-demo.sh` | rc0 ✓ |
| `bash -n claude-code/run-demo.sh` | rc0 ✓ |
| `git diff --check` | rc0 ✓ |
| `settings.json` python3 json 解析（旁证，任务 1.1 资产） | 解析通过，`SessionEnd` 已注册 ✓ |

## 步骤 4：三路径验收实跑

**成功路径（ambient `TMPDIR` = `/tmp`）**

- `bash claude-code/run-demo.sh` rc=0。
- 真实树根 `claude-code/CURRENT_FEATURE` 前后 sha256 逐字不变
  （`befc80edf67b81b5f30ae2b4e518f1d39acc6ce1ab676d4c0616ca5bcf0b8e41`）。
- `${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot` 缺席。
- `test -z "$(ls -d "${TMPDIR:-/tmp}"/claude-harness-demo.* 2>/dev/null)"` 通过（前缀 glob 断言，
  不做 `/tmp` 全量 inventory，避免同机其他进程竞态）。

**inventory 比较（私有 `TMPDIR`，四步严格有序，未合并未调序）**

1. `mkdir -p "$tmp/demotmp"`；
2. 采前值 `find "$tmp/demotmp" | sort >priv.before`（1 行）与
   `find . -maxdepth 2 -not -path './.git/*' | sort >root.before`（62 行）——**前值在跑之前采**；
3. `TMPDIR="$tmp/demotmp" bash claude-code/run-demo.sh` rc=0；
4. 以逐字相同的 find 表达式与深度采后值，`cmp -s` 双双通过：私有 TMPDIR inventory 与树根
   inventory 均逐字相同，私有 TMPDIR 下亦无 `.aosp-harness-demo.feature-snapshot`。

**受控失败路径**：由 demo 内 UserPromptSubmit `exit 2` 断言自证——demo 整体 rc0 即证明
`drift_rc -ne 2` 分支未触发、断言通过后 demo 继续。

**信号路径**：按 design 测试策略节，由单 EXIT trap 结构核对覆盖（`rg -c 'trap'` == 1，
唯一一行为 `trap 'rm -rf -- "$DEMO_TMP_DIR"' EXIT`），不做非确定性中途注信号。

**v1 生命周期行为实证**（私有 fixture 内确实消费 provider v1，而非 legacy）

```
  [state 树] /tmp/claude-harness-demo.HaZFC2/state/357d6198...b9222/demo-session/feature
  [无漂移时] check-branch-drift.sh 零输出：
  <上面应无告警>
  [切到 dev-next 后] 再跑 check-branch-drift.sh（受控失败演示：期望 exit 2 阻止 prompt）：
⚠️ [分支漂移] 会话注入时在 'dev-sidebar'，现在切到了 'dev-next'。
   当前会话仍含旧上下文；退出后用 .claude/bin/claude-feature 重启，别拿旧分支约定改新分支。
[demo] 已按预期以 exit 2 阻止该 prompt；私有 fixture 之外的真实 CURRENT_FEATURE 始终只读。
  [SessionEnd 清理后 state 树] （应为空）
```

- state 落点在 mktemp 子目录内、project-id 为 64 位小写 hex（权威物理根完整 SHA-256）、
  session 目录为 `demo-session`；
- demo stdout 中 `compat: session-provider=legacy` 出现 **0** 次 → 走的是 v1 而非 legacy；
- SessionEnd 后 state 树为空（remove 自底向上剪枝）。

## 步骤 5：提交与累计断言

| 断言 | 结果 |
|---|---|
| working-tree `git diff --name-only` 恰为 `claude-code/run-demo.sh` | ✓ |
| 单文件 `git diff --numstat` 总和 ≤62 | `42+9=51` ✓ |
| `git diff --name-only "$BASE_SHA" "$TASK_HEAD"` 恰为 1.1 四文件 + 本文件 | 5 文件 ✓ |
| `git diff --numstat "$BASE_SHA" "$TASK_HEAD"` 总和 ≤214 | `191` ✓ |
| `git diff --name-only "$BASE_SHA" "$TASK_HEAD" -- $UPSTREAM12` 为空 | 空 ✓ |
| `git status --porcelain` 为空 | 空 ✓ |
| `git rev-parse HEAD~1` == `$TASK_BASE` | ✓ 相邻连续 |

累计断言均以 execution BASE `cc04996e` 为准；`$TASK_BASE` 只用于 manifest 行与相邻连续性。

## 不变量复核

| 不变量 | 阈值 | 实测 |
|---|---|---|
| 上游十二 tracked 文件在 BASE..HEAD 的变更数 | ≤0 | 0（`git diff --name-only` 对 `$UPSTREAM12` 为空） |
| run-demo.sh 退出后 mktemp 子目录外净文件变更数 | ≤0 | 0（树根 `CURRENT_FEATURE` 逐字未变、全局快照缺席、无 `claude-harness-demo.*` 残留、两份 inventory `cmp` 相同） |
| 既有 Claude/Codex/common 与已合入 session 回归失败数 | ≤0 | 0——`bash ./scripts/check.sh --offline` rc0，全部 `RESULT PASS`（shared Harness regression、device safety、session path race assurance/path safety/write interrupts/snapshot assurance/snapshot safety/state foundation/state、offline quality gate） |

## 顾虑

1. **本 worktree 存在并发写入者，最终落盘内容不是我这次 Write 调用的产物。**
   我起手时已核实 worktree clean、HEAD `b2fab190`；但在我执行期间，另一进程反复重写
   `claude-code/run-demo.sh` 并反复建/回退提交。`git reflog` 留下的痕迹：
   `fd1e0be` → `7bab650` → reset 回 `b2fab19` → `078a52b` → reset 回 `b2fab19` → `a8d03d1`。
   我自己那份一次性候选（numstat `42+15=57`，六项结构核对、shfmt/ShellCheck/bash -n/`git diff --check`
   全绿）被覆盖三次，其中一次是在我三路径实跑的中途被换掉（run 起头与收尾的文件 sha256 不一致，
   该次实跑证据作废后已重跑）。**最终 `a8d03d1` 的文件内容由该并发进程作者化**，我的角色是对它做了
   完整独立复验（上列全部门禁均在同一次原子命令内、且首尾 sha256 一致的稳定状态下取得）。
   建议 controller 在派 reviewer 前先确认 `TASK_HEAD` 仍为 `a8d03d1`、文件 sha256 仍为
   `100474fa...a303`；若不符说明并发写入者仍在动，需先隔离再复验。
2. **中途出现过两个不满足验收门的提交**：`7bab650` 与 `078a52b` 的候选都**未通过步骤 3 的
   `shfmt -d -i 2 -ci -bn`**（rc1）。最终 `a8d03d1` 已修好。这两个 SHA 只存在于 reflog、不在
   `b2fab19..a8d03d1` 的历史里，但如果 controller 之前记过它们，需要作废。
3. **现状 `run-demo.sh` 本身就不是 shfmt-clean，因此 design 的「`sep()` 逐字保留」无法同时满足。**
   实测 pristine `b2fab19:claude-code/run-demo.sh` 在 `shfmt -d -i 2 -ci -bn` 下有两类差异：
   单行 `sep() { echo; ...; }` 要展开成 5 行、`> file` 要收成 `>file`。步骤 3 的门要求该单文件
   shfmt 无输出，故最终候选把 `sep()` 展开为多行（净增 4 行 numstat，已计入 51/62 预算）。
   这是被 shfmt 门逼出的必要偏离，不影响行为；但它说明 03e 的「保留现状 ~45 行逐字」在
   `run-demo.sh` 上对 `sep()` 一行不成立，后续片子如再引用该措辞建议改口径。
4. 步骤 6（task brief/report 之外的 4 参 `review-package.sh`、evidence package、独立 diff review、
   manifest 追加行、mark/ledger 锚点/sync-ledger）按 brief 属 controller 动作，我未执行、
   也未改 `review-manifest.tsv`。
