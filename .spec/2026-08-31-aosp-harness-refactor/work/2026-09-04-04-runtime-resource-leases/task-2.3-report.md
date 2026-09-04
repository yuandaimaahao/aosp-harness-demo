# task-2.3 report: exact rollback 与 03e 回归

Status: DONE

Commits: 临时 rollback commit `f8d815829c90619926ab08fa90d7a386993de89a`（仅存在于已清理的物理隔离 clone；implementation 未产生 commit）

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.3-red.txt

## RED 与 implementation 基线

- 在报告物理缺席时运行 `test -s "$WORK/task-2.3-report.md"`，rc `1`；`test -e` 同为 rc `1`。证据为 487 B，SHA-256 `4414bccd961f3de61ddc741616744e0be31d6dbb039b0e72796729e29a0ce59c`。
- implementation 运行前 HEAD 为 `f7cfcb202d1fd2934d07cc90e333a4205b563243`，逐字等于 `ACCEPTED_HEAD`，`git status --short` 为 0 行。

## 物理隔离 rollback commit

- 使用 `mktemp -d /tmp/aosp-harness-task-2.3-rollback.XXXXXX` 创建私有根 `/tmp/aosp-harness-task-2.3-rollback.XPE7ZG`，再执行 `git clone --no-local "$IMPLEMENTATION_WORKTREE" "$ROLLBACK_ROOT/checkout"`，rc `0`；clone HEAD 为 accepted HEAD，初始状态 clean。
- 在 clone 中创建 `task-2.3-exact-rollback` 分支，执行 `git rm -- common/.harness/lib/resource-leases.sh docs/resource-leases.md tests/test-resource-leases.sh` 并以普通 commit 提交；commit rc `0`，rollback commit 为 `f8d815829c90619926ab08fa90d7a386993de89a`，父提交为 accepted HEAD。
- `git diff-tree --no-commit-id --name-status -r HEAD` 逐字核得恰三行 `D`，路径集合 exact 等于 `common/.harness/lib/resource-leases.sh`、`docs/resource-leases.md`、`tests/test-resource-leases.sh`。
- `git diff --name-status 692d52d00b56df9609760aa33a6f9aa3c38095a3 HEAD` 输出为空：rollback HEAD 相对 `EXEC_BASE` 为 zero diff。

## rollback 回归

- `bash tests/test-claude-session-lifecycle.sh` → rc `0`。stdout 保存于 `evidence/task-2.3-rollback-lifecycle.out`，38 B，SHA-256 `d82576f80324213355380079d3e34e911bcb7d005a4b767cab2b43a4ca8ba16e`，逐字节为 `RESULT PASS  claude session lifecycle\n`；stderr 保存于对应 `.err`，0 B，SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。
- `bash ./scripts/check.sh --offline` → rc `0`。合并日志保存于 `evidence/task-2.3-rollback-offline.log`，574 B，SHA-256 `071b0476836d42654102fdcf089493d2b3dfb03ab2f9a19a546380dbcc97a047`；`RESULT PASS` 共 12 条、`RESULT FAIL` 0 条；`RESULT PASS  resource leases` 出现 0 次，`RESULT PASS  claude session lifecycle` 恰 1 次。
- rollback checkout 中 exact3 均经 `test ! -e` 核为物理缺席。
- `UPSTREAM03E` 六路径在 `EXEC_BASE..rollback HEAD` 的 `git diff --name-status` 输出为空；`git status --short` 为 0 行。

## cleanup 与零源码 delta

- 在删除前核 rollback checkout clean；随后对已逐字确认的 `/tmp/aosp-harness-task-2.3-rollback.XPE7ZG` 执行 `find "$ROLLBACK_ROOT" -depth -delete`，并以 `test ! -e "$ROLLBACK_ROOT"` rc `0` 证明整个临时根消失。
- implementation 运行后 HEAD 仍为 `f7cfcb202d1fd2934d07cc90e333a4205b563243`；`git diff --quiet`、`git diff --cached --quiet` 均 rc `0`，`git status --porcelain=v1` 为 0 行。implementation HEAD、index 与源码均未改变。
- 本任务未执行 review、ledger、manifest 或后续任务操作。

## Evidence package

`evidence/task-2.3-package.tsv` 汇总 RED、临时 rollback commit、exact3/3D/zero-diff、两项回归、物理缺席、UPSTREAM03E、clean、cleanup 与 implementation zero-source-delta 结论。

测试摘要: rollback lifecycle 与 offline gate 均 rc0；offline 12 PASS/0 FAIL，lease 摘要 0 次、03e 摘要 1 次；全部 exact rollback、zero-diff、clean 与 cleanup 断言 PASS。

顾虑: 无。
