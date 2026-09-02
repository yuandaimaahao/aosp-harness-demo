# 03a1 Task 1 implementation report

## Status

DONE

## Commits

- `d79de6bb6b10bce9ffd4238b071656cf7089db88` — `test(session): add private race driver protocol`

## Red evidence

红阶段证据: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-03a1-session-path-race-assurance/task-1-red.log`

在BASE `c959efaf9887808621852aff28073cf1f8789ca7`运行`python3 tests/lib/session-path-race-driver.py protocol`：文件物理缺席，rc `2`，stdout `0B`，stderr `186B`，stdout/stderr均无`session-path-race-driver-v1` token；未创建临时同名源码或修改上游。

## Implementation

- 只新增`tests/lib/session-path-race-driver.py`，实现`protocol`、`self-test FOUNDATION PROVIDER`和`run-matrix FOUNDATION PROVIDER ABSENT_WORKSPACE CASE_TSV CASE_LOG`三种argv形状的dispatcher骨架。
- `protocol`立即输出固定v1 token；两个正确arity执行mode以`AssertionError("matrix executor incomplete")`确定性保持rc1，无private PASS。
- 未读取foundation/provider或未来03a2，未定义runtime API、capability marker，也未实现Task 2–5内容。

## Green verification

提交前及提交后均通过：

- `protocol`: rc `0`，stdout精确`28B`（`session-path-race-driver-v1\n`），stderr `0B`。
- 无参数、unknown、`protocol extra`、self-test短/长arity、run-matrix短/长arity：各rc `2`，stdout `0B`，无PASS。
- 正确arity self-test/run-matrix：各rc `1`，stdout `0B`，stderr `286B`，无PASS。
- `ast.parse(..., feature_version=(3,8))`: PASS。
- `git diff --check`: PASS。

## Diff and repository state

- `TASK_BASE`: `c959efaf9887808621852aff28073cf1f8789ca7`
- `TASK_HEAD`: `d79de6bb6b10bce9ffd4238b071656cf7089db88`
- BASE..HEAD name-only: exact `tests/lib/session-path-race-driver.py`
- BASE..HEAD numstat: `16  0  tests/lib/session-path-race-driver.py`，总计`16 <= 400`
- BASE foundation blob: `45d3a7fddbe5caab086f28bf3355e0486cb97e18`
- BASE provider blob: `b859b2fcde3fc18b0578d5a21f575c47525033e6`
- 03a2 branch、worktree、spec目录和work目录均缺席。
- 实现worktree最终`git status --porcelain`为`0B`，clean。

## Concerns

None. Task 2–5 intentionally remain unimplemented; their correct-arity CLI calls stay at the specified deterministic rc1 seam.
