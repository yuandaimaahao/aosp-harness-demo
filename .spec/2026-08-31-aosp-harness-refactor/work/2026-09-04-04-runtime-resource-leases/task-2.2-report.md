# task-2.2 report: 完整历史与真实 depth-1 checkout

Status: DONE

Commits: 无（本任务只读取 implementation worktree；未修改源码、index、HEAD 或创建 commit）

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-04-04-runtime-resource-leases/evidence/task-2.2-red.txt

## RED 与 implementation 基线

- 在报告物理缺席时执行 `test -s "$WORK/task-2.2-report.md"`，rc `1`；证据已保存为 `evidence/task-2.2-red.txt`（131 B，SHA-256 `13195b2866299e114f34e35cdf38aa411c662929e431353017dd85442963d1b0`）。
- implementation HEAD 在运行前后均为 `f7cfcb202d1fd2934d07cc90e333a4205b563243`，逐字匹配 `ACCEPTED_HEAD`。
- 运行前后 `git status --porcelain=v1` 均为 0 行，`git diff --quiet` 与 `git diff --cached --quiet` 均 rc `0`。

## 完整历史 clone

在私有 `mktemp -d` 根下执行 `git clone --no-local "$IMPLEMENTATION_WORKTREE" full`，clone rc `0`；`git -C full rev-parse HEAD` 为 accepted HEAD。

- `cd full && bash ./tests/test-resource-leases.sh` → rc `0`；`task-2.2-full-default.out` 为 29 B，SHA-256 `91cc39b0d798a121e52ca21cb7aa42970725c9afa25229a4b99d782cf79a821b`，逐字等于 `RESULT PASS  resource leases\n`；对应 stderr 为 0 B（空流 SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`）。
- `cd full && bash ./scripts/check.sh --offline` → rc `0`；日志 `task-2.2-full-offline.log` 为 603 B，SHA-256 `2c58ffd67925744312239804178e80401c2376395528499ea1c7e2c756da7a2a`，其中 `RESULT PASS  resource leases` 恰 `1` 次。
- `find full/tests -maxdepth 1 -type f -name test-resource-leases.sh | wc -l` 为 `1`；三文件均存在。`git diff --quiet`、`git diff --cached --quiet` 均 rc `0`，`git status --porcelain=v1` 为 0 行。

## 真实 depth-1 clone

在同一私有根下执行 `git clone --depth 1 "file://$IMPLEMENTATION_WORKTREE" depth1`，clone rc `0`；HEAD 为 accepted HEAD，`git rev-list --count HEAD` 为 `1`，`test -s depth1/.git/shallow` rc `0`。

- `cd depth1 && bash ./tests/test-resource-leases.sh` → rc `0`；`task-2.2-depth1-default.out` 为 29 B、SHA-256 `91cc39b0d798a121e52ca21cb7aa42970725c9afa25229a4b99d782cf79a821b`，逐字等于固定摘要；stderr 为 0 B、空流 SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。
- `cd depth1 && bash ./scripts/check.sh --offline` → rc `0`；`task-2.2-depth1-offline.log` 为 603 B、SHA-256 `2c58ffd67925744312239804178e80401c2376395528499ea1c7e2c756da7a2a`，其中 resource-leases 摘要恰 `1` 次。
- `find depth1/tests -maxdepth 1 -type f -name test-resource-leases.sh | wc -l` 为 `1`；exact3 三文件存在。`git diff --quiet`、`git diff --cached --quiet` 均 rc `0`，`git status --porcelain=v1` 为 0 行。

## 清理与范围

使用 `find /tmp/tmp.mhjCUgPYbN -depth -delete` 删除两个临时 clone；随后 `test ! -e /tmp/tmp.mhjCUgPYbN` rc `0`，临时根已不存在。未修改 implementation、未提交，且未执行 review、ledger、manifest 或任何后续任务操作。

## Evidence package

`evidence/task-2.2-package.tsv` 汇总 RED、full/depth1 四份运行日志、checkout 断言、临时目录清理和 implementation 前后不变结论。

测试摘要: full 与真实 depth-1 均完成 default/offline 四次运行；全部 rc0，固定摘要、离线发现计数、exact3、shallow、HEAD 与 clean 断言均 PASS。

顾虑: 无。
