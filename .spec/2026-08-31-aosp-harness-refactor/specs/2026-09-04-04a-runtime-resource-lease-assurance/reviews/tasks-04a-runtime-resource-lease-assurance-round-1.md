# 04a tasks review — round 1

## 结论

**FAIL**

计数：Blocking **1** / Important **1** / Minor **0**

审查对象：`tasks.md`（SHA-256 `bca7bcd3a744517699a551d425d47adb12502a196fce717568fb29de4e756f54`）。本轮复用已 PASS 的 design reviewer 上下文，独立对照当前 requirements、design、PLAN v5.9、最终熔断融合报告与两个 runnable prototype；未修改 tasks、源码或 prototype。

## 机械检查

- `check-tasks.py tasks.md`：rc0。
- 共四个必需任务，编号为 `1,2,3,4`；每个任务均有文件/消费/产出/需求/必需五字段和具体失败验证。
- 四任务需求并集逐字等于 R1–R10；内部产出/消费链为 `resource-lease-final-attempt-v1 -> resource-lease-assurance-v1 -> resource-lease-assurance-checkouts-v1 -> 终交付摘要`，没有孤儿产出。
- 源码边界只有任务1修改 provider、任务2创建 assurance；任务3/4为零源码 delta。manifest 设计为四行六列：任务1 `BASE->H1`、任务2 `H1->H2`、任务3 `H2->H2`、任务4 `H2->H2`；所给 awk 能核序号、任务ID、40位 SHA、首尾、相邻连续、reviewer 与全 PASS。
- 任务1/2均采用与已审 prototype 的 byte-identical 机械安装、numstat/static/source/运行复核，单次上下文可完成，diff review 可在 10 分钟内用 blob identity 和窄 diff 完成；任务3/4是日志与门禁审计，粒度成立。
- 文档明确本项目只要求清晰本地 commit，不套用组织 commit 模板；各任务未出现组织五段式字段或要求。

## Blocking

### B1 — 任务1的 red/green 同构树缺少 assurance 强制读取的两个已验收输入，预期 monotonic oracle 不可到达

证据：`tasks.md:34` 要求 repo 外同构树“放入当前production provider与prototype assurance”，`tasks.md:37` 又要求“只复制production provider与prototype assurance”。但最终 prototype 在 `test-resource-leases-assurance.sh:98`、远早于 monotonic oracle `:355-356`，无条件执行：

```bash
tracked_before=$(sha256sum "$provider" "$here/../docs/resource-leases.md" "$here/test-resource-leases.sh") || fail 'tracked inputs'
```

按任务原文只复制这两个文件独立复现得到 rc1，stderr 首行为：

```text
sha256sum: /tmp/review-04a-task1-red.*/tests/../docs/resource-leases.md: No such file or directory
```

因此 red 不会以逐字 `FAIL monotonic attempt count` 为首错，也不会形成一次 `flock` 证据；同样的遗漏会让步骤4的修复后 green 在进入 monotonic 场景前以 `tracked inputs` 失败。任务1当前不可按写定验收，且这个红不是目标缺陷导致的真红。

最小修法：把步骤1和步骤4的同构树输入改为四个文件：相应版本的 provider、prototype assurance、当前 accepted `docs/resource-leases.md`、当前 accepted `tests/test-resource-leases.sh`，路径必须分别落到 `common/.harness/lib/`、`tests/`、`docs/` 的真实顶层布局。明确用固定 `/tmp/aosp-harness-lease-assurance-task1.XXXXXX` 或等价唯一前缀创建外部树，先核绝对前缀与 repo 外边界，再安装 trap/删除；red 后逐字核首个专属失败及 `flock=1`，green 后核唯一摘要及 `flock=2`。

## Important

### I1 — depth-1 步骤要求“exact两文件”，但未给出在 BASE 对象不存在时可执行的判据

证据：`tasks.md:70` 先要求真实 `--depth 1` clone、`commit count=1` 与非空 shallow marker，随后要求在该 checkout “核…exact两文件”。本 reviewer 独立运行这两种 clone 命令，`--no-local` full 与 `file://... --depth 1` 均可创建，depth-1 的 commit count 确为1且 shallow marker非空；但这也意味着 execution `BASE_SHA` 不在 shallow object graph 中。若沿用本片在 candidate/full 使用的 `git diff "$BASE_SHA" "$ACCEPTED_HEAD"` exact 判据，depth-1 会因未知 BASE object 失败，而 tasks 没有规定替代命令。执行者只能临时决定“exact”在 shallow checkout 中是什么意思。

最小修法：保留 BASE..HEAD exact2/400 的机械判定在 candidate 和 full clone；把 depth-1 的该短语改成可执行的 blob/树一致性判据，例如在确认 `HEAD=$ACCEPTED_HEAD` 后分别 `cmp -s` 两个交付文件与只读 prototype，并核 docs/base-test 与 candidate 记录的 SHA-256 相同、`git status --porcelain`为空。若仍要在 depth-1 内重算 BASE diff，则必须明确只读获取 BASE object 的命令及其对 `commit count=1`、shallow marker 不变量的影响。

## 已通过的专项核查

- 任务2的 red 是目标入口物理缺席导致的 `cmp` 非零，不写源码；机械复制后只产生 `396/0` 单文件提交，并在累计门核 `2+2+396=400`，不会扩出第三个源码文件。
- 任务2把 active/all、真实 absent、damaged、生命周期 fault 与四个专属 mutant oracle都绑定到 byte-identical prototype；生命周期伪 helper 只建在 repo 外并要求 controller 核前缀后清理。
- full clone 与真实 `file://... --depth 1` clone 命令本身可执行；rollback 恢复 provider BASE blob、删除 assurance 后，其源码树与 BASE 相同的设计成立，04基础、03e、offline、入口发现0及上游零diff的判据齐全。
- 任务4覆盖 05 五类资产：日期前缀 spec 目录、`spec/` branch、worktree、ledger execution BASE、dispatch；`rg` 的 0/1/>1 三态也已明确，且终验收再次重跑该门。inert PASS 没有被用于解除 05/06/08 顺序门。

## 最终裁定

**FAIL — B=1, I=1, M=0。** 修正任务1同构树的四文件输入，并把 depth-1 的 exact 声明替换为无需 BASE object 的明确命令后，可做增量复审；其余任务粒度、exact2源码边界、manifest、需求全集、顺序门与个人项目提交约束成立。
