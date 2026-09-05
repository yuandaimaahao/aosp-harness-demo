# 门⑤独立验收审查 r1

结论：PASS — B=0 / I=0 / M=0。

审查对象为当前 `acceptance-report.md`，实现候选固定为
`9e5edb45a3048e4c208e2d7fe135639768cc87db`，execution BASE 为
`65d67b52e5b34d0d9d2add587083ebf2fadcd3ea`。本轮仅读取规格、任务报告、
独立审查报告、green 日志和候选源码，执行只读 Git/文本机械对照及
`closeout-evidence.py`；未重跑 contract、offline、clone 或 rollback，未修改源码或规格。

## 审查中发现并已补证的问题

### I1（已闭合）：第三条不变量的 canonical INCOMPLETE 执行证据

位置：`acceptance-report.md:121`；对照 requirements 第三条不变量、R5，
以及 candidate `tests/test-verifier-contract.sh:75`。

初始报告写「strict INCOMPLETE/FAIL误作交付成功次数为0：terminal与rc联合断言、
offline门通过」。实际 102 行 base test 联合核对了完整 PASS/rc0 与 boot query
FAIL/rc1，但没有构造 package 缺席、断言 `RESULT INCOMPLETE`/rc2 的场景。
任务 1/2 review 对该测试的覆盖描述也只到 PASS、query FAIL 和 preflight。
offline 默认发现该相同测试；现有 device-safety 的探索断言针对旧入口，不能证明
新增 canonical provider 的 INCOMPLETE。green 的最终 candidate 重跑也只运行
这个 base test。

provider 的终态分支静态上实现了 INCOMPLETE/rc2，因此这不是已证实的产品行为
错误。controller 已在同次审查中补充验收层 probe：`DEMO_PACKAGE_LIST=''`
运行 canonical `--demo`，报告原样记录五条明细、`SUMMARY PASS=4 FAIL=0 SKIP=1`、
`RESULT INCOMPLETE`，以及 provider rc2、stderr空和交付PASS正则无匹配rc1。
第三条不变量现在明确将 FAIL 归属基础测试，将 INCOMPLETE 归属该只读 probe。
首次 oracle 明细猜测错误与修正后重跑均已披露；产品判据和源码没有变更，也没有
将05a穷举矩阵移入102行基础测试。该补证足以闭合本 finding。

### I2（已闭合）：current 21 资产 converge 的 checker 输入绑定

位置：`acceptance-report.md:68`；对照 `evidence/task-6-green.txt` 第4节、
`task-6-review-r2.md` 的“与最终 converge 的关系”。

唯一保留具体 converge 命令、fixture 与 rc/双流的 green 仍明确为历史 20 文件。
其 SHA-256 与报告一致，未被篡改成21资产记录，这一点正确。任务6增量 review
也明确其 PASS 不替代更新后清单的最终 converge。初始报告与 ledger 新增的
`ISOLATED_CONVERGE_CURRENT PASS assets=21 cleanup=absent` 及 rc0 声明说明了
controller 结论，但没有保留本次 checker 调用、current tasks 复制/展开步骤、
21个输入清单与实际临时路径；单一 marker 不能辨别 checker 是否仍消费旧 tasks。

本 reviewer 机械展开当前 tasks 的 `$WORK` 并去重，已确认21个声明路径全部是
存在的普通非 symlink 文件，其中包括原 green；源码 BASE..HEAD 也确为 exact3。
controller 已在同次审查中补入 `/tmp/vc-accept-converge21.XXXXXX` fixture 的
构造方法：clone candidate、detach accepted HEAD、复制controller当前tasks并只
在副本展开 `$WORK`；输入集合为六任务各brief/report/red，加green、manifest、
acceptance共21文件。报告给出实际checker参数、rc0/双流空和显式删除后缺席断言。
该输入集合与本 reviewer 独立展开current tasks的结果一致，且正确与历史20资产
日志区分。结合既有green的完整fixture语义，当前21资产执行绑定已闭合；不要求
重跑已经完成的耗时四路回归。

## 六块与机械对照结果

| 项目 | 核对结果 |
|---|---|
| closeout 七节 | 本 reviewer 重放 rc0；与报告首个 text block 经 `cmp` 逐字一致。七节完整，legacy 四项缺记录按原样保留。 |
| ① 原始判据与收敛 | candidate 固定摘要/rc/双流、full/depth-1 metadata 和 rollback 七末行与任务报告、review、green 无冲突；current 21 converge 补证后输入集合、命令和结果闭合。 |
| ② R1–R10 | 报告逐条列出，provider/doc/base 的责任和05a穷举边界明确；静态实现审查来自任务2，基础动态证据来自任务1/2/4/5/6。没有把05a穷举提前记为完成。 |
| ② 四条不变量 | 四项均列出；零前置query、五明细与受保护文件零变化有相应证据。第三项INCOMPLETE补证后与FAIL既有证据一起闭合。 |
| ③ ledger 裁定 | 机械提取全部7条 ASCII `裁定:`，逐条全文匹配成功；无遗漏、无改写，排序从接口/证据风险到时间代价。20资产旧裁定和21资产补声明裁定都保留并说明替代关系。 |
| ④ SKIPPED | STATE 表只有表头、closeout 输出为“无”，报告一致。 |
| ⑤ 挂账 findings | 六任务最终 review 均 B0/I0/M0；任务3 I1 已修复并 r2 PASS，任务6新增 green 声明 r2 PASS。没有发现被漏掉的最终未修 minor；本次验收I1/I2也已补证闭合。 |
| ⑥ 结论 | 当前“可以验收”有足够证据，门⑤可通过；本报告不执行发布，也不替代发布入口前置检查。 |

只读机械输出：

```text
HEAD=9e5edb45a3048e4c208e2d7fe135639768cc87db
git status --porcelain=v1 -uall: empty
202  0  common/.harness/bin/verify-sidebar.sh
67   0  docs/verifier-contract.md
102  0  tests/test-verifier-contract.sh
DECISIONS_MATCH 7
MANIFEST PASS rows=6
CLOSEOUT_RAW_MATCH PASS
task-6-green SHA256=d45cf2343db20fa803b47c4cd1baa1e663a58dc36f37a057b44f1c5d8048ca16
```

manifest 六行均六列、序号/任务名对应、reviewer非空、全部PASS且相邻前后HEAD
连续，起点为 execution BASE、终点为 accepted HEAD；任务4–6的零delta行合理。
full/depth-1的历史记录绑定同一accepted HEAD，depth-1记录count=1与shallow marker；
rollback green绑定删除exact3后的提交与BASE零diff，七回归命令及双流均明确。
NEXT green从controller主树检查六片、16个execution目标及零dispatch目标的真实
no-match调用，未从rollback树推断顺序门；报告明确未push，未提前解除05a/06/09门。

上述通过项只表示本 reviewer 对已有证据和当前只读状态的核对结果，不冒充本轮
重新运行四路回归。最终 findings：Blocking 0、Important 0、Minor 0。
