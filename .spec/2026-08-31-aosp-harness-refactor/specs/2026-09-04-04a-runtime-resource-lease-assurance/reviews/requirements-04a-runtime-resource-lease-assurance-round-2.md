# 04a requirements review — round 2

结论：**FAIL**

计数：Blocking **2** / Important **1** / Minor **0**

本轮只复核 round 1 的 B1/B2/I1/I2 闭合情况，并独立运行 fixed tools 与 prototype 三入口。

## Round 1 finding 闭合表

| Round 1 | 结论 | 本轮证据 |
|---|---|---|
| B1：预算把 deletion 漏计 | **已闭合** | PLAN v5.9、DECISIONS、R1/R9、验收清单均统一为 provider `2/2` + assurance `396/0`，churn 为 `2+2+396=400`。当前 prototype provider 相对生产 provider 的真实 `git diff --no-index --numstat` 也是 `2/2`，assurance 为 fixed-shfmt 396 行。 |
| B2：398 行 prototype 未执行完整负向矩阵 | **未闭合** | 缺项在文本和脚本中大多已补入，但默认 provider 路径使目标交付布局中的 default/all 实际走 inert PASS；显式指定 active provider 又因变量泄漏使内部 absent fixture 失败。另有压缩链与 mutant 的假绿，见 B1/B2。 |
| I1：失败双流未钉死 | **已闭合** | R3 已固定 invalid CLI 双流空、damaged provider rc1/空 stdout/逐字 `FAIL provider validation\n`；R8 已固定 mutant 非零、空 stdout、stderr 含 FAIL 且不得含固定 PASS。脚本也有对应比较。 |
| I2：adapter mutant 命名越界 | **文本已闭合** | R8/验收清单现区分三类 production mutant 与一类 fake-adapter key-selection fixture mutant，未再把不存在的 production adapter 当 mutation target。实际 unpublish mutant 仍不具 production 语义，另列 I1。 |

## Blocking

### B1 — default/all 在真实交付路径会把健康 provider 误判为缺席并 inert PASS

prototype `tests/test-resource-leases-assurance.sh:17-20` 已正确把 repo 算为 `here/..`，但 provider 仍写成：

```bash
provider=${HARNESS_ASSURANCE_PROVIDER:-$here/../../common/.harness/lib/resource-leases.sh}
```

本片的真实目标是仓库顶层 `tests/test-resource-leases-assurance.sh`。从该位置，`$here/../../common` 指向“仓库父目录/common”，而不是仓库内的 `common`；正确关系应基于已求得的 repo root。当前 prototypes 目录也能直接复现：

```text
default rc=0 stdout=RESULT PASS  resource lease assurance stderr=
all     rc=0 stdout=RESULT PASS  resource lease assurance stderr=
resolved provider=.../04a-runtime-resource-lease-assurance/common/.harness/lib/resource-leases.sh
actual provider=.../04a-runtime-resource-lease-assurance/prototypes/common/.harness/lib/resource-leases.sh
```

两个 PASS 都是 provider 不存在后的 inert PASS，完整 active 矩阵零执行。若用 `HARNESS_ASSURANCE_PROVIDER=<patched prototype provider>` 强制 active，外层变量会继承到脚本内部构造的 absent surface；default/all 均在该 surface 处失败：

```text
default rc=1 stdout= stderr=FAIL absent provider execution
all     rc=1 stdout= stderr=FAIL absent provider execution
```

真实缺席并传 `--dependency-absent` 可 rc0/固定 PASS，但不能替代 dependency-present。由此，boundary 中“default/all active PASS”和 R8/R9 的 active prototype 证明在预定交付布局不可复现，round 1 B2 仍然阻断。

修复时应让 prototype 与最终目标使用同一顶层布局（`tests/`、`common/`、`docs/`），从 `repo=$here/..` 派生 provider，并确保内部 absent fixture 显式清除 provider override 或根本不依赖继承环境。修复后须证明 default/all 的 provider 是普通文件且 SHA 与 candidate 相同，再开始矩阵；不能只凭最终摘要判断 active。

### B2 — 压缩链与 mutant harness 仍允许错误原因被当成目标 oracle，存在可构造假绿

ledger 的裁定声称“所有压缩链以显式 `|| fail` 收口”，脚本并不满足：

- `:169-172` 的 control-byte fixture 使用 `mkdir ... && ln ...`，两者失败都未收口；链接缺失时 provider 同样返回 rc2，后续 `invoke` 会把 fixture 构造失败误判为 control-byte 拒绝成功。复用的 `control-link` 删除失败也会让后续字节 case 继续命中旧链接而假绿。
- `:176-178` 的两个 alias symlink 创建没有 `|| fail`；任一链接缺失时 `realpath` 失败仍是预期 rc2，因此 canonical-alias duplicate oracle 可假绿。
- `:314-317` 改写 fake Python 未检查写入成功。若改写失败，上一版“fake worker”仍返回 rc2，capture-disappearance case 会按同一 rc2/双流通过。
- `:384-390` 的 production mutant 构造没有验证 sed anchor 命中一次、输出可 source 且仅发生预期 diff。mutant child 只要以任意 `FAIL ` 非零结束就被接受；构造出空/损坏 provider 时的 `FAIL provider validation` 也会被当成 mutant 被杀死，而不必到达 overlap/unpublish/bundle 的预期 oracle。

这些路径直接违背“完整保证 + 自反证”的用途，也正是 round 1 要求防止的压缩假绿。每个承重 fixture 构造必须显式失败收口；每个 mutant 必须先证明唯一 anchor/唯一预期 diff、健康 source surface，再核对该 mutant 的专属失败标签，而不是接受任意 `FAIL `。

## Important

### I1 — 所谓 unpublish production mutant 只删除 no-op test seam，不是生产语义变异

当前 `:385` 的 unpublish mutant 是：

```bash
sed 's/test_seam("unpublish"); //' "$provider"
```

健康 production provider 中 `test_seam` 是 no-op；删除这次调用不会改变未注入环境下的 publish/unpublish 行为，只会让 assurance 的 fault injection 不再触发。它可以反证“测试 seam 被调用”，但不能称为 production unpublish mutant，也不能证明 oracle 会杀死跳过/错误执行 `os.replace(path, trash)` 的生产缺陷。

应将 mutation target 改成真实 unpublish 状态转换，并要求专属 oracle（例如 release 不得成功、active/tombstone 后置状态不符）；或者把它改名为 seam-wiring mutant，且另补真正的 unpublish production mutant。前者更符合当前 R8 的三类 production mutant 合同。

## 独立执行结果

固定静态门：

```text
STATIC=PASS shfmt=v3.14.0 shellcheck=0.11.0 bash-n=PASS lines=396
provider numstat=2/2
docs prototype == tracked docs
base-test prototype == tracked base test
```

入口结果：

```text
直接 default: rc0，固定 PASS，实际为 provider-path 错误后的 inert
直接 all: rc0，固定 PASS，实际为 provider-path 错误后的 inert
真实 absent --dependency-absent: rc0，stdout 固定 PASS，stderr 空
显式 provider 的 default/all: rc1，stderr 为 FAIL absent provider execution
```

因此不能采信 `requirements-prototype-boundary.md:43-57` 所写的 active/default/all 全 PASS 作为当前 396 行目标布局证据。

## 保持成立的判断

- Deadline 相邻两行的控制流仍成立：到期 `continue` 后不 sleep，下一轮执行最后一次 flock；取得锁后既有 deadline 检查在 `recover_trash`、active-record decode 和 publish 之前返回 rc3。
- R1-R10 的 candidate/full/depth-1/rollback/NEXT 五类门、全 PASS manifest 和四不变量文本没有新冲突。
- 预算口径、CLI/damaged/mutant 双流合同，以及 fake-adapter fixture mutant 的分类文字已经按 round 1 修正。

## 最终裁定

**FAIL — B=2, I=1, M=0。** 修正目标布局的 provider/absent fixture 路由、全部承重 fixture 的失败收口和 mutant 专属健康/失败证明，并重跑真正的 dependency-present default/all 后再复审。
