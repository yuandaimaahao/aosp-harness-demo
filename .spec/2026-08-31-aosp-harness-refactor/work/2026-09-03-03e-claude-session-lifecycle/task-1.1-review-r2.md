# Review: task 1.1 (4ceca2bf..b73676ba) round 2 — 增量复查

verdict: PASS
阻断: 0 / 重要: 0 / 次要: 2

范围：只审 fix 提交 `b73676ba1607c2a7a6c642c2f2ff80249bef7050`（`4ceca2bf..b73676ba`，三文件 13+/10-）。
round 1 的 B1/B2/I1/S1/S2/S4 **六条全部真实闭合**，逐条独立复验（不采信报告表格，全部重跑）。
S3 按控制器指令未动，我复核三个 guard 块仍逐字节相同（单一 sha `d5927d73…`），符合备案结论。
新增两条次要 finding（S5/S6），都不阻断，均可留到任务 1.3 或后续片处理——但 **S5 需要一条明确的
design/tasks 决定**，否则 1.3 写 oracle 时无据可依。

## ① 规格符合性

- **R1（guard 三合取才消费 v1）… ✅** — 无回退。八类负例（absent / missing-foundation,path,snapshot,signals,remove / marker 篡改为 `2` / marker=1 但只有 4-of-5 API 的桩 aggregator）× 三 hook = 24 次，一律 rc0 + compat 恰 1 + v1 状态树缺席。三个 guard 块本轮零改动。
- **R2（任一 partial → legacy + marker 恰一次 + rc0，不形成 partial capability）… ✅（round 1 为 ❌，本轮闭合）** — 唯一缺口「`session_id` 非法」已补：`load-feature.sh:35` 与 `check-branch-drift.sh:25` 都加入了与 `session-end.sh:26` **逐字相同**的 `re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", sid)`（三文件 `grep -o` 后 `sort -u` 只剩一个值），且该规则与 `session-state-foundation.sh:7` 的 `${#1} -ge 1 && -le 128 && ^[A-Za-z0-9][A-Za-z0-9._-]*$` 同源；`harness_validate_feature_name` 仍在其后作为第二道闸。九类畸形 `session_id`（TAB / LF / 内嵌 LF / 空格 / `../etc` / 空串 / 前导点 / 129 字符 / 非字符串）全部落 legacy（rc0、compat=1、零状态创建），边界 128 字符正常走 v1——上下界都对。
- **R3（SessionStart 按 source 分级建/读基线，五 source 永不覆盖）… ✅（round 1 为 ❌，本轮闭合）** — round 1 的坏例 `{"session_id":"sess-evil\tcompact","source":"compact"}` 现在 rc0 + compat=1 + `state/<pid>/sess-evil` **不存在**（此前会创建基线）；`{"session_id":"sessnl\ninjected","source":"startup"}` 同样落 legacy。正常矩阵零回退：startup/fork/clear/resume 各自建基线、重复幂等、compact 缺基线只 stderr 一行不创建、基线在场时改 `CURRENT_FEATURE` 后 resume 仍读到旧值不改写、v1 全程 `$TMPDIR` 无 legacy 快照。
- **R4（UPS 漂移 exit 2 阻止 prompt，缺席/一致静默 rc0）… ✅（round 1 为 ❌，本轮闭合）** — round 1 的坏例：`check-branch-drift.sh` 收 `{"session_id":"s1\n"}` 现在 rc0 + compat=1、不再截断读到 `s1` 的基线、不再误 exit 2；内嵌换行与 TAB 同理。合法 `s1` 在真实漂移下仍 rc2 且两行告警逐字不变。
- **R5（SessionEnd 校验后幂等清理 + settings.json 注册）… ✅（round 1 为 ❌，本轮闭合）** — 执行位已入库（`git ls-files -s` 三 hook 均 `100755`，BASE..HEAD 的 `session-end.sh` 是 `:000000 100755 … A`）。我没有只看 mode 位，而是走了**真实调用形态**：从 `settings.json` 用 python 提取三条 `command` 字符串、展开 `${CLAUDE_PROJECT_DIR}`、经 fixture 里的 `.claude -> features/.harness` 软链、用 `sh -c "$cmd"` 逐条执行——SessionStart rc0 建基线、UserPromptSubmit rc0、**SessionEnd rc0 且 state 树被清空**（round 1 时此处是 rc126 Permission denied）。五个合法 reason、重复调用幂等、事件名/session ID/reason 三类非法零删除，全部无回退。唯一残留是 python3 不可用这一角落（S5），不影响正常语义。
- **R6（legacy 段行为逐字不变，v1 不读写 legacy 全局文件）… ✅** — 无回退。legacy surface 全矩阵重跑：SessionStart 覆盖写全局快照内容 == feature、UPS 漂移纯文本两行 rc0 不阻断、SessionEnd 幂等 `rm -f` 且重复仍 rc0、非法 sid 零删除；v1 路径下 `$TMPDIR` 始终为空、legacy 路径下 `$HARNESS_STATE_ROOT` 始终不存在。I1 修复后新增的 stderr 诊断行走的是 stderr，**不污染 stdout、不触发 compat marker、不写 legacy 快照**（下方 I1 的端到端证据里逐项确认）。

## ② 质量

- **YAGNI**：fix 提交干净，恰好只动了被指出的三个文件、13 插入 10 删除，没有顺手重构。S3 按指令未动（三个 guard 块 sha 相同，确认零改动）。`settings.json` 本轮零改动。numstat 逐文件 41/49/47/3（上限 42/52/52/6），合计 **140 ≤152**，name-only 仍恰四文件，上游十二文件仍零变更，`git status --porcelain` 空。
- **验证是不是真的在验**：报告「fix round 1」节的每条都给了修复前/后对照与真实 rc，且**都是可复现的**——我逐条独立重跑，结论与其表格一致，没有发现夸大或倒填。B1 我没有采信「mode 位对了」这一层，而是用真实注册命令形态复验；B2 我把用例从 2 个扩到 9 个（含 128/129 边界）；S2 我做了一个只差那一行的干净差分（下详）。唯一可以更强的是 I1 的证明形式（见「对第 3 点的判断」）。
- **逻辑块逐字复制**：本轮**没有引入新的复制**。特别值得肯定的是 S4 的改法：用 `[[ $prc == 0 ]] || use_v1=0` 让异常路径**复用既有的 `else`（legacy）分支**，而不是把 `compat_legacy` + `rm -f` 再抄一份，净增仅 2 行且 compat 字面量仍恰 1 处（`LOOP_RC=0`）。S3 的三份 guard 复制按备案保留。
- **错误路径**：整体改善明显。write rc3 从静默变为有诊断（I1）；早退路径排水补回（S1）；解释器故障与输入非法分流（S4）。剩余两处见 S5、S6，都在「python3 不可用」这一条极窄路径上。

## findings

### 六条 round-1 finding 的闭合判定

| 编号 | 结论 | 独立复验依据（我跑的，不是报告的） |
|---|---|---|
| **B1** | **闭合** | `git ls-files -s` 三 hook 均 100755；BASE..HEAD raw 为 `:000000 100755 … A session-end.sh`；从 `settings.json` 提取的三条 `command` 经 `.claude` 软链 + `sh -c` 实跑，SessionEnd **rc0 且清理生效**（round 1 为 rc126） |
| **B2** | **闭合** | 三 hook 的形态正则 `sort -u` 后只剩一个值，且与 `session-state-foundation.sh:7` 同源；9 类畸形 sid × 两 hook 全部落 legacy（rc0/compat=1/零状态），128 接受、129 拒绝；round 1 的两个坏例逐字复现为「已挡住」 |
| **I1** | **闭合** | 我自建了比实现者更强的端到端确定性证据（见下「对第 3 点的判断」）：真实 hook 进程、修复前 stderr 空 / 修复后有诊断行，两版都 rc0、compat=0、存储值仍为冲突前的 `dev-OTHER`、legacy 快照未被写 |
| **S1** | **闭合** | 300KB payload SIGPIPE 探针覆盖 **7 条路径**（load-feature 的 no-target / legacy / v1，check-branch-drift 的 legacy / v1，session-end 的 legacy / v1）全部 `writer_rc=0`；round 1 报 141 的 no-target 早退路径现为 0。三 hook 的 `exit` 点我逐个 `grep` 过，没有遗漏的未排水早退（session-end 的 python3 故障路径除外，见 S6） |
| **S2** | **闭合** | 做了只差那一行的干净差分：把 HEAD 的 `if [[ $use_v1 == 1 ]] && v1_drift; then :; fi` 用 python 精确替回 `[[ … ]] && v1_drift \|\| true`（`diff` 确认全文仅第 43 行不同），对 `v1_drift` 的 **7 类出口**（无漂移 exit0 / 漂移 exit2 / rc3 缺席 exit0 / 非法 sid return1 / malformed return1 / legacy 漂移 / legacy 无漂移）逐一比对：**rc 与 stdout、stderr 全部逐字节相同**。语义等价，非「看起来等价」 |
| **S4** | **闭合** | 假 `python3`（恒 exit 9）+ 预置 legacy 快照：修复前快照残留、修复后被清理，marker 与行为一致；`prc==3`（真实解析/校验失败）仍是零删除出口，用真 python3 的非法 payload 对照确认未被误伤 |

### S5（次要，新）`claude-code/features/.harness/hooks/session-end.sh:35`

```
[[ $prc == 0 ]] || use_v1=0
```

`prc` 为 `3` 以外的非零值（python3 不可用、解释器崩溃）时，代码强制落到 `else`（legacy）分支并执行
`rm -f -- "${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot"`——**在 stdin 从未被校验过的情况下执行了删除**。

实测（假 `python3` 恒 exit 9，预置 legacy 快照）：

| payload | 真 python3 时的正确行为 | 假 python3 下的实际行为 |
|---|---|---|
| `{"hook_event_name":"SessionEnd","session_id":"s1","reason":"clear"}` | 校验通过 → legacy 删除 | 删除（结果碰巧正确） |
| `{"hook_event_name":"NotSessionEnd","session_id":"../evil","reason":"bogus"}` | 校验失败 → **零删除**（实测确认） | **同样删除** |

为什么是缺陷：R5 写的是「校验**通过**的 legacy 路径幂等删除全局快照」与「校验失败……不删除任何状态」，
design 的 SessionEnd 错误处理表也只有三种出路（任一非法零删除 / 校验通过+v1 / 校验通过+legacy）。
「校验无法进行」是**第四种语义**，现在被并入了「删除」一侧，于是一条本该零删除的非法 payload 在解释器故障时
会被删掉。这正是控制器问我的那一点，我的答复是：**是第三/第四种语义，不在 design 表内。**

需要说明的是这**不算修坏**：它正是我 round 1 给 S4 的建议方向（「其他非零视为解释器故障走完整 legacy 清理」），
而且爆炸半径接近零——该文件只是 demo 级全局快照，删除幂等，且 python3 不可用时 `load-feature.sh` 本来也建不了
任何基线、下一次 SessionStart 会重新写回该文件。所以判**次要**，不阻断。

建议修法（二选一，都请落到 design 或 tasks 上，别只改代码）：
(a) 把「python3 不可用」判定**前移到 guard 阶段**（`command -v python3 >/dev/null || { compat_legacy; exit 0; }`），
使「无法校验 ⇒ 零删除」，与 R5 的删除闸门严格一致；
(b) 保留现行行为，但在 design 的 SessionEnd 错误处理表里**显式补上第四行**（解释器故障 → legacy 清理），
并让任务 1.3 的 oracle 按这一行断言。

### S6（次要，新发现；**非本轮引入**）`claude-code/features/.harness/hooks/session-end.sh` 全文无 stdin 排水

`session-end.sh` 从头到尾没有 `cat >/dev/null`，唯一消费 stdin 的是 `python3`。当 python3 不可用时 stdin 从未被读取，
写端被 SIGPIPE 杀死。实测（300KB payload）：

| 版本 | session-end 在 python3 故障下的 `writer_rc` |
|---|---|
| `4ceca2b`（fix 前） | **141** |
| `b73676b`（fix 后） | **141** |

对照：同一条件下 `load-feature.sh` 与 `check-branch-drift.sh` 都是 `writer_rc=0`（它们的 legacy 段有 `cat >/dev/null`）。

为什么是缺陷：与 S1 完全同类（早退/异常路径不排水 → 写端 SIGPIPE）。**它不是本轮的回退**——我取 `4ceca2b` 的
blob 单独复验，同样是 141，属于 round 1 我漏掉的一处；但 S1 的整改原则（「每条路径都要排水」）本轮只落到了
`load-feature.sh`，而 fix 恰好又改动了 `session-end.sh` 的这条分支，所以在此一并提出。影响面与 S1 同级（真实 hook
payload 通常小于管道缓冲），故判次要。

建议修法：在 `if [[ $prc == 3 ]]` 判定之前补一行 `[[ $prc == 0 ]] || cat >/dev/null 2>&1 || true`，
或与 S5 方案 (a) 合并——guard 阶段发现 python3 缺席就先排水再 `compat_legacy; exit 0`，一处改动同时关掉 S5 与 S6。

## 对控制器第 3 点（I1 证明强度）的明确判断

**结论：实现者的证明够用，I1 判定闭合，我不要求他补做任何证明。** 但我自己做了一个更强的，把配方交给任务 1.3。

分三层说：

1. **「80 对并发没跑出交错」不是证明能力不足，是这条竞态本来就不该用并发去撞。** `write` 的 rc3 只发生在
   同一进程内 `read` 返回 3 与 `write` 落盘之间被别人插入了一次异值写；这个窗口是两次 provider 调用之间的几毫秒，
   而 provider 自身的 verified fd 链又是原子替换的。靠加并发度去提高命中率属于非确定性 oracle，**即使撞出来一次也
   不该进测试套件**（会变成 flaky）。他放弃并发、改用注入，方向是对的。

2. **他的 awk 抽取 + 打桩驱动确实是确定性的，且用的是两个提交里的真实函数体文本**，能证明「同一 rc 序列下，
   修复前静默、修复后有诊断」这一条 finding 本身。作为 finding 闭合证据，**充分**。

3. **但它比必要的弱一档**：它只 source 了 `v1_baseline()` 的函数体，因此证不到 hook 级后果——rc 是不是 0、
   有没有误吐 compat marker、有没有误写 legacy 快照、存储值有没有被覆盖。这四点恰恰是 R2/R3/R6 关心的。
   我用 design 自己的 fixture 机制做了一个**端到端确定性**版本，成本相同：在 `$ROOT/../common/.harness/lib/session-state.sh`
   放一个 **shim aggregator**——`source` 真实 provider（marker 与五 API 齐备，guard 照常通过），然后只覆写
   `harness_session_state_read() { return 3; }`；再用真实 `harness_session_state_write` 预置一个**异值**基线。
   于是真实 hook 进程会走到「read 说缺席 → write 说冲突」，`write` 的 rc3 是**真 provider 返回的**，不是桩造的：

   | 版本 | rc | compat | stderr | 存储值 | legacy 快照 |
   |---|---|---|---|---|---|
   | `4ceca2b`（修复前） | 0 | 0 | **空**（缺陷复现） | `dev-OTHER`（未被覆盖） | 未写 |
   | `b73676b`（修复后） | 0 | 0 | `error: [load-feature] 会话基线已存在且值不同，未改写。` | `dev-OTHER`（未被覆盖） | 未写 |

   这一版额外证明了：修复既没有把这条路径推去 legacy（compat 仍为 0、快照未写，R6 保持），也没有破坏
   「五 source 永不覆盖已有基线」（存储值不变，R3 保持），还保持了 rc0 不变量。

   **要求**：不要求实现者在本轮补做。但请任务 1.3 用 **shim aggregator 这一形态**写这条 oracle，
   **不要**把 awk 抽函数体的驱动脚本沉淀进测试套件——那不是对出厂 hook 的可运行 oracle，hook 分派逻辑一旦改动它就
   会静默失去覆盖。

## 核对记录

工作区 `…/work/2026-09-03-03e-claude-session-lifecycle/worktree`，全部只读，未修改任何文件、未提交（末尾 `git status --porcelain` 仍为空）。

| # | 命令 / 手段 | 结果 |
|---|---|---|
| 1 | `git rev-parse HEAD` / `git status --porcelain` | `b73676ba…` / 空 |
| 2 | `git diff --name-only BASE HEAD` | 恰四文件 |
| 3 | `git diff --numstat BASE HEAD` + `awk` | 41 / 49 / 47 / 3，合计 **140 ≤152** |
| 4 | `git diff --raw BASE HEAD` | `:000000 **100755** … A session-end.sh` ← B1 入库证据 |
| 5 | `git diff --name-only BASE HEAD -- $UPSTREAM12` | 空 |
| 6 | `git ls-files -s .../hooks/` | 三 hook 均 `100755`（`feature-common.sh` 仍 755） |
| 7 | `shfmt -d -i 2 -ci -bn` / `shellcheck -x --severity=warning` / `bash -n` ×3 / `git diff --check` | 全 rc0 无输出（含新加的单行 `if…elif…fi`） |
| 8 | `python3 -c 'json.load(...)'` settings.json | rc0 |
| 9 | `( set -e; for h in …; done )` compat 恰一次 + guard 锚定 | **LOOP_RC=0** |
| 10 | 三 hook 的 `sed -n '/^use_v1=0$/,/^compat_legacy() /p' \| sha256sum \| sort -u` | 单一值 `d5927d73…` ⇒ S3 三份 guard 逐字节未动，符合控制器指令 |
| 11 | 从 settings.json 提取三条 `command`，展开 `${CLAUDE_PROJECT_DIR}`，经 fixture `.claude -> features/.harness` 软链 `sh -c` 实跑 | SessionStart rc0 建基线 / UPS rc0 / **SessionEnd rc0 且 state 清空** ⇒ **B1 在真实调用路径闭合** |
| 12 | 9 类畸形 `session_id` × `load-feature.sh`（TAB/LF/内嵌 LF/空格/`../etc`/空串/前导点/129 字符/非字符串） | 全部 rc0 + compat=1 + 零状态创建；128 字符正常走 v1 ⇒ **B2 闭合，边界正确** |
| 13 | 4 类 × `check-branch-drift.sh`（TAB / 尾随 LF / 内嵌 LF / 合法） | 前三者 rc0+compat=1 落 legacy，合法 sid 漂移仍 rc2 ⇒ round-1 坏例已挡 |
| 14 | 三 hook 正则 `grep -o … \| sort -u`；对照 `session-state-foundation.sh:7` | 单一值，且与 foundation 规则同源 ⇒ 统一到了正确一侧 |
| 15 | **shim aggregator 端到端 I1 证明**（真 provider + 覆写 read→rc3 + 预置异值基线），对 `4ceca2b` 与 HEAD 各跑一次 | 见上表；修复前 stderr 空、修复后有诊断，两版 rc0/compat=0/存储值不变/快照未写 |
| 16 | 300KB payload SIGPIPE 探针 × 7 条路径 | 全部 `writer_rc=0` ⇒ **S1 闭合**（round 1 的 no-target 路径由 141 → 0） |
| 17 | 只差第 43 行的干净差分（python 精确替换），对 `v1_drift` 7 类出口比 rc + stdout + stderr | **全部逐字节相同** ⇒ **S2 语义等价，无回退** |
| 18 | 假 `python3`（恒 exit 9）+ 预置 legacy 快照，`session-end.sh` 新旧版对照 | 旧版残留、新版清理 ⇒ **S4 闭合**；同一手段下非法 payload 也被删 ⇒ **S5** |
| 19 | 真 python3 + 非法 payload（`NotSessionEnd`/`../evil`/`bogus`）对照 | 快照**保留** ⇒ R5 零删除闸门在正常路径完好 |
| 20 | 假 python3 下三 hook 的 SIGPIPE 探针；再取 `4ceca2b` 的 session-end blob 同样探测 | 新旧均 141，load-feature/check-branch-drift 均 0 ⇒ **S6 为既存问题、非本轮回退** |
| 21 | v1 全矩阵重跑（startup/fork/clear/resume 建基线、重复幂等、compact 缺基线只报错、基线在场不改写、UPS 三态、SessionEnd 五 reason + 三类非法） | 零回退，与 round 1 的正确结论逐条一致 |
| 22 | legacy surface 全矩阵重跑（SessionStart 写快照、UPS 漂移 rc0 两行、SessionEnd 幂等删除 + 重复 + 非法零删除） | 零回退 |
| 23 | 八类 guard 负例 × 三 hook = 24 次（absent / 五模块各缺 / marker=2 / 4-of-5 API 桩） | 一律 rc0 + compat=1 + 无 v1 状态 ⇒ **R1 无回退，三合取仍是真合取** |
| 24 | `bash ./scripts/check.sh --offline` | **rc0**，13 行全 PASS |
