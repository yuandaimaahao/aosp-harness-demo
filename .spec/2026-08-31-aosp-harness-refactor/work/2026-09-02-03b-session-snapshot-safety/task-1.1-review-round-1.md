# Task 1.1 独立审查报告 — round 1

- spec: `2026-09-02-03b-session-snapshot-safety`
- 任务: 1.1 机械落地完整 snapshot runtime
- BASE `3d15a0d76c2a2e6c8541c5d47001a55f0ca18649` → HEAD `9edf76cced42e22185677b240f77d86ddbf0eb01`
- 分支 `spec/2026-09-02-03b-session-snapshot-safety`
- reviewer: 独立 agent，全新上下文，未参与实现
- 审查日期: 2026-09-02

## 结论

**NEEDS_CHANGES** — 阻断 0 / 重要 1 / 次要 8

机械落地本身完全正确：交付文件与 prototype blob 逐字节相同，208 行，
sha256 双向确认。安全核心（create-once publish、nofollow 三层 managed 链、
shared read oracle、信号 latch 与 owned-temp cleanup）经我独立复现的行为矩阵
全部通过，无任何 fail-open。

唯一的 **重要** 项是 blob 自身在 `mktemp` 失败路径上泄漏 stderr，违反 R2/R4
无条件的「双流空」约定。该缺陷源自 prototype blob，而非实现者的落地动作——
本任务的裁定口径禁止实现者偏离 blob，因此修复应路由到 prototype/spec
（新 `PROTO_SHA`）或由控制器出具显式豁免，而不是判定实现者执行有误。

---

## 独立复核方法

实现者未落盘逐命令日志，report 内联记录 command/rc/结论。我按控制器指示
**独立重跑了 blob 一致性核对**，并**额外自建 driver 复现了 report 未覆盖的
完整行为矩阵**（攻击表、损坏表、并发、PID、信号）。所有临时产物在 `/tmp`，
worktree 未被修改（`git status --porcelain` 空，`git log` 未变）。

独立复现的 blob 核对：

```
git -C <worktree> show a708ce6f0979c6644292b58b4a7b0d4afcdf821d:.spec/.../prototype/snapshot-core-r2.sh
  → 208 行, sha256 d437bcccd4f6893d53e63f5d1bca4340e865862a2389886a867491c5db0b1a98
交付文件 common/.harness/lib/session-state-snapshot.sh
  → 208 行, sha256 d437bcccd4f6893d53e63f5d1bca4340e865862a2389886a867491c5db0b1a98
cmp -s → rc=0
```

自建 driver（注入真实语义的 `harness_validate_feature_name` stub 与可控
`_harness_session_path_core`），在 `/tmp/snapcheck` 下的一次性 session 树上执行。
report 已给出的完整 prototype-test 验证矩阵未重跑。

---

## ① 规格符合性

| 需求 | 判定 | 依据 |
|---|---|---|
| R1 source 零副作用 / 三私有 export / inert | ✅ | 独立四态验证 |
| R2 arity / feature / held capture / managed 链 / rc 表 | ✅ | 独立行为矩阵 |
| R3 verified read oracle / 损坏表 / 3-1-2 分类 | ✅ | 独立 17 例损坏表 |
| R4 create-once publish / 信号协议 / cleanup | ✅ | 独立 27 轮信号 + PID |
| R5 EEXIST 分支 / 并发 create-once | ✅ | 独立两波 8-writer 并发 |
| R6 攻击表 fail-closed / 八 anchor exact-once | ✅ | 独立 12+8 例攻击表 + grep |
| R7 默认基础测试 `tests/test-session-snapshot.sh` | ⚠️ | 不在本 diff（属任务 1.2） |

### R1 — ✅

独立四态（none / validate / path / both）验证，每态均 rc=0、双流 0 字节：

| 态 | source_rc | `declare -F` 增量 | `export -p` 增量 | `set -o` 增量 | provider marker | public API |
|---|---|---|---|---|---|---|
| none | 0 | 空 | 空 | 空 | 缺席 | 0 |
| validate | 0 | 空 | 空 | 空 | 缺席 | 0 |
| path | 0 | 空 | 空 | 空 | 缺席 | 0 |
| both | 0 | 恰好 3 个（worker / write_core / read_core） | 空 | 空 | 缺席 | 0 |

- source 时**零文件读写**：模块顶层只有两个 `declare -F` 判定，无任何 I/O。
- **不覆写依赖**：文件中不出现 `harness_validate_feature_name(){` 或
  `_harness_session_path_core(){` 的定义。
- **不设置** `HARNESS_SESSION_STATE_PROVIDER_VERSION`：grep 零命中，运行时
  `[ -v ... ]` 四态均为 no。
- **不发布 public 状态 API**：`harness_session_{path,write,read,remove}` 四者
  grep 零命中，`declare -F` 四态均为 0。
- **依赖缺席时静默 inert**：三态下 `if` 条件为假、整个 `if` 语句退出 0、
  函数面完全为空。

补充观察见次要 #7（helper 函数只在 worker 被调用时才进入 caller 命名空间）。

### R2 — ✅

**arity / op（全部独立复现，rc=2、双流 0 字节）**

| 调用 | rc | 期望 |
|---|---|---|
| `_harness_session_snapshot_worker`（0 参） | 2 | 2 ✅ |
| `_harness_session_snapshot_worker frob a b` | 2 | 2 ✅ |
| `_harness_session_snapshot_write_core p s`（缺 feature） | 2 | 2 ✅ |
| `_harness_session_snapshot_write_core p s f extra` | 2 | 2 ✅ |
| `_harness_session_snapshot_read_core p s extra` | 2 | 2 ✅ |

L188 `[[ ($# == 3 && $1 == read) || ($# == 4 && $1 == write) ]] || return 2`
是**exact** arity（不是 `-ge`），先于任何状态动作。

**feature 校验（R2「同等规则」）** — L190 调用**真正的**
`harness_validate_feature_name`（不是重实现），`>/dev/null 2>&1` 抑制其双流后
映射 2。独立验证 `.bad` / `a/b` / 空串均 rc=2、双流空。单一真值源，无漂移风险。

**held capture** — L191–L198：`umask 077` → `mktemp`（O_EXCL、0600）→
`exec {path_fd}<>` 持有读写 fd → `rm -f` 立即 unlink 名字 → anchor
`CAPTURE_READY`。Python 侧 `path_from_fd`（L151–157）以
`verify(info, "file", geteuid(), 0o600, 0)` 断言 **regular / 当前 EUID / 0600 /
nlink==0**——nlink==0 正是「名字已消失」的密码学等价证明，重建原名无法改变
该 fd 消费的 bytes。全程**无 pathname reopen**：Python 只对 `int(path_fd)` 做
fstat / lseek / read。

**exec 继承同一 fd 与 PID** — 独立验证：background `_harness_session_snapshot_worker`
后轮询 `ps -o comm=`，同一 PID `191764` 的 comm 由 `bash` 变为 `python3`，
随后正常 rc=0 并写出 feature。证明 `exec python3 - "$@" <<'PY'` 确实是最终
步骤、fd 跨 exec 继承、PID 不变（R4 对 03c 的前置条件）。

**有界解析** — L155–156 读 4097 字节，`len==4097` / `count(b"\n")!=1` /
不以 LF 结尾 → Unsafe。即 exact 一个结尾 LF、上限 4096 字节。

**path core 只写该 fd** — L199 `2>/dev/null 1>&"$path_fd"`，stderr 丢弃，
stdout 定向到 capture fd。

**physical parent 语义与逐层验证** — `open_session`（L54–66）
`path.rsplit(os.sep, 3)` 要求 4 段、`parts[1]`（root）非空、`parts[2:]` 逐字
等于 `[project, session]`，否则 Unsafe。独立验证后缀不匹配（project 或
session 任一不符）→ rc=2。随后 `open_dir` 对 root/project/session 各执行
**nofollow name-stat 预检 → verify(dir, EUID, 0700) → anchor → open(O_NOFOLLOW|
O_DIRECTORY|O_CLOEXEC) → fstat → after-stat → 两次 verify → 三向 ident 比较**。
最后只用 session fd 操作固定 leaf `feature`（`os.stat("feature", dir_fd=...)`、
`os.open("feature", ..., dir_fd=...)`），从不拼路径。

**rc 表（独立复现，全部双流 0 字节）**

| 场景 | rc | 期望 |
|---|---|---|
| root/project/session 任一为 symlink | 2 | 2 ✅ |
| root/project/session 任一为 regular file | 2 | 2 ✅ |
| root/project/session 任一 mode 0755 | 2 | 2 ✅ |
| root/project/session 任一（已认证后）缺席 | 1 | 1 ✅ |
| suffix 不匹配（project / session） | 2 | 2 ✅ |
| path core rc=1 | 1 | 透传 ✅ |
| path core rc=2 | 2 | 透传 ✅ |

symlink 之所以是 2 而不是 1：`os.stat(follow_symlinks=False)` 成功返回
symlink 自身 mode，`verify` 的 `S_ISDIR` 为假 → Unsafe。open 期 ELOOP/ENOTDIR
也显式映射 Unsafe（L46）。真实 I/O 与已认证对象消失 → Failed → 1。分类正确。

L201 `((rc == 0)) || return "$rc"` 逐字透传 path core 的 1/2，不折叠。

### R3 — ✅

**non-creating 承诺**：read 路径的 Python 侧对 leaf 只做 `os.stat` /
`os.open(O_RDONLY|O_NOFOLLOW|O_CLOEXEC)`，**没有任何 O_CREAT**；managed 目录
的创建完全由 path core 承担。独立验证 leaf 缺席时 rc=3 且 session 目录
inventory 为 0（既不建 leaf 也不建 temp）。

**先归类后 open**：L80–85 name-stat（nofollow）→ `verify(before, "file",
snapshot_euid(), 0o600, 1)`，属性错**立即 Unsafe，不进入 open**。
FileNotFoundError → Missing(3)，其他 OSError → Failed(1)。

**open 后三重校验**：L89–99 open → fstat → after-stat → 对 current/after 各
verify 一次 → `ident(before)/ident(current)/ident(after)` 三向一致。

**有界循环读取**：`read_bytes`（L69–77）`while total < 130`，`os.read(fd,
130-total)`，`if not chunk: break` —— 容忍合法 short read；`total == 130` →
Unsafe（129-byte feature + LF = 130 被拒）。

**精确语法**：`VALID = re.compile(br"[A-Za-z0-9][A-Za-z0-9._-]{0,127}\n\Z")`
配 `fullmatch`，接受 2..129 字节。独立复现的固定损坏表（read 与 write 各一遍，
全部 rc=2、双流 0 字节、victim 不变）：

| 内容 | read rc | write rc |
|---|---|---|
| 空文件 | 2 ✅ | 2 ✅ |
| 129-byte feature + LF | 2 ✅ | — |
| 非 ASCII（`caf\xc3\xa9\n`） | 2 ✅ | — |
| 无 LF（`alpha`） | 2 ✅ | 2 ✅ |
| 多 LF（`alpha\n\n`） | 2 ✅ | 2 ✅ |
| 合法 LF 后额外字节（`alpha\nx`） | 2 ✅ | 2 ✅ |
| `.bad\n` | 2 ✅ | 2 ✅ |
| `a b\n` | 2 ✅ | 2 ✅ |
| `a/b\n` | 2 ✅ | 2 ✅ |
| **128-byte feature + LF（边界合法）** | **0 ✅** | — |

边界正例 128+LF → rc=0、stdout 129 字节，确认 129/130 边界不是 off-by-one。

**成功 stdout**：`od -c` 确认为 `a l p h a \n` 共 6 字节——feature + 唯一 LF，
无多余字节。

**失败双流空 + victim 不变**：全部 17 例 stderr 0 字节、stdout 0 字节，
`ls -ld` 确认 victim（symlink target / hardlink / dir / wrong-mode 文件）
属性与内容未被触碰。

### R4 — ✅

**owned temp 创建**：L121–126，名字 `.snapshot-` + `secrets.token_hex(16)`
（32 hex，密码学不可猜测），`O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC`
+ 0600，随后 `verify(os.fstat(temp_fd), "file", geteuid(), 0o600, 1)`
—— fstat 证明 owned。

**循环写入**：L128 `while data: data = data[os.write(temp_fd, data):]`，
真正处理 short write。

**close 前转移并清空 ownership**：L129–130
`owned_fd, temp_fd = temp_fd, None` 再 `os.close(owned_fd)`。若信号在 close
期间到达，`finally` 看到 `temp_fd is None` 不会二次 close，而 `temp` 仍非 None
所以名字仍被 unlink。R4 该条精确落实。

**publish 只用 renameat2(RENAME_NOREPLACE)**：全文
`grep -n 'os\.rename(|os\.replace(|os\.link(|shutil\.|renameat'` **只命中一处**：
L110 `ctypes.CDLL(None, use_errno=True).renameat2`。L113
`call(dir_fd, temp.encode(), dir_fd, b"feature", 1)`，flags=1=RENAME_NOREPLACE。
**无 replace-rename、无 link publish、无「先删 winner」路径。**

**不降级的 OS 错分支**：
- 缺 symbol → `AttributeError` → `raise Failed`（L111–112）→ 顶层 rc=1。
- `ENOSYS` 及其他非 EEXIST errno → L136 `if result != errno.EEXIST: raise Failed`
  → rc=1。**没有任何 fallback**；`raise Failed` 位于 try 内，`finally`
  照常清 owned temp。
- 成功 → L133–135 `temp = None; return 0`，双流空。

**信号协议（L170–184，逐条核对 + 27 轮独立复现）**

| R4 条款 | 实现 | 判定 |
|---|---|---|
| 任何 `.snapshot-*` 前安装 HUP/INT/TERM | L177–179 在 `dispatch(...)` 之前 | ✅ |
| first_signal 原子锁存 | L172–173 check-then-set（见次要 #4） | ✅（有窄窗，见下） |
| 重入 handler 只返回 | L172 `if first_signal[0] is not None: return` | ✅ |
| 三信号随后设 ignore | L174 `for item in SIGNALS: signal.signal(item, SIG_IGN)` | ✅ |
| close 前转移并清空 fd ownership | L129 | ✅ |
| cleanup 收集 close 错误并继续 close 全部 fd | `close_all` L12–18，`error = error or exc` 后**不 break** | ✅ |
| 嵌套 finally 仍尝试 unlink | L143–150 双层 finally | ✅ |
| 已锁存信号优先于 cleanup 错误 | L17 `if first_signal[0] is not None: raise Interrupted` 先于 L18 `raise error`；L150 signal 已锁存时吞掉 unlink 错误 | ✅ |

独立复现（25 轮 TERM + HUP + INT，每轮全新 session 树）：

```
13 × rc=0   temps=0  feature=omega   (信号在 publish 提交后到达/未命中)
12 × rc=143 temps=0  feature=-none-  (rename 未提交：清 temp 且无 winner)
HUP → rc=129 temps=0 feature=-none-
INT → rc=130 temps=0 feature=omega   (rename 已提交：winner 继续存在)
```

全部 27 轮 **stdout / stderr 均 0 字节，owned-temp 残留恒为 0**。
`INT → rc=130 且 feature=omega` 正是 R4 要求的 post-commit 窗口：rename 已提交后
信号到达，`finally` 对旧 temp 名 unlink 得到 ENOENT（L150 `isinstance(exc,
FileNotFoundError)` 显式吞掉），**winner 未被回滚**，仍返回首信号码。
`rc=143 且 feature=-none-` 是 pre-commit 窗口。两个窗口都被实证覆盖。

**read 无信号契约**：L177 `if sys.argv[1] == "write"` 才安装 handler；独立
验证 read + TERM → rc=143（Python 默认行为），符合「read worker 不承诺信号码
或 first-signal latch」。

**spawn-only 普通函数链 + 最终直接 exec**：`_harness_snapshot_dispatch` →
`_harness_snapshot_exec` → `exec python3`，中间无 `&`、无子 shell、无 wait。
PID 稳定性已实证。两个 `_core` 用 `( ... )` 隔离 subshell 调用 worker
（L206–207）。

### R5 — ✅

**EEXIST 分支顺序**：L137 `os.unlink(temp, dir_fd=dir_fd); temp = None`
**先于** L139 `read_snapshot(dir_fd)`。owned temp 在进入 winner 首次 name-stat
之前已被移除——03b1 可在 `SNAPSHOT_BEFORE_OPEN` anchor 处直接证明 session 中
无该 temp。

**复用 R3 同一完整 oracle**：EEXIST 后走的是同一个 `read_snapshot`，
不是简化副本。same → 0、different → 3、Unsafe → 2（透传）、
消失 → **L140–141 `except Missing as exc: raise Failed from exc`**。
这条正是 R5 的「不得让最外层 Missing 把消失误映射成 3」：EEXIST 内层的 Missing
被显式改写为 Failed(1)，因此顶层 `except Missing: SystemExit(3)`（L182）只可能
来自 read 路径的 leaf 缺席。**该陷阱已被正确规避。**

**并发（独立复现，两波各 8 writer）**

```
波 1（异值 v1..v8，leaf 初始缺席）: rc 直方图 = 1×0, 7×3
  winner = v7（属于请求集），temps = 0
波 2（同值 ×8，值 = 当前 winner）: rc 直方图 = 8×0
  winner 完整指纹（dev ino uid mode nlink size + sha256）与波 1 后逐字相同
  temps = 0，session inventory 仅 {feature}
```

「异值恰一 0 其余 3」「同值全 0」「winner 属于请求集」「loser/幂等不改
winner dev/inode/uid/mode/nlink/size/hash」「无 temp 残留」全部实证成立。

**publish marker 可供 03b1 四分支注入**：`publish_errno`（L107–114）的**第一行**
即 `pass  # HARNESS_TEST_MARKER_PUBLISH_RESULT`，03b1 只需在 provider copy 中
把该行替换为 `return <errno>` 即可确定性进入 success / 缺 symbol / ENOSYS /
EEXIST 四分支。结构可行。

### R6 — ✅

**攻击表 fail-closed（独立复现，全部双流 0 字节、攻击对象不变）**

| 攻击对象 | read | write |
|---|---|---|
| snapshot = symlink（指向外部合法内容） | 2 ✅ | 2 ✅ |
| snapshot = hard link（nlink=2, 0600, 内容合法） | 2 ✅ | 2 ✅ |
| snapshot = directory | 2 ✅ | 2 ✅ |
| snapshot = wrong-mode 0644 | 2 ✅ | 2 ✅ |
| managed 三层 × {symlink, file, wrong-mode} | 2 ✅ | — |
| managed 三层 × 已认证后消失 | 1 ✅ | — |
| 九类内容损坏 | 2 ✅ | 2 ✅ |

`ls -ld` 逐例确认 symlink target、hardlink 兄弟、目录、wrong-mode 文件均
未被跟随、未被修改、未被删除。不安全层未产生任何 temp。

**stat→open 替换**：三处 ident 三向比较（`open_dir` L50、`read_snapshot` L99）
覆盖，动态 swap 反证留给 03b1（符合范围划分）。

**八 anchor exact-once 且无副作用**（我独立 `grep -c` 逐一确认，并列举全文
所有 `HARNESS_TEST_MARKER_*` 出现，总计 8 个不同 token 各 1 次，无第九个）：

| anchor | 行 | 形态 | 副作用 |
|---|---|---|---|
| `CAPTURE_READY` | 198 | `: # ...` | 无 |
| `SNAPSHOT_MANAGED_BEFORE_OPEN` | 29 | `pass  # ...` | 无 |
| `MANAGED_EXPECTED_EUID` | 20 | `return os.geteuid()  # ...` | 纯函数 |
| `SNAPSHOT_EXPECTED_EUID` | 22 | `return os.geteuid()  # ...` | 纯函数 |
| `SNAPSHOT_BEFORE_OPEN` | 68 | `pass  # ...` | 无 |
| `TEMP_BEFORE_PUBLISH` | 106 | `pass  # ...` | 无 |
| `PUBLISH_RESULT` | 108 | `pass  # ...` | 无 |
| `OS_ERROR` | 159 | `pass  # ...` | 无 |

八者**均非 capability marker**（不是 `HARNESS_SESSION_STATE_PROVIDER_VERSION`
或任何 export）。

**不读测试环境变量**：`grep -n 'os\.environ|getenv'` 零命中。Bash 侧全文
仅引用 `${TMPDIR` 一个环境变量（L192）——标准 POSIX 变量，非测试变量。✅

### R7 — ⚠️ 无法从本 diff 判断

`tests/test-session-snapshot.sh` **不在本 diff 中**（BASE..HEAD name-only 仅
`common/.harness/lib/session-state-snapshot.sh`），该交付物属任务 1.2。

实现者步骤 3 用 prototype test blob（192 行）以绝对 `SNAPSHOT_CORE` 指向本
runtime，得 rc0 + 逐字 `RESULT PASS  session snapshot safety\n` + stderr 0B，
这是对 runtime 的**间接**证据，但不构成 R7 交付物的验收。见次要 #9。

---

## ② 质量

### YAGNI — 无

BASE..HEAD name-only 恰好 1 个文件、numstat `208 0`，逐字节等于 mandated blob。
没有多做任何一行：没有顺手创建 test、没有改上游、没有加辅助脚本、
没有提前实现 03b1/03c/03d 的任何内容（无 remove、无 prune、无
`PRUNE_BEFORE_IDENTITY`、无 facade、无 provider marker、无 public API）。
四个上游文件（foundation / path / 03a1-driver / 03a2-entrypoint）blob SHA
在 BASE 与 HEAD **逐一相同**（我用 `git rev-parse <sha>:<path>` 独立比对）。

### 验证是否真的在验 — 是（但见次要 #9）

- **红阶段是真红**：`evidence/task-1.1-red.txt` 七行 schema 完整，
  `stdout_sha256=e3b0c442...`（我确认这是空串的 sha256，非伪造），
  `stderr_sha256=4caeb5b2...` —— 我用
  `printf 'bash: line 1: ...: No such file or directory\n' | sha256sum`
  **独立重算得到完全相同的值**。红阶段记录的是真实缺席失败，不是空断言。
- **evidence package 完整可核**：`task-1.1-evidence.tsv` 四行的 sha256 与
  bytes 我逐一重算，**四行全部 hash OK / size OK**，无漂移。
- **固定工具版本我独立重跑**：`shfmt v3.14.0`、`shellcheck version: 0.11.0`
  逐字符合；`shfmt -d -i 2 -ci -bn` rc=0 无 diff、`shellcheck -x
  --severity=warning` rc=0 无诊断、`bash -n` rc=0、`git diff --check` rc=0。
- **无恒真断言**：report 中的每条结论我都能独立复现；未发现「只跑不验」
  （每个命令都配了 rc 或逐字比较）或恒真断言。
- **边界正例存在**：我额外验证 128-byte feature（合法上界）→ rc=0，
  排除「全部拒绝」式的假通过。
- **report 表格自洽**：source 四态表中 `both` 行的「exports 增量=无变化」
  与「3 export 存在=是」并非矛盾——前者指 `export -p`，后者指
  `declare -F` 函数面；我独立复核两者，与 report 一致。

### 逻辑块逐字复制

- 整个文件是 prototype blob 的逐字复制，但这**正是本任务的强制口径**，
  不算缺陷。
- 文件内部：`managed_euid()` / `snapshot_euid()` 函数体完全相同
  （`return os.geteuid()`）——刻意为之，为 03b1 提供两个可独立注入的
  exact-once anchor，属正当设计。
- `open_dir`（L30–53）与 `read_snapshot`（L78–104）共享
  「name-stat → verify → anchor → open → fstat → after-stat → verify ×2 →
  ident 三向」的同构骨架。因 dir 与 file 的 verify 参数、错误映射
  （Failed vs Missing）、后续动作（返回 fd vs 读内容）均不同，未抽公共
  helper 是可接受的；且 `verify` / `ident` / `close_all` 三个真正的公共
  判据**已经**被抽出并共用。read 与 EEXIST-winner 确实共用同一个
  `read_snapshot`，没有第二份实现（R5 的关键要求）。

### 错误路径处理 — 基本完整，三处瑕疵

绝大多数错误路径都被显式分类并映射（见 R2/R3/R4 表）。发现的瑕疵见
重要 #1 与次要 #2、#3。特别值得肯定的是两处容易漏掉的边界都写对了：
L140–141 的 Missing→Failed 改写，以及 L150 signal-latched 时吞掉 unlink 错误。

---

## findings

### 阻断（0）

无。

### 重要（1）

**[重要][R2, R4] `mktemp` / `exec` / `rm` 失败路径泄漏 stderr，违反无条件的「双流空」约定**

- 位置：`common/.harness/lib/session-state-snapshot.sh` L192–L197
- R2 要求「所有 write 结果及 read 失败结果双流空」，R4 要求非 EEXIST 分支
  「双流空/1」。这是**无条件**约定，未按错误场景豁免。
- L192 `path_file=$(mktemp "${TMPDIR:-/tmp}/snapshot-path.XXXXXXXX") || return 1`
  **没有 `2>/dev/null`**。L193 的 `exec {path_fd}<>"$path_file"` 与 L197 的
  `rm -f -- "$path_file"` 同样无抑制。
- **实证复现**：

  ```
  TMPDIR=/nonexistent-dir-xyz _harness_session_snapshot_write_core proj sess alpha
    → rc=1, stdout 0 bytes, stderr 120 bytes:
      mktemp: failed to create file via template
      '/nonexistent-dir-xyz/snapshot-path.XXXXXXXX': No such file or directory
  ```

- 可达性：TMPDIR 指向不存在/不可写目录、`/tmp` 写满或只读挂载。TMPDIR 由
  调用方控制，在 harness 场景中并不罕见。
- 影响评估：**不破坏安全性**——rc=1 正确、fail-closed 成立、无状态写入、
  无 create-once 违规。影响面是（a）R2 字面约定被违反；（b）R7/03b1 的
  逐字节流比较 oracle 在异常 TMPDIR 下会产生假阴性。
- **路由说明**：该缺陷位于 prototype blob `a708ce6f…:snapshot-core-r2.sh` 自身。
  本任务裁定口径为「机械落地，必须与 blob 逐字相同」，实现者**无权**修改，
  因此这不是实现者的执行错误。修复需由控制器在
  prototype/spec 层解决（产出新 `PROTO_SHA` 并重跑任务 1.1），
  或对 R2 的「双流空」出具显式豁免并记入 ledger。
- 最小修复（若走 blob 修订路线）：L192/L193/L197 各追加 `2>/dev/null`，
  合计 3 处、不增行数、不影响 208 行门与 numstat≤400。

### 次要（8）

**[次要][R2] `open_dir` 在 open 后 verify 失败时泄漏 dirfd**

L48–49 `verify(current, ...)` / `verify(after, ...)` 抛 Unsafe 时，L41 刚打开的
`fd` 既未被 `os.close`，也未被 append 进 `open_session` 的 `fds` 列表，
因此 L65 的 `close_all(reversed(fds))` 无法关闭它。对比 L50–52（ident 不符时
显式 `os.close(fd)`）与 `read_snapshot` L96–102（try/finally 正确处理），
这是本文件中唯一未贯彻 transfer/close 纪律的位置。实际影响为零（进程随即
退出，内核回收），但属未处理的错误路径资源泄漏。

**[次要][R3] `dispatch` 先 print 后 close，close 失败会让失败 rc 携带非空 stdout**

L167 `print(read_snapshot(session_fd)); return 0` 位于 try 内，L169
`finally: close_all(...)` 之后才执行。若 `close_all` 抛出，进程以 1/2 退出，
但 feature+LF 已进入 stdout 缓冲并在解释器退出时 flush ——
违反 R3「所有失败双流空」。实践中不可达（关闭有效 dirfd 几乎不会失败），
纯分析发现，未实证复现。

**[次要][R4] first_signal 锁存在 Python 层是 check-then-set，非严格原子**

L172–173：

```python
if first_signal[0] is not None: return
first_signal[0] = number
```

两条语句之间存在字节码边界。若第二个信号恰在该间隙到达，CPython 会嵌套
执行 handler，嵌套帧锁存的是**第二个**信号号、装 ignore 并抛 Interrupted，
外层的 `first_signal[0] = number` 永不执行 —— 最终返回的是第二信号码。
R4 措辞为「首个 handler 入口必须先原子锁存 first_signal」。CPython 在纯
Python 层无更强原语，窗口仅两条字节码；design 的叙述也只覆盖了锁存**之后**的
第二信号（「second signal during ignore installation returns only」，该部分
实现正确）。建议 03b1 在 assurance 说明中显式承认此窄窗，而非改代码。

**[次要][R4, R6] temp 与 capture 的 EUID 检查绕过了 anchor 函数**

L126 `verify(os.fstat(temp_fd), "file", os.geteuid(), 0o600, 1)` 与 L153
`verify(info, "file", os.geteuid(), 0o600, 0)` 直接调用 `os.geteuid()`，
未走 `snapshot_euid()` / `managed_euid()` anchor。语义上说得通（temp 和
capture 都是本进程刚创建的对象，非攻击者可控），但意味着 03b1 用
provider-copy 注入 wrong-expected-EUID 时**触及不到这两个调用点**。
请 03b1 的 sizing 不要假设这两处可被 anchor 覆盖。

**[次要][R4] `RENAME_NOREPLACE` 以裸字面量 `1` 传入，且 ctypes 无 argtypes/restype**

L113 `call(dir_fd, temp.encode(), dir_fd, b"feature", 1)`，`1` 无命名常量也无
注释；L110 的 `renameat2` 句柄未声明 `argtypes` / `restype`。在 Linux/x86_64 上
两者都正确（我已实证 publish 与 EEXIST 双分支均按预期工作），但「publish 只用
RENAME_NOREPLACE」这条审计要靠 reviewer 记得该常量值为 1，可读性偏弱。

**[次要][R1] 直接调用 worker 会向 caller 泄漏两个 helper 函数并改写 caller 的 umask**

`_harness_snapshot_exec` / `_harness_snapshot_dispatch` 是 `_harness_session_snapshot_worker`
体内的嵌套定义，`umask 077` 在 L191。实证：

```
umask before=0022 → 直接调 _harness_session_snapshot_worker（rc=1 早返回）
  → umask after=0077，caller 多出 _harness_snapshot_dispatch / _harness_snapshot_exec
```

R1 只约束 **source 时**的表面（我已验证 source 后恰为 3 个函数、umask 不变），
故 R1 判定不受影响；两个 `_core` 用 `( ... )` subshell 也把泄漏隔离在子 shell 内。
仅当调用方违反「spawn-only」约定时才会显现，而模块本身不强制该约定。
提请 03c 务必保持 background/spawn 调用形态。

**[次要][R4] `sys.argv[1]` 无越界保护**

L177 `if sys.argv[1] == "write"` 在 try 之外的语义上位于 `try:` 内但
`IndexError` 不在 L181–184 任何 except 子句中，会以 traceback 打到 stderr。
Bash 侧的 exact arity 门（L188）保证了始终传 5 个参数，因此正常路径不可达；
仅在有人直接调用内嵌 Python 时出现。属防御性缺口，非实际缺陷。

**[次要][流程] `review-manifest.tsv` 尚未创建**

任务 1.1 的「验收资产」列出「创建 review-manifest.tsv」，但该文件在 `$WORK`
下**物理缺席**。report 明确声明步骤 6/7 留给控制器，与 brief 步骤 7 的措辞
（`printf ... >>"$MANIFEST"` 由控制器执行）一致，故非实现者遗漏。
提醒控制器：在 mark 任务 1.1 完成之前必须补齐第 1 行
（`1<TAB>task-1.1<TAB>$TASK_BASE<TAB>$TASK_HEAD<TAB>$REVIEWER<TAB>PASS`），
否则任务 2.6 的 8 行 awk 收敛核验会失败。

**[次要][验证] 步骤 3 的绿色 oracle 与被测 runtime 同源**

步骤 3 用 prototype 的 `snapshot-test-prototype.sh`（192 行）验证 prototype 的
`snapshot-core-r2.sh`（208 行）—— 两者出自同一 prototype commit，构成自证。
本次审查已通过自建独立 driver 复现了 R2–R6 的完整行为面（arity 5 例、
feature 3 例、managed 12 例、suffix 2 例、rc 透传 2 例、snapshot 对象 8 例、
内容 17 例、并发 16 writer、PID 1 例、信号 27 轮），结论一致，风险已缓解。
建议控制器在 ledger 中不要把步骤 3 单独记为独立功能证据。

---

## 附：本次审查执行的只读命令清单

```
git -C <wt> log --oneline -3 / rev-parse --abbrev-ref HEAD / status --porcelain
git -C <wt> diff --name-only|--numstat|--check BASE HEAD
git -C <wt> show a708ce6f...:.../prototype/snapshot-core-r2.sh   (→ /tmp)
wc -l / sha256sum / cmp -s   (blob vs 交付文件)
git -C <wt> rev-parse BASE:<f> 与 HEAD:<f>  ×4 上游文件
grep -c / grep -o / grep -n   (八 anchor、fallback 原语、provider marker、public API、env 读取)
shfmt --version / shfmt -d -i 2 -ci -bn
shellcheck --version / shellcheck -x --severity=warning
bash -n
sha256sum / stat -c%s   (evidence TSV 四行重算)
printf ... | sha256sum   (red.txt stderr_sha256 重算)
自建 driver 行为矩阵（全部在 /tmp/snapcheck，未触及 worktree 与 repo）
```

worktree 未被修改、未提交、未新建分支；所有临时文件位于 `/tmp`。
