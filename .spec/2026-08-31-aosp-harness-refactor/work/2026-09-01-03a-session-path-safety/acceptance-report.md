# 03a-session-path-safety 最终验收报告

## 结论

**PASS**

严重度：blocker 0 / important 0 / minor 0。

实现交付在固定范围 `d68911bde93f72d1e42dc85fba6271159e945170..f91f54d3d9832c803097bf171e9628b8d1adedab` 内通过 R1–R7 行为、固定工具、391/400、foundation 不变、四行 review manifest、完整与 depth-1 离线回归及 clean 门。Round 1 唯一 finding 已通过把 `tasks.md` task 4 文件前缀从 `验证` 改为解析器支持且语义准确的 `测试` 闭合；Round 2 独立重跑 `check-tasks.py`、`check-converge.py` 与 `git diff --check` 均 rc 0、双流空，未发现新问题。

## 固定验收点与范围

- 实现仓库：`/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03a-session-path-safety`
- BASE：`d68911bde93f72d1e42dc85fba6271159e945170`
- HEAD：`f91f54d3d9832c803097bf171e9628b8d1adedab`
- `git diff --name-status BASE HEAD`：仅 `A common/.harness/lib/session-state-path.sh` 与 `A tests/test-session-path.sh`。
- `git diff --numstat BASE HEAD`：provider `114 + 0`，test `277 + 0`，合计 `391/400`。
- foundation diff：`common/.harness/lib/session-state-foundation.sh` 与 `tests/test-session-state-foundation.sh` 的 BASE..HEAD name-only 输出为空。
- `git status --porcelain`：0 bytes；`git diff --check BASE HEAD`：rc 0、无输出。

## 主验收命令与原始结果

以下命令均在本轮、最终实现 HEAD 上重新执行；stdout 比较使用带末尾 LF 的期望文件和 `cmp`，不是 command substitution。

```text
bash ./tests/test-session-path.sh
rc=0 stdout_bytes=33 stdout_exact=0 stderr_bytes=0

bash ./tests/test-session-path.sh --case source-validate
rc=0 stdout_bytes=33 stdout_exact=0 stderr_bytes=0

bash ./tests/test-session-path.sh --case roots-static
rc=0 stdout_bytes=33 stdout_exact=0 stderr_bytes=0

bash ./tests/test-session-path.sh --dependency-absent
rc=0 stdout_bytes=33 stdout_exact=0 stderr_bytes=0

expected stdout (all four):
RESULT PASS  session path safety\n
```

保留真实 provider/test、物理删除 foundation 文件的隔离 fixture：

```text
foundation-absent-default rc=0 stdout_bytes=33 stdout_exact=0 stderr_bytes=0
foundation-absent---dependency-absent rc=0 stdout_bytes=33 stdout_exact=0 stderr_bytes=0
```

回归与边界：

```text
bash ./tests/test-session-state-foundation.sh
rc=0 stderr_bytes=0 last=RESULT PASS  session state foundation

bash ./scripts/check.sh --offline
rc=0 stderr_bytes=0 last=RESULT PASS  aosp-harness offline quality gate

bash ./tests/test-session-path.sh --case mutations
rc=1 stdout_bytes=0 stderr=FAIL option: unsupported case mutations\n
bash -n common/.harness/lib/session-state-path.sh tests/test-session-path.sh
rc=0
```

真实 depth-1 file-URL clone：

```text
clone rc=0 head=f91f54d3d9832c803097bf171e9628b8d1adedab commit_count=1 .git/shallow_bytes=41
depth1 path rc=0 stdout_bytes=33 stderr_bytes=0 last=RESULT PASS  session path safety
depth1 offline rc=0 stderr_bytes=0 last=RESULT PASS  aosp-harness offline quality gate
```

## R1–R7 映射

### R1 — PASS

- provider 第 2–4 行用三个 `declare -F` 组成 source capability guard，第 5 行只定义 private `_harness_session_path_core`。
- test 第 183–227 行在同一隔离 shell 中比较 source 前后 rc/双流、HARNESS/XDG/TMP `declare -p`、foundation 函数体、函数名集合、marker/public surface 与文件 inventory；功能分支运行 PASS。
- provider 不含 `HARNESS_SESSION_STATE_PROVIDER_VERSION` 或四个 public state API；source fixture 逐名断言它们缺席（test 第 214–225 行）。

### R2 — PASS

- guard 任一依赖缺席时不进入函数定义（provider 第 2–5、114 行）。
- test 第 190–197、218–236 行覆盖 all-missing 与三个单依赖缺席，逐个要求 inert exact function surface。
- 显式 `--dependency-absent` 和真实 foundation 文件缺席时 default/flag 的本轮精确流测试均 rc 0、33-byte stdout、空 stderr。

### R3 — PASS

- exact arity 与按 project/session 顺序调用 public validate：provider 第 6–10 行；validate 双流被丢弃，失败统一为 unsafe/2。
- root precedence/physical parent：provider 第 18–44、90–103 行；test 第 85–130 行逐字覆盖 HARNESS/XDG/TMP/default、physical symlink parent、危险值、missing parent、高优先级生效时低优先级 inventory 不变。
- 本轮另以真实 foundation 分别调用非法 project 与非法 session：两者均 rc 2、stdout 0 bytes、stderr 精确 `error: unsafe session state\n`。test 第 246–276 行还用记录型 validate 证明 project/session 调用顺序、session 拒绝时 fake python 调用为 0、inventory 不变。
- 成功/unsafe/operation 顶层协议由 provider 第 104–111 行固定；确定性 post-mkdir disappearance 在 test 第 108–113 行逐字得到 operation/1。

### R4 — PASS（动态竞态按批准边界由 03a1 验收）

- `open_managed` 在 provider 第 48–89 行统一处理 existing、fresh、EEXIST：`stat(no-follow) -> mkdir(0700) -> name stat -> open(O_NOFOLLOW) -> fstat -> final name stat`，比较 dev/inode/type、EUID 与精确 0700；全文件无 `fchmod`。
- open 的 `ELOOP|ENOTDIR` 映射 unsafe，其余普通 OS 错映射 operation（provider 第 25–30 行）；所有已取得 fd 在错误路径或 dispatch `finally` 中关闭（第 74–88、92–103 行）。
- 2×2 fixture 创建精确 7 个安全目录并逐项验证 EUID/0700/nonlink（test 第 132–143 行）。root/project/session × link/file/wrong-mode 全矩阵逐例要求 unsafe/2、inventory 不变，link victim identity/hash 不变（第 144–173 行）。
- wrong-owner、EEXIST 和 stat→open 等 anchor-driven 动态替换由 requirements 第 25–27、45–46、60–62 行明确交给直接后继 03a1；本片没有 consumer/public capability，BASE..HEAD 也只有本片两个私有文件。

### R5 — PASS

- 三个生产 anchor occurrence 均为 1；`before_mkdir`、`after_eexist`、`before_open` 在全文件及提取的 `open_managed` 函数体中各为 1；provider 不含 `fchmod`。
- 结构 oracle 位于 test 第 70–82 行；生产调用位于 provider 第 46–47、53、63、72、80、94 行。
- `rg` 未发现 test-only marker env seam；`--case mutations` 精确拒绝，测试中不存在 anchor-driven provider-copy mutation。
- task4 最终 review 记录的 managed-body self-disproof：把 `before_mkdir` 移出 `open_managed`、保持全局计数为 1 时，测试 rc 1 并精确报 `FAIL phase before_mkdir global or managed-body count\n`。

### R6 — PASS

- 独立脚本具备 source/inert、validate fail-fast、fresh/existing、四级 root、危险根、2×2 isolation、三层静态攻击、post-mkdir operation 分类和结构 oracle；默认 dispatcher 第 40–48 行按顺序运行两个子组，以真实文件 `cmp` 保留摘要末尾 LF。
- source fixture 有主动 self-disproof（test 第 177–182、226 行），避免内层失败被掩盖；最终四个入口和真实 foundation 缺席两个入口的精确流均已在本轮通过。
- full 与 depth-1 offline 都通过，证明长期自动发现测试不再依赖 execution BASE object。

### R7 — PASS

```text
shfmt --version: v3.14.0
shfmt -d -i 2 -ci -bn <exact two files>: rc=0 stdout=0 stderr=0
ShellCheck version field: 0.11.0
shellcheck -x --severity=warning <exact two files>: rc=0 stdout=0 stderr=0
exact names: rc=0
numstat: files=2 lines=391 rc=0
foundation diff path count=0
manifest: rows=4 final_head=f91f54d3... rc=0
worktree status bytes=0
```

四行 manifest 原文：

```text
1\ttask-1\td68911bde93f72d1e42dc85fba6271159e945170\tc77766f26adf939acb3a192946bf2f80e07cda05\treview_plan_v5_2\tPASS
2\ttask-2\tc77766f26adf939acb3a192946bf2f80e07cda05\t2f2142b18243b3c5c9198b1d851aef39089a0f57\treview_plan_v5_3_1\tPASS
3\ttask-3\t2f2142b18243b3c5c9198b1d851aef39089a0f57\tbbdc50d6ba52b720a2a3fed74215b4199476fe0d\treview_plan_v5_3_1\tPASS
4\ttask-4\tbbdc50d6ba52b720a2a3fed74215b4199476fe0d\tf91f54d3d9832c803097bf171e9628b8d1adedab\treview_plan_v5_3_1\tPASS
```

## 验收清单与不变量

- exact 两文件、private core、三个唯一 anchor、固定摘要：PASS。
- source present/三种 partial missing/all-missing 与真实 foundation 文件缺席：PASS。
- arity、非法 project/session、四级 safe root、危险根与精确错误流：PASS。
- validate 顺序、拒绝、fake python=0、inventory 不变：PASS。
- 2 project × 2 session 的唯一路径、七目录 EUID/0700/nonlink：PASS。
- 三层 link/file/wrong-mode 的 victim/inode/mode/inventory 与后续创建不变量：PASS；变化数 0。
- anchor/phase/fchmod 结构与 03a1 边界：PASS。
- public API/marker absent、foundation diff、foundation/offline 回归：PASS。
- manifest、exact2/391、固定工具、clean：PASS。
- 完整与 depth-1 offline：PASS。
- Claude/Codex/common/device-safety/foundation 的 offline 回归失败数：0。

## Task 4 最终复审链

- `bbdc50d6..3fd9053d` round 1：NEEDS_CHANGES，发现 depth-1 checkout 依赖裸 BASE SHA 的 blocker 与无效 `invoke` 首参 minor。
- fix `f91f54d3`：仅修改 `tests/test-session-path.sh`，删除长期测试中的历史 SHA 查询并收紧 `invoke(project, session, env...)`；provider SHA-256 保持 `07af7800401608fd679c1244854ab1852daa2a98c459a0cff053c1b0e07c4b64`。
- `bbdc50d6..f91f54d3` 最终独立 review：PASS，blocker 0 / important 0 / minor 0；本轮复跑 depth-1 path/offline 再次确认修复有效。

## Ledger 裁定

按 closeout 规则逐字重报本 spec ledger 中唯一 `裁定:` 行：

```text
- 裁定: 回PLAN v5.5，把全部动态mutation测试归并到既有03a1，03a只保留provider/source/root/static/marker结构并要求shfmt-clean；依据task4 fix1实测397未格式化、527格式化，且03a1在03b前无consumer；如果错了代价是多一次03a文档/任务复审和03a1测试体积增加，若不做则400行/P5与CI格式门不可同时成立。
```

## SKIPPED

无。`STATE.md` 的 SKIPPED 表只有表头，没有记录；本轮没有跳过软门禁。真实设备、网络、build、Claude/Codex 客户端执行属于本 spec 明确超出范围，不记作 SKIPPED。

## Round 1 finding 与 Round 2 闭合记录

### Round 1 Important — `check-converge.py` 因 task 4 文件字段产生伪路径欠账

证据：

```text
python3 .../check-converge.py <spec-dir> d68911b... f91f54d... --repo <implementation-worktree>
missing: 欠账: 验证 common/.harness/lib/session-state-path.sh 在文件清单里但 BASE..HEAD 未改
rc=1
```

原因是 `tasks.md` task 4 的文件字段写成：

```text
文件: 修改 `tests/test-session-path.sh` / 验证 `common/.harness/lib/session-state-path.sh`
```

共享解析器只识别 `创建|修改|测试` 前缀，因而保留了 `验证 ` 并将其当作路径；真实 changed/listed 路径实际都是 `common/.harness/lib/session-state-path.sh` 与 `tests/test-session-path.sh`，不存在实现欠账或范围扩张。

Round 2 修复将字段改为：

```text
文件: 修改 `tests/test-session-path.sh` / 测试 `common/.harness/lib/session-state-path.sh`
```

Round 2 独立复跑原始结果：

```text
check-tasks rc=0 stdout_bytes=0 stderr_bytes=0
check-converge rc=0 stdout_bytes=0 stderr_bytes=0
git-diff-check rc=0 stdout_bytes=0 stderr_bytes=0
implementation_status_bytes=0
```

该修复未修改 implementation worktree，收敛检查现在把 task 4 的两个文件都映射到真实 BASE..HEAD 路径。Round 1 finding 已闭合。

## Outstanding findings

无。
