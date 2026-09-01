# ledger — spec: 2026-09-01-00-environment-seed-preflight
# plan: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-09-01-aosp-feature-minimal-checkout/PLAN.md v5
# worktree: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo

> 会话压缩之后，「我刚做完什么」的记忆不可靠。这份文件和 git log 才是。
> `任务 N: 完成` 是唯一的恢复锚点。

## requirements review

- Round 1: FAIL，4 blocker / 7 important / 3 minor；修复 input/output ABI、dispatcher/recovery、exit/ref 与独立安全 oracle。
- Round 2: FAIL，3 blocker / 7 important / 2 minor；修复双 scope owner、POSIX commit point、closed schema、resource/control/budget gate。
- Round 3: FAIL，2 blocker / 6 important / 2 minor；达到 `fix_loop_max=3`，依 review skill 熔断并逐条裁定如下。

### 熔断裁定

- B1 public producer→consumer 断链：接受并修复。PLAN 升 v5，public request 与 fixed ref 分离，后序统一 `--descriptor-ref`，real public exit 0 是进入 01 的唯一 gate。若判断错，代价是 02 才发现 seed 不可消费，整条 closure 链作废。
- B2 evidence ABI 不可表示/悬空 digest：接受并修复。trace result/dirfd 使用 signed-64，固定 exec argv 与全部 path operand；定义 per-project/workspace source-state digest。若判断错，代价是同一 trace/source 得到不同 bytes，proof/cache 主键不可重算。
- I1 publish recovery 不闭合：接受并修复。collision 后置到 observation 后、补 `REF_BUSY/REF_CORRUPT`，publish exit 30 固定 channel/code，并以 scope ref lock 单 writer。若判断错，代价是并发 producer 改写 stable ref 或错误分支留下不可解释状态。
- I2 out-ref/dispatcher base 不固定：接受并修复。dispatcher 相对自身 realpath 解析 commands.d，public/local ref 名与 state-dir namespace 固定，逐分量 no-follow。若判断错，代价是 path escape 或 producer/consumer 读取不同 ref。
- I3 resource 公式不闭合：接受并修复。四项 request minimum 不得低于默认，disk 同时覆盖 estimate，v2 provider 优先、v1 fallback，cpuset 缺失回 online，CPU rational 交叉相乘。若判断错，代价是资源不足环境被错误放行或本机被过度保守终止。
- I4 mutation/ignored coverage 不足：接受并修复。trace 记录所有 path/fd operand 和 fd/cwd/symlink resolution，补写入/mmap/copy/xattr 等 mutation family，读取的 ignored symlink target content 入 identity。若判断错，代价是源码被改变或本地隐式输入未进 seed key仍假 PASS。
- I5 trace 调度污染 seed：接受并修复。新增 stable seed identity，排除 trace/journal/瞬时资源/OUT_DIR；完整 artifact 保留 run audit，重复 real run 验 stable digests。若判断错，代价是相同源码每次 cache miss，seed 无法复现。
- I6 rollback fixture 身份不明：接受并修复。revert 后 test-only 安装固定 recovery-fixture，直接 ABI 精确输出；dispatcher 应缺席，旧三项回归精确 PASS。若判断错，代价是回滚只验证了同片已删除模块，无法证明后序 direct recovery。
- M1 wrapper/inner exit 混写：接受文案修复。明确 inner public 0/20 与 wrapper 0/20 及各自末行。若判断错，代价是编排器把 terminal 当普通 PASS。
- M2 800/160 时点：接受文案修复。tasks 门检查 estimate，implementation acceptance 检查 actual。若判断错，代价是到实现后才发现人审预算失守并返工拆片。

自动通过: 门② — requirements 三轮独立 review 达熔断上限后已逐条裁定全部 blocker/important/minor，PLAN/DECISIONS 同步为 v5，check-req.py、check-criteria.py、check-analyze.py、check-plan.py 均 exit 0；G-VERIFY 判据已固定但尚未执行实现验证。

## 门③ sizing / PLAN v6

- sizing: 原 combined 00 为 890–1310 行非生成 diff，触发 R24 的 800 行 gate；00a/00b 复用 runtime 后高位分别 730/630 行，summary 高位 140/160。
- PLAN v6 incremental review round 1: FAIL，0 blocker / 5 important / 1 minor；修复 P5、00a 缺席协议、preflight/control gate 分层、01 owner 和 DECISIONS supersession。
- PLAN v6 incremental review round 2: PASS，0 blocker / 0 important / 1 minor；`check-plan.py` exit 0。
- 次要挂账：sizing 属估算，00a/00b 各自 tasks 门仍必须重算 actual file/line budget；任一高位超过 800 立即回 PLAN。若忽略，代价是实现后才发现人审预算超限。

自动通过: PLAN v6 增量门① — 第二轮独立 reviewer PASS，00a/00b P1–P5、producer/consumer、owner、rollback、public gate 与 DAG 已闭合；用户已要求后续 autopilot。

## design review

- Round 1: FAIL，3 blocker / 4 important / 2 minor；修复非法 design→retro 跳转、R6/R19/R20/R23/R25 owner、可执行验收/回滚、successor interface、error/test/file ownership 与 Python YAGNI。
- Round 2: FAIL，0 blocker / 2 important / 1 minor；修复 00a `verify-seed` fixture CLI/stdout、validator 三模式/single-parent SHA/negative mutation，并将 current task source diff 固定为 19 个 exact path。
- Round 3: FAIL，1 blocker / 3 important / 1 minor；达到 `fix_loop_max=3`，依 review skill 熔断并逐条裁定如下。

### design 熔断裁定

- B1 frozen base 已落后共享 main：接受并修复。base 不再硬编码；execute 开始把当时 HEAD 冻结进 manifest，pre-commit 要求 HEAD 未漂移，accept 要求 task commit 唯一 parent 等于该 base，不 reset/revert 他人提交。若判断错，代价是其他 spec 的 `common/` diff 被误判成本片改动或本片绑定错误 parent。
- I1 五类 mutation oracle 不唯一：接受并修复。固定 `MISSING_REPLACEMENT`、`REQUIREMENT_OWNER_MISSING`、`BUDGET_LIMIT_EXCEEDED`、`LEDGER_SHA_MISMATCH`、`COMMIT_SCOPE_MISMATCH` 五个 exact stderr，并要求 subprocess 穿过真实 pre-commit/accept mode。若判断错，代价是恒失败或错误优先级仍可假 PASS。
- I2 manifest nested schema 未闭合：接受并修复。design 固定全部顶层/嵌套 key、array order、owner enum、数字/路径边界与 unknown/missing rejection；实际 manifest 必须列出 19 个 exact path。若判断错，代价是 validator 与 artifact bytes 不兼容。
- I3 task commit 与 merge 契约冲突：接受并修复。PLAN/DECISIONS/requirements/design 统一声明：已从 PLAN 移除的 superseded original 00 是唯一 single-parent task commit 例外；00a–05 继续使用独立 merge commit。若判断错，代价是 closeout/rollback 读取错误 SHA 类型。
- M1 create/modify 与 Git tree 不符：接受文案修复。19 个路径相对 frozen base 均为 create；当前工作区的持续编辑不改变 Git diff operation。若判断错，代价仅是 review package 标签不准，不改变 exact path set。

自动通过: 门③ — design 三轮独立 review 达熔断上限后已逐条裁定全部 blocker/important/minor，PLAN/DECISIONS/requirements/design 同步；进入 tasks 前重新运行静态 checker。

## tasks review

- Round 1: FAIL，3 blocker / 4 important / 0 minor。接受全部 finding：把 4615+ 行已审 process documents 移出 task source diff，门④后先提交为 isolation baseline；task 改为 exact two-path/≤800 行；completion/ledger/accept 移到独立 diff review PASS 后且 `sync-ledger.py` 仅作核对；每条命令从 manifest 重读 base；stage 后跑 cached whitespace；self-test 扩为 closed schema/path/base/commit/rollback matrix；补函数边界、exact commit/ledger grammar 与 amend/re-review 时序。若判断错，代价是 worktree 缺输入、空 whitespace gate、错误 SHA 锚点或两文件 validator 的拒绝面假绿。
- Round 2: FAIL，2 blocker / 2 important / 0 minor。接受全部 finding：补逐slice 75–95/150–190/150–190、合计375–475行和120行summary的tasks-time estimate及2/4/4分钟review窗口；pre-commit允许base或其eligible candidate，review fix在同parent candidate上amend并重验，main漂移则fresh worktree+`cherry-pick -n`重建parent；补baseline/candidate/completion exact shell、Python dispatch skeleton；matrix增加duplicate object key、DECISIONS/sizing、missing/extra non-common path、post-revert helper与malformed ledger grammar。若判断错，代价是R24在实现后才触发、修复轮恒报base mismatch、或closed rejection仍可假绿。
- Round 3: FAIL，2 blocker / 2 important / 1 minor；达到`fix_loop_max=3`，依review skill熔断并逐条裁定如下。

### tasks 熔断裁定

- B1 amend相对HEAD导致single-file fix与actual budget假绿：接受并修复。所有task prospective path/whitespace用`git diff --cached TASK_PARENT`，cumulative whitespace/numstat用`git diff --cached FROZEN_BASE`；初次与amend共用同一函数。若判断错，代价是单文件review fix无法提交或累计超800仍通过。
- B2单文件dense validator不满足10分钟review：接受并承重replan。终止片改为六个non-overlap files、四个顺序tasks，估算分别260–320/60–85/105–140/160–210，总高755；每片独立review预算9/3/5/7分钟且PASS前不开始后片。最终由parent1=base,parent2=task tip的two-parent merge交付。若判断错，代价是任务上下文/人审仍超预算，必须再次回PLAN而不能进入accept。
- I1 completion/public channel不够exact：接受并修复。补`run_exact`逐字断言三个public mode，task/parent/merge SHA从Git链计算，apply_patch后逐行`grep -Fxc`并验证report/review存在，`sync-ledger.py`只读核对。若判断错，代价是额外输出或错误ledger anchor假PASS。
- I2 initial/rebuild worktree边界：接受并修复。baseline后用唯一tmp path/branch exact创建并验HEAD/clean；main漂移fail closed并从新baseline完整replay/review，不在旧candidate上reparent。若判断错，代价是validator在错误root/parent执行。
- M1 rebuild cleanup：接受并修复。成功accept/retro后remove worktree并delete已mergebranch；失败保留唯一owned worktree且不创建同名重试。若判断错，代价是临时worktree/branch泄漏并阻塞重跑。

门④自动裁定：三轮独立review已达熔断上限，全部blocker/important/minor均接受并同步到PLAN/DECISIONS/requirements/design/tasks；以四任务modular merge方案进入执行，执行前重跑全部静态checker。

裁定: process baseline的`git diff --check`排除`research/raw/**`，因为两份raw evidence保留Markdown hard-break与命令转录尾空白；其余process文件和后续六个implementation paths仍严格检查。若判断错，代价是raw evidence格式被误当产品源码质量问题；implementation whitespace仍由task gate覆盖。

---
