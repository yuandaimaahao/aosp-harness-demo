# task-1.1 report: 一次性交付完整 remove 模块

## task

task-1.1: 创建 `common/.harness/lib/session-state-remove.sh`（source-inert 的 remove 模块：`_harness_session_write_with_signals` 单检查 guard 与唯一私有 export `_harness_session_remove_core`，non-creating verified remove + `PRUNE_BEFORE_IDENTITY` 自底向上 prune），只做 source 契约与静态门，R3/R4 行为矩阵由任务 1.3 封闭。

## base

d8c2baaee20c52c2f4bac88eb6d4938af2d61516

## head

0bb53a040249ddb5fef1a16c89e6d99a7710cd25

## files

- `common/.harness/lib/session-state-remove.sh`（新建，110 行，BASE..HEAD numstat 总和 110 ≤ 110，name-only 恰该单文件，上游九 tracked 文件零变更）

## commands

- 红：`test ! -e common/.harness/lib/session-state-remove.sh && bash -c 'source common/.harness/lib/session-state-remove.sh'` → rc1，stdout 空（无 PASS），stderr 报文件缺席
- 计数门：`wc -l` = 110 ≤ 110；`rg -cF 'pass  # PRUNE_BEFORE_IDENTITY'` = 1；`rg -cF 'pass  # HARNESS_TEST_MARKER_OS_ERROR'` = 1；`rg -c '^[a-z_0-9]+\(\)'` = 1（唯一函数定义）；`rg -q setsid`、`rg -q HARNESS_SESSION_STATE_PROVIDER_VERSION`、`rg -q mktemp` 均无匹配
- 静态门：shfmt v3.14.0 `-d -i 2 -ci -bn` 无输出 rc0；ShellCheck 0.11.0 `-x --severity=warning` rc0；`bash -n` rc0；`git diff --check` rc0（add -N 前后各一次）
- source 齐全态：`bash -c 'source foundation && source path && source snapshot && source signals && source remove'` rc0，stdout/stderr 均 0B
- export inventory（齐全态）：`_harness_session_remove_core` 在场；`harness_session_state_path`/`harness_session_state_write`/`harness_session_state_read`/`harness_session_state_remove` 逐个缺席；`declare -p HARNESS_SESSION_STATE_PROVIDER_VERSION` 非 0（未定义）
- export 缺席抽查态：`mktemp -d` 中将 signals 模块 `_harness_session_write_with_signals` 全局改名后 source 五文件 rc0、双流空、remove export 缺席（改名 export 在场证明副本生效）；临时目录已删除
- 冒烟（任务 1.3 矩阵前的自检，证据 `smoke.log`）：feature 存在删除并全层 prune rc0 双流空；全缺失幂等 rc0；feature 缺失但安全目录存在仍 prune 空层级 rc0；并发非空 project 保留他项且只删空 session rc0；unsafe ID 与 arity 错 rc2 固定 stderr；wrong-mode 目录 rc2 且不删除
- anchor 注入自检（证据 `anchor-eio.log`/`anchor-swap.log`，均在 `mktemp -d` provider 副本上）：`HARNESS_TEST_MARKER_OS_ERROR` 后注入 `raise OSError(errno.EIO, ...)` → rc1、stdout 空、stderr 逐字 `error: session state operation failed\n`；`PRUNE_BEFORE_IDENTITY` 后注入换入攻击（rename + 同名 mkdir）→ rc2、stderr 逐字 `error: unsafe session state\n`、`session` 与 `session.held` 两目录均保留
- 提交：`git add -N` 核 working-tree name-only 恰单文件、numstat 110 ≤ 110 后，真 `git add` 并 `git commit -m "feat(session): add non-creating verified remove module"`；BASE..HEAD name-only 恰单文件、numstat=110 ≤ 110、`-- $UPSTREAM9` 为空、`git status --porcelain` 为空

## results

- 红阶段：rc1，文件缺席，stdout 无 PASS（证据见下）
- 静态门：shfmt rc0 无输出 / shellcheck rc0 / bash -n rc0 / git diff --check rc0
- source 契约：齐全态 rc0 双流空、export inventory 全符合；缺席抽查态 rc0 双流空、remove export 缺席
- 冒烟与双 anchor 注入自检全部符合 R3/R4 预期（正式矩阵由任务 1.3 封闭）
- 提交门：BASE..HEAD 恰单文件、numstat 110 ≤ 110、上游九文件零变更、worktree clean
- 注：候选共 110 行，恰好顶到 ≤110 预算；guard 采用单行 `declare -F ... || return 0 2>/dev/null || exit 0`（与 signals 两行式同语义），注释块压至 8 行，python 侧沿用 path/snapshot 同源词汇与密集风格

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/evidence/task-1.1-red.txt
