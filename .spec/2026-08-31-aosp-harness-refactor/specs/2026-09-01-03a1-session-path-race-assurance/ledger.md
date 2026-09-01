# ledger — spec: 2026-09-01-03a1-session-path-race-assurance
# plan: .spec/2026-08-31-aosp-harness-refactor/PLAN.md v5.6
# worktree: 待execute时创建

> 会话压缩之后，「我刚做完什么」的记忆不可靠。这份文件和 git log 才是。
> `任务 N: 完成` 是唯一的恢复锚点。

---

## Requirements

- 选片：03a验收/retro与PLAN v5.5均指向03a1；用户已授权autopilot，无待问问题。
- 依据：03a round2 prototype已提供269/400、19个实际case的三层共享driver；本片把剩余18个data rows/calls补齐为37-case完整矩阵，不改provider或发布API。
- requirements round 1 NEEDS_CHANGES blocker=2 important=2 minor=0 reviewer=review_plan_v5_2：补provider存在但foundation/core不可用的inert分支；修正三类anchor适用字段并禁止普通needle；补symlink target签名与03b dispatch顺序门。
- round 1 rewrite：R2增加core-unavailable default/flag；R3/R6固定MANAGED/EXPECTED_EUID/OS_ERROR的字段与case映射，final-stat等通过anchor hook安装一次性真实os monkeypatch；R5加入readlink target；验收要求accepted manifest先于任何03b base/dispatch。round3 anchor-only prototype完成后再复审。
- round3 anchor-only prototype PASS：270/400、余量130，严格每child只替换MANAGED/EXPECTED_EUID/OS_ERROR之一，19个代表case与全部provider/core absent形态实跑PASS；anchor损坏fail closed、readlink target与provider hash闭合，pinned工具PASS。
- requirements round 2 NEEDS_CHANGES blocker=1 important=0 minor=0 reviewer=review_plan_v5_2：anchor损坏与core-unavailable组合态优先级未定义，原型先判core会把损坏provider误报inert PASS。
- round 2 rewrite：provider文件存在时必须在core/flag之前先验三个anchor；损坏始终fail closed，只有结构完整但core unavailable才inert。验收补marker missing/duplicate × foundation missing/core unavailable × default/flag八组合。
- round4 prototype PASS：280/400、余量120；八个损坏组合全fail closed，结构完整的core unavailable四组合、provider absent default/flag、full-deps flag与19-case动态default均PASS；only-anchor/provider hash/pinned tools/clean不变。
- requirements round 3 PASS blocker=0 important=0 minor=0 reviewer=review_plan_v5_2：组合态优先级、前序四finding、280/400原型、37-case/回滚/顺序门全部闭合。
- 自动通过: 门②（autopilot）。依据：三轮requirements review最终PASS，check-req/check-criteria/check-analyze/git diff-check均PASS，round4可运行原型支撑only-anchor与400行门。
- PLAN v5.6 requirements backflow round 1 PASS blocker=0 important=0 minor=0 reviewer=review_design_03a_r1：初审的protocol mismatch rc归属与原型未支持的TSV exact-LF/workspace安全承诺均已收窄；R1-R9只定义private driver、37/37、14项自反证、full/depth-1、exact1/400与03a2顺序门。
- 自动通过: 门②回流（autopilot）。依据：PLAN v5.6 review round2 PASS，requirements round1修复后PASS，round7拆分原型与check-req/check-criteria/check-analyze/git diff-check全PASS。

## Design

- design round 1 NEEDS_CHANGES blocker=1 important=1 minor=0 reviewer=review_plan_v5_2：补九family共享allowed-delta schema/精确表和承重prototype；EEXIST hook expectation改一对多有序结构。
- round 1 rewrite：delta_spec固定added/removed/replaced/protected/post_predicate，driver由before机械推导expected after；列出九family精确delta；CASE_ROW一对多有序HOOK_EXPECTATION并删除单数phase/made。round5 prototype完成后复审。
- round5 prototype PASS：351/400；19-case中九family全部消费共享完整inventory/signature/delta oracle，EEXIST有序双hook，四项主动self-disproof有效；补18 rows投影约382/400、余量18，not BLOCKED但实现不得复制family body。
- design round 2 NEEDS_CHANGES blocker=1 important=1 minor=0 reviewer=review_plan_v5_2：swap delta漏victim subtree重键；mkdir replacement漏runtime original完整签名；round5未支付marker/case/sentinel/made-catch全部self-disproof。
- round 2 rewrite：delta使用精确path-key/subtree重键；mkdir hook记录runtime original并与`.old`逐字比较；round6必须实跑全部强制self-disproof后再判断400行门。
- round6 executable sizing BLOCKED：完整37-case单文件原型固定格式后411/400，37/37与14项active self-disproof全PASS，证明需求/oracle可行但原PLAN文件边界不可交付；不允许删减承重证据换取行数。
- PLAN backflow initiated：最小切口为保留当前03a1独占private race driver/self-test，新增03a2独占默认发现的37-case shell matrix；03b必须等待两片accepted HEAD/全PASS manifest且03a2是dependency-present的37-case默认运行。round7可执行拆分原型与PLAN v5.6增量review完成后，当前requirements/design必须按driver片重写并重走门禁。
- PLAN v5.6 accepted：round7 final实测driver 400/400、entrypoint 109/400，matrix自损坏检查早于任何inert，full/depth-1 direct+offline与独立回滚组合全PASS；PLAN review round1的3 important/1 minor均修复，round2 PASS（0 blocker/0 important/1 typo minor已修）。当前stage回到requirements，旧R1-R8/design仅作拆分证据，不得按原single-shell边界进入tasks。
- PLAN v5.6 design round 1 NEEDS_CHANGES blocker=1 important=4 minor=1 reviewer=review_plan_v5_2：CASE_LOG可alias/symlink provider并先改坏上游；run-matrix误执行self-test-only反证；self-test顺序、inventory canonical sort、full/depth-1 private证据与design不一致；capture媒介表述过度约束。
- round7 design-fix prototype PASS：workspace要求physical existing parent并只创建0700 leaf，log限定为新workspace直接子项并用`O_EXCL|O_NOFOLLOW` 0600持有fd写；7类alias/缺席/既有反例均0 case、provider hash不变。run-matrix合法子集、self-test-only 14反证、R4固定顺序、filesystem-bytes inventory和full/depth-1 protocol+self-test均实跑PASS；只移除纯空行后driver为400/400，未删oracle或压缩长行。
- PLAN v5.6 design round 2 NEEDS_CHANGES blocker=0 important=2 minor=1 reviewer=review_plan_v5_2：`Path.stat(follow_symlinks=False)`不兼容Python 3.8/3.9；CASE_LOG写早于最终provider hash；workspace absolute/normalized实际行为未入契约。
- round2 fixes：等行改为`parent.lstat()`，Python3.9 runtime与3.8 grammar均PASS；final provider hash前移至log fd写前，隔离ordering反证实测case hook=1/rc1/PASS无/log 0B；driver仍400/400。
- PLAN v5.6 design round 3 NEEDS_CHANGES blocker=0 important=1 minor=0 reviewer=review_plan_v5_2：原回写称raw `.`/`..`都拒绝，但Python `Path`已折叠`.`且实测会成功。
- fix_loop_max=3 controller裁定闭合：requirements/design改为精确的`Path`词法契约（解析后absolute且无`..`）；实跑relative workspace/log与保留`..`的workspace/log均rc1，raw `.`折叠后的1-row运行rc0/log精确，report/evidence已逐字记录；check-req/check-criteria/check-analyze/check-plan/diff-check全PASS。错判代价仅是允许语义等价的`.`别名；若继续宣称raw必须拒绝则会与已验证的Python `Path`行为冲突。
- 自动通过: 门③回流（autopilot）。依据：三轮design review均已处理，最后唯一finding在熔断上限后以实跑5组路径证据与精确契约闭合；R1-R9、九节design、round7 400/400与全部机械门通过。

## Tasks

- tasks round 1 NEEDS_CHANGES blocker=1 important=5 minor=0 reviewer=review_design_03a_r1：accepted-HEAD checkout时机不可满足；四任务存在复杂度断崖且最终红因不真实；代码步骤缺骨架；path实现偏离round7；current/untracked diff与03a2终态门不闭合。
- round 1 rewrite：拆为五个串行纵切（CLI、preflight+EIO、primary families、managed lifecycle+精确self-test红、14反证+acceptance）；每任务加入round7代码骨架；路径回到`parent.lstat()+resolve`；Git门覆盖intent-to-add/current diff；candidate提交后才做full/depth-1，manifest改为五行并在ledger前重查03a2。
- tasks round 2 NEEDS_CHANGES blocker=1 important=2 minor=0 reviewer=review_plan_v5_2：误把BASE_SHA要求为absolute file；14项仍有占位且无mutant harness；03a2 absence没有fail-closed命令/精确路径。
- round 2 rewrite：BASE_SHA与manifest类型门分离；逐项展开14个真实oracle callback并提供14-copy mutation harness；03a2 branch/worktree/spec/work/execution-base/manifest/task1 brief加入精确fail-closed门。
- tasks round 3 NEEDS_CHANGES blocker=2 important=2 minor=0 reviewer=review_design_03a_r1：inode多行导致mutation未命中；accepted implementation与controller `.spec`混用仓根；两个R7名称不精确；`! -e`放过dangling symlink。
- fix_loop_max=3 controller裁定闭合：inode callback固定单物理行，14 labels逐一探针为14/14 singleton；名称改为`symlink readlink target`与`regular file hash`；终态门显式传入同common-dir的`CONTROL_REPO_ROOT`/`IMPLEMENTATION_WORKTREE`并分别取accepted HEAD与controller资产；absence统一`! -e && ! -L`且dangling symlink负例拒绝。实跑common-dir一致、final shell `bash -n`、check-tasks/check-plan/check-req/check-criteria/check-analyze/diff-check全PASS。错判代价：若仓根绑定或物理缺席判断仍错，会提前解除03a2顺序门；因此execute前后必须原样运行该fail-closed块，不接受口头替代。
- 自动通过: 门④回流（autopilot）。依据：三轮tasks review全部finding已修复或在熔断上限后由14-site、双仓common-dir、dangling-symlink和shell语法实跑裁定；五任务完整覆盖R1-R9、每片有确定红绿/独立review、exact1/400与五行manifest/accepted-HEAD顺序闭合。
