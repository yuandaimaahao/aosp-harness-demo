# Task 1.3 fix round 1 incremental re-review

## 结论

**PASS**

- Findings：**B/I/M = 0/0/1**
- 增量范围：`2fae1505f9d995edbc4a5cb5909075b56a06ba77..f7cfcb202d1fd2934d07cc90e333a4205b563243`
- 原 B1、I1 均已关闭；未发现新的阻断或重要缺陷。

## 原 findings 关闭情况

### B1 — 已关闭 — R9

`tests/test-resource-leases.sh:30-31` 的 reentry 比较、`:38-39` 的 stale token 比较与 release 已拆成独立 simple command，不再位于 `&&` 左侧。

独立重建并运行 round 1 的两个 product mutant：

- reentry 分支返回 32 个零而非 active token：rc1，stdout 0 B，stderr 0 B，无 PASS；
- stale 回收返回已删除的旧 token 且不 publish：rc1，stdout 0 B，stderr 0 B，无 PASS。

两项均在目标断言处失败；后续 cleanup/inventory 不再有机会掩盖错误。B1 的“逆序同 token”与 stale oracle 已真实生效。

### I1 — 已关闭 — R9

测试先对 `mktemp -d` 的结果执行 `cd` + `pwd -P`，再导出 root，并取消继承的相对 `TMPDIR`，避免 provider 私有 capture 再次使用相对模板。

独立结果：

- `TMPDIR=. bash ./tests/test-resource-leases.sh`：rc0、stdout 精确 29 B PASS、stderr 0 B；
- `TMPDIR=. bash ./tests/test-resource-leases.sh all`：同上；
- 两个 stdout SHA-256 均为 `91cc39b0d798a121e52ca21cb7aa42970725c9afa25229a4b99d782cf79a821b`；
- 使用独立 xtrace fd 复核，实际传入 provider 的值形如 `/home/.../worktree/tmp.*/state`，以 `/` 开头并经过 `pwd -P`，是真实绝对 root；
- 两次运行后 worktree clean，说明相对 `TMPDIR` 下创建的 fixture 仍被 trap 清理。

I1 已关闭。

## 新 finding

### M1 — 次要 — 更新报告记录了不存在的 execution base

`task-1.3-report.md:53` 写 execution base 为 `ff3f15db48f7cf45675a544979cf512772348238`，但：

```text
git cat-file -e ff3f15db48f7cf45675a544979cf512772348238^{commit}
# rc 128
```

首个 runtime commit 的真实 parent、也是本轮可验证的 execution base 是 `692d52d00b56df9609760aa33a6f9aa3c38095a3`。从该 base 到 fix HEAD 的 diff 确为 exact 三个新增文件、`336+7+57=400`。这是报告审计标识错误，不影响当前提交内容或已复核的尺寸事实，故定为次要；建议把报告中的 hash 改回 `692d52d...`。

## 增量规格与质量复核

- Fix diff exact 只修改 `tests/test-resource-leases.sh`，numstat `9/9`；未改 provider/docs/API。
- 压缩到 57 行引入的 fixture `&&` 未形成新假绿：`mkdir` 与第二个 `printf` 都是列表末项；第一个 `printf` 若失败会使对应必要 fixture 缺席，后续未被条件包裹的 acquire 会失败。正常完整矩阵独立运行通过。
- 默认/all 均 rc0、stdout 精确固定 PASS、stderr 0 B。
- `all extra`、`unknown`、`--x value` 均 rc1、双流 0 B、无 PASS。
- test-only dependency-absent surface rc1、双流 0 B、无 PASS。
- tombstone cleanup、fake Python 收敛与最终 inventory 回归通过；最终 assurance 测试仍缺席。
- 三个 final 文件与批准 prototype 分别 `cmp -s` rc0；行数 `336+7+57=400`。
- 从正确 execution base `692d52d...` 到 HEAD 的 name-status exact 为三个 `A` 文件，numstat exact 400。
- fixed shfmt 逐字 `v3.14.0`、ShellCheck version field `0.11.0`；shfmt diff、ShellCheck warning、bash-n 均 rc0 且双流空。
- `git diff --check` rc0；目标 worktree `git status --short` 0 行。

## 最终判定

B1/I1 修复符合 R9，且未损坏 R10 的 57 行、prototype、exact3/400、静态与运行门。M1 不阻塞本轮通过，应作为次要审计修正进入 ledger/收口处理。
