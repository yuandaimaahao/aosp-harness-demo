# Task 1.1 Report: 机械落地完整 snapshot runtime

## task

任务 1.1（8 任务中的第 1 个）：在隔离 implementation worktree 中机械创建
`common/.harness/lib/session-state-snapshot.sh`，内容与 prototype blob
`PROTO_SHA:PROTO_CORE`（`a708ce6f0979c6644292b58b4a7b0d4afcdf821d:
.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/prototype/snapshot-core-r2.sh`）
逐字相同，用 prototype test blob（`PROTO_TEST`）以绝对 `SNAPSHOT_CORE` 指向
目标 runtime 作为反证，再跑固定工具门与结构核对，最后提交。

本报告只覆盖步骤 1–5（步骤 6 独立 review 与步骤 7 manifest/mark/ledger 由
控制器执行）。

## base / head

- TASK_BASE = `3d15a0d76c2a2e6c8541c5d47001a55f0ca18649`
- TASK_HEAD = `9edf76cced42e22185677b240f77d86ddbf0eb01`
- 分支：`spec/2026-09-02-03b-session-snapshot-safety`
- worktree：`/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/worktree`
- 提交前 `HEAD == TASK_BASE`（已核实），提交后 `TASK_BASE..TASK_HEAD` 恰好
  推进一个 commit。

## files

- 创建（源码，仅此一个）：`common/.harness/lib/session-state-snapshot.sh`
  （208 行，与 `git show a708ce6f0979c6644292b58b4a7b0d4afcdf821d:
  .spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/prototype/snapshot-core-r2.sh`
  逐字节相同，`cmp -s` 与 sha256 双重确认，两者 sha256 均为
  `d437bcccd4f6893d53e63f5d1bca4340e865862a2389886a867491c5db0b1a98`）。
- 验收资产（不纳入源码文件清单，本次实际创建）：
  - `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/evidence/task-1.1-red.txt`
  - `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/task-1.1-report.md`（本文件）
  - `review-manifest.tsv` 由控制器在步骤 7 之后创建/追加，本任务未创建。
- `BASE..HEAD` 工作树 diff 仅含上述 1 个源码文件，无其他改动。

## commands

### 步骤 1（red 证据）

```
test ! -e common/.harness/lib/session-state-snapshot.sh
bash -c 'source common/.harness/lib/session-state-snapshot.sh'
```
- rc=1；stderr=`bash: line 1: common/.harness/lib/session-state-snapshot.sh: No such file or directory`；stdout 空。
- red 证据写入 `$WORK/evidence/task-1.1-red.txt`（固定六行 schema + assertion），`test -s` 确认非空。

### 步骤 2（机械落地）

```
git -C "$IMPL" show a708ce6f0979c6644292b58b4a7b0d4afcdf821d:.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/prototype/snapshot-core-r2.sh > /tmp/tmp.sznvQd3uQl
cp /tmp/tmp.sznvQd3uQl "$IMPL/common/.harness/lib/session-state-snapshot.sh"
cmp -s /tmp/tmp.sznvQd3uQl "$IMPL/common/.harness/lib/session-state-snapshot.sh"
wc -l "$IMPL/common/.harness/lib/session-state-snapshot.sh"
```
- 结论：`cmp -s` rc=0（CMP-IDENTICAL）；`wc -l` = 208（与 brief 已核实值一致）。

### 步骤 3（prototype test 反证）

```
git -C "$IMPL" show a708ce6f0979c6644292b58b4a7b0d4afcdf821d:.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/prototype/snapshot-test-prototype.sh > /tmp/tmp.uvYniYuoGy.sh   # 192 行
cp /tmp/tmp.uvYniYuoGy.sh "$IMPL/.proto-test-137555-5433.sh"
SNAPSHOT_CORE="$IMPL/common/.harness/lib/session-state-snapshot.sh" bash "$IMPL/.proto-test-137555-5433.sh" >"$OUT" 2>"$ERR"
rm -f "$IMPL/.proto-test-137555-5433.sh"
```
- 结论：rc=0；stdout（`od -c` 逐字节核对）恰为 `RESULT PASS  session snapshot safety\n`；stderr 0 字节；临时测试文件已删除，`git status --porcelain` 确认仅剩目标源码文件为 untracked。

### 步骤 4（固定工具门 + 结构核对）

```
export PATH=/tmp/claude-1000/.../scratchpad/tools/bin:$PATH
shfmt --version      # v3.14.0
shellcheck --version # version: 0.11.0
shfmt -d -i 2 -ci -bn common/.harness/lib/session-state-snapshot.sh
shellcheck -x --severity=warning common/.harness/lib/session-state-snapshot.sh
bash -n common/.harness/lib/session-state-snapshot.sh
git -C "$IMPL" add -N common/.harness/lib/session-state-snapshot.sh
git -C "$IMPL" diff --check
git -C "$IMPL" diff --numstat -- common/.harness/lib/session-state-snapshot.sh
```
- shfmt version 逐字比对 = `v3.14.0`（PASS）；shellcheck version 字段逐字比对 = `0.11.0`（PASS）。
- `shfmt -d -i 2 -ci -bn`：rc=0，无 diff 输出。
- `shellcheck -x --severity=warning`：rc=0，无诊断输出。
- `bash -n`：rc=0。
- `git diff --check`：rc=0，无空白错误。
- `git diff --numstat`：`208 0 common/.harness/lib/session-state-snapshot.sh`；`git diff --name-only` 仅此一个文件。

八 anchor exact-once（`grep -c`逐一核对，均=1，且均为 `pass` / `: #` /
`return os.geteuid()  # ANCHOR` 形式的无副作用文本点，不读任何测试环境变量）：

| anchor | count |
|---|---|
| HARNESS_TEST_MARKER_CAPTURE_READY | 1 |
| HARNESS_TEST_MARKER_SNAPSHOT_MANAGED_BEFORE_OPEN | 1 |
| HARNESS_TEST_MARKER_MANAGED_EXPECTED_EUID | 1 |
| HARNESS_TEST_MARKER_SNAPSHOT_EXPECTED_EUID | 1 |
| HARNESS_TEST_MARKER_SNAPSHOT_BEFORE_OPEN | 1 |
| HARNESS_TEST_MARKER_TEMP_BEFORE_PUBLISH | 1 |
| HARNESS_TEST_MARKER_PUBLISH_RESULT | 1 |
| HARNESS_TEST_MARKER_OS_ERROR | 1 |

无 fallback 核对：`grep -n "renameat2\|RENAME_NOREPLACE\|ENOSYS"` 仅命中
`ctypes.CDLL(None, use_errno=True).renameat2` 一处调用点；`grep -n
"os\.rename(\|os\.replace(\|os\.link(\|shutil\."` 无匹配（无替换/link
publish 等降级路径）。`HARNESS_SESSION_STATE_PROVIDER_VERSION` 与四个
public API（`harness_session_path/write/read/remove`）均未在文件中出现。

source 四态核对（none/validate/path/both 组合，逐态验证 source rc、
export 快照增量（已剔除 bash 自身 `$_` 噪声后逐字比对）、
`HARNESS_SESSION_STATE_PROVIDER_VERSION` 缺席、三个 snapshot 私有 export
只在 `both` 态出现、四个 public API 在全部四态均缺席）：

| setup | source_rc | exports 增量 | provider marker | 3 export 存在 | 4 public API 泄漏 |
|---|---|---|---|---|---|
| none | 0 | 无变化 | 缺席 | 否 | 无 |
| validate | 0 | 无变化 | 缺席 | 否 | 无 |
| path | 0 | 无变化 | 缺席 | 否 | 无 |
| both | 0 | 无变化 | 缺席 | 是 | 无 |

此外，步骤 3 所跑的官方 192 行 prototype test 本身在其
`for setup in none validate path both` 循环内部即以逐字符串比较
`before`/`before_inventory`/`before_exports` 与 `after`/`after_inventory`/
`after_exports`（含 provider marker `-v` 缺席检查）作为进入后续 active
case 的前置门；该测试已在步骤 3 以 rc0 + 逐字 PASS 通过，等价确认了同一
四态零副作用结论。

assurance sizing hash 只读核对（仅确认 git 对象可达，未读取/修改内容，
不构成对 03b1 assurance 范围的实施）：

```
git -C "$IMPL" cat-file -e a708ce6f0979c6644292b58b4a7b0d4afcdf821d   # PROTO_SHA，存在
git -C "$IMPL" cat-file -e cbdbdde0e1e3ff4ceb2dc0279b1db83127a0ea9e   # assurance，存在
git -C "$IMPL" cat-file -e 9f0dfbc5bca35df8fe9ea9ba249050a8aa4547fd   # evidence，存在
```
- 三个引用 commit 对象均可达（`cat-file -e` rc=0）；PROTO_SHA 下
  `snapshot-core-r2.sh`（208 行）与 `snapshot-test-prototype.sh`（192 行）
  的 sha256 与步骤 2/3 中落地临时文件的 sha256 完全一致，确认全程未发生
  内容漂移。

### 步骤 5（提交与核验）

```
git -C "$IMPL" add common/.harness/lib/session-state-snapshot.sh
git -C "$IMPL" commit -m 'feat(session): add snapshot runtime ...'
TASK_HEAD=$(git -C "$IMPL" rev-parse HEAD)
git -C "$IMPL" diff --name-only "$TASK_BASE" "$TASK_HEAD"
git -C "$IMPL" diff --numstat "$TASK_BASE" "$TASK_HEAD"
git -C "$IMPL" status --porcelain
sha256sum common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh tests/lib/session-path-race-driver.py tests/test-session-path-races.sh   # before/after
```
- 提交前以 `git add -N` 确认 working-tree name-only exact 1 / numstat
  `208 0`。
- commit message 首行逐字 `feat(session): add snapshot runtime`（后接
  Co-Authored-By / Claude-Session 归属行）。
- `TASK_BASE..TASK_HEAD` name-only 恰为 `common/.harness/lib/session-state-snapshot.sh` 一个文件；numstat `208 0`。
- `git status --porcelain` 提交后为空（clean）。
- 上游四文件 sha256（`session-state-foundation.sh` /
  `session-state-path.sh` / `session-path-race-driver.py` /
  `test-session-path-races.sh`）提交前后逐字节比对（`diff` 无差异），确认
  未被本任务触碰。

## results

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/evidence/task-1.1-red.txt

- 目标文件与 `PROTO_SHA:PROTO_CORE` 逐字节相同（cmp + sha256 双证），208 行。
- 官方 192 行 prototype test 以绝对 `SNAPSHOT_CORE` 指向目标 runtime：rc0、
  stdout 逐字 `RESULT PASS  session snapshot safety\n`（od -c 核对）、
  stderr 0 字节。
- shfmt `v3.14.0` / ShellCheck `0.11.0` 版本逐字核对通过；对目标文件运行
  `shfmt -d -i 2 -ci -bn`、`shellcheck -x --severity=warning`、`bash -n`
  均 rc0 且无差异/诊断输出。
- `git diff --check` rc0；working tree 提交后 clean。
- 八个 anchor 各精确出现 1 次，均为无副作用文本点，不读测试环境变量；无
  fallback rename/replace/link 路径；无 provider marker；无四个 public
  API 定义。
- source 四态（none/validate/path/both）逐态 rc0、export/inventory 无
  额外增量、provider marker 缺席、3 export 只在 `both` 出现、public API
  全态缺席。
- assurance sizing 相关三个 commit 对象只读核对为可达，未做任何写入或
  用于本任务实施范围。
- `TASK_BASE..TASK_HEAD`（`3d15a0d76c2a2e6c8541c5d47001a55f0ca18649..
  9edf76cced42e22185677b240f77d86ddbf0eb01`）恰好新增 1 个文件、numstat
  `208 0`；working tree clean；上游 foundation/path/03a1-driver/
  03a2-entrypoint 四文件 SHA-256 提交前后逐字节不变。
- 提交：`9edf76cced42e22185677b240f77d86ddbf0eb01`
  `feat(session): add snapshot runtime`（仅此一个文件）。

本任务未执行步骤 6（独立 review）与步骤 7（manifest 追加行 /
mark-task-done / ledger sync），留给控制器处理。

## fix round 1

独立 reviewer 对提交 `9edf76cced42e22185677b240f77d86ddbf0eb01` 给出
NEEDS_CHANGES（阻断 0 / 重要 1 / 次要 8）。控制器裁定：只修那 1 条重要
finding（R2/R4 双流空违约），其余 8 条次要挂账不修。本节记录修复过程与
重跑门禁的证据。

### 复现（修复前）

在最小 harness 下（`harness_validate_feature_name` 与
`_harness_session_path_core` 均先于 `source` 定义好，满足 active 分支
前置条件）以 `TMPDIR=/nonexistent` 触发 write core：

```
TMPDIR=/nonexistent bash -c '
  harness_validate_feature_name() { ...; }
  _harness_session_path_core() { echo unused; }
  source common/.harness/lib/session-state-snapshot.sh
  _harness_session_snapshot_write_core proj sess feat
'
```
- 修复前：rc=1（正确），stdout 5 字节（`rc=1\n`），**stderr 112 字节**
  （`mktemp: failed to create file via template '/nonexistent/snapshot-path.XXXXXXXX': No such file or directory`）——违反 R2/R4「所有 write
  结果及 read 失败结果双流空」的无条件要求。
  read core（`_harness_session_snapshot_read_core proj sess`）在同一
  `TMPDIR=/nonexistent` 条件下走同一 `_harness_snapshot_dispatch` 捕获
  逻辑，同样会泄漏。

### delta 逐条枚举

修改面严格限定在 `_harness_snapshot_dispatch` 内原第 192/193/194/197
四行的失败路径双流抑制，全部用行内 `2>/dev/null` 完成，**未新增行、
未拆行、未重排**，文件仍为 208 行：

1. 第 192 行：`path_file=$(mktemp "${TMPDIR:-/tmp}/snapshot-path.XXXXXXXX") || return 1`
   → 在 `mktemp` 调用末尾加 `2>/dev/null`（位于 `$(...)` 内部，只抑制
   mktemp 自身的 stderr，不影响 `|| return 1` 的失败分支判定）。
2. 第 193 行：`exec {path_fd}<>"$path_file" || {`
   → 在 `exec {path_fd}<>"$path_file"` 后加 `2>/dev/null`，抑制该
   redirection 若失败时 bash 打到 stderr 的错误文本。
3. 第 194 行（193 行失败分支内的清理）：`rm -f -- "$path_file"`
   → 加 `2>/dev/null`，抑制该清理性 `rm -f` 罕见失败（如目录权限问题）
   时的错误文本。
4. 第 197 行：`rm -f -- "$path_file" || return 1`
   → 同样在 `rm -f -- "$path_file"` 后加 `2>/dev/null`。

未触碰的部分：`open_dir` 的 dirfd 使用方式、`dispatch` 里
print-before-close 顺序、`first_signal` 间隙、`managed_euid`/
`snapshot_euid` 的 EUID 直调、`renameat2`/`RENAME_NOREPLACE` 字面量、
`close_all` 等 helper 的可见性、`sys.argv[1]` 越界防护——这 8 条均为
reviewer 挂账的次要项，本轮不改，未来提交越过任何这些点的行为不变。

### 复现（修复后回归）

同一 harness、同一 `TMPDIR=/nonexistent`，write 与 read 两路均重跑：

```
TMPDIR=/nonexistent bash /tmp/repro.sh <target>       # write core
TMPDIR=/nonexistent bash /tmp/repro-read.sh <target>  # read core
```
- write：top-level rc=0（脚本自身），内部 `_harness_session_snapshot_write_core`
  rc=1（不变），stdout 5 字节（`rc=1\n`，不变），**stderr 0 字节**（修复前 112 字节）。
- read：同上，内部 `_harness_session_snapshot_read_core` rc=1（不变），
  stdout 5 字节，**stderr 0 字节**（同一 dispatch 路径同步验证）。

rc 与既有成功/失败契约完全不变，仅 stderr 由泄漏变为空，证明修复只封堵
双流泄漏、未改变任何返回码语义。

### 重跑步骤 3–5 全部门（对修复后文件）

```
export PATH=/tmp/claude-1000/-home-zzh0838-CareerDevelop-AI2D-aosp-harness-demo/bdc6e669-9154-4030-a9db-78dc599ab491/scratchpad/tools/bin:$PATH
shfmt --version                                   # v3.14.0
shellcheck --version                              # version: 0.11.0
shfmt -d -i 2 -ci -bn common/.harness/lib/session-state-snapshot.sh   # rc=0，无 diff
shellcheck -x --severity=warning common/.harness/lib/session-state-snapshot.sh  # rc=0，无诊断
bash -n common/.harness/lib/session-state-snapshot.sh                # rc=0
git diff --check                                  # rc=0
SNAPSHOT_CORE=<target-abs-path> bash <prototype-test-tmp>             # rc=0, stdout=`RESULT PASS  session snapshot safety\n`, stderr=0B
wc -l common/.harness/lib/session-state-snapshot.sh                  # 208
```
- 全部 rc=0；prototype test stdout 经 `od -c` 逐字节核对为
  `RESULT PASS  session snapshot safety\n`，stderr 0 字节；`wc -l`
  仍为 208。
- 八 anchor（`HARNESS_TEST_MARKER_CAPTURE_READY` /
  `..._SNAPSHOT_MANAGED_BEFORE_OPEN` / `..._MANAGED_EXPECTED_EUID` /
  `..._SNAPSHOT_EXPECTED_EUID` / `..._SNAPSHOT_BEFORE_OPEN` /
  `..._TEMP_BEFORE_PUBLISH` / `..._PUBLISH_RESULT` / `..._OS_ERROR`）
  逐一 `grep -c` 核对均恰为 1；`grep -n
  "os\.rename(\|os\.replace(\|os\.link(\|shutil\."` 无匹配（仍无
  fallback）；`HARNESS_SESSION_STATE_PROVIDER_VERSION` 与四个 public
  API 仍全缺席。
- source 四态（none/validate/path/both）重跑：四态 `source_rc=0`，
  export 快照（剔除 `$_` 噪声）无变化，`HARNESS_SESSION_STATE_PROVIDER_VERSION`
  四态均缺席，与修复前一致。

### 提交与 BASE..HEAD 核对

```
git diff 9edf76cced42e22185677b240f77d86ddbf0eb01 -- common/.harness/lib/session-state-snapshot.sh   # 仅 4 行原地修改，无新增/删除行
git commit -m 'fix(session): suppress stderr on capture temp-file failure paths ...'
```
- 新提交（非 amend，`9edf76c` 历史保留）：
  `133ccdb71e62d5312225a33aa8b86f3af5885ee0`
  `fix(session): suppress stderr on capture temp-file failure paths`。
- `git diff --name-only 3d15a0d76c2a2e6c8541c5d47001a55f0ca18649 133ccdb71e62d5312225a33aa8b86f3af5885ee0`
  → 仅 `common/.harness/lib/session-state-snapshot.sh` 一个文件。
- `git diff --numstat` 同区间 → `208 0`（文件相对 TASK_BASE 仍是新增
  208 行，内部 4 行原地替换不改变该统计口径）。
- `git status --porcelain` → 空（clean）。
- 上游四文件（foundation/path/03a1-driver/03a2-entrypoint）SHA-256 与
  修复前、TASK_BASE 时完全一致（`diff` 无输出）。

新 TASK_HEAD = `133ccdb71e62d5312225a33aa8b86f3af5885ee0`。

## fix round 2

全新 reviewer 对 fix round 1（提交 `133ccdb71e62d5312225a33aa8b86f3af5885ee0`）
回审给出 NEEDS_CHANGES（阻断 0 / 重要 1 / 次要 0）。问题：round 1 在原
L193 裸 `exec {path_fd}<>"$path_file"` 后直接追加 `2>/dev/null`；Bash
里无命令词的裸 `exec` 的重定向对当前 shell 是**永久**生效的，因此这不是
"抑制这一行失败时的报错"，而是把 `_harness_snapshot_dispatch` 这个
subshell 剩余生命周期——包括最终 `exec` 出来的同 PID python3 worker——
的 stderr 永久静音，掩盖了本应可见的真实 traceback。控制器裁定：只改这
一处，用分组把重定向的作用域收紧到这一次 exec 本身。

### 改了什么

只改原（round-1 后）第 193 行一行，其余全部不变：

- 修改前：`      exec {path_fd}<>"$path_file" 2>/dev/null || {`
- 修改后：`      { exec {path_fd}<>"$path_file"; } 2>/dev/null || {`

即把裸 `exec {path_fd}<>"$path_file"` 包进一个 `{ ...; }` brace group，
把 `2>/dev/null` 挂在这个 group 上而不是挂在裸 exec 本身上。

### 为什么这样能收紧作用域

`{ list; }` 在**当前 shell**里执行（不是 `( list )` 子 shell），所以
group 内部对 `path_fd` 的持久 fd 分配（`{path_fd}<>"$path_file"`）仍然
照常持久化到调用它的 `_harness_snapshot_dispatch` subshell，供后续
`_harness_session_path_core ... 1>&"$path_fd"` 和最终
`_harness_snapshot_exec` 使用——这一点没有变化。但 `2>/dev/null` 现在是
挂在 `{ ...; }` 这个复合命令上的重定向：Bash 对复合命令的重定向语义是
"进入前把 fd 2 另存并 dup 到目标，执行完 list 后立即把 fd 2 恢复原样"，
只对 fd 2 这一个描述符做临时替换/恢复，不影响 group 内部因裸 exec 而
新开的其它 fd（如 `path_fd`）。于是：
- group 内那次 exec 若失败，它写到 fd 2 的报错文本命中的是已被临时
  重定向到 `/dev/null` 的 fd 2，被吞掉；
- group 一结束（无论 exec 成功与否），fd 2 立刻恢复成调用前的原始
  stderr，后续所有代码（含最终 `exec python3` 出来的同 PID worker）
  拿到的都是正常 stderr，不再被静音。

### 两个反例

**反例①：`TMPDIR=/nonexistent`（验证原 bug 仍然修复，未回退）**

```
TMPDIR=/nonexistent bash -c '<harness with validate+path stubbed>; source <target>; _harness_session_snapshot_write_core proj sess feat; echo rc=$?'
TMPDIR=/nonexistent bash -c '<同上>; _harness_session_snapshot_read_core proj sess; echo rc=$?'
```
- write：内部 rc=1（不变），stdout 5 字节（`rc=1\n`，不变），
  **stderr 0 字节**（mktemp 报错仍被吞，未回退）。
- read：内部 rc=1（不变），stdout 5 字节，**stderr 0 字节**（同一
  `_harness_snapshot_dispatch` 路径，同步验证）。

**反例②：注入未捕获 `RuntimeError`（本轮核心回归，验证静音范围已收窄）**

临时在 python heredoc 的 import 语句后插入一行
`raise RuntimeError("test-round2-regression")`（`sed -i '7a raise
RuntimeError("test-round2-regression")'`，使文件临时变为 209 行），
用一个把 `_harness_session_path_core` stub 成返回真实临时目录路径
（`/tmp/snap-state-test/project/session`，提前 `mkdir -p`）的最小
harness 触发一次真实 `_harness_session_snapshot_write_core`：

- **round-1（修复前，取自已提交的 `133ccdb`）+ 同一注入**：
  top-level rc=0，内部 `rc=1`，stdout 5 字节，**stderr 0 字节**——
  traceback 被完全吞掉，复现 reviewer 描述的问题（reviewer 原始实证是
  162 字节可见 traceback → 修复后 0 字节；本次用略有不同的注入点得到
  同样的定性结果：完全静音）。
- **round-2（本次修复后）+ 同一注入**：top-level rc=0，内部 `rc=1`
  （不变），stdout 5 字节（不变），**stderr 110 字节**，内容为完整
  `Traceback (most recent call last): ... RuntimeError:
  test-round2-regression`——证明 exec 之后的 python3 worker 的 stderr
  已恢复正常，不再被裸 exec 的重定向永久静音。

验证完毕后，用修复前保存的字节级备份把注入改动完全还原
（`cp /tmp/target-backup-round2.sh <target>`），`diff` 确认与还原前
逐字节相同，`wc -l` 回到 208；`git status --porcelain` 与
`git diff 133ccdb71e62d5312225a33aa8b86f3af5885ee0 --
common/.harness/lib/session-state-snapshot.sh` 确认工作树里只剩这一处
预期中的单行改动，没有任何注入残留。

### 重跑步骤 3–5 全部门（对 round-2 修复后文件）

```
export PATH=/tmp/claude-1000/-home-zzh0838-CareerDevelop-AI2D-aosp-harness-demo/bdc6e669-9154-4030-a9db-78dc599ab491/scratchpad/tools/bin:$PATH
shfmt --version                                   # v3.14.0
shellcheck --version                              # version: 0.11.0
shfmt -d -i 2 -ci -bn common/.harness/lib/session-state-snapshot.sh   # rc=0，无 diff（未触发任何重排）
shellcheck -x --severity=warning common/.harness/lib/session-state-snapshot.sh  # rc=0，无诊断
bash -n common/.harness/lib/session-state-snapshot.sh                # rc=0
git diff --check                                  # rc=0
SNAPSHOT_CORE=<target-abs-path> bash <prototype-test-tmp>             # rc=0, stdout=`RESULT PASS  session snapshot safety\n`, stderr=0B
wc -l common/.harness/lib/session-state-snapshot.sh                  # 208（shfmt 未改变行数，控制器要求的 BLOCKED 分支未触发）
```
- 全部 rc=0；prototype test stdout 经 `od -c` 逐字节核对为
  `RESULT PASS  session snapshot safety\n`，stderr 0 字节；`wc -l`
  仍为 208。
- 八 anchor 逐一 `grep -c` 核对均恰为 1（`HARNESS_TEST_MARKER_CAPTURE_READY`
  / `..._SNAPSHOT_MANAGED_BEFORE_OPEN` / `..._MANAGED_EXPECTED_EUID` /
  `..._SNAPSHOT_EXPECTED_EUID` / `..._SNAPSHOT_BEFORE_OPEN` /
  `..._TEMP_BEFORE_PUBLISH` / `..._PUBLISH_RESULT` / `..._OS_ERROR`）。
- source 四态（none/validate/path/both）重跑：四态 `source_rc=0`，
  export 快照（剔除 `$_` 噪声）无变化，`HARNESS_SESSION_STATE_PROVIDER_VERSION`
  四态均缺席，与 round 1 一致。

### 提交与 BASE..HEAD 核对

```
git diff 133ccdb71e62d5312225a33aa8b86f3af5885ee0 -- common/.harness/lib/session-state-snapshot.sh   # 仅第193行 1 行改动，无新增/删除行
git commit -m 'fix(session): scope capture fd-open stderr suppression to the exec itself ...'
```
- 新提交（非 amend，`9edf76c`/`133ccdb` 历史保留）：
  `192fa1e133c50625ac5a6d1ce14f9a5df8502f72`
  `fix(session): scope capture fd-open stderr suppression to the exec itself`。
- `git diff --name-only 3d15a0d76c2a2e6c8541c5d47001a55f0ca18649 192fa1e133c50625ac5a6d1ce14f9a5df8502f72`
  → 仅 `common/.harness/lib/session-state-snapshot.sh` 一个文件。
- `git diff --numstat` 同区间 → `208 0`（相对 TASK_BASE 仍是新增 208
  行，内部 1 行原地替换不改变该统计口径）。
- `git status --porcelain` → 空（clean）。
- 上游四文件（foundation/path/03a1-driver/03a2-entrypoint）SHA-256 与
  round 1、TASK_BASE 时完全一致（`diff` 无输出）。
- 8 条挂账的次要项（open_dir 的 dirfd、dispatch 的
  print-before-close、first_signal 间隙、EUID 直调、
  `RENAME_NOREPLACE` 字面量、helper 泄漏、`sys.argv[1]` 越界，以及
  round 1 报告中列出的同一清单）本轮继续不动。

新 TASK_HEAD = `192fa1e133c50625ac5a6d1ce14f9a5df8502f72`。
