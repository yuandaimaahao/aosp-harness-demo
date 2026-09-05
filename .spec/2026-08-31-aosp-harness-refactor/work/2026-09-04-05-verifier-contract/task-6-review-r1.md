# Task 6 独立 Diff Review r1 — rollback / NEXT / 终收敛

## 结论

**PASS — B=0 / I=0 / M=0。**

任务 6 的零源码 delta、exact rollback、旧回归、controller 作用域的 NEXT
检查、机械检查和隔离 converge 证据足以交给 controller 终验。
这不是整个 spec 的最终 acceptance，也不解除 05a / 06 / 09 的顺序门。

审查输入为 task-6 brief、更新后的 report、acceptance 草稿、同 SHA 的零 diff
包，以及补充的 `evidence/task-6-green.txt`。只读核对该 green 证据为 9,121
bytes，SHA-256 为
`d45cf2343db20fa803b47c4cd1baa1e663a58dc36f37a057b44f1c5d8048ca16`，
与报告引用一致。补证前只有报告摘要的可追溯性疑问已由命令、作用域、rc、
双流长度/hash 和清理检查补齐。本 reviewer 未重跑已有测试、clone 或 checker，
仅读取证据、检查 Git 状态和精确临时路径，未修改实现源码或 controller 状态。

## 规格符合性（R → E）

| R / 任务步骤 | E | 结论 |
|---|---|---|
| R9 / 步骤 1：在 ACCEPTED_HEAD、clean 状态执行；报告缺席 red。 | `task-6-red.txt` 记录创建报告前 `test -s` 返回 1；report 与 green 均固定 HEAD `9e5edb45a3048e4c208e2d7fe135639768cc87db`。只读 Git 核对 HEAD 相符，porcelain 和该 HEAD 自差均为空。 | ✅ |
| R9 / 步骤 2：隔离 rollback 删除 exact3、提交，并相对 execution BASE 零 diff。 | green §1 记录 repo 外 clone、checkout accepted SHA、逐路径 `git rm` 和 rollback commit `5f555cca02b0cb4cdd075f21ac0001db23cf528d`；删除恰三文件共 371 行。相对 BASE `65d67b52e5b34d0d9d2add587083ebf2fadcd3ea` 的 name-only、numstat 均 0 bytes，diff-check rc=0。 | ✅ |
| R9 / 步骤 2：rollback 保留 01 / 02 / 04 / 04a 和三个旧 verifier demo。 | green §1 列出 device-safety、offline、resource-leases、resource-leases-assurance、common / claude-code / codex 三旧入口的七条具体命令；均 rc=0、stderr 0 bytes，并记录各自 PASS 末行和 stdout hash。 | ✅ |
| R9 / 步骤 3：NEXT 必须从 controller 主树检查源码与五类执行资产缺席。 | green §2 明确 cwd 为 `/tmp/aosp-harness-publish-04-main.AGaEae`，先检查 05a source 缺席，再逐个检查 05a、06、07、08、09、10 的 spec 目录、Git branch、worktree、execution-base.env 内容及 dispatch.tsv 内容。execution targets=16；dispatch targets=0 时实际执行 `/dev/null` no-match；逐项记录 rg rc=1 和外围断言 rc=0。当前主仓只读 branch / worktree 清单也无上述后序资产。 | ✅ |
| R9 / 步骤 3：requirements 机械检查与隔离 converge。 | green §3 的 tasks、req、criteria、analyze、design 五检查均 rc=0、双流 0 bytes。§4 固定相同 BASE / accepted SHA，在独立 clone 仅复制任务声明的 20 个验收资产，运行 check-converge rc=0、双流为空。`$WORK` 只在 disposable fixture 中展开为对应 repo-relative 路径。 | ✅ |
| R9：candidate / full / depth-1 与固定静态、exact3 预算须有既有证据。 | task-4 / task-5 report 及已 PASS 的 review 提供 candidate、完整历史、真实 file:// depth-1 的 contract / offline、固定工具、count=1 / shallow marker 证据；任务 6 保持同一 accepted SHA。只读复核 BASE..HEAD 为 canonical provider / doc / base-test，numstat 为 202+67+102=371，无第四个源码路径。 | ✅（消费上游证据） |
| R9 / 步骤 4：独立 review 后才能写第六行 manifest、mark / ledger / sync-ledger，再进入 accept。 | 当前 manifest 五行均六列、reviewer 非空、PASS，BASE/HEAD 首尾连续且末尾为 accepted SHA。brief 明定“PASS 后 manifest 第 6 行”；report 和草稿明确保留 controller 操作，未提前声称六行或终验已完成。 | ⚠️（本 PASS 后由 controller 完成） |
| R10：检查结果按 rc / 双流 / 固定摘要判断，失败不得伪装成 contract PASS。 | red 的预期失败记录为 rc=1；green 对 NEXT 的 no-match 明确核对实际 rc=1，未把工具错误或空 argv 当 no-match。七项回归和机械门有独立 rc 与双流记录。最后 candidate contract 为 rc=0、stderr 空、31 bytes stdout，固定摘要 hash `f86f451c3b350f9d90f35c199aa248d0d98632542586e65bdf6d67e9a6c3e7d2`。任务 6 无解析器 / 测试矩阵变更。 | ✅ |
| R10：显式清理，不能残留受管状态或扩大源码范围。 | green §1 / §4 记录 exact realpath 和 clone `.git` 检查、depth-first 删除 rc=0 与缺席断言；只读核对新增两棵及原报告两棵临时树均不存在。candidate clean、零任务 delta；未改旧 verifier、session / resource-lease API 或后序源码。 | ✅ |

上表的 ⚠️ 是 brief 中明确的后续 controller 状态迁移，不是本任务缺陷。
本任务消费已审的基础测试和前序 checkout 证据；不将本次成功路径日志冒充
05a 才负责的穷举 grammar / mutation 证明。

## 质量审查

- Rollback 回到 BASE：通过。证据比较的是删除并提交后的 rollback HEAD 与
  40 位 execution BASE，不是只检查三文件不存在，也不是 accepted HEAD 自差。
  当前原始候选从 BASE 仅增加这三文件，与 rollback 的 371 行删除相互吻合。
  物理 provider 删除使后序 09 可据缺席启用自有 fallback；本任务没有实现或
  宣称验证尚未存在的 09 adapter。
- 旧回归：通过。七条命令覆盖所列 01 / 02 / 04 / 04a 与三个旧入口；04a 的
  输出为正常 resource lease assurance PASS，未将 verifier provider 缺席混为
  resource-lease provider 缺席。没有用 canonical verifier 代替旧入口回归。
- NEXT 作用域：通过。spec / execution 文件来自 controller 项目，branch /
  worktree 来自 controller 所属 Git 仓；没有从已删除 canonical provider 的
  rollback clone 推断未来资产缺席。dispatch 的零目标情形有实际 no-match
  调用和目标枚举说明。此处证明当前顺序门关闭，不能替代后续 ledger 入库。
- Converge 与 cleanup：通过。检查器的输入为独立 clone 的相同候选、完整
  exact3 源码差异和显式声明资产；仅解析 `$WORK` 占位符，没有删除待交付源码、
  缩减清单或修改主树 tasks。任务外 review / green 日志未混入该受限 fixture，
  符合任务约定的隔离检查用途。四棵已列临时树现在物理缺席。
- 零 delta：通过。review 包的 commit / stat / patch 均空；只读 accepted HEAD
  到当前 HEAD 差异及工作树状态也为空。rollback commit 仅属于已删除的外部
  clone，没有成为交付候选的新增提交。

## Acceptance 草稿与 controller 终验

草稿足以进入 controller 终验：它固定 BASE / HEAD，覆盖任务 6 的 rollback、
NEXT、机械检查、converge、cleanup 和 candidate contract，且明确没有代替
controller 写 manifest / STATE / ledger 或作出验收决定。与更新后的 task-6
report 及其 green 引用合读，执行证据可定位。

终验仍须把 task-4 / task-5 的 candidate / full / depth-1、固定工具及 exact3/371
证据合并到最终 acceptance；本 PASS 后追加 task-6 manifest 行，核六行六列、
reviewer 非空、首尾连续、全 PASS，完成 mark 6 / ledger / sync-ledger，并执行
controller 所需最终收敛和顺序门核对。只有 05 dependency-present 证据入 ledger
后才可创建 05a；只有 05a 完整 active 证据入库后才可启动 06 / 09，inert PASS
不能解除该门。

## Findings

- Blocking (B): 0
- Important (I): 0
- Minor (M): 0
