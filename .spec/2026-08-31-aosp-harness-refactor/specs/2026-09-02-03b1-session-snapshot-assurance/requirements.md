---
id: 2026-09-02-03b1-session-snapshot-assurance
依赖: [2026-09-02-03b-session-snapshot-safety]
消费: "session-snapshot-core-v2的spawn-only _harness_session_snapshot_worker write|read ...、signal-aware write/read core私有协议与八个确定性测试anchor；tests/test-session-snapshot.sh基础测试dependency-present PASS证据（无运行时API）"
产出: "session-snapshot-assurance-v1 —— tests/test-session-snapshot-assurance.sh默认发现入口、provider-copy完整矩阵与固定摘要`RESULT PASS  session snapshot assurance`；无运行时API/provider marker"
验收方式: 混合判定
已由用户确认: true
确认依据: 用户已授权后续按autopilot执行；03b验收记录（DECISIONS.md 2026-09-02 03b行）确认accepted HEAD、active证据、八anchor、signal协议、exact2/400与全PASS manifest已入ledger，03b1启动门已满足；03b1 runnable prototype cbdbdde0e1e3ff4ceb2dc0279b1db83127a0ea9e在当前main（ffddb95）实跑rc0、stdout精确`RESULT PASS  session snapshot assurance`、240项断言、308/400行，固定shfmt v3.14.0、ShellCheck 0.11.0与bash -n全绿
---

> 用户原话：“$spec review 这套 aosp harness 工程，有哪些欠缺的地方，进行重构和完善”；并确认后续按 autopilot 执行。PLAN v5.7要求03b1在03b accepted后、03c signals facade前，以provider-copy穷举snapshot mutation/publish/child signal动态分支。

## 目标

只新增默认发现的shfmt-clean assurance测试`tests/test-session-snapshot-assurance.sh`：不修改已验收snapshot provider，只复制它并在八个无副作用anchor注入攻击，逐项反证held capture fd不受同名路径重建影响、managed/snapshot stat→open mutation、无特权wrong-owner、短读仍逐字节产出精确`feature`、真实EIO、`renameat2`缺symbol/`ENOSYS`、确定性`EEXIST`后same/different/disappear/unsafe，以及write child在`TEMP_BEFORE_PUBLISH`后的HUP/INT/TERM清理（含五次close与已提交winner旧名只得`ENOENT`的窗口）；全部provider副本与state root位于`mktemp`隔离目录。成功唯一摘要为`RESULT PASS  session snapshot assurance`。八个anchor是`HARNESS_TEST_MARKER_CAPTURE_READY`、`HARNESS_TEST_MARKER_SNAPSHOT_MANAGED_BEFORE_OPEN`、`HARNESS_TEST_MARKER_MANAGED_EXPECTED_EUID`、`HARNESS_TEST_MARKER_SNAPSHOT_EXPECTED_EUID`、`HARNESS_TEST_MARKER_SNAPSHOT_BEFORE_OPEN`、`HARNESS_TEST_MARKER_TEMP_BEFORE_PUBLISH`、`HARNESS_TEST_MARKER_PUBLISH_RESULT`与`HARNESS_TEST_MARKER_OS_ERROR`；它们都不是capability marker。本片继续不设置`HARNESS_SESSION_STATE_PROVIDER_VERSION`、不发布运行时API；dependency-present完整矩阵入ledger后才可启动03c，inert PASS不能解除该顺序门。

## 需求

R1. [计划] 系统必须只新增一个默认发现且shfmt-clean的`tests/test-session-snapshot-assurance.sh`，不修改common/.harness/lib/session-state-snapshot.sh及任何前序模块或测试；入口从自身路径解析repo root，只接受无参数、`all`或唯一`--dependency-absent`，unknown/extra/flag带值返回1且不打印PASS。

R2. [计划] 当真实snapshot provider物理缺席时，系统必须使默认无参数、`all`与`--dependency-absent`运行走同一零active case的inert oracle并以同一固定摘要`RESULT PASS  session snapshot assurance\n`逐字退出0；当provider路径存在但非普通文件、是symlink、`bash -n`语法失败、source非零、source后预期三个snapshot export缺席、任一anchor非精确一次或`renameat2`非精确一次时，系统必须fail closed返回1且不打印PASS。

R3. [计划] 当入口执行active分支时，系统必须只复制provider到隔离临时副本并在八个anchor处注入攻击，注入前核对原provider文本中八个marker各精确一次、`renameat2`调用精确一次且不存在rename/link publish fallback；不得修改原provider文件，副本与state root必须位于`mktemp`隔离目录。

R4. [计划] 当攻击者在held capture fd的已unlink pathname上重建同名文件时，系统必须证明worker仍消费held fd字节：snapshot发布落到canonical session path、重建文件内容逐字节等于攻击者写入、无owned temp残留。

R5. [计划] 当managed root/project/session任一层或snapshot leaf在stat→open之间被换成symlink/different-inode或消失时，系统必须对read/write各覆盖全部组合：link与different-inode返回2、认证后消失返回1、失败双流空，并逐行核对被移原winner完整指纹不变、victim不变、换入对象的注入identity与精确shape、无owned temp残留。

R6. [计划] 如果发生无特权wrong-owner、强制一字节short read或真实EIO，系统必须使managed与snapshot expected-EUID失败对read/write均返回2且winner/temp不变、short read仍逐字节产出精确`feature`+LF并返回0、EIO对既有read与fresh write均返回1且双流空，并逐行核对各自winner/victim/temp delta。

R7. [计划] 如果发生publish seam的libc symbol缺失、`ENOSYS`或确定性`EEXIST`，系统必须使缺symbol与ENOSYS返回1且无任何fallback，EEXIST后same/different/unsafe/disappear分别返回0/3/2/1且全部双流空；same/different必须在进入winner首次name-stat前证明owned temp已清，并在返回后核对完整winner指纹（dev/inode/uid/mode/nlink/size/hash），unsafe/disappear核对注入identity与精确shape，所有分支victim不变且无temp残留。

R8. [计划] 当write child在`TEMP_BEFORE_PUBLISH` barrier后收到HUP/INT/TERM时，系统必须向`ps`证实已为Python的PID逐信号送达，并核对首信号rc恰为129/130/143、无winner、owned temp清零；ignore安装期第二信号必须只返回且不改首信号码。provider-copy窗口行必须覆盖post-close信号、signal+cleanup-close-error下owned temp/session/三层ancestor共五次close尝试且锁存信号码优先于cleanup错误、rename未提交窗口无winner、rename已提交窗口winner保持完整指纹且旧temp名只得到`ENOENT`、已提交winner绝不回滚。

R9. [计划] 当03b1进入验收时，系统必须在candidate、完整历史checkout和真实`git clone --depth 1 file://...`中分别运行默认assurance入口与`bash ./scripts/check.sh --offline`，自动发现本入口恰好一次，且每个checkout的当前tracked上游六文件（common/.harness/lib/session-state-foundation.sh、common/.harness/lib/session-state-path.sh、tests/lib/session-path-race-driver.py、tests/test-session-path-races.sh、common/.harness/lib/session-state-snapshot.sh、tests/test-session-snapshot.sh）SHA-256在测试前后不变。controller必须先逐字验证shfmt `v3.14.0`与ShellCheck version field `0.11.0`，再只对本片exact单文件运行`shfmt -d -i 2 -ci -bn`、`shellcheck -x --severity=warning`与`bash -n`；execution BASE到accepted HEAD必须exact只新增`tests/test-session-snapshot-assurance.sh`、numstat总和`<=400`，六列review manifest必须与tasks一一对应、首尾/相邻连续、reviewer非空且全PASS，`git diff --check`与worktree clean必须通过。

R10. [计划] 当验证独立回滚与顺序时，系统必须从accepted HEAD建立隔离临时分支，提交一个exact只删除该assurance入口的rollback commit，在该clean checkout运行03b基础测试与offline并要求全绿、本入口发现0次；验收后丢弃临时checkout，不改变candidate/full/depth-1 checkout。controller只有在03b1 accepted HEAD、dependency-present完整矩阵、exact1/400与全PASS manifest入ledger后，才可创建规范ID `2026-09-02-03c-session-write-interrupts`的spec目录、同名`spec/`分支/worktree、ledger execution BASE或dispatch记录；此前这四类资产必须物理缺席，以`test ! -e`、`git show-ref --verify --quiet`反值、`git worktree list --porcelain`与`rg`机械核对；任何inert PASS不得作为本片验收证据或解除该顺序门。

## 验收标准

主验证命令: bash ./tests/test-session-snapshot-assurance.sh
期望输出: dependency-present时退出码为`0`、stderr空，stdout逐字节精确为`RESULT PASS  session snapshot assurance\n`，且完整矩阵逐case全PASS

验收清单:

- [ ] exact单文件入口只消费03b provider与八anchor；unknown/extra/flag带值rc1且无PASS；provider物理缺席时默认/all/--dependency-absent逐字同一inert摘要且零active case。
- [ ] provider存在但非普通文件、是symlink、bash -n/source失败、三export缺席、anchor或renameat2次数错时fail closed rc1无PASS；inert摘要不计入本片验收证据。
- [ ] 注入前核对八marker各精确一次、renameat2精确一次、无rename/link fallback；原provider文件SHA-256在运行前后不变；副本与state root均在mktemp隔离目录。
- [ ] capture同名重建行证明发布落到canonical path、重建文件内容逐字节等于攻击者写入、无temp残留。
- [ ] managed三层×link/inode/missing×read/write与snapshot leaf×link/inode/missing×read/write逐行核对rc、双流、被移原winner指纹、victim、换入identity与shape、temp。
- [ ] wrong-owner四行rc2、short-read行rc0且stdout hex精确feature+LF、EIO两行rc1双流空；各行winner/victim/temp delta均核对。
- [ ] 缺symbol/ENOSYS行rc1且无fallback；EEXIST四行rc 0/3/2/1，same/different在winner首次name-stat前证明temp已清且完整winner指纹一致，unsafe/disappear核对identity/shape，victim不变。
- [ ] HUP/INT/TERM三行在barrier后送达ps证实为Python的PID，首信号rc 129/130/143、第二信号不改码、无winner、temp清零；post-close、cleanup-close五次close、rename未提交/已提交窗口行核对锁存rc、namespace与已提交winner不回滚。
- [ ] candidate/full/depth-1的默认入口与offline全PASS，offline发现恰好一次，depth-1 commit-count=1且shallow marker非空；每个checkout的上游六文件SHA-256测试前后不变且clean。
- [ ] 隔离rollback commit exact只删除本入口后，clean checkout中03b基础测试与offline全PASS且本入口发现0次；03c的spec/ref/worktree/BASE/dispatch按R10机械查缺席。
- [ ] review manifest六列、任务序号、execution BASE、相邻base/head、accepted HEAD和全PASS一次机械验证通过；BASE..HEAD exact name-only为上述单文件、numstat总和`<=400`，固定版本断言后对exact单文件运行shfmt/ShellCheck/bash-n全绿，`git diff --check`和clean通过；只有dependency-present完整矩阵入ledger后才可创建03c。

不变量（不许劣化，2-4项）:

- assurance任一case改变已发布安全winner的次数 ≤ `0`，验证: 每case前后比较winner dev/inode/uid/mode/nlink/size/hash指纹。
- 不安全换入对象被read/write跟随或victim被修改的次数 ≤ `0`，验证: 攻击矩阵的victim指纹与session namespace inventory delta。
- case结束后本调用未发布owned temp残留数 ≤ `0`，验证: 每case前后在临时根下find `.snapshot-*`计数。
- 上游六tracked文件在execution BASE..HEAD的变更数 ≤ `0`，验证: `git diff --name-only "$BASE" "$HEAD" -- common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh tests/lib/session-path-race-driver.py tests/test-session-path-races.sh common/.harness/lib/session-state-snapshot.sh tests/test-session-snapshot.sh`。

## 超出范围

- 不修改03b snapshot provider及03/03a/03a1/03a2任何模块或测试；不设置`HARNESS_SESSION_STATE_PROVIDER_VERSION`，不发布public path/write/read/remove或任何运行时API。
- 不实现03c的Bash signals facade、spawn-gap补转发、process-group信号或facade first-signal-wins；本片只证明03b worker级信号语义，03c启动仍以dependency-present完整矩阵ledger为门。
- 不重复03b基础测试已验收的静态攻击表与真实并发矩阵；本片独占provider-copy动态穷举，inert PASS不替代dependency-present证据。
- 不实现remove/prune/final aggregator/coverage fragment（属03d）；不调用设备、网络、AOSP build、Claude/Codex客户端，不push、不清理已有spec/prototype/implementation分支或worktree。
