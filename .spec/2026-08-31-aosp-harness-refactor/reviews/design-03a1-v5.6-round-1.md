# 03a1 design v5.6 review — round 1

Reviewer: `review_plan_v5_2`

Verdict: **NEEDS_CHANGES** — blocker 1 / important 4 / minor 1

审查范围：只读核对当前03a1 `design.md`，对照requirements R1–R9、PLAN v5.6、round7 final report/evidence及两份实际prototype；未修改design、requirements、PLAN或prototype。九个编号章节均存在，R1–R9映射、private CLI三种形状、成功双流/rc、canonical四列grammar、三个唯一anchor、九family delta表、14项self-disproof清单、exact1/400/manifest/order gate均有落点；以下承重缺口阻止进入tasks。

## Blocker

### B1 — `CASE_LOG`与workspace没有物理隔离契约，合法CLI可先改坏production provider再以rc1失败

- 位置：`design.md:58,64-66,70,153-167,175`；对应`requirements.md:21,25,29`。
- 证据：design只要求`ABSENT_WORKSPACE`不存在并以0700创建，却没有要求其parent已存在、没有禁止创建任意祖先，也没有约束`CASE_LOG`必须位于workspace内、调用前不存在、不得是symlink/hardlink或不得与`FOUNDATION`/`PROVIDER`/`CASE_TSV` alias。round7实际driver `:29`接受任意`CASE_LOG`，`:42`以`parents=True`创建workspace，`:216`用跟随symlink且append既有文件的`case_log.open("a")`写日志，直到`:380`才检查provider bytes。令`CASE_LOG == PROVIDER`或令其为指向provider的symlink时，第一个通过oracle的case就会向provider追加ID；末尾hash即使把进程变成rc1，也无法撤销已发生的上游修改。这直接违反R1“不得修改provider”、R5“provider前后相同”和design `:167`“不写production provider”。
- 影响：private测试CLI不是fail-before-mutation；错误或恶意fixture路径可以损坏已验收03a文件，也会使“只新增driver、前序零diff、可独立回滚”失真。
- 可执行修复：在任何`mkdir`/日志写入/child执行前定义并实现单一物理路径preflight。推荐要求workspace parent预先存在，最终workspace只以`parents=False`创建；`CASE_LOG`必须调用前物理不存在且位于新workspace内，以`O_CREAT|O_EXCL|O_NOFOLLOW`创建。若坚持允许外置log，则必须等价地拒绝symlink/hardlink、与foundation/provider/TSV的inode或解析路径alias/祖先重叠，并证明不创建workspace祖先。增加provider直连、symlink、hardlink、既有log与缺失parent反证，失败须发生在任何case执行前且provider hash不变。

## Important

### I1 — design把14项自反证限定为`self-test`，round7实际却在`run-matrix`无条件执行并暗含未声明的完整37-row前置

- 位置：`design.md:37,108,163,167`；`requirements.md:25,33,48`；round7 driver `:241-266,288-291,318-379`。
- 证据：design的数据图和流程都明确只有`self-test`进入14项self-disproof；R7触发条件也是“当self-test准备打印成功摘要”。但prototype在所有mode执行完rows后无条件访问`oracle_probe`、三种`oracle_probes`、`eexist_hook_probe`和`mkdir_hook_probe`并运行`:345-379`的14项反证。语法和canonical ID均合法的外部row子集会因缺这些probe而NameError/KeyError或oracle失败，而R3/Row validator并未声明`run-matrix`必须精确包含整套37 rows。round7只实跑完整37-row外部matrix，未反证这一接口漂移。
- 影响：实际prototype没有证明design描述的通用四列executor；若用“driver要求固定37”来补洞，又会把03a2独占的外部matrix集合/生成职责带回03a1并与PLAN边界冲突。
- 可执行修复：实现中把14项probe与self-disproof严格置于`self-test`分支，`run-matrix`只执行输入rows及共享逐case oracle/log；增加一个合法非37子集的成功验收和一个完整37-row外部验收。若确实要拒绝子集，则必须先回流requirements/PLAN重新定义owner，不可仅在design隐含。

### I2 — self-test声明的固定family顺序与prototype实际顺序不同

- 位置：`design.md:82`；`requirements.md:27,47`；round7 driver `:15-20`。
- 证据：design/验收顺序是`swap → wrong-euid → eexist → mkdir-replace → mkdir-failure → post-mkdir → open-disappear → final-stat → real-eio`。prototype `default_rows()`实际构造`swap → eexist → 五种managed family → wrong-euid → real-eio`。round7 evidence只给九类计数，没有给self-test case-log的37行逐字顺序，因此不能支撑“固定顺序”声明。
- 影响：实现者按design或按已通过prototype会得到不同canonical执行日志，review没有唯一oracle。
- 可执行修复：将prototype/实现的`default_rows()`重排到design/R4顺序并在evidence记录37个ID的逐字hash或完整有序比较；或者先从requirements/design删除顺序要求。前者不增加LOC，且保留已有验收口径。

### I3 — R6/design要求C-locale排序，381行prototype没有实施该行为

- 位置：`design.md:92`；`requirements.md:31`；round7 driver `:126-133,145-152`。
- 证据：`inventory()`直接迭代`os.walk()`返回的`directories + files`，既未排序目录以稳定walk顺序，也未按C-locale/byte key排序最终path keys。后续set/dict相等能消除部分顺序影响，但不等于requirements要求的“比较C-locale排序的scoped inventory”，也没有相反目录创建顺序的反证。
- 影响：381/400 sizing原型没有支付一项明确R6行为；不同文件系统枚举顺序下无法用现有evidence证明canonical inventory实现，剩余19行headroom也尚未重新计数。
- 可执行修复：明确唯一canonical key算法（例如对relative-path的filesystem bytes排序），在walk时阻止未排序目录顺序传播，并用逆序创建/非字典序名字fixture证明before/after oracle一致；重新固定格式和计数，仍须`<=400`。

### I4 — design声称round7已经支付full/depth-1 private self-test，现有final evidence只记录03a2 shell direct/offline

- 位置：`design.md:7,193,197`；`requirements.md:35,52,60`；`round7-sizing-report.md:49-50,59`；`round7-evidence.log:37-38`。
- 证据：R8/design要求accepted HEAD的full和真实file-URL depth-1分别运行driver `protocol`与38-byte `self-test`。report/evidence的checkout条目却只记录`direct rc0/stdout41`和offline；41 bytes是03a2 shell的`session path race assurance`摘要，不是本片38-byte private摘要。driver self-test的38-byte记录只有未标注checkout的单条evidence `:10`。因此`design.md:197`“已支付上述承重路径”超出现存证据。
- 影响：浅克隆门本身写对了，但不能用round7 final作为已经支付的实现/尺寸证据；当前证据混合了03a1与03a2职责。
- 可执行修复：在full与真实depth-1 staged checkout分别显式记录driver protocol/self-test的rc、stdout字节数/精确文本、stderr字节数和当前tracked foundation/provider；保留shell direct/offline为03a2证据，不用其41-byte摘要替代03a1门。

## Minor

### M1 — stream capture机制的design陈述与prototype不一致且不是需求

- 位置：`design.md:84`；round7 driver `:201-204`。
- 证据：design说stdout/stderr/rc“以文件capture”，prototype实际使用`subprocess.PIPE`内存捕获。R2只要求逐字比较双流和rc，没有规定媒介。
- 影响：不影响结果语义，但会让实现review把合规的PIPE误判为偏离design，或错误声称prototype已证明文件capture。
- 可执行修复：改为“独立捕获并逐字比较stdout/stderr/rc”，除非文件capture本身有需要验收的安全理由。

## 已闭合项

- 九个标准章节均完整；需求映射覆盖R1–R9，consume/produce逐字匹配requirements frontmatter，03a1不读/import未来03a2且直接依赖无环。
- CLI成功流和rc 0/1/2、protocol不读依赖、失败无private PASS、TSV token/canonical ID语法均清楚；prototype `protocol`与`self-test`本reviewer实跑分别得到精确v1 token与38-byte PASS。
- 三anchor字段、EEXIST双phase、九family delta、完整signature字段和14项名称/顺序均有明确oracle；未发现把inert/default discovery/runtime API带回03a1。
- 测试策略保留full/depth-1、offline non-discovery、exact1/400、03/03a zero-diff、六列manifest连续和ledger-before-03a2顺序门；owner仍仅`tests/lib/session-path-race-driver.py`。

## Mechanical/runtime evidence

- `check-req.py`: rc0
- `check-criteria.py`: rc0
- `check-analyze.py`: rc0
- `check-plan.py`: rc0
- `git diff --check`: rc0（写本报告前）
- round7 prototype LOC：driver 381/400，entrypoint 109/400
- 本reviewer实跑round7 driver：`protocol` rc0、精确v1 token；`self-test` rc0、精确38-byte PASS。

## 最终判定

**NEEDS_CHANGES**。B1必须先闭合；I1–I4必须让design、requirements和重新执行的prototype/evidence形成同一契约后，才能进入tasks。
