---
id: 2026-09-01-03-session-state-safety
依赖: [2026-09-01-02-offline-quality-gate]
消费: "scripts/check.sh --offline|--ci —— 自动发现普通文件 tests/test-*.sh；成功退出 0，任一根测试失败则 gate 退出 1"
产出: "harness_validate_feature_name <name> —— 合法安全单组件返回 0 且零输出，arity/名称非法返回 2 与固定错误；_harness_session_state_foundation_path <project-id> <session-id> 与 _harness_session_state_run path <project-id> <session-id> —— 仅供 03a 实现/测试消费的私有 fresh-root fd foundation，均不是状态公共 API"
验收方式: 混合判定
已由用户确认: true
确认依据: 用户已明确后续按 autopilot 执行；execute sizing backflow 只把原五 API 按安全完成边界串行拆片，不改变最终用户目标
---

> 用户原话：“$spec review 这套 aosp harness 工程，有哪些欠缺的地方，进行重构和完善”；并确认后续按 autopilot 执行。

## 目标

交付可独立验收的session-state foundation：公开安全名称校验；私有四级根选择、physical parent与fresh fd链。尚未完成existing-object身份/owner/mode/TOCTOU防护的path facade不得公开，`HARNESS_SESSION_STATE_PROVIDER_VERSION`不得设置，避免后续consumer误用半安全API。

## 术语

- “安全单组件”是长度 `1..128` 的 ASCII `[A-Za-z0-9][A-Za-z0-9._-]*`。
- “foundation path”是私有 `_harness_session_state_foundation_path`；它先校验两个ID，再调用同样私有的 `_harness_session_state_run path <project-id> <session-id>`。两者只在 fresh fixture 中证明环境选择、物理父级和新inode属性；03a才补既有对象hardening，完整public path直到03d aggregator才发布。
- “危险根”是空的 HARNESS/XDG、相对路径、含 ASCII 控制字节或完整 `.`/`..` 组件的路径；HARNESS 精确 `/` 也危险。TMPDIR unset/empty 才回退 `/tmp`。

根选择真值表：

| 候选 | unset | empty | nonempty safe absolute | parent/base missing | nonempty危险值 |
|---|---|---|---|---|---|
| `HARNESS_STATE_ROOT` | 继续XDG | 安全错2 | exact root；其physical parent下创建leaf | 安全错2 | 安全错2；精确`/`也拒绝 |
| `XDG_RUNTIME_DIR` | 继续TMP | 安全错2 | root=`$XDG_RUNTIME_DIR/aosp-harness-$EUID` | 安全错2 | 安全错2 |
| `TMPDIR` | root=`/tmp/aosp-harness-$EUID` | 同unset，回退`/tmp` | root=`$TMPDIR/aosp-harness-$EUID` | 安全错2 | 安全错2 |

所有候选的相对路径、控制字节、完整`.`/`..`组件均属危险值；低优先级候选在高优先级set时不得读取或触碰。

## 需求

R1. [计划] 当调用 `harness_validate_feature_name <name>` 时，系统必须只接受安全单组件，合法时返回 `0` 且 stdout/stderr 为空，arity 或名称非法时不得触碰文件系统、stderr 精确为 `error: invalid feature name` 加 LF 并返回 `2`。

R2. [计划] 当03a的实现测试调用 `_harness_session_state_foundation_path <project-id> <session-id>` 或 `_harness_session_state_run path <project-id> <session-id>` 时，系统必须按真值表选择根，从strict physical parent fd只创建root leaf/project/session的当前EUID `0700`非链接目录；成功stdout唯一为physical absolute session path+LF、stderr空、返回0。两个export都必须独立校验project/session ID；任一export的arity/ID错以及dispatcher的op错均stdout空、stderr精确`error: unsafe session state\n`、返回2；根安全错同样返回2；其他普通OS错stdout空、stderr精确`error: session state operation failed\n`、返回1。

R3. [计划] 当在`HARNESS_SESSION_STATE_PROVIDER_VERSION`初始unset的隔离shell中source provider时，系统必须返回0、stdout/stderr空，只定义函数，不读取状态环境、不创建或修改文件，并保持调用者预置sentinel变量的值与export属性逐字不变；source不得创建marker。foundation完成时必须逐个证明public `harness_session_state_path/write/read/remove`均不存在，使未harden的path无法被consumer当成稳定API。

R4. [计划] 系统必须提供独立离线 `tests/test-session-state-foundation.sh`，逐字验证 R1、四级根选择、危险路径零创建、优先级低候选 untouched、physical parent、fresh EUID/0700/nonlink、source 零副作用和预存默认根不删除；成功末行精确为 `RESULT PASS  session state foundation`，且不调用设备、网络、build、Claude 或 Codex。

R5. [计划] 当foundation进入验收时，系统必须由controller证明执行前BASE到最终HEAD只修改`common/.harness/lib/session-state-foundation.sh`与`tests/test-session-state-foundation.sh`、总新增+删除不超过`400`，并用PLAN v5.3规定的六列`seq/task/base/head/reviewer/final-status` review manifest证明任务1.1–1.3的base/head连续、独立reviewer最终PASS、首尾绑定review package且提交链无缺口。

R6. [计划] 如果发生PLAN v5.3的review package文件集合/行数超过R5或review manifest缺行、断链、非PASS，系统必须拒绝foundation验收并回流对应任务或PLAN，不得把私有foundation标记为可供consumer使用。

## 验收标准

主验证命令: bash ./tests/test-session-state-foundation.sh
期望输出: 退出码为 `0`，stdout 末行精确为 `RESULT PASS  session state foundation`

验收清单:

- [ ] `harness_validate_feature_name`名称表覆盖零/多参数、空、`.`、`..`、前导`-`、斜线、反斜线、空白、换行、非ASCII、129字节拒绝和1/128字节、`a._-Z9`成功，并逐字比较rc/stdout/stderr bytes。
- [ ] `_harness_session_state_foundation_path`与`_harness_session_state_run path`各自独立覆盖完整结果协议：合法调用逐字断言physical path+LF/空stderr/rc0；普通OS错误注入逐字断言空stdout/`error: session state operation failed\n`/rc1；零/少/多参数、非法project/session及仅dispatcher的非法op逐字断言空stdout/`error: unsafe session state\n`/rc2，证明直接dispatcher也不接受未经校验的组件。
- [ ] 根选择真值表逐项通过：HARNESS/XDG empty失败而TMP empty/unset回退`/tmp`；三变量的safe/relative/dotdot/control/missing和HARNESS`/`逐字通过；失败时fixture inventory不变，成功时低优先级候选untouched。
- [ ] physical parent 输出、fresh root/project/session 的非链接目录类型、EUID、0700 和两项目×两会话隔离逐项成立；测试不删除调用前存在的空 `/tmp/aosp-harness-$UID`。
- [ ] 在marker初始unset、预置并export sentinel变量的隔离shell中，source rc0且双流空，sentinel的`declare -p`前后逐字相等，目录/inode/size/内容与危险目标均不变，source后marker仍unset；循环四个状态public函数并对每个单独执行`declare -F "$name"`，任一成功即失败，而public validate与两个private exports逐个存在。
- [ ] `bash ./scripts/check.sh --offline` 退出 `0` 且末行为 `RESULT PASS  aosp-harness offline quality gate`，`git diff --check` 退出 `0`。
- [ ] `review-manifest-v1`与review package在隔离worktree根一次执行以下完整片段退出0：`: "${EXECUTION_BASE_FILE:?}" "${REVIEW_MANIFEST:?}"; BASE_SHA=$(sed -n 's/^BASE_SHA=//p' "$EXECUTION_BASE_FILE"); HEAD_SHA=$(git rev-parse HEAD); test -n "$BASE_SHA"; awk -F '\t' -v base="$BASE_SHA" -v head="$HEAD_SHA" 'NF!=6 || $1 != NR || $2 != "1." NR || $3 !~ /^[0-9a-f]{40}$/ || $4 !~ /^[0-9a-f]{40}$/ || $5=="" || $6!="PASS" {bad=1} NR==1 && $3!=base {bad=1} NR>1 && $3!=prev {bad=1} {prev=$4} END {exit bad || NR!=3 || prev!=head}' "$REVIEW_MANIFEST"; test "$(git diff --name-only "$BASE_SHA" "$HEAD_SHA" | LC_ALL=C sort)" = "$(printf '%s\n' common/.harness/lib/session-state-foundation.sh tests/test-session-state-foundation.sh)"; git diff --numstat "$BASE_SHA" "$HEAD_SHA" | awk 'NF != 3 || $1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+$/ {bad=1} {files++; lines += $1 + $2} END {exit bad || files > 2 || lines > 400}'`。

不变量（不许劣化，2-4 项）:

- source 与 unsafe case 的 fixture 内容变化数 ≤ `0`，验证: `bash ./tests/test-session-state-foundation.sh`。
- 调用前已存在的默认根删除数 ≤ `0`，验证: `bash ./tests/test-session-state-foundation.sh` 的 preexisting-root case。
- 既有 Claude、Codex、common 与 device-safety 回归失败数 ≤ `0`，验证: `bash ./scripts/check.sh --offline`。

## 超出范围

- 不公开 path/write/read/remove；03a–03d 按顺序完成并发布。
- 不做 existing managed-object owner/mode/dev-inode/TOCTOU、snapshot、signal、remove 或 coverage active 注册。
- 不改 Claude hook/demo；03e 只在 03d 完整 provider 后接入。
- 不调用真实设备、网络、build 或客户端，不发布或 push。

## autopilot 裁定

- execute 证据证明原五 API 单片 400 行不成立；当前片停在安全发布边界：只公开已完整验证的 validate，path foundation 保持私有。若判断错误，代价是 03a 需要调整私有签名；若公开半安全 path，代价是 consumer 可绕过后续 hardening。
- 03 独占 foundation module/test；03a–03d 各自交付不同模块，03d aggregator 只有在全部私有模块及预期函数存在时才设置 `HARNESS_SESSION_STATE_PROVIDER_VERSION=1` 并定义五个 public API。若判断错误，代价是多一层 source/能力探测；若共享同一 provider 文件，代价是任一前序片无法独立回滚且 partial provider 可能被 consumer 误用。
