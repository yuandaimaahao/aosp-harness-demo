# Task 1.3 independent diff review — round 1

## 结论

**FAIL**

- Findings：**B/I/M = 1/1/0**
- 审查范围：`c226a238189fda96e7130cf5cedc9e1bdbe6f8fa..2fae1505f9d995edbc4a5cb5909075b56a06ba77`
- 任务提交：`2fae1505f9d995edbc4a5cb5909075b56a06ba77 test(harness): add resource lease contract`
- 提供的 task brief 没有 `## R→E 映射` 或 E-ID；本报告不伪造 E-ID，按其中明确列出的 R9、R10 逐项审查。

## Findings

### B1 — 阻断 — R9：两个必需矩阵 oracle 可在行为错误时假绿

位置：`tests/test-resource-leases.sh:32`、`tests/test-resource-leases.sh:39`。

脚本把关键断言写成：

```bash
cmp -s "$tmp/reentry" "$tmp/token" && [[ ... ]]
[[ $stale != "$fresh" ]] && harness_lease_release "$fresh"
```

在 `set -e` 下，`&&` 列表中除最后一个命令外的失败属于 errexit 例外。因此：

- reentry token 不同时，`cmp` 返回 1，但脚本继续；
- stale 与 fresh token 相同时，`[[ ... ]]` 返回 1，但脚本继续且跳过 release。

两个定点 product mutant 都独立复现了假绿：

1. 仅把 provider 的 reentry 分支输出从现有 token 改成 `"0" * 32 + "\n"`，不改变 active record；运行测试得到 `rc=0`、stdout 精确 `RESULT PASS  resource leases\n`、stderr 0 B。
2. 仅在 stale record 被删除后的 `session == "fresh"` 路径输出刚删除的旧 token 并返回、不 publish 新 record；运行测试同样得到 `rc=0`、相同唯一 PASS、stderr 0 B。

这直接违反 R9 的“逆序 request 的同 token 完整重入”和“死 owner stale 回收”必须由基础矩阵真实验证的要求。后续测试不能替代这两个 oracle：第一个 mutant 保持状态正确而只破坏 public token；第二个 mutant 不遗留 inventory 资产。

建议修复：把两个断言改为能独立传播失败的 simple command（例如分别写 `cmp -s ...` 和 `[[ ... ]]`），release 另起一条命令；不要依赖 `&&` 左侧触发 errexit。修复后用上述两个 mutant 回归，预期均 rc 非 0 且无 PASS。

### I1 — 重要 — R9：状态根不保证是绝对路径

位置：`tests/test-resource-leases.sh:7-10`。

`tmp=$(mktemp -d)` 会遵循调用者的 `TMPDIR`。当它是合法但相对的目录时，GNU `mktemp` 返回相对路径，随后导出的 `HARNESS_RESOURCE_LEASE_ROOT=$tmp/state` 也为相对路径，不满足 R9 明确要求的“独立 `mktemp -d` 的 `0700` 绝对路径”。

可复现：

```bash
TMPDIR=. mktemp -d
# 输出形如 ./tmp.Cak8xMSf6M，mode 0700，但不是绝对路径

TMPDIR=. bash ./tests/test-resource-leases.sh
# rc=2，stdout 0 B，stderr 0 B，无 PASS
```

建议修复：创建后通过进入该目录并 `pwd -P` 得到绝对路径，再导出 root；可在现有一行内完成以保持 57 行门限。修复后增加相对 `TMPDIR` 的定点执行。

## 规格符合性

### R9 — ❌

已确认以下项目确实执行并在当前 provider 上通过：source 后 `harness_*` exact surface 与 session marker 缺席；33-byte framing；同 owner 换 session rc2；foreign owner rc3 且原 token 后续可 release；disjoint acquire/release；空 request rc2；自洽非法 stored record 导致全局 rc2；合法 tombstone 恢复并最终清空；版本探针通过而 worker 任意 rc/双流的假 Python 收敛固定 rc2；最终 inventory 除 `.lock` 外为空；seam 在 provider 中恰一处且测试中引用 0 次；最终 `tests/test-resource-leases-assurance.sh` 缺席。

但 B1 证明“逆序同 token”和 stale 两项 oracle 并未可靠验证，I1 证明测试未无条件建立绝对状态根，因此 R9 不符合。

### R10 — ✅（task 1.3 所属部分）

- RED：BASE tree 中入口物理缺席；保存证据为 rc127、stdout 0 B、无 PASS。
- TASK_BASE..HEAD：exact 只新增 `tests/test-resource-leases.sh`，numstat `57 0`。
- EXEC_BASE..HEAD：exact 新增三文件，numstat `336+7+57=400`。
- 三个 final 文件分别与批准 prototype `cmp -s` rc0；测试为 57 行。
- fixed tools 独立复核：shfmt 逐字 `v3.14.0`，ShellCheck version field `0.11.0`；两 shell 的 shfmt/ShellCheck/bash-n 均 rc0、双流空。
- 当前未修源码的 default/all 均 rc0、stdout 29 B 且 SHA-256 为 `91cc39b0d798a121e52ca21cb7aa42970725c9afa25229a4b99d782cf79a821b`、stderr 0 B。
- `all extra`、`unknown`、`--x value` 均 rc1、双流 0 B；test-only dependency-absent surface rc1、双流 0 B；均无 PASS。
- `git diff --check` rc0，worktree `git status --short` 0 行。

candidate/full/depth-1/offline/rollback 与 NEXT 五类 controller 门属于简报明确列出的后续零源码验收，不是本次 57 行 task diff 的产物；本 review 未用它们掩盖 B1/I1。

## 质量结论

- YAGNI：未发现；diff 只新增指定测试文件。
- 验证真实性：**不通过**；B1 是可执行 product mutant 证明的假绿。
- 逐字复制：测试文件与批准 prototype 完全一致，未发现新增的重复逻辑块；prototype 相同不免除当前 diff 的 oracle 缺陷。
- 错误路径：rc2/rc3 固定 stderr、空 stdout、假 Python、非法 stored state、dependency-absent 和 invalid argv 均有实际判据；绝对临时根错误路径存在 I1。

## 最终判定

因 B1 为必需基础合同矩阵的承重 oracle 缺陷，本轮必须进入修复循环；修复 B1 与 I1 并重跑对应 mutant 后再 re-review。
