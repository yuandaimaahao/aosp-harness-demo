# 2026-09-04-04 runtime resource leases — 门⑤验收报告

## Research-first 机械证据回放（原始输出）

```text
# 收口证据回放

## 调研范围
legacy：无此记录

## 调研深度
legacy：无此记录

## 分类依据
legacy：无此记录

## report review
legacy：无此记录

## 自动通过的门及其依据
- 2026-09-01-03-session-state-safety: 门② — 依据：PLAN v5.1 收窄 requirements 已完成三轮全新上下文独立审查并在熔断后逐项裁定；R1-R9、五 API/信号返回、攻击与规模 oracle 闭合，check-plan/check-req/check-criteria/check-analyze/git diff --check 全部通过
- 2026-09-01-03-session-state-safety: 门③ — 依据：PLAN v5.1 收窄 design 经三轮全新上下文独立审查最终 PASS；R1-R9、八节<absolute-path> marker、3文件359行 sizing 全闭合，全部机械检查通过
- 2026-09-01-03-session-state-safety: 门④ — 依据：三轮全新上下文 tasks review 达熔断上限并融合全部承重 finding；16 个串行任务覆盖 R1-R9、六 marker、BASE 证据和 3文件<absolute-path> diff --check 全通过
- 2026-09-04-04-runtime-resource-leases: 门② — 依据：用户已授权后续按 autopilot 执行；requirements 经同一独立 reviewer 三轮审查从 2/5/2 收敛至 0/0/0，owner/独占矩阵<absolute-path> 原子性<absolute-path> hash/状态根<absolute-path> 回流责任全闭合，三项 checker 全绿
- 2026-09-04-04-runtime-resource-leases: 门② — 依据：PLAN v5.8 回流 requirements 经三轮审查与熔断裁定后由同 reviewer 验证最终 PASS（0/0/0）；R1-R8 生产正确性不变，R9 基础合同与04a穷举边界、R10 exact3=400及04a NEXT 五类缺席门闭合，三 checker、固定工具和四类基础 mutant 全绿
- 2026-09-04-04-runtime-resource-leases: 门③ — 依据：PLAN v5.8回流design三轮审查达熔断后由同reviewer只读融合验证最终PASS（0/0/0）；stored lexical canonical、capture安全生命周期、helper固定协议与publish后rollback、assurance反证全部闭合，core exact3=400/400、04a exact1=398/400，固定工具<absolute-path>
- 2026-09-04-04-runtime-resource-leases: 门④ — 依据：tasks三轮独立审查最终PASS（0/0/0）；7任务<absolute-path>

## 跳过门禁
无

## 挂账 findings
无
```

## ① 判据执行结果

本轮在 `accepted HEAD=f7cfcb202d1fd2934d07cc90e333a4205b563243`、`execution BASE=692d52d00b56df9609760aa33a6f9aa3c38095a3` 上重新执行。原始输出：

```text
RESULT PASS  resource leases
RESULT PASS  resource leases
RESULT PASS  claude session lifecycle
PASS  demo harness startup, process layer, and strict verification
PASS  Codex feature context selection and branch checks
RESULT PASS  shared Harness regression suite
RESULT PASS  device safety
RESULT PASS  offline quality gate child
RESULT PASS  resource leases
RESULT PASS  session path race assurance
RESULT PASS  session path safety
RESULT PASS  session write interrupts
RESULT PASS  session snapshot assurance
RESULT PASS  session snapshot safety
RESULT PASS  session state foundation
RESULT PASS  session state
RESULT PASS  aosp-harness offline quality gate
INVALID=PASS rc=1 streams=0B cases=3
STATIC=PASS shfmt=v3.14.0 shellcheck=0.11.0 bash-n=2
EXACT=PASS files=3 numstat=400 manifest=7 clean=true
CHECK_CONVERGE=PASS assets=62
FULL=PASS head=f7cfcb202d1fd2934d07cc90e333a4205b563243 default=RESULT PASS  resource leases lease-discovery=1 offline-last=RESULT PASS  aosp-harness offline quality gate clean=true
DEPTH1=PASS head=f7cfcb202d1fd2934d07cc90e333a4205b563243 count=1 shallow=true default=RESULT PASS  resource leases lease-discovery=1 offline-last=RESULT PASS  aosp-harness offline quality gate clean=true
ROLLBACK=PASS temp-commit=6cb64714547fb63157802bbd7822db73ce1c90ca exact=3D diff-vs-base=0 lifecycle=RESULT PASS  claude session lifecycle lease-discovery=0 offline-last=RESULT PASS  aosp-harness offline quality gate clean=true implementation-unchanged=true
NEXT=PASS spec=absent work=absent refs=absent worktrees=absent records=27-all-rc1 temp-residue=0 clean=true
```

`check-converge.py` 在 accepted HEAD 的临时 `--no-local` clone 中运行，只叠加当前 spec 文档与 tasks 字面列出的 62 个去重验收资产；临时 clone 已删除。depth-1 第一次命令误把相对 worktree 拼入 `file://` 并 rc128；改用 ledger 中的 canonical absolute 路径后，同一判据得到上述 rc0。

## ② 逐条对照 requirements 与不变量

- R1：PASS。source surface 仅新增两个 lease public API；会话 API/provider version 缺席。
- R2：PASS。TSV、domain/mode、workspace realpath/control-byte 与 android safe instance ID 由基础矩阵执行；完整 adapter 反证按边界留给 04a。
- R3：PASS。规范 request/hash、重复键拒绝、bundle 单 publish 与失败零 partial 由矩阵/provider review 覆盖。
- R4：PASS。33-byte token、逆序重入同 token、非完整重叠 rc2 与不相交并存均真执行；两个旧假绿 mutant 已 rc1/无 PASS。
- R5：PASS。协议/状态/工具/worker 异常收敛 rc2 与固定错误双流；invalid CLI 三例 rc1/双流 0B。
- R6：PASS。token/owner/session/request/hash 验证、单点 unpublish、成功双流空及错误 token fail-closed 均覆盖。
- R7：PASS。wait=0、monotonic deadline、stale/tombstone 通过；deadline 后恢复 rc3/零 active，且超时后锁可再获取。
- R8：PASS。协议文档与 approved 7 行 prototype 逐字一致，独立 review 为 0/0/0。
- R9：PASS。default/all 固定摘要、static、dependency-absent、inventory 与基础矩阵通过；seam 恰一处、assurance final 缺席；执行期测试假绿与相对 TMPDIR 均已修复/re-review。
- R10：PASS。candidate/full/depth-1 default+offline、depth1 count/shallow、fixed tools、exact3/400、七行 manifest、rollback 3D/zero-diff 与后序五类缺席门全绿。

不变量：

- exact 文件边界：PASS，额外变更文件数 0。
- 存活 owner 抢占：PASS，相交 request rc3 且 holder token 可释放。
- release 后残留：PASS，最终 inventory 与 `/tmp/aosp-harness-lease.*` 均为 0。
- 既有 lifecycle/offline：PASS，candidate 与 rollback 均 rc0。

## ③ 执行期裁定（按判断错误代价降序，原文）

- 裁定: 04 的 requirements/design/tasks、approved prototypes、task briefs 与验收资产保留在主工作树的 `.spec/2026-08-31-aosp-harness-refactor/` 下，实现者将这些绝对路径视为只读输入；实现源码与 commit 只写隔离 worktree — 依据：主工作树承载多个会话的未提交簿记与原型，implementation worktree 从已验收的 clean `main` 基线创建，不能安全吸入整片未提交 `.spec` 树；上一片亦已裁定验收资产落主树 work 目录。若判断错误，代价是实现者误把证据资产提交进源码链或读取到变化中的原型；因此派活固定绝对路径，并以 task source allowlist、worktree clean 与 BASE..HEAD exact 文件门机械约束。
- 裁定: task 1.1 round1 finding 属 approved provider prototype 的实现缺陷，不是需求/API/安全边界扩大；fix round 由原实现者同时修正主树 approved prototype 与隔离 worktree 已安装副本，保持二者逐字一致、336行/固定工具预算，并新增锁竞争真红回归证据；随后只把finding、修复diff与R7判据交同一独立reviewer增量复审 — 依据：requirements/design 已明确 monotonic deadline 与 resource unavailable rc3，当前阻塞flock与文字规范直接冲突，若只改worktree会破坏任务的prototype逐字门。若判断错误，代价是执行期悄然改变已批准设计；因此不得变更public API/requirements/design/tasks，prototype+installed diff限同一行预算内的非阻塞锁获取，并由原reviewer核语义与相邻回归。
- 裁定: task 1.3 fix round 1 同步修正approved base-test prototype与installed test，不变更provider/docs/API/requirements/design/tasks，保持57行与exact3=400；把关键assert改为明确失败路径，并把临时根规范成绝对真实目录，新增两个假绿mutant与相对TMPDIR真红/绿证据后交原reviewer增量复审 — 依据：R9已要求逆序同token、stale与绝对私有临时根，finding均是approved test prototype的oracle/fixture实现缺陷而非scope扩大。若判断错误，代价是压缩行数时引入新的errexit豁免或把TMPDIR语义改成不安全路径；因此必须用mutant rc非零且无PASS、`TMPDIR=.` default/all PASS、prototype cmp/57/fixed static/default/all/invalid/absent/exact3/clean共同约束。
- 裁定: task 1.1 fix round 2 继续由原实现者闭合同一R7边界，拿锁后且任何record读取/发布前必须再次用monotonic clock判deadline，超时即释放锁并rc3；同步prototype与installed副本、保持336行与API不变，再交当前可用reviewer做增量复审 — 依据：round2 finding是round1非阻塞化的直接相邻回归，未扩大需求或安全边界。若判断错误，代价是wait=0首次无竞争请求可能被错误视作超时，或超时路径持锁/触碰状态；因此修复证据必须同时覆盖无竞争wait=0成功、跨deadline锁释放rc3且零active、锁可被后续请求获取。
- 裁定: 原reviewer额度不可用后，结构化review另开`execute-1.1-replacement` cycle，由替补reviewer的FAIL→PASS连续记录满足reuse_reviewer策略；原cycle保留ABORTED事实不冒充闭合 — 依据：在原cycle直接追加替补PASS会被`check-review-policy.py`正确拒绝“未复用原reviewer”，新cycle只包含同一替补reviewer的连续fix复审并已rc0。若判断错误，代价是审查链被拆周期而遗漏首轮全量diff；首轮全量FAIL报告与package仍在原cycle和ledger，替补复审只在该finding修复范围内生效，最终验收还会对execution BASE..accepted HEAD做exact与全测试门。
- 裁定: execute-final首次后序/clean复跑唯一失败是`/tmp/aosp-harness-lease.uWaNXc`测试capture残留；只读核为当前EUID、0700且顶层恰`out/err`后，按provider安全协议点名删除两文件再`rmdir`，重跑后零残留且五类门全绿 — 依据：早先合并长命令在检查残留前退出，遗留的是本轮测试capture而非用户资料；未使用递归删除。若判断错误，代价是误删同EUID其他进程capture；因此删除前逐项验证固定前缀、owner、mode和exact inventory，且只操作该唯一已解析绝对路径。

## ④ 跳过的门禁

无。04a assurance 是明确后序交付，不是本片 SKIPPED 门禁；其真实资产仍缺席。

## ⑤ 挂账 findings

无。task 1.1 的两个 Blocking、task 1.3 的 Blocking/Important 与报告 Minor 均经 fix/re-review 闭合；最终 review 均 PASS，B/I/M=0/0/0。

## ⑥ 结论

可以验收。主验证、R1–R10、四条不变量、full/depth-1/rollback、exact3/400、七行 review manifest、后序缺席门与 `check-converge.py` 均在本轮退出 0；accepted HEAD 为 `f7cfcb202d1fd2934d07cc90e333a4205b563243`。本片未 push，也未提前创建后序 spec 的真实资产。
