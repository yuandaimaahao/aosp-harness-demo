# Task 1.1 独立审查报告 — round 2（fix round 1 回审）

- spec: `2026-09-02-03b-session-snapshot-safety`
- 任务: 1.1，本轮 diff 包 `9edf76cced42e22185677b240f77d86ddbf0eb01..133ccdb71e62d5312225a33aa8b86f3af5885ee0`
- reviewer: 独立 agent，全新上下文，未参与实现，非 round 1 reviewer
- 审查日期: 2026-09-02
- 范围：只审本轮 diff（4 行原地修改），不重审 BASE..9edf76c 的既有内容

## 结论

**NEEDS_CHANGES** — 阻断 0 / 重要 1 / 次要 0

裁定要求的表面动作（只在 4 个失败易发命令上加行内 `2>/dev/null`、不增删行、
不重排、208 行不变）**执行精确无误**，独立复现确认 write/read core 在
`TMPDIR=/nonexistent` 下 stderr 均恰好由泄漏变为 0 字节、rc 不变。但独立
排查发现其中 1 处 (`exec {path_fd}<>"$path_file" 2>/dev/null`) 的
`2>/dev/null` 因 bash「无命令词的裸 `exec` 重定向对当前 shell 永久生效」
语义，实际抑制范围**不是**报告所述「仅该行自身失败时的错误文本」，而是
把该 subshell 剩余生命周期内（含最终 `exec python3` 替换进程的全部 stderr）
永久静音——包括未被 R2–R6 枚举覆盖的未捕获异常（如已被上一轮记为次要 #6
的 `sys.argv[1]` 越界）。这超出了裁定「修改面只限失败路径的双流抑制」的
授权范围，且未被本轮报告的 delta 枚举披露/发现。

---

## ① 本轮 delta 是否恰好只做了裁定允许的事

独立重新拉取 `9edf76c..133ccdb` 的 diff 与 review 包逐字比对，完全一致：

```
git diff 9edf76cced42e22185677b240f77d86ddbf0eb01 133ccdb71e62d5312225a33aa8b86f3af5885ee0 -- common/.harness/lib/session-state-snapshot.sh
```

- 只有 4 行原地修改（4 insertions / 4 deletions，即同一 4 行替换），均为在
  已有命令末尾追加 `2>/dev/null`：L192 `mktemp(...)`、L193 `exec
  {path_fd}<>"$path_file"`、L194（193 失败分支内）`rm -f`、L197（成功分支）
  `rm -f`。
- 无新增行、无拆行、无重排、无夹带的裁定范围外改动（未触碰 `open_dir`、
  信号协议、`renameat2`、anchor 位置等）。
- `wc -l` 仍为 208（TASK_BASE..HEAD numstat 仍 `208 0`，本轮 diff 内部
  numstat `4 4`）。
- 提交为独立新 commit `133ccdb`（未 amend `9edf76c`），历史保留。

**该问的判断：本轮文本层面的 delta 完全符合裁定第 3 条的字面授权。**（但见
下方③——其中一行的**运行时效果**超出了字面授权的范围，这是本轮的核心发现。）

## ② 修复是否真的修好了（独立复现，未只信报告数字）

用最小 harness（`harness_validate_feature_name` 与 `_harness_session_path_core`
先于 `source` 定义，满足 active 分支前置条件），独立复现 round 1 的反例：

```
TMPDIR=/nonexistent bash -c '
  harness_validate_feature_name() { ... }
  _harness_session_path_core() { echo /tmp/unused-session-path; }
  source common/.harness/lib/session-state-snapshot.sh
  _harness_session_snapshot_write_core proj sess alpha
'
```

| 场景 | rc | stdout bytes | stderr bytes |
|---|---|---|---|
| 修复前 (`9edf76c`) write core | 1 | 5 (`rc=1\n`，来自我的 harness echo) | **112**（`mktemp: failed to create file via template '/nonexistent/snapshot-path.XXXXXXXX': No such file or directory`） |
| 修复后 (`133ccdb`) write core | 1 | 5 | **0** |
| 修复后 (`133ccdb`) read core（同一 `TMPDIR`） | 1 | 5 | **0** |

rc 在修复前后完全不变（均为 1），仅 stderr 由泄漏变为空，与报告一致。

官方 192 行 prototype test（`SNAPSHOT_CORE=<修复后文件>`，从 worktree 根下
临时文件运行，运行后已删除，`git status --porcelain` 确认干净）：
rc=0，stdout 逐字节 `RESULT PASS  session snapshot safety\n`（37 字节），
stderr 0 字节。

**结论：修复对 round 1 反例的直接效果属实，未夸大。**

## ③ 有没有引入新问题（核心发现）

对比 `exec {path_fd}<>"$path_file" 2>/dev/null || { ... }` 这一行：这是一条
**没有命令词、只有重定向的裸 `exec`**。Bash 对这种形式的规则是：所有重定向
对**当前 shell 永久生效**，而不是像普通命令那样只在该命令执行期间生效、
结束后自动恢复。独立最小复现证实：

```
bash -c '
  exec {fd}<>/tmp/somefile 2>/dev/null
  echo "SHOULD_BE_VISIBLE" >&2
'
# → stderr 0 字节（"SHOULD_BE_VISIBLE" 也被吞了，尽管它是无关的后续命令）
```

对照组：把同一条裸 `exec` 包进 `{ ...; } 2>/dev/null` 分组后，重定向能正确
限定在分组内、退出后自动恢复（`echo ... >&2` 恢复可见）——证明存在更精确
的写法，本轮实际写法不是最小/正确限定的方案。

**实证复现（在目标文件上注入一个无关的、未被任何 except 捕获的
`RuntimeError`，模拟真实 bug/未来越界场景）：**

| 版本 | rc（内部） | stdout | stderr |
|---|---|---|---|
| 修复前 (`9edf76c` + 注入 bug) | 1 | 5 bytes | **162 字节**（完整 Python traceback） |
| 修复后 (`133ccdb` + 注入 bug) | 1 | 5 bytes | **0 字节**（traceback 被完全吞掉） |

即：本轮那一处 `2>/dev/null` 实际把该 subshell 剩余执行期间（含最终
`exec python3` 替换进程）的**全部** stderr 永久静音，而不只是「mktemp/exec/
rm 这四个失败易发命令自身的错误文本」。报告 delta 枚举第 2 条的描述
（"抑制该 redirection 若失败时 bash 打到 stderr 的错误文本"）**不准确**——
实际效果既不限于「该 redirection 失败时」，也不限于「该 redirection 自身」。

**是否改变 rc / 是否让失败变成静默成功**：否。上表内部 rc 前后均为 1，只有
stderr 内容不同；未发现任何 rc 从非 0 变 0 的情形。

**是否违反 R2/R4 字面「双流空」**：不违反——该副作用只会让**更多**场景
（包括未被 R2–R6 枚举覆盖的未捕获异常路径）表现为双流空，而不是更少，
所以不构成对 R2/R4 明文条款的违反。但它：
- 超出了控制器裁定第 3 条「修改面只限失败路径的双流抑制」的授权范围
  （运行时效果覆盖了成功路径之后的全部执行，且波及与本轮四个目标命令
  无关的下游 Python 进程）；
- 把这个「session-snapshot-safety」模块中任何未来的真实 bug（例如上一轮
  已挂账的次要 #6 `sys.argv[1]` 越界、或任何未被 except 覆盖的异常）从
  「有 traceback 可查」变成「完全静默」，是可审计性/可调试性的实质倒退，
  且未被本轮报告披露或提及。
- `set -e`／管道／命令替换语义：本文件未使用 `set -e`，无管道；
  `path_file=$(mktemp ... 2>/dev/null)` 的 `2>/dev/null` 正确限定在命令替换
  自身的子进程内，不泄漏；两处 `rm -f ... 2>/dev/null` 也是普通命令、
  正确限定，无此问题。**仅 L193 的裸 `exec` 一行受影响。**

## ④ 门是否仍然成立

```
export PATH=<scratchpad>/tools/bin:$PATH
wc -l common/.harness/lib/session-state-snapshot.sh        → 208
shfmt -d -i 2 -ci -bn common/.harness/lib/session-state-snapshot.sh   → rc=0，无 diff
shellcheck -x --severity=warning common/.harness/lib/session-state-snapshot.sh → rc=0，无诊断
bash -n common/.harness/lib/session-state-snapshot.sh       → rc=0
git diff --check                                            → rc=0
```

八个 `HARNESS_TEST_MARKER_*` anchor 逐一 `grep -c` 独立核对，均恰为 1
（`CAPTURE_READY` / `SNAPSHOT_MANAGED_BEFORE_OPEN` /
`MANAGED_EXPECTED_EUID` / `SNAPSHOT_EXPECTED_EUID` / `SNAPSHOT_BEFORE_OPEN` /
`TEMP_BEFORE_PUBLISH` / `PUBLISH_RESULT` / `OS_ERROR`）。

**全部门通过，与报告一致。**

## ⑤ 规格符合性（R2、R4 的「双流空」条款）

| 需求 | 判定 | 依据 |
|---|---|---|
| R2「所有 write 结果及 read 失败结果双流空」 | ✅ | 独立复现 `TMPDIR=/nonexistent` 反例，write/read 均 rc=1、双流 0 字节；官方 192 行 prototype test rc=0/双流按契约 |
| R4「非 EEXIST 分支双流空/1、无 fallback」 | ✅ | 同上，未触及 publish/信号相关代码，行为未变 |

两条字面「双流空」判定均为 ✅（且如③所述，某种意义上被「过度满足」）。
③ 中的发现不构成对 R2/R4 字面条款的违反，而是**裁定授权范围**与**未来
可调试性**层面的问题，因此单独作为「重要」finding 列出，而不影响 R2/R4
本身的 ✅ 判定。

---

## findings

### 阻断（0）

无。

### 重要（1）

**[重要][裁定范围/可调试性，非 R2/R4 字面违反] L193 裸 `exec` 的
`2>/dev/null` 永久静音该 subshell 剩余生命周期（含最终 exec 的 python3
进程）的全部 stderr，超出「只限失败路径」的授权范围，且报告 delta 枚举
对该行为的描述不准确**

- 位置：`common/.harness/lib/session-state-snapshot.sh` L193
  `exec {path_fd}<>"$path_file" 2>/dev/null || { ... }`
- 机制：裸 `exec`（无命令词，只有重定向）对当前 shell 永久生效，不像
  普通命令那样随命令结束自动恢复。
- 实证：注入一个无关的、未被任何 except 捕获的 `RuntimeError`
  （模拟真实 bug 或次要 #6 `sys.argv[1]` 越界这类未来可能命中的路径）：
  修复前 stderr 162 字节（完整 traceback 可见），修复后 stderr 0 字节
  （完全静默）；rc 前后均为 1，未改变。
- 影响评估：不违反 R2/R4 字面「双流空」（只会让更多路径双流空，不会更
  少），不改变任何 rc，不产生 fail-open。影响面是：(a) 超出控制器裁定
  「修改面只限失败路径的双流抑制」的授权范围——实际抑制了与 mktemp/exec/
  rm 四个目标命令无关的下游全部输出；(b) 使该安全模块任何未来真实 bug
  从「有 traceback 可查」变为「完全静默无输出」，是可审计性倒退；(c) 本轮
  报告 delta 枚举第 2 条对此行为的描述（"仅抑制该 redirection 若失败时…
  的错误文本"）与实测不符。
- 建议（如需再修）：把该行改为分组重定向以正确限定作用域，例如
  `{ exec {path_fd}<>"$path_file"; } 2>/dev/null || { ... }`——已独立验证
  该写法能把重定向正确限定在分组内、退出后自动恢复，不影响 208 行预算
  （字符层面增改，非新增/删除行）。是否值得为此再开一轮，留给控制器
  裁定。

### 次要（0）

本轮未发现新的次要问题（上一轮挂账的 8 条按控制器裁定不复议）。

---

## 独立复现结果汇总（供控制器核对）

```
# 反例（round 1 原始触发条件）
TMPDIR=/nonexistent bash <write-core-harness>   → 内部 rc=1，stdout 5B，stderr 0B（修复前 112B）
TMPDIR=/nonexistent bash <read-core-harness>    → 内部 rc=1，stdout 5B，stderr 0B（修复前 112B）

# 新发现（本轮独立追加验证）
注入无关 RuntimeError 后 write core：
  修复前 (9edf76c)：rc=1，stderr 162B（traceback 可见）
  修复后 (133ccdb)：rc=1，stderr 0B（traceback 被吞）

# 官方 192 行 prototype test（worktree 内临时文件运行，已清理）
SNAPSHOT_CORE=<修复后文件> bash <proto-test>   → rc=0，stdout 37B 逐字 `RESULT PASS  session snapshot safety\n`，stderr 0B

# 固定工具门
wc -l → 208；shfmt -d -i 2 -ci -bn → rc0 无diff；shellcheck -x --severity=warning → rc0 无诊断；bash -n → rc0；git diff --check → rc0
八 anchor grep -c 逐一 = 1

worktree 全程 git status --porcelain 为空，未修改/未提交。
```
