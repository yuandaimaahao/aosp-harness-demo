---
id: 2026-09-01-03a-session-path-safety
依赖: [2026-09-01-03-session-state-safety]
消费: "harness_validate_feature_name <name>、_harness_session_state_foundation_path <project-id> <session-id>、_harness_session_state_run path <project-id> <session-id> —— foundation source 后存在；validate 合法0/双流空，path+LF/0，普通 OS 错1，安全/协议错2"
产出: "session-path-delivery-v1 —— _harness_session_path_core <project-id> <session-id>成功path+LF/0或OS错1或安全协议错2 plus三个生产文本唯一anchor plus tests/test-session-path.sh固定PASS摘要"
验收方式: 混合判定
已由用户确认: true
确认依据: 用户已明确后续按 autopilot 执行；PLAN v5.5 保留03a完整私有provider与确定性错误分类probe，把全部anchor-driven provider-copy mutation移至无运行时API的03a1，并以pinned shfmt-clean实测固定文件owner、inert回滚和各片400行门
---

> 用户原话：“$spec review 这套 aosp harness 工程，有哪些欠缺的地方，进行重构和完善”；并确认后续按 autopilot 执行。PLAN v5.5 的 `03a-session-path-safety` 条目是本片直接依据。

## 目标

交付可独立验收的私有 path hardening 模块：在不修改 foundation 的前提下，实际消费 public `harness_validate_feature_name`，并对 root/project/session 的新建、`EEXIST` 竞争与既有目录统一执行 nofollow、EUID、精确 `0700` 和 name↔fd dev/inode/`fstat` 身份校验，禁止对namespace重取对象执行`fchmod`。安全探针固定为 `HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN`、`HARNESS_TEST_MARKER_EXPECTED_EUID`、`HARNESS_TEST_MARKER_OS_ERROR`；本片不设置 `HARNESS_SESSION_STATE_PROVIDER_VERSION`，不发布 public path API，以 manifest 全 `PASS` 作为验收前提。

## 需求

R1. [计划] 当 foundation 的 `harness_validate_feature_name`、`_harness_session_state_foundation_path` 与 `_harness_session_state_run` 已定义时，系统必须使 source `common/.harness/lib/session-state-path.sh` 返回 `0`、stdout/stderr 为空，只新增私有 `_harness_session_path_core <project-id> <session-id>`；source 结果不得受 HARNESS/XDG/TMP 状态值影响，不得创建/修改文件、改写这三个变量的值/导出属性、覆写 foundation 函数体、设置 `HARNESS_SESSION_STATE_PROVIDER_VERSION` 或定义 `harness_session_state_path/write/read/remove`。

R2. [计划] 如果发生 R1 的 public validate 或两个 foundation 私有函数任一缺席，系统必须使直接 source path 模块静默返回 `0` 并保持 inert：不定义 `_harness_session_path_core`、状态 public API 或 marker。`bash ./tests/test-session-path.sh --dependency-absent` 与真实上游缺席时的默认运行都必须验证此分支，成功摘要与功能分支相同。

R3. [计划] 当调用 `_harness_session_path_core <project-id> <session-id>` 时，系统必须先检查 exact arity，再以 foundation public `harness_validate_feature_name` 按 project/session 顺序校验两个 ID，丢弃 validate 自身双流并映射为 core 的 unsafe 错误；合法调用按 foundation 的 HARNESS/XDG/TMP/default 选择语义得到 physical parent，以 fd-relative `mkdir/open` 持有 root/project/session 链，成功 stdout 唯一为 physical absolute session path+LF、stderr 空、返回 `0`。arity/ID/根安全错必须 stdout 空、stderr 精确 `error: unsafe session state\n`、返回 `2`；其他普通 OS 错 stdout 空、stderr 精确 `error: session state operation failed\n`、返回 `1`。

R4. [计划] 当 root/project/session 组件缺席时，系统必须在 `umask 077` 下用 `mkdir(0700)` 创建，不对 mkdir 后从 namespace 重新取得的任何 inode 执行 fchmod；新建成功后必须取 name stat，再 nofollow open/fstat 并证明 dev/inode/type/EUID/0700 一致。当组件已存在时，必须只校验而不 chmod，并且要求非链接目录、owner 等于当前 EUID、mode 精确 `0700`。对 root/project/session 各层的软链接、普通文件、错误 mode 或 owner 必须返回安全错 `2`，不跟随 victim，不修改既有 inode/mode/内容，不在不安全层下创建后续目录。fresh 的 stat-missing→mkdir 若遇 `EEXIST`，必须重新取 name stat 并执行同一套 type/EUID/0700/name-fd 校验：安全 winner 返回同一路径/`0`，不安全 winner 返回 `2`，winner 在 EEXIST 后消失或其他普通竞争 OS 错返回 `1`。

R5. [计划] 如果发生受管目录的 missing/create/open 竞争，系统必须通过一个生产文本仅出现一次的 `HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN` no-op checkpoint 函数支持 before_mkdir、after_eexist、before_open 三个调用 phase；生产实现必须在 nofollow fd 后比较 name stat 与 `fstat` 的 dev/inode/type，并把换入链接/非目录导致的 `ELOOP|ENOTDIR` 或身份不同映射为 `2`、消失竞争映射为 `1`。生产文件还必须各精确保留一个 `HARNESS_TEST_MARKER_EXPECTED_EUID` 和 `HARNESS_TEST_MARKER_OS_ERROR`，且不得读取测试专用环境变量。本片以source文本结构检查证明三个anchor各精确一次、三个phase各精确一次、checkpoint真实位于managed路径且不存在`fchmod`；全部provider-copy动态注入与sentinel/catch/made/victim oracle由直接后继03a1独占，且03a1通过前没有consumer。

R6. [计划] 系统必须提供独立离线的 `tests/test-session-path.sh`，功能分支覆盖 fresh 与既有安全目录、确定性post-mkdir disappearance的OS错误分类、root/project/session 三层静态攻击、两 project×两 session 唯一性、R5 的anchor/phase结构、参数/环境/错误字节和 source 零副作用；inert 分支覆盖 public validate 与两 private foundation export各自缺席。默认dispatcher必须逐子组精确传播rc/stdout/stderr并用保留末尾LF的文件比较固定摘要。成功必须退出 `0`、stderr空且stdout逐字节精确为 `RESULT PASS  session path safety\n`，不调用设备、网络、build、Claude 或 Codex。

R7. [计划] 当 03a 进入验收时，系统必须由 controller 证明 execution BASE 到最终 HEAD 只修改 `common/.harness/lib/session-state-path.sh` 与 `tests/test-session-path.sh`、总 numstat 行数不超过 `400`；先精确验证 `shfmt --version` 为 `v3.14.0`、ShellCheck `--version` 的version字段为`0.11.0`，再对上述exact两文件分别运行 `shfmt -d -i 2 -ci -bn` 与 `shellcheck -x --severity=warning`并要求零输出/零退出。且本 spec 六列 `seq/task/base/head/reviewer/final-status` manifest 的任务顺序、首尾、相邻提交链和最终 `PASS` 都经机械校验；超范围、超行数、版本/格式/静态检查失败、断链或非 PASS 必须拒绝验收。

## 验收标准

主验证命令: bash ./tests/test-session-path.sh
期望输出: 退出码为 `0`、stderr空，stdout逐字节精确为 `RESULT PASS  session path safety\n`

验收清单:

- [ ] `session-path-delivery-v1`由exact两个实现文件组成：private core、三个唯一anchor与固定PASS摘要测试均存在。
- [ ] source 功能分支和三种 missing-export inert fixture 都在同一隔离 shell/fixture 的一次 source 前后同时比较 rc/双流、三个 exported 状态变量的 `declare -p`、marker unset、仍应存在的 foundation 函数 `declare -f`、path/core/public 函数面和文件 inventory；另在保留provider/test但删除foundation文件的隔离仓库副本中分别运行default与`--dependency-absent`，两者均rc0、stderr空、stdout逐字节等于同一固定摘要。
- [ ] core 的 arity `0/1/3`、非法 project/session 和 HARNESS/XDG/TMP/default 安全错都逐字节比较空stdout、固定 unsafe stderr 与 rc `2`；HARNESS、XDG、TMP、default 四个 safe fixture 各自逐字节断言合法 physical path+LF/0，其中一个 parent 使用 symlink 并必须输出物理目标，高优先级生效时低优先级候选 inventory 不变。
- [ ] 在隔离 fixture 中包装 foundation `harness_validate_feature_name`，让它记录 project/session 两次实际调用并拒绝一个原本合法的 session ID；PATH 内 fake `python3` 调用数必须为 `0`，core 返回精确 unsafe/`2`、命中 validate sentinel 且 inventory 不变。
- [ ] 同一 HARNESS root 下两 project×两 session 得到四条唯一路径，root、两 project、四 session 逐项为非链接目录、当前 EUID、精确 `0700`。
- [ ] root/project/session 各层预置软链接、普通文件和 wrong-mode，逐例返回 `2`且无后续创建，victim hash/inode/mode 不变，既有 wrong-mode 不被 chmod；wrong-owner与全部动态替换oracle明确属于03a1。
- [ ] 以`grep -Fo | wc -l`逐字证明MANAGED/EXPECTED_EUID/OS_ERROR三个anchor在生产文本各精确一次；提取`open_managed`函数体后，证明before_mkdir/after_eexist/before_open在全文件和该函数体内各精确一次且provider不存在`fchmod`。03a测试不得保留`--case mutations`或执行anchor-driven provider-copy动态注入，后者由03a1在03b开始前独占验收。
- [ ] 循环逐名证明 `harness_session_state_path/write/read/remove` 均不存在，marker 仍 unset；foundation 文件 BASE..HEAD diff 为空，foundation 与 offline gate 仍退出 `0`。
- [ ] review manifest 的六列、任务序号、execution BASE、相邻 base/head、最终 HEAD 和全 `PASS` 一次机械校验通过；BASE..HEAD exact name-only 为上述两文件，numstat 总和 `<=400`；固定版本断言后，对exact两文件运行`shfmt -d -i 2 -ci -bn`与`shellcheck -x --severity=warning`均退出0且无诊断，worktree clean。
- [ ] `bash ./scripts/check.sh --offline` 退出 `0` 且末行为 `RESULT PASS  aosp-harness offline quality gate`，`git diff --check` 退出 `0`。

不变量（不许劣化，2-4 项）:

- 静态软链接、非目录与wrong-mode case的victim内容/inode/mode变化数 ≤ `0`，验证: `bash ./tests/test-session-path.sh --case roots-static`；wrong-owner与stat→open动态替换不变量由03a1验收。
- 不安全既有层下新建后续目录数 ≤ `0`，验证: `bash ./tests/test-session-path.sh` 的三层攻击 inventory。
- foundation 两个已验收文件的 BASE..HEAD 变更数 ≤ `0`，验证: `git diff --name-only "$BASE" "$HEAD" -- common/.harness/lib/session-state-foundation.sh tests/test-session-state-foundation.sh`。
- Claude、Codex、common、device-safety 与 foundation 回归失败数 ≤ `0`，验证: `bash ./scripts/check.sh --offline`。

## 超出范围

- 不修改 foundation module/test，不公开 path API，不设置 provider marker；03d 才发布完整 capability。
- 不实现 snapshot write/read、竞争发布、signal cleanup、remove/prune、aggregator 或 coverage active fragment；分别属于 03b–03d。
- 不在本片执行任何root/project/session anchor-driven provider-copy mutation；直接后继 `03a1-session-path-race-assurance` 独占完整race矩阵，并在03b开始前强制通过。03a可保留不替换三个anchor的确定性错误分类probe。
- 不改 Claude/Codex hook、demo 或 `CURRENT_FEATURE`，不调用真实设备、网络、build 或客户端，不发布或 push。
