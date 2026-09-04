# 04a requirements review — round 3

结论：**FAIL**

计数：Blocking **1** / Important **1** / Minor **0**

本轮只增量复核 round 2 的 B1/B2/I1，并确认 round 1 已闭合项没有回归。fixed tools、default、all、真实 absent 与 requirements 机械检查均由本 reviewer 独立重跑。

## Round 2 finding 闭合表

| Round 2 | 结论 | 本轮证据 |
|---|---|---|
| B1：default provider 路径错误、override 污染 absent | **已闭合** | `repo=$here/..`，默认 provider 为 `$repo/common/.harness/lib/resource-leases.sh`；父 default/all 在进入 active 前机械核对精确默认路径、普通文件、非 symlink。内部 surface 改为顶层 `tests/`/`common/` 布局并以 `env -u HARNESS_ASSURANCE_PROVIDER` 执行真实 absent 三入口。独立 default/all 均约 30 秒后 rc0、唯一 PASS；不再是快速 inert PASS。 |
| B2：fixture/mutant 可错因假绿 | **主体已闭合，生命周期与后台 marker 尚未完全闭合** | request/control/alias/record/helper 等父进程承重 fixture 均已有显式失败收口；三个 production mutant 由 Python 断言唯一 anchor 后替换并通过 `provider_state`，四个 child 的 stderr 又逐字匹配专属首个失败标签。仍有顶层临时树创建/EXIT 清理和后台 marker/adapter 改写未收口，见 B1/I1。 |
| I1：unpublish 只删 no-op seam | **已闭合** | unpublish mutant 现在唯一替换真实状态转换 `os.replace(path, trash)` 为 `os.replace(path, path)`，健康 source 后逐字命中 `FAIL disjoint release rc=2`；不再以 test seam 缺失充当 production mutation。 |

## Blocking

### B1 — 顶层临时树生命周期仍可在清理失败时发布 PASS，未满足 R8 的零外部残留门

修订后的 `requirements.md:33,53,61` 明确要求每个承重 fixture 的创建/改写/清理失败立即以专属失败退出，且 assurance 对 repo root 外状态的修改次数为 0。prototype 的最外层生命周期仍是：

```bash
tmp=$(mktemp -d /tmp/aosp-harness-lease-assurance.XXXXXX)
[[ $tmp != "$repo"/* ]] || exit 1
trap 'rm -rf -- "$tmp"' EXIT
...
pass() {
  printf '%s\n' "$summary"
  exit 0
}
```

这里有两个承重缺口：

- `mktemp -d` 失败没有被检查；空 `tmp` 会继续进入路径判断与后续绝对 `/provider.out`、`/surface` 等路径拼接，而不是立即以 fixture 创建失败退出。
- 成功路径先打印 PASS/`exit 0`，之后才执行一个不检查 rc、也不验证目录消失的 EXIT trap。若 `rm -rf` 部分或全部失败，脚本仍可保留 PASS 与 rc0并遗留 repo 外临时树；这正是第三不变量要排除的状态。

因此 round 2 B2 所称“所有承重 fixture cleanup 显式收口”尚未成立，tracked 三文件 hash 相同也不能证明临时树已经清除。必须先检查 `mktemp` 成功、绝对路径/0700/owner/空目录属性，并在打印 PASS 前执行可验证的 cleanup（删除成功且路径物理缺席）；EXIT trap 可保留作失败路径兜底，但不能作为成功门的唯一清理证据。

## Important

### I1 — concurrency readiness 与 adapter mutant 改写仍未“立即、专属”收口

父进程的大部分压缩链已修复，但以下承重操作仍没有检查自身结果：

- holder child 中写 `adapter_log` 与 `holder_ready`（prototype `:201`）；`holder_ready` 创建失败而 gate 仍存在时，父进程的 startup loop 可一直看到 child 存活并挂到外层 timeout，而不是专属 fixture failure。
- waiter child 的 `waiter_ready`（`:221`）和 clock-holder child 的 `clock-ready`（`:352`）没有 `|| exit`/专属诊断；clock gate 同样可能使失败 child 长时间存活。
- adapter mutant 对 `instance-mode.tsv` 的关键改写（`:209`）没有收口。写失败最终通常会由父层“mutant survived”捕获，不会形成本轮正常 PASS，但它不是 R8 所要求的立即、专属 fixture 改写失败。

这些问题目前没有让独立正常运行假绿，故定为 Important；但 requirements 已把“每个承重 fixture 创建/改写/清理立即专属失败”写成硬合同，不能用稍后的 timeout 或另一个 oracle 间接代替。应在 child 中用确定的非零退出/诊断，并让父进程有界等待后映射为专属标签；adapter 改写应直接 `|| fail`。

## 已通过的独立验证

```text
shfmt v3.14.0: PASS
ShellCheck version field 0.11.0: PASS
bash -n: PASS
assurance fixed-shfmt lines: 396
provider numstat: 2/2
total churn: 2+2+396=400
default active: rc=0, stdout="RESULT PASS  resource lease assurance\n", stderr empty
all active: rc=0, stdout="RESULT PASS  resource lease assurance\n", stderr empty
physical-absent --dependency-absent: rc=0, 38-byte fixed stdout, stderr empty
check-req.py: PASS
check-criteria.py: PASS
check-analyze.py: PASS
```

由于 default/all 的父进程 route guard 已通过，这两次 PASS 可以确认 active 矩阵、七类 damaged provider、三个真实 absent surface、同 owner 异 mode、tracked hash 和四个 mutant 都实际执行。四个 mutant 的正常自反证链也已足够排除“provider validation 等其他错因被接受”：构造检查唯一 anchor，变异 provider 先健康 source，stderr 再逐字匹配 `stored overlap`、`disjoint release`、`same owner subset`、`adapter command count` 四个专属标签且 stdout 空。

## Round 1 闭合项回归检查

- 全局预算继续按 churn 计数，未回退 additions-only。
- damaged provider、三入口真实 absent、同 owner 异 mode、tracked hashes/repo 外 temp、invalid/damaged/mutant 双流均仍在 requirements 与 prototype 中。
- 分类仍为三类 production mutant + 一类 fake-adapter key-selection fixture mutant；unpublish 已是真实 production 状态转换 mutation。
- Deadline 的最后一次无 sleep flock 与锁后零 record/stale/publish 控制流没有变化。
- candidate/full/depth-1/rollback/NEXT 五类门及四不变量没有回归。

## 最终裁定

**FAIL — B=1, I=1, M=0。** active/inert 路由、预算和 mutant 专属 oracle 已成立；只需再闭合 assurance 自身临时树的成功前清理证明，以及后台 readiness/adapter 改写的立即专属失败路径，即可进入下一轮。
