# Task 1.3 report

Status: DONE

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.3-red.txt

- BASE: `c226a238189fda96e7130cf5cedc9e1bdbe6f8fa`
- HEAD: `2fae1505f9d995edbc4a5cb5909075b56a06ba77`
- Commit: `2fae1505f9d995edbc4a5cb5909075b56a06ba77 test(harness): add resource lease contract`
- 唯一变更文件（TASK_BASE..HEAD）: `tests/test-resource-leases.sh`（新增 57 行）。未修改 provider、docs 或其他源码。

## RED

`bash ./tests/test-resource-leases.sh` 在入口缺席时返回 rc `127`；stdout 为 0 B、无 PASS；stderr 逐字为 `bash: ./tests/test-resource-leases.sh: No such file or directory\\n`（65 B）。

## Fixed checks and execution

- `/tmp/aosp-harness-tools-04/shfmt --version` 为逐字 `v3.14.0`；`shellcheck --version` 的 version field 为 `0.11.0`。
- `shfmt -d -i 2 -ci -bn tests/test-resource-leases.sh common/.harness/lib/resource-leases.sh`、`shellcheck -x --severity=warning`（同两文件）及 `bash -n`（同两文件）均 rc 0，双流空；日志见 `evidence/task-1.3-static.log`。
- `bash ./tests/test-resource-leases.sh` 与 `bash ./tests/test-resource-leases.sh all` 均 rc 0，stdout 逐字为 `RESULT PASS  resource leases\\n`（29 B），stderr 0 B；对应 `.out/.err` 证据已保存。
- `all extra`、`unknown`、`--x value` 均 rc 1，stdout/stderr 都是 0 B，且无 PASS；双流 SHA-256 均为空流 hash，见 `evidence/task-1.3-invalid.log`。
- 仅含测试入口且没有 provider 的临时 surface 为 rc 1、双流 0 B、无 PASS，见 `evidence/task-1.3-absent.log`。

## Basic matrix and sizing

基础入口已实际运行并通过其 source exact surface、33-byte token framing、逆序同 token 重入、换 session rc2、异 owner rc3、不相交 bundle、dead-owner stale 回收、空 request rc2、自洽非法 stored record rc2、tombstone 恢复、版本探针后假 Python rc2，以及 release 后完整 inventory allowlist oracle。

三个 final 文件分别与批准 prototype `cmp -s` 一致，行数为 `336 + 7 + 57 = 400`：provider、docs、测试入口都为 rc 0 一致。

`git diff --name-status c226a238189fda96e7130cf5cedc9e1bdbe6f8fa 2fae1505f9d995edbc4a5cb5909075b56a06ba77` 的实际结果是 `A tests/test-resource-leases.sh`；`git diff --numstat c226a238189fda96e7130cf5cedc9e1bdbe6f8fa 2fae1505f9d995edbc4a5cb5909075b56a06ba77` 是 `57 0 tests/test-resource-leases.sh`，总和 `57`。worktree `git status --short` 为 0 行（clean）。

## Concern

给定 TASK_BASE 是 task 1.2 的 `c226a238...`，并且本任务被明确限制为只新增测试、不得修改既有 provider/docs、不得 amend 前序 commit，因此无法同时让该 BASE..HEAD 包含三个新增文件或 numstat 总和为 400；实际可验证的 cumulative exact3/400 是 HEAD 工作树的三个 prototype-identical 文件，TASK_BASE..HEAD 则正确地仅为本任务的 57 行测试提交。未执行 review、ledger、manifest 或后续任务。

## Fix round 1

Status: PASS

修复轮1红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-1.3-fix1-red.txt

- Fix BASE: `2fae1505f9d995edbc4a5cb5909075b56a06ba77`
- Fix HEAD: `f7cfcb202d1fd2934d07cc90e333a4205b563243`
- Fix commit: `f7cfcb202d1fd2934d07cc90e333a4205b563243 test(harness): harden resource lease matrix`
- 唯一源码修改: `tests/test-resource-leases.sh`；批准 prototype 同步为逐字相同内容。provider、docs、API 与 spec 正文未改。

RED 在 fix BASE 上真实复现：reentry product mutant rc 0、stdout 精确 `RESULT PASS  resource leases\\n`、stderr 0 B；stale product mutant 同为 rc 0 和该 PASS；`TMPDIR=.` default 为 rc 2、双流 0 B、无 PASS。完整命令结果与 mutant 定义保存于上述 RED 证据。

GREEN：reentry mutant 与 stale mutant 分别为 rc 1、stdout/stderr 均 0 B、无 PASS。`TMPDIR=. bash ./tests/test-resource-leases.sh` 与其 `all` 变体均 rc 0、stdout 逐字 `RESULT PASS  resource leases\\n`（29 B、SHA-256 `91cc39b0d798a121e52ca21cb7aa42970725c9afa25229a4b99d782cf79a821b`）、stderr 0 B。fixture canonicalization 后的 trace 显示传入 provider 的 `HARNESS_RESOURCE_LEASE_ROOT` 是以 `/home/.../tmp.*/state` 开头的绝对路径；测试随后取消继承的 `TMPDIR`，使 provider 的私有 capture 也不接受相对临时目录。

固定 `shfmt v3.14.0`、ShellCheck version field `0.11.0`、`shfmt -d -i 2 -ci -bn`、`shellcheck -x --severity=warning` 和 `bash -n` 均 rc 0。default/all、三个 invalid argv（均 rc 1、双流 0 B、无 PASS）、test-only dependency-absent（rc 1、双流 0 B、无 PASS）和基础矩阵均通过。

三个 final 文件仍逐字 cmp approved prototype，行数 `336+7+57=400`。execution base `692d52d00b56df9609760aa33a6f9aa3c38095a3` 到 fix HEAD 的 name-status 是三个 `A` 文件，numstat 为 `336+7+57=400`；fix BASE 到 fix HEAD 仅 `tests/test-resource-leases.sh` 为 `9/9`。`git diff --check` 通过，worktree clean。
