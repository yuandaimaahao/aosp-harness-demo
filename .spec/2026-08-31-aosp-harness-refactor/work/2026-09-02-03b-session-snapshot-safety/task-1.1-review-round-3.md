# Task 1.1 独立审查报告 — round 3（fix round 2 回审）

- spec: `2026-09-02-03b-session-snapshot-safety`
- 任务: 1.1，本轮 diff 包 `133ccdb71e62d5312225a33aa8b86f3af5885ee0..192fa1e133c50625ac5a6d1ce14f9a5df8502f72`
- reviewer: 独立 agent，全新上下文，未参与实现，非 round 1 / round 2 reviewer
- 审查日期: 2026-09-02
- 范围：**只审本轮 diff（1 行原地修改）**，不重审 BASE..133ccdb 的既有内容
- 只读审查：未修改 worktree、未提交；所有注入实验均在 `/tmp` 的副本上完成，
  worktree 文件全程未被触碰（见 §6）

## 结论

**PASS** — 阻断 0 / 重要 0 / 次要 2

round-2 的单行改动（把裸 `exec {path_fd}<>"$path_file"` 包进 `{ ...; }` 分组，
把 `2>/dev/null` 挂到分组上）经独立实证：作用域确实收窄、失败路径仍然静音、
`path_fd` 仍然持久传播并被最终 exec 的 python3 继承、控制流与 rc 完全不变。
额外发现：本轮改法还**顺带修好了 round-1 实际上没修成的那个泄漏**（见 §4.1），
不只是"回退副作用"。两条次要均为原型层面/理论边界，不构成 NEEDS_CHANGES。

---

## ① 本轮 delta 精确性

`git diff 133ccdb 192fa1e1 --numstat` → `1 1 common/.harness/lib/session-state-snapshot.sh`，
与 review 包逐字一致，只改 L193 一行：

- before: `      exec {path_fd}<>"$path_file" 2>/dev/null || {`
- after:  `      { exec {path_fd}<>"$path_file"; } 2>/dev/null || {`

无新增/删除行、无重排、无夹带改动。相对 PROTO_SHA 原型 blob
（`a708ce6f…:…/prototype/snapshot-core-r2.sh`）的**累计**差异仍恰好是
round-1+round-2 的那 4 行（L192/193/194/197），`diff` 输出中无第五处：

```
< path_file=$(mktemp ...)                       > ... 2>/dev/null) || return 1
< exec {path_fd}<>"$path_file" || {              > { exec {path_fd}<>"$path_file"; } 2>/dev/null || {
< rm -f -- "$path_file"                          > rm -f -- "$path_file" 2>/dev/null
< rm -f -- "$path_file" || return 1              > rm -f -- "$path_file" 2>/dev/null || return 1
```

`git diff --name-only 3d15a0d 192fa1e1` = 仅 1 个文件；`--numstat` = `208 0`。

## ② 作用域是否真的收窄了（要求 1，实证）

### 2.1 构造层最小对照

```
bash -c 'exec {fd}<>/tmp/x 2>/dev/null; echo "fd=$fd"; echo SHOULD_BE_VISIBLE >&2; exec python3 -c "..."'
  → stdout fd=10，stderr 0 字节（shell echo 与 python stderr 全被吞）
bash -c '{ exec {fd}<>/tmp/x; } 2>/dev/null; echo "fd=$fd"; echo SHOULD_BE_VISIBLE >&2; exec python3 -c "..."'
  → stdout fd=11，stderr 28 字节（`SHOULD_BE_VISIBLE\npy-stderr\n` 均可见）
```

### 2.2 目标文件上的注入实验

在 `/tmp` 的 133ccdb 与 192fa1e1 两份副本上，用 `sed '7a raise
RuntimeError("r3-uncaught-probe")'` 在 python heredoc 顶层插入一个
**不被任何 except 子句捕获**的异常（`except` 列表只有 Interrupted / Missing /
Unsafe / (OSError, Failed, AttributeError)，RuntimeError 逃逸），
用真实 state 树（`/tmp/r3-state/proj/sess`，三层 0700）触发一次真实 write：

| 版本 | 内部 rc | stdout | stderr |
|---|---|---|---|
| 133ccdb + 注入 | 1 | 5 B | **0 B**（traceback 被吞） |
| 192fa1e1 + 注入 | 1 | 5 B | **105 B**，逐字 `Traceback (most recent call last):\n  File "<stdin>", line 2, in <module>\nRuntimeError: r3-uncaught-probe\n` |

read 路径同样：133ccdb 0 B / 192fa1e1 105 B。rc 前后均为 1，未变。

**判定：作用域确实收窄，traceback 恢复可见。✅**

注入全部只发生在 `/tmp` 副本上，worktree 文件的 sha256 与 HEAD blob 逐字相同
（见 §6），无需"还原"。

## ③ 失败路径是否仍然静音（要求 2，实证）

`TMPDIR=/nonexistent` 触发 `mktemp` 失败：

| 版本 | write 内部 rc / stderr | read 内部 rc / stderr |
|---|---|---|
| PROTO（无任何抑制） | 1 / **112 B**（`mktemp: failed to create file via template …`） | 1 / **112 B** |
| 133ccdb | 1 / **0 B** | 1 / **0 B** |
| 192fa1e1（HEAD） | 1 / **0 B** | 1 / **0 B** |

**判定：未回退，rc 不变，stderr 恰好 0 字节。✅**

## ④ 控制流 / 新逃逸排查（要求 4）

### 4.1 强制 `exec` 重定向本身失败（核心新发现，对 HEAD 有利）

用 `ulimit -n` 压低 RLIMIT_NOFILE，使 `mktemp` 仍成功但 `{path_fd}<>` 无法
分配 fd（bash 的 varredir fd 需要 ≥10）：

| RLIMIT_NOFILE | 133ccdb（裸 exec + `2>/dev/null`） | 192fa1e1（分组） |
|---|---|---|
| 6 / 7 / 8 / 9 / 10 | rc=1，**stderr 158 B 泄漏**，temp 已清 | rc=1，**stderr 0 B**，temp 已清 |
| 11 | rc=0（成功） | rc=1，stderr 0 B，temp 已清 |
| 12 / 14 / 20 | rc=0 | rc=0 |

158 B 泄漏内容：
`…: redirection error: cannot duplicate fd: Invalid argument` +
`…: line 193: /tmp/…/snapshot-path.XXXXXXXX: Invalid argument`。

机制：裸 `exec` 的重定向按**从左到右**依次应用，`{path_fd}<>"$path_file"`
在 `2>/dev/null` **之前**就失败，报错因此打到尚未被重定向的真 stderr。
即 **round-1 的写法对它自己声称要修的那条失败路径根本没生效**；round-2 的
分组写法把 `2>/dev/null` 提到复合命令层，进入 group 前先完成 fd2 替换，才
真正堵住了这条泄漏。这是本轮的净正收益，不只是"撤销副作用"。

失败分支控制流：两版均走 `|| { rm -f -- "$path_file" 2>/dev/null; return 1; }`，
rc 均为 1，`TMPDIR` 目录事后 `ls -A` 均为空（无 temp 残留），**没有任何
错误路径变成静默成功**。

### 4.2 shell 选项语义

`set -e` / `set -u` / `set -eu` / `set -o pipefail` / `shopt -s nullglob`
五种调用方状态 × {默认 TMPDIR, TMPDIR=/nonexistent}，两版本逐格比对
**完全一致**（rc、stdout、stderr 字节数无一处差异）。`{ ...; }` 处于 `||`
列表左侧，errexit 不触发，与裸 exec 相同。本文件自身不用 `set -e`、无管道。

### 4.3 双流空回归全扫（stderr 恢复后是否暴露既有噪声）

round-1 的过度静音可能掩盖了 python worker 在既有失败路径上的输出。恢复
stderr 后逐条复验 R2/R3/R4 枚举的失败分类，**全部仍为 0 字节**：

| 场景 | rc | stderr |
|---|---|---|
| read: leaf 缺席 | 3 | 0 B |
| read: leaf symlink / 0644 / 是目录 / nlink=2 | 2 | 0 B |
| read: 空内容 / `a b\n` / 无 LF / 多 LF / 201 字节 / 非 ASCII | 2 | 0 B |
| read & write: managed 目录 0755 | 2 | 0 B |
| read & write: session 目录消失 | 1 | 0 B |
| path core `return 1` / `return 2` 透传 | 1 / 2 | 0 B |
| path core 无 LF / 多 LF / 5000 字节输出 | 2 | 0 B |
| write 非法 feature `a/b`、arity 3/5、`read` arity 2/4、未知 op | 2 | 0 B |
| 信号：TEMP barrier 处 TERM（见 §5.3） | 143 | 0 B |

唯一新暴露项见次要 #1（`python3` 解释器缺席）。

## ⑤ fd 契约（要求 3，实证，非读码推断）

### 5.1 分组内 fd 赋值仍持久传播

```
bash -c '{ exec {fd}<>/tmp/f; } 2>/dev/null; rm -f /tmp/f; printf "hello-from-shell\n" >&$fd;
         exec python3 -c "…" "$fd"'
→ py sees fd 11 nlink 0 content b'hello-from-shell\n'
```

`{ list; }` 在当前 shell 执行（非 `( )` 子 shell），fd 分配持久化；分组只对
fd 2 做临时替换/恢复，退出后 `ls /proc/$$/fd` = `0 1 2 3 11`，**没有遗留
bash 用于暂存 stderr 的 fd 10**。

### 5.2 目标文件端到端（held-capture 全链路）

真实 state 树（`/tmp/r3-state/{proj,sess}` 三层 0700）+ 真实 path core stub：

```
write alpha（首发）      → rc=0，双流：stdout 5B(`rc=0\n`)，stderr 0B；产出 -rw------- feature（6 B）
read                     → rc=0，stdout 逐字 `alpha\n`，stderr 0B
write alpha（幂等）      → rc=0，双流空，winner 不变
write beta（异值冲突）   → rc=3，stderr 0B，winner 仍为 `alpha`，未被修改
```

在 `/tmp` 副本上插桩 python 侧打印 `/proc/self/fd`：

```
PYFDS [0, 1, 2, 3, 11]   argv ['write', '11', 'proj', 'sess', 'alpha']
```

（fd 3 是 `os.listdir("/proc/self/fd")` 自身的句柄。）即：bash 分配的
`path_fd=11` 原样通过 argv 传给 python，且该 fd 在 exec 后的 python 进程中
仍然打开、可 fstat/lseek/read。python 端 `path_from_fd` 要求
`verify(info, "file", euid, 0o600, 0)` —— **nlink 必须为 0**，端到端成功即
证明 capture 已被 unlink 且 fd 被持有传递。

**判定：held-capture fd 契约（R2「只向该 fd 写入 + 最终 exec 的 python3
继承同一 fd」）未被分组写法破坏。✅**

### 5.3 backgrounded PID 与信号（R4/R7 相邻契约未被波及）

`_harness_session_snapshot_worker write proj sess alpha &` 后轮询：

```
bg_pid=334222  comm=python3  exe=/usr/bin/python3.12  fds= 0 1 2 11
```

即 `$!` 拿到的 PID 就是 python worker，且它持有的额外 fd 恰好只有 capture
fd 11（无 fd 10 泄漏）。在 `HARNESS_TEST_MARKER_TEMP_BEFORE_PUBLISH` 处插桩
延迟后对同一 PID 发 `SIGTERM`：worker rc=**143**、stderr **0 B**、session 目录
事后 `ls -A` 为空（temp 已清、无 winner）。

## ⑥ 门（要求 5）

```
export PATH=<scratchpad>/tools/bin:$PATH
shfmt --version                          → v3.14.0
shellcheck --version                     → version: 0.11.0
wc -l  common/.harness/lib/session-state-snapshot.sh   → 208
shfmt -d -i 2 -ci -bn  <file>            → rc=0，输出 0 字节（无 diff）
shellcheck -x --severity=warning <file>  → rc=0，输出 0 字节（无诊断）
bash -n <file>                           → rc=0
git diff --check                         → rc=0
git status --porcelain                   → 空（clean）
git diff HEAD --stat                     → 空，rc=0
```

八 anchor `grep -c` 各恰一次：
`CAPTURE_READY=1  SNAPSHOT_MANAGED_BEFORE_OPEN=1  MANAGED_EXPECTED_EUID=1
SNAPSHOT_EXPECTED_EUID=1  SNAPSHOT_BEFORE_OPEN=1  TEMP_BEFORE_PUBLISH=1
PUBLISH_RESULT=1  OS_ERROR=1`

官方 192 行 prototype test（`PROTO_SHA:…/prototype/snapshot-test-prototype.sh`，
`wc -l` 核实 192），以 `SNAPSHOT_CORE=<worktree 绝对路径>` 从 worktree 根下的
临时文件运行，运行后立即删除：

```
rc=0   stdout 37 B，od -c 逐字 `RESULT PASS  session snapshot safety\n`   stderr 0 B
运行后 git status --porcelain → 空
```

worktree 完整性：
`HEAD=192fa1e133c50625ac5a6d1ce14f9a5df8502f72`；
工作树文件 sha256 = HEAD blob sha256 =
`17dfa03a4126231f4f4afbbee33178c0f109c637355cc222d7f874a7ec4b5d0f`；`wc -l`=208。

**全部门通过。✅**

## ⑦ 规格符合性（要求 6）

| 需求 | 判定 | 依据 |
|---|---|---|
| R2「所有 write 结果及 read 失败结果双流空」 | ⚠️（实质 ✅） | §3 + §4.3 全表 0 B；§5.2 成功路径双流按契约。唯一例外是次要 #1（`python3` 缺席时 `exec` 报错 50 B / rc 127），该行为**原型 blob 本身即存在**（同条件泄漏 56 B），非本轮引入 |
| R2 held-capture fd 契约（path core 只向该 fd 写、最终 exec 的 python3 继承同一 fd） | ✅ | §5.1/§5.2 实证：分组不影响 fd 持久分配，`PYFDS [0,1,2,3,11]` + `argv[…,'11',…]`，nlink=0 校验通过，端到端 write/read 成功 |
| R4「非 EEXIST 分支双流空/1、无 fallback」 | ✅ | §4.3 managed/session 消失均 1/0 B；`grep` 复核无 `os.rename(`/`os.replace(`/`os.link(`/`shutil.`；publish 仍只走 `renameat2` |
| R4 spawn-only worker = python PID + 信号协议 | ✅ | §5.3：`$!` comm=python3，TERM → 143、0 B、无 temp、无 winner |

---

## findings

### 阻断（0）

无。

### 重要（0）

无。上一轮唯一的「重要」（裸 exec 永久静音）已被本轮修复，且经 §2.2 实证；
本轮未发现新的重要问题。

### 次要（2）

**[次要][R2 字面「双流空」，但源自 PROTO 原型文本、非本轮引入] `python3`
解释器缺席时 `exec python3` 的 not-found 报错现在可见（50 B），rc=127**

- 位置：`common/.harness/lib/session-state-snapshot.sh` L6
  `exec python3 - "$@" <<'PY'`（本轮未触碰）。
- 实证（`env -i PATH=<仅 mktemp/rm 的目录>`）：
  - PROTO blob：内部 rc=127，stderr **56 B** `…: line 6: exec: python3: not found`
  - 133ccdb：内部 rc=127，stderr **0 B**（被裸 exec 的永久静音意外掩盖）
  - 192fa1e1（HEAD）：内部 rc=127，stderr **50 B**
- 定性：这是 PROTO_SHA 原型文本（任务 1.1 要求逐字落地的对象）自带的行为；
  round-1 只是因为 bug 顺带把它盖住了，本轮按裁定正确收窄作用域后必然重新
  暴露。它也不属于 R2 枚举的失败分类（managed 身份错→2 / 真实 I/O 或对象
  消失→1 / path 原始 1/2 透传），而是"解释器缺失"这类环境前置条件。
- 建议：与已挂账的 8 条次要同处置（留给 03b1/03c 或规格层面统一决定）；
  本轮不应因此判 NEEDS_CHANGES。

**[次要][健壮性，无直接对应 R] 分组写法比裸 exec 多消耗 1 个 fd 槽位，在
RLIMIT_NOFILE=11 这一极端边界上由成功变为 fail-closed 失败**

- 机制：`{ ...; } 2>/dev/null` 需要一个 ≥10 的 fd 暂存原 stderr，导致
  `path_fd` 由 10 变为 11（§2.1/§5.1 实测）。
- 实证（§4.1 sweep）：`ulimit -n 11` 时 133ccdb rc=0（成功），192fa1e1 rc=1；
  `ulimit -n ≥12` 两版一致成功。
- 影响：fail-**closed**（rc=1、双流空、temp 已清、无 winner 变更），不是
  fail-open；且 nofile=11 在任何真实环境下不可达（默认 1024+）。同时在
  nofile ≤10 的区间 HEAD 反而比 133ccdb 少泄漏 158 B。综合为净改善。
- 建议：不需修，仅记录。

---

## 独立复现结果汇总（供控制器核对）

```
# 门
wc -l → 208
shfmt -d -i 2 -ci -bn        → rc=0，stdout+stderr 0 B
shellcheck -x --severity=warning → rc=0，0 B
bash -n                      → rc=0
git diff --check             → rc=0
git status --porcelain       → 空
八 anchor grep -c            → 全 = 1
prototype test (192 行, SNAPSHOT_CORE=绝对路径) → rc=0, stdout 37 B 逐字
                               `RESULT PASS  session snapshot safety\n`, stderr 0 B

# 要求 1：作用域收窄（注入未捕获 RuntimeError，/tmp 副本）
133ccdb + 注入  write → 内部 rc=1, stdout 5 B, stderr   0 B
192fa1e1 + 注入 write → 内部 rc=1, stdout 5 B, stderr 105 B（完整 traceback）
192fa1e1 + 注入 read  → 内部 rc=1,            stderr 105 B

# 要求 2：失败路径仍静音（TMPDIR=/nonexistent）
PROTO    write/read → rc=1 / stderr 112 B
133ccdb  write/read → rc=1 / stderr   0 B
192fa1e1 write/read → rc=1 / stderr   0 B

# 要求 3：fd 契约
{ exec {fd}<>f; } 2>/dev/null → fd=11 持久；rm 后 nlink=0；exec python3 继承同一 fd 可读
目标文件 PYFDS [0,1,2,3,11] argv ['write','11','proj','sess','alpha']
端到端 write alpha rc=0 / read rc=0 stdout `alpha\n` / 幂等 rc=0 / 异值 rc=3 winner 不变
backgrounded worker: comm=python3, fds=0 1 2 11；TEMP barrier 处 TERM → rc=143, stderr 0 B, 无 temp

# 要求 4：exec 失败控制流（ulimit -n sweep）
nofile 6..10 : 133ccdb rc=1 stderr 158 B ; 192fa1e1 rc=1 stderr 0 B ; 两版 temp 均已清
nofile 11    : 133ccdb rc=0             ; 192fa1e1 rc=1 stderr 0 B
nofile ≥12   : 两版均 rc=0，stderr 0 B
set -e / -u / -eu / pipefail / nullglob × {默认TMPDIR, /nonexistent} → 两版逐格一致

# 双流空回归全扫（stderr 恢复后）
read 缺席3 / symlink・0644・目录・nlink2 → 2 / 九类内容损坏 → 2 / managed 0755 → 2
session 消失 → 1 / path core 1・2 透传 / path core 输出损坏 → 2 / arity 与非法 feature → 2
以上 20+ 场景 stderr 全部恰好 0 B

# 新暴露（次要 #1）
python3 缺席：PROTO stderr 56 B / 133ccdb 0 B / 192fa1e1 50 B，三者 rc 均 127

# worktree
HEAD = 192fa1e133c50625ac5a6d1ce14f9a5df8502f72
工作树文件 sha256 == HEAD blob sha256 == 17dfa03a4126231f4f4afbbee33178c0f109c637355cc222d7f874a7ec4b5d0f
git status --porcelain 全程为空；所有注入实验均在 /tmp 副本上进行，已全部删除
```
