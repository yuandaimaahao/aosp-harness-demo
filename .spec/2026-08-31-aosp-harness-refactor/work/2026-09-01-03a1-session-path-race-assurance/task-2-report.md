# 03a1 Task 2 implementation report

## Status

DONE

## Commits

- `565008482663664d9192817ccff9810993ca8ba0` — `test(session): isolate external race matrices`

## Red evidence

红阶段证据: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-03a1-session-path-race-assurance/task-2-red.log`

在`TASK_BASE=d79de6bb6b10bce9ffd4238b071656cf7089db88`运行合法单行EIO `run-matrix`：命中`matrix executor incomplete`，rc `1`、stdout `0B`、stderr `286B`、无PASS、CASE_LOG缺席，provider SHA前后均为`07af7800401608fd679c1244854ab1852daa2a98c459a0cff053c1b0e07c4b64`。同时建立的16项初始path/log/TSV反例全部rc1、stdout0、0 case、provider不变。

## Implementation

- 实现至少一行、无NUL、exact四列、ID唯一、完整family/layer/variant枚举和canonical ID validator；合法但未实现的family进入executor后确定性rc1。
- 按round7边界实现`parent.lstat()`、absolute + strict-resolve physical parent、absent workspace、`parents=False`、0700/EUID workspace，以及通过workspace fd以`O_EXCL|O_NOFOLLOW`创建并验证0600/EUID/link-count的direct-child CASE_LOG。
- 新增filesystem-byte canonical inventory、完整lstat signature、delta schema/assertion和strict single-anchor provider copy共享原语。
- 仅实现`real-eio`：只替换唯一OS_ERROR marker-bearing line，逐字核对全N/A hook、rc1/空stdout/operation stderr和零delta；final provider bytes、执行集合通过后才通过held fd一次写log并打印private PASS。
- 未实现swap、wrong-EUID、EEXIST、managed lifecycle、内建37 rows或14项self-disproof。

## Green verification

提交前及提交后关键门均通过：

- 单行`real-eio`: rc0、stdout精确38B、stderr0B、log精确`real-eio\n`（9B），hook逐字`OS_ERROR|N/A|N/A|N/A|N/A|N/A\n`。
- workspace/log mode精确0700/0600；production provider SHA保持`07af...4b64`。
- 提交后负例矩阵21/21 PASS：relative、保留`..`、missing parent、parent symlink、existing/symlink workspace、provider-direct/existing/symlink/hardlink log、空/NUL/三列/五列/空字段/重复/未知/非法组合/noncanonical TSV，以及未实现单row和`real-eio`后接未实现row；全部rc1、stdout0、无PASS。preflight反例0 case；未实现row log 0B；mixed fixture真实EIO hook 1次但log仍0B；existing log及provider均不变。
- absolute raw `.` workspace/log折叠路径：rc0、stdout38B、stderr0B、log 1行。
- Task 1协议回归：protocol rc0、stdout28B、stderr0B；misuse rc2；self-test正确arity保持rc1且无PASS。
- 临时`PYTHONPYCACHEPREFIX` py_compile与Python 3.8 grammar：PASS。
- `tests/test-session-state-foundation.sh`与`tests/test-session-path.sh`：PASS。
- `git diff --check`: PASS。

## Diff and repository state

- `TASK_BASE`: `d79de6bb6b10bce9ffd4238b071656cf7089db88`
- `TASK_HEAD`: `565008482663664d9192817ccff9810993ca8ba0`
- Task diff name-only: exact `tests/lib/session-path-race-driver.py`
- Task diff numstat: `170  3  tests/lib/session-path-race-driver.py`，总计173。
- Execution BASE `c959efaf9887808621852aff28073cf1f8789ca7`到HEAD：exact同一driver，numstat `183  0`，累计`183 <= 400`；driver当前183行。
- 03 foundation/provider与03a foundation/path tests的execution BASE..HEAD diff为空。
- 实现worktree最终`git status --porcelain`为`0B`，clean。

## Concerns

None. Valid non-EIO rows intentionally remain the Task 3 red seam and cannot write a success log.
