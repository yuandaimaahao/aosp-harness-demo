# 03a2 requirements v5.6 review — round 1

Reviewer: `review_plan_v5_2`

Verdict: **NEEDS_CHANGES** — blocker 0 / important 3 / minor 1

## Findings

### Important 1 — entrypoint 与 controller 的 driver self-test 职责没有排他闭合

- 位置：`requirements.md:29,33,48,53`（R6、R8及验收清单）。
- 证据：R8要求“系统必须独立运行accepted driver的protocol与self-test”，但没有明确这是controller验收命令而不是`tests/test-session-path-races.sh`的运行时职责；R6只要求入口调用`run-matrix`，也没有写“且不得调用self-test”。PLAN `:107,111`和round7原型的真实边界是：private driver用self-test独立验收，默认entrypoint只消费`protocol`与一次`run-matrix`。
- 影响：实现者可让默认入口先跑driver self-test的内部37 case，再跑外部37-row；CASE_LOG仍只有37行，现有验收文字可能假绿，但默认/offline实际执行74 case，并把03a1的14项自反证职责带回03a2。
- 可执行修复：在R6/R8逐字规定“入口只调用一次`protocol`和一次`run-matrix`，绝不调用`self-test`；controller把`python3 DRIVER self-test FOUNDATION PROVIDER`作为独立验收命令”。验收增加fake-driver argv log或等价fixture，要求入口调用序列精确为`protocol,run-matrix`，同时controller单独取得self-test 38-byte PASS。

### Important 2 — pinned shfmt/ShellCheck 只有版本名，没有固定argv与exact文件集合

- 位置：`requirements.md:33,54`（R8及验收清单）。
- 证据：正文只写“pinned shfmt 3.14.0、ShellCheck 0.11.0、bash -n必须通过”，未规定版本输出字段、实际检查的唯一文件或参数。round7已验证的承重命令是`shfmt v3.14.0 -d -i 2 -ci -bn`、`ShellCheck 0.11.0 -x -S warning`和`bash -n`；已验收03a requirements `:31,48`也固定了版本断言、argv、exact owned files。
- 影响：实现可只运行`--version`、用较弱默认参数或检查别的文件，仍声称“pinned工具通过”，无法机械阻止格式/静态门假绿。
- 可执行修复：R8固定先逐字验证shfmt版本为`v3.14.0`、ShellCheck version字段为`0.11.0`，再仅对`tests/test-session-path-races.sh`运行`shfmt -d -i 2 -ci -bn`、`shellcheck -x --severity=warning`和`bash -n`，要求rc0且诊断/差异为空；验收清单照抄同一命令。

### Important 3 — R7名为“独立回滚”，却没有验收03a2自身的删除回滚

- 位置：`requirements.md:31,50-55`（R7及验收清单）；对照`PLAN.md:197,219`。
- 证据：R7完整覆盖03a/03a1依赖回滚后的provider/driver inert，但没有执行PLAN已固定的03a2自身回滚：删除唯一root entrypoint后，private driver self-test仍PASS，offline不再发现race入口，且不依赖尚未实现的03b文件。
- 影响：exact1使回滚看似简单，但没有运行证据证明root gate在entrypoint缺席时保持绿色、driver不被默认发现；PLAN的“03a1/03a2均可独立回滚”只闭合了一半。
- 可执行修复：在R7与验收清单加入隔离candidate checkout：只移除`tests/test-session-path-races.sh`，运行`python3 tests/lib/session-path-race-driver.py self-test ... && bash ./scripts/check.sh --offline`，要求driver精确38-byte PASS、offline PASS、root gate发现race entrypoint次数为0，且03b文件无需存在。

### Minor 1 — provider/driver SHA 门没有定义比较对象

- 位置：`requirements.md:33,54`。
- 证据：只写“provider/driver SHA必须通过”，未说明是固定摘要、BASE摘要，还是调用前后不变；同时R8又禁止depth-1查询固定历史SHA。
- 影响：不同实现者会生成不可比较的证据，或误把历史commit查询带入浅克隆。
- 可执行修复：规定在每个验收checkout从当前tracked dependency文件采集调用前SHA-256并在全部测试后逐字比较不变；accepted dependency身份由BASE..HEAD零diff/ledger绑定，不在运行时查询固定历史SHA。

## Confirmed coverage

- R1–R7的主优先级正确且无环：参数与matrix自损坏 → provider缺席inert/存在时三anchor → driver absent inert或type/protocol损坏fail closed → dependency flag/foundation/core inert → dependency-present单次run-matrix。
- R2、R6把外部matrix所有权、37唯一canonical ID、九类连续计数`9/3/9/3/3/3/3/3/1`、CASE_LOG有序逐字复核和损坏matrix先于inert写成可观察判据。
- R4–R7的inert surface明确要求private core、四public API与marker均缺席；provider/driver真正损坏不会被后序flag/core inert掩盖。
- R9–R10覆盖exact1、`git diff --numstat <=400`、六列manifest连续全PASS、dependency-present证据写ledger后才允许03b worktree/base/dispatch；inert PASS明确不能解除03b门。
- full history、真实file-URL depth-1、默认入口、offline自动发现、03/03a/03a1零diff与worktree clean均已进入R8/R9；除上述self-test职责措辞外，没有要求shell复制driver family/oracle。

## Mechanical checks

- `check-req.py`: rc0
- `check-criteria.py`: rc0
- `check-analyze.py`: rc0
- `check-plan.py`: rc0
- `git diff --check`: rc0

机械门全绿不覆盖上述跨条职责、rollback与工具argv语义缺口。
