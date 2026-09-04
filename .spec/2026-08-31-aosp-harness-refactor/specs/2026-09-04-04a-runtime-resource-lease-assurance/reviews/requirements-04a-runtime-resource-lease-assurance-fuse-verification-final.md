# 04a requirements 熔断融合验证 — final

## 最终结论

**可按熔断融合裁定放行 PASS (0/0/0)**

本文件是达到 `fix_loop_max=3` 后对最终 artifact 的只读融合验证，不构成 requirements 第 4 轮改写 review。

## Round 3 B1：顶层临时树生命周期

结论：已按精确修法闭合。

- `mktemp -d /tmp/aosp-harness-lease-assurance.XXXXXX` 失败立即输出专属 `FAIL temporary tree fixture` 并 rc1。
- 创建后先用 `find` 验空，再同时验证 `/tmp/aosp-harness-lease-assurance.*` 绝对形状、非 repo 子路径、普通非 symlink 目录、`EUID:700` 与空目录属性，验证通过后才安装清理 trap。
- 失败路径 EXIT trap 保留原 rc；若 `rm -rf` 失败或路径仍物理存在，则追加 `FAIL temporary tree cleanup` 并把最终 rc 收敛为 1。
- 成功 `pass()` 在打印摘要前执行删除并核 `! -e && ! -L`；删除失败时撤销重复 trap 后以专属 cleanup failure/rc1 退出，不会先发布 PASS。

独立 fault 验证：

```text
fail-mktemp rc=1 stdout= stderr=FAIL temporary tree fixture
fail-rm-pass rc=1 stdout= stderr=FAIL temporary tree cleanup
fail-rm-error rc=1 stdout= stderr=FAIL provider validation | FAIL temporary tree cleanup
```

其中 `fail-rm-pass` 使用“实际删除目标但返回 1”的独立 Bash function 注入，证明成功路径依据 cleanup rc 拒绝发布 PASS；`fail-rm-error` 证明既有失败与 EXIT cleanup 失败融合后仍为 rc1、无 stdout/PASS。

## Round 3 I1：readiness marker 与 adapter 改写

结论：已按精确修法闭合。

- holder child 的 adapter log 与 `holder_ready` 写入分别 `|| exit 91/92`；marker 未出现时父循环在 child 消失后以 `FAIL holder startup` 专属收口。
- waiter child 的 `waiter_ready` 写入 `|| exit 91`；父循环映射为 `FAIL waiter startup`。
- clock holder 的 readiness 写入 `|| exit 91`；父循环映射为 `FAIL clock holder`。
- adapter mutant 的 `instance-mode.tsv` 改写位于显式 `if` 中，并以 `|| fail 'adapter mutant fixture'` 立即专属收口。

这些分支不再依赖后序 rc2、timeout 或 mutant-survived oracle 间接发现 fixture 错误。

## Active / inert 路由

结论：通过。

- repo root 由顶层 `tests/` 的 `here/..` 得出，默认 provider 为 `$repo/common/.harness/lib/resource-leases.sh`。
- 顶层 default/all 在 active 矩阵前机械确认 provider 是 repo 内精确默认路径、普通文件且非 symlink；因此固定 PASS 不能由顶层 inert 路径伪造。
- 内部 absent surface 使用真实顶层 `tests/`/`common/` 布局，并通过 `env -u HARNESS_ASSURANCE_PROVIDER` 清除 override；default、all、`--dependency-absent` 三入口执行真实 absent。

独立执行结果：

```text
default active: rc=0, stdout=RESULT PASS  resource lease assurance, stderr empty
all active: rc=0, stdout=RESULT PASS  resource lease assurance, stderr empty
physical absent --dependency-absent: rc=0, stdout=RESULT PASS  resource lease assurance, stderr empty
```

default/all 均运行完整 active 矩阵约 30 秒，不是先前的快速 inert PASS。

## Mutant 专属 oracle

结论：通过。

- overlap、真实 unpublish 与 bundle 三个 production mutant 均由 Python 先断言目标 anchor 恰一次，再只替换该 anchor，并经 `provider_state` 验证可静默 source。
- unpublish 真实把 `os.replace(path, trash)` 改为 `os.replace(path, path)`，不再删除 no-op test seam。
- fake-adapter fixture mutant 使用成功 `cp` 的 candidate provider，不修改 production provider 文本。
- 四者的 child 必须非零、stdout 空，stderr 分别逐字为：

```text
FAIL stored overlap rc=0
FAIL disjoint release rc=2
FAIL same owner subset rc=0
FAIL adapter command count
```

独立 default/all 完整 PASS 也机械证明四个 child 均到达并匹配各自专属首个失败标签；任意 provider-validation 等错因不能通过逐字 `cmp`。

## 预算、静态门与机械检查

```text
provider numstat: 2 additions / 2 deletions
assurance fixed-shfmt lines: 396
total churn: 2+2+396=400
shfmt v3.14.0: PASS
ShellCheck version field 0.11.0: PASS
bash -n: PASS
check-req.py: PASS
check-criteria.py: PASS
check-analyze.py: PASS
```

provider diff 仍只有 deadline 相邻两行；docs 与 04 基础测试 prototype 仍与已验收文件逐字相同。tracked provider/docs/base-test 前后 SHA-256、repo 外 fixture、七类 damaged provider、同 owner 异 mode、CLI 双流、三类 production mutant与 fake-adapter 分类均未回归。

## 融合裁定

Round 3 的 B1/I1 已闭合，round 2 的 active/inert route、mutant 错因与真实 unpublish 已闭合，round 1 的 churn、矩阵、双流和分类修订未回归。没有剩余 Blocking、Important 或 Minor finding。

**可按熔断融合裁定放行 PASS (0/0/0)**
