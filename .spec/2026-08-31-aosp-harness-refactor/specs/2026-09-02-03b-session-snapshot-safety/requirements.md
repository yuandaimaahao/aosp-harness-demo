---
id: 2026-09-02-03b-session-snapshot-safety
依赖: [2026-09-01-03-session-state-safety, 2026-09-01-03a-session-path-safety, 2026-09-02-03a2-session-path-race-matrix]
消费: "session-foundation-v1的harness_validate_feature_name <name>；session-path-delivery-v1的_harness_session_path_core <project-id> <session-id>成功path+LF/0或OS错1或安全协议错2；session-path-race-matrix-v1的03a2 accepted ledger中dependency-present 37/37与九类全PASS门（无运行时API）"
产出: "session-snapshot-core-v2 —— spawn-only _harness_session_snapshot_worker write|read ...、signal-aware _harness_session_snapshot_write_core <project-id> <session-id> <feature>与_harness_session_snapshot_read_core <project-id> <session-id>的私有协议 plus tests/test-session-snapshot.sh基础摘要及03b1 anchors；无public API/provider marker"
验收方式: 混合判定
已由用户确认: true
确认依据: 用户已授权后续按autopilot执行；PLAN v5.7把Python child信号清理归还03b并新增03b1顺序门；03a2启动门已满足，prototype a708ce6补齐child latch、strict worker零state副作用、四态source完整inventory/export、held capture、静态攻击整树delta、字节级read、并发winner及post-close/early-second/post-rename/signal+cleanup-close-error线性化，固定格式实跑core208+base192=400/400且exact2 ShellCheck全绿；03b1 prototype cbdbdde固定格式308/400、240项调用/状态delta全绿
---

> 用户原话：“$spec review 这套 aosp harness 工程，有哪些欠缺的地方，进行重构和完善”；并确认后续按 autopilot 执行。PLAN v5.7要求03b在03a2 dependency-present竞态门通过后交付signal-aware create-once snapshot worker，03b1再穷举其动态安全分支。

## 目标

只新增snapshot私有模块与基础默认测试：在已harden的session path下以held capture fd和重新验证的managed fd链首次发布固定`feature`快照，同值幂等、异值冲突且绝不覆盖winner，读取只接受安全唯一规则文件；spawn-only `_harness_session_snapshot_worker write|read ...`自己处理HUP/INT/TERM并清本调用未发布temp。feature规则以`harness_validate_feature_name`为真值；发布只使用Linux `renameat2`的`RENAME_NOREPLACE`，`ENOSYS`是不降级的OS错分支。生产文本供03b1 provider-copy反证的anchors是`HARNESS_TEST_MARKER_CAPTURE_READY`、`HARNESS_TEST_MARKER_SNAPSHOT_MANAGED_BEFORE_OPEN`、`HARNESS_TEST_MARKER_MANAGED_EXPECTED_EUID`、`HARNESS_TEST_MARKER_SNAPSHOT_EXPECTED_EUID`、`HARNESS_TEST_MARKER_SNAPSHOT_BEFORE_OPEN`、`HARNESS_TEST_MARKER_TEMP_BEFORE_PUBLISH`、`HARNESS_TEST_MARKER_PUBLISH_RESULT`与`HARNESS_TEST_MARKER_OS_ERROR`；它们都不是capability marker。本片继续不设置`HARNESS_SESSION_STATE_PROVIDER_VERSION`、不发布public path/write/read/remove；03b1先穷举动态分支，03c再只包装信号转发facade。

## 需求

R1. [计划] 当`harness_validate_feature_name`与`_harness_session_path_core`均已定义时，系统必须使source `common/.harness/lib/session-state-snapshot.sh`返回0、双流空，只新增spawn-only `_harness_session_snapshot_worker write|read ...`、write core与read core三个私有export；source不得读写文件、覆写依赖、定义状态public API或设置`HARNESS_SESSION_STATE_PROVIDER_VERSION`。如果source时validate或path core任一缺席，系统必须静默返回0并保持三个snapshot export、四个状态public API与marker全缺席。

R2. [计划] 当调用两个snapshot core时，系统必须先检查exact arity，write还必须按已验收`harness_validate_feature_name`同等规则拒绝非安全单组件feature；再以umask077 exclusive创建0600 capture、持有fd后立即unlink名字，让`_harness_session_path_core <project-id> <session-id>`只向该fd写入，并由最终exec替换成的Python进程继承同一fd，经fstat/lseek/有界读取解析exact path+LF；不得按pathname reopen，重建原名不得改变消费bytes。这个已unlink的capture输入文件不属于R4的同session `.snapshot-*` publish owned-temp。认证后的path core输出是physical parent/root的语义真值；解析器只要求root非空且末两段逐字为project/session，再从physical parent fd对root/project/session逐层执行nofollow name-stat预检→open/fstat/after-stat、当前EUID、mode精确0700与身份一致检查，最后只通过session fd操作固定leaf `feature`。managed link/type/owner/mode/identity错返回2，真实I/O或已认证对象消失返回1；path原始1/2分别透传。所有write结果及read失败结果双流空。

R3. [计划] 当读取既有`feature`快照时，系统必须以R2调用会安全创建缺失managed目录的path core取得session fd；non-creating承诺只覆盖snapshot leaf。name stat后必须先按当前EUID、regular type、0600、nlink1归类，错误立即返回2而不尝试open；再经过snapshot marker以`O_NOFOLLOW|O_CLOEXEC`相对open、fstat和after-stat验证同一对象及属性保持。内容必须循环读取以容忍合法short read，累计130 bytes立即拒绝，否则直到EOF并只接受精确字节语法`^[A-Za-z0-9][A-Za-z0-9._-]{0,127}\n$`。成功唯一stdout逐字节为feature+唯一LF/0；leaf缺席3且不建leaf/temp；已安全stat对象消失1；链接/类型/owner/mode/nlink/身份或内容损坏2。固定损坏表含空文件、129-byte feature+LF、非ASCII、无LF、多LF、合法LF后额外字节，以及`.bad\n`、`a b\n`、`a/b\n`三种非法ASCII；所有失败双流空且不修改victim。

R4. [计划] 当write看到leaf物理缺席时，系统必须用不可猜测同目录名、`O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC`、0600创建并fstat证明owned temp，循环写入feature+LF并close后经过temp/publish marker，只用Linux `renameat2(..., RENAME_NOREPLACE)`发布；不得使用替换rename、link publish或先移除winner。缺symbol、`ENOSYS`及其他非EEXIST errno均双流空/1且无fallback；成功双流空/0。spawn-only worker必须是普通函数链并在最终步骤直接exec Python，使03c background调用取得的PID就是Python worker；write/read core只在各自隔离subshell调用worker。Python write worker必须在创建任何同session `.snapshot-*` publish owned-temp前安装HUP/INT/TERM handler；首个handler入口必须先原子锁存first_signal，后续重入handler只返回，再把三者全设为ignore并抛私有中断。任何可中断close前必须先转移并清空fd ownership；cleanup必须记录close错误或私有中断、继续尝试全部后续fd close，并以嵌套finally保证仍尝试unlink；全部cleanup结束后已锁存的129/130/143优先于任何cleanup错误。rename未提交时信号清temp且无winner；rename已经提交但Python尚未更新ownership时winner必须继续存在、旧temp名清理只可得到ENOENT并返回首信号码；EEXIST期间先清temp且绝不修改winner。publish之后不得移除winner。read worker不创建owned-temp，只承诺普通`0|1|2|3`协议，不承诺信号码或first-signal latch。

R5. [计划] 如果发生publish marker后的`RENAME_NOREPLACE`返回EEXIST，系统必须先清owned temp，并由03b1在进入winner的首次name-stat之前证明session中已无该owned temp，再用R3同一完整oracle读winner：同值0、异值3、unsafe2、消失1且全部双流空；不得让最外层Missing把消失误映射成3。系统必须使并行同值writers全0、并行异值恰一0而其余3，最终唯一安全winner属于请求集，loser/幂等不改winner dev/inode/uid/mode/nlink/size/hash；生产publish marker可供03b1只改provider copy便确定性进入缺symbol、ENOSYS与EEXIST四分支，基础测试至少证明真实并发结果、完整winner指纹不变和无temp残留。

R6. [计划] 如果发生managed/snapshot链接、hard link、directory、wrong-owner、wrong-mode、九类内容或stat→open替换，系统必须使read/write fail closed且不修改攻击对象/victim/winner。基础测试必须覆盖三managed层的static link/file/wrong-mode/disappear、managed后缀不匹配、snapshot static对象/内容表和七anchor加OS anchor各精确一次；03b1才用provider-copy穷举capture同名重建、managed/snapshot link/different-inode/disappear、无特权expected-EUID、short-read、真实EIO、publish与temp信号。生产模块不得读取测试环境变量；任一anchor只能是无副作用文本点，完整动态证据不是03b自身验收或03c启动的替代品。

R7. [计划] 系统必须提供默认发现且shfmt-clean的`tests/test-session-snapshot.sh`，只接受无参数、`all`或唯一`--dependency-absent`；dependency-present默认/all覆盖source零副作用、三export/arity/双流、held capture结构、path rc、first/read/same/different、managed/snapshot static表、同/异值并发、常规temp cleanup、worker直接background后越过TEMP barrier时`ps`所见PID已为Python且信号命中同PID、以及八anchor occurrence。真实validate/path provider缺席或fixture缺任一export时，默认与flag运行同一inert surface并零active case；成功唯一摘要为`RESULT PASS  session snapshot safety\n`，unknown/extra/flag带值rc1且无PASS。

R8. [计划] 当03b进入验收时，系统必须在candidate、完整历史checkout和真实`git clone --depth 1 file://...`中分别运行默认snapshot测试与`bash ./scripts/check.sh --offline`，自动发现snapshot入口恰好一次，且每个checkout的当前tracked foundation/path/03a1-driver/03a2-entrypoint SHA-256在测试前后不变。controller必须先逐字验证shfmt `v3.14.0`与ShellCheck version field `0.11.0`，再只对本片exact两文件运行`shfmt -d -i 2 -ci -bn`、`shellcheck -x --severity=warning`与`bash -n`；execution BASE到accepted HEAD必须exact只新增`common/.harness/lib/session-state-snapshot.sh`与`tests/test-session-snapshot.sh`、numstat总和`<=400`，六列review manifest必须与tasks一一对应、首尾/相邻连续、reviewer非空且全PASS，`git diff --check`与worktree clean必须通过。

R9. [计划] 当验证独立回滚与顺序时，系统必须从accepted HEAD建立隔离临时分支，提交一个exact只删除snapshot module/test的rollback commit，在该clean checkout运行03a path、03a1 self-test、03a2默认入口和offline并要求全绿、snapshot发现0次；验收后丢弃临时checkout，不改变candidate/full/depth checkout。controller只有在03b accepted HEAD、基础active证据、八anchor、signal-aware协议、exact2/400和全PASS manifest入ledger后，才可创建规范ID `2026-09-02-03b1-session-snapshot-assurance`的spec目录、同名`spec/`分支/worktree、ledger execution BASE或dispatch记录；规范ID `2026-09-02-03c-session-write-interrupts`的相同四类资产仍必须物理缺席，且只有未来03b1 dependency-present完整矩阵入ledger后才能创建。顺序门必须以`test ! -e`核spec目录、`git show-ref --verify --quiet refs/heads/spec/<id>`的反值核分支、`git worktree list --porcelain`核worktree路径/branch、`rg`核ledger/dispatch/BASE记录；任一inert PASS不得解除任何顺序门。

## 验收标准

主验证命令: bash ./tests/test-session-snapshot.sh
期望输出: 退出码为`0`、stderr空，stdout逐字节精确为`RESULT PASS  session snapshot safety\n`

验收清单:

- [ ] exact两文件只发布spawn-only worker与两个snapshot core及固定摘要基础测试；source功能/validate缺席/path缺席fixture逐字比较rc/双流、依赖函数体、三个snapshot export、四public API、provider marker、环境export属性和inventory，证明零副作用或inert。
- [ ] write/read arity、非法feature与path core的`0|1|2`表逐字验证；capture fd创建后名字已缺席、Python继承同一0600/nlink0 fd且生产文本无pathname reopen；read在缺失managed目录时只可由path core创建安全目录，leaf缺席3且不创建leaf/temp。
- [ ] root/project/session各自的static symlink/file/wrong-mode均返回2且不触及目标；认证path后managed对象真实消失返回1，后缀不匹配返回2；完整stat-open mutation留给03b1而非移除anchor。
- [ ] fresh write后read以文件hex/cmp逐字证明唯一LF成功；同值重写返回0、异值重写返回3且每次winner dev/inode/uid/mode/nlink/size/hash不变；快照为当前EUID、0600、nlink1的nofollow普通文件并精确feature+LF。
- [ ] 并行同值writers全rc0，并行异值writers结果恰好一个0与其余3；第二波并发幂等/loser前后完整winner指纹不变，最终唯一winner内容属于请求集且无未发布temp。
- [ ] snapshot symlink/hardlink/directory/wrong-mode与固定九类损坏内容的read/write均fail closed；victim/winner不变、不安全层不产生temp；wrong-owner、short-read与动态swap由各自exact-once anchor留给03b1无特权反证。
- [ ] capture/managed-EUID/managed-before-open/snapshot-EUID/snapshot-before-open/temp/publish及OS八个anchor在生产文本各精确一次且不读测试环境；write worker在任何`.snapshot-*` owned-temp前安装三个handler并先锁存first signal，close前转移ownership，cleanup错误不遮蔽信号码且不阻断后续unlink/close；provider-copy覆盖post-close、ignore安装期第二信号、signal+cleanup-close-error的五次close尝试、rename未提交与已提交窗口，已提交winner不回滚；read无信号协议。
- [ ] 真实dependency-present默认/all与隔离provider-absent默认/flag均得唯一固定摘要，但只有dependency-present基础active evidence计入03b验收；unknown/extra/flag带值rc1/no-PASS；03b1完整矩阵尚未存在不能冒充PASS。
- [ ] candidate/full/depth-1的snapshot默认与offline全PASS，offline发现恰好一次，depth-1 commit-count=1且shallow marker非空；每个checkout的当前tracked上游SHA测试前后不变且clean。
- [ ] 隔离rollback commit exact只移除snapshot module/test后，clean checkout中path、driver self-test、race entrypoint与offline全PASS且snapshot发现0次；03b1/03c的spec/ref/worktree/BASE/dispatch按R9机械查缺席。
- [ ] review manifest六列、任务序号、execution BASE、相邻base/head、accepted HEAD和全PASS一次机械验证通过；BASE..HEAD exact name-only为上述两文件、numstat总和`<=400`，固定版本断言后对exact两文件运行shfmt/ShellCheck/bash-n全绿，`git diff --check`和clean通过；只有ledger accepted后才可创建03b1，03c继续缺席。

不变量（不许劣化，2-4项）:

- 已发布安全winner被同值、异值或并发loser改变的次数 ≤ `0`，验证: 每次调用前后比较winner dev/inode/hash/mode/nlink。
- 不安全snapshot/victim被read/write跟随或修改的次数 ≤ `0`，验证: 攻击表的victim与namespace inventory delta。
- 常规或worker信号返回后本调用未发布owned temp残留数 ≤ `0`，验证: session directory每case前后完整inventory；Bash facade信号转发属于03c。
- foundation/path/driver/race-entrypoint的execution BASE..HEAD变更文件数 ≤ `0`，验证: `git diff --name-only "$BASE" "$HEAD" -- common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh tests/lib/session-path-race-driver.py tests/test-session-path-races.sh`。

## 超出范围

- 不修改03/03a/03a1/03a2模块或测试，不设置provider marker，不发布public path/write/read/remove；03d aggregator才原子发布完整capability。
- 不实现Bash facade、spawn-gap/process-group转发或facade first-signal-wins；它们属于03c。Python child的首信号latch、owned-temp cleanup和`TEMP_BEFORE_PUBLISH`属于本片。
- 不在本片穷举provider-copy动态mutation、publish注入与signal barrier；只交付anchor和基础证明，03b1独占完整assurance入口。
- 不实现snapshot remove、目录prune、`PRUNE_BEFORE_IDENTITY`、final aggregator或coverage fragment；它们属于03d。
- 不调用设备、网络、AOSP build、Claude/Codex客户端，不push、不清理已有spec/prototype/implementation分支或worktree。
