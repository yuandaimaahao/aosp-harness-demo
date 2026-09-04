verdict: PASS
阻断: 0 / 重要: 0 / 次要: 1

# 任务 1.3 独立审查报告

审查对象：`review-a8d03d1d-5b2e66b3.md`（`5b2e66b3` 新增 `tests/test-claude-session-lifecycle.sh`，176 insertions，单文件）
方法：全程只读；候选取自 `git show 5b2e66b:tests/test-claude-session-lifecycle.sh`；在 worktree 内直接实跑候选与三 hook/`run-demo.sh`/`settings.json`（均为任务 1.1/1.2 已提交内容，只读消费），未修改 worktree 任何文件、未移动 HEAD；结束前 `git status --porcelain` 确认干净。所有下方结论均为本次亲自复跑得到的一手证据，非单纯代码推断。

---

## 一、规格符合性（R1–R8）

### R1（guard 三合取）— 通过
三个 hook（`load-feature.sh`/`check-branch-drift.sh`/`session-end.sh`）guard 逐一读取确认：均为 `source aggregator 2>/dev/null && marker精确1 && declare -F 五名` 三元合取，`source` 失败天然覆盖 aggregator 缺席，无需单独 `-f` 检查，与设计一致。
复现：
```
$ rg -oF '"${HARNESS_SESSION_STATE_PROVIDER_VERSION:-}" == 1' <hook>.sh | wc -l   # 各=1
$ rg -oF 'declare -F harness_validate_feature_name harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove' <hook>.sh | wc -l  # 各=1
```
三 hook 结果均为 `marker=1 api=1`。

### R2（partial→legacy+marker 恰一次）— 通过
- `dependency_present()` 用隔离 `bash -c` 子 shell source 真实 aggregator 后核 marker+五 API，不污染父 shell 状态。
- `session-state.sh` aggregator 自身是 fail-closed 设计（五模块文件存在性 + source rc0 + 九个内部符号 `declare -F` 全部合取，任一环节失败整体 `return 1`/`exit 1`，不会出现"部分模块生效"的中间态）——已读源码确认（`common/.harness/lib/session-state.sh`），故 missing-foundation/path/snapshot/signals/remove 五类 fixture 各自都会使**整个** aggregator source 失败，从而让三个 hook 的 guard 同时失败，不存在 partial capability。
- 实跑七类 fixture 的 CLI 单跑模式（`--session-provider-fixture <值>`）逐个复现：
```
missing-foundation: rc=0 out=[RESULT PASS  claude session lifecycle] errbytes=0
missing-path:       rc=0 out=[RESULT PASS  claude session lifecycle] errbytes=0
missing-snapshot:   rc=0 out=[RESULT PASS  claude session lifecycle] errbytes=0
missing-signals:    rc=0 out=[RESULT PASS  claude session lifecycle] errbytes=0
missing-remove:     rc=0 out=[RESULT PASS  claude session lifecycle] errbytes=0
absent:             rc=0 out=[RESULT PASS  claude session lifecycle] errbytes=0
```
- compat marker 字面量三 hook 各恰一次（`rg -oF 'compat: session-provider=legacy' <hook>.sh` 均=1），且 legacy 分支（guard 失败/stdin 非法/provider 设计外错误码）都以 rc0 结束——已在完整矩阵 137 checks 与 absent surface 12 checks 中被行为断言覆盖（见下）。

### R3（SessionStart 按 source 分级；rc3 异值冲突用 shim aggregator）— 通过，且验证候选未使用 awk 抽函数体的禁止手法
- 候选对"read 谎报缺席（rc3）导致 write 撞见真实异值冲突"的构造方式为：`cp` 真实 `session-state.sh` 备份 → 向**同一份被 hook 实际 source 的树内文件**追加一行 `harness_session_state_read() { return 3; }` → 触发 hook → 用备份文件立即还原。这是"source 真 provider 后只覆写 read"的 shim aggregator 手法，不是 awk 抽函数体：`declare -F` 五名检查在覆写后依然全部为真（原始五个函数定义仍在文件中，只是 `read` 被随后定义的同名函数覆盖），guard 判定不受影响，走的是 hook 的真实 v1 分支与真实 `write()` 实现。已读 `load-feature.sh` 源码确认 rc3 分支表：
  - `read` rc3 且 `src != compact` → 调用 `write`；`write` rc3 → 打印 `已存在且值不同`、不改写、函数返回 0（v1 内部处理，**不**触发 legacy）。
  - 用回归测试验证该 oracle 非摆设：临时删除该 stderr 报错行（模拟"漏打日志"回归），重跑候选：`RESULT FAIL claude session lifecycle checks=137 failures=1`（对应新增断言精确检出），随后立即用备份还原、`git status --porcelain` 确认无残留。
- startup/fork/clear/resume 四 source 建基线循环、compact 缺失报错不创建、已在场任意 source 不改写、同值幂等：均在完整矩阵实跑中以 `checks=137 failures=0` 验证通过（见二.1）。

### R4（UPS 漂移 exit 2）— 通过
读 `check-branch-drift.sh` 确认 `v1_drift()` 内 `exit 2`/`exit 0`/`return 1` 三路径均为直接 `exit`（非子 shell），与设计"函数体内 exit 直接终止整个 hook 进程"一致；无漂移/漂移/基线缺席/非法 session_id 四态在完整矩阵中逐一断言 rc 与 marker 计数，137 checks 全过。

### R5（SessionEnd 校验后清理）— 通过
读 `session-end.sh` 确认："先解析+校验（含事件名/session_id 正则/reason 五值），非法一律 `compat_legacy` + rc0 + 零删除" → "校验通过 + v1 → remove 幂等清理，rc≠0（设计外错误码）只 marker，不回退删 legacy 快照" → "校验通过 + legacy → marker + `rm -f` 全局快照"，三段严格顺序隔离、互不跨越。矩阵内"provider 设计外错误码注入"（`HARNESS_STATE_ROOT=/`）、"事件名/session_id/reason 非法零删除"均被覆盖并通过。

### R6（legacy 逐字/v1 不写全局快照）— 通过
- `load-feature.sh`：仅 legacy 分支（`v1_baseline` 失败后的 `else`）执行 `printf '%s' "$feature" >snapshot`；v1 成功路径不触碰该文件。
- `check-branch-drift.sh`：`v1_drift` 三个出口全部 `exit`，只有 `return 1`（partial/非法）才会跌落到 `compat_legacy` 之后读取全局快照的 legacy 尾段。
- 独立实跑验证：默认矩阵中 `check_eq 'start link + project-id + no legacy write' ...` 断言 v1 后快照 absent，且被完整矩阵 0 failures 证实为真（非静态推断）。

### R7（demo 收敛）— 通过（独立实跑）
```
$ rg -oF "trap 'rm -rf -- \"\$DEMO_TMP_DIR\"' EXIT" run-demo.sh | wc -l   # 1
$ rg -oF 'trap ' run-demo.sh | wc -l                                      # 1（全文件唯一一处 trap）
$ before=$(sha256sum CURRENT_FEATURE); TMPDIR=$tmpd bash run-demo.sh; after=$(sha256sum CURRENT_FEATURE)
rc=0；CURRENT_FEATURE unchanged；snapshot absent（good）；claude-harness-demo.* 残留目录=0
```
demo 全部 hook 演示在 `$DEMO_TMP_DIR/tree` 私有树内进行，真实 `CURRENT_FEATURE` 全程只读，`UserPromptSubmit` 受控失败（exit 2）由 demo 自身 `set +e` 捕获并断言。

### R8（CLI/fixture/摘要 printf 恰 2 处/依赖探测）— 通过
```
$ wc -l tests/test-claude-session-lifecycle.sh                                                        # 176
$ rg -cF "printf 'RESULT PASS  claude session lifecycle\n'" tests/test-claude-session-lifecycle.sh    # 2
```
CLI 非法表五行与六个合法 fixture 值逐一独立复现（见下方"红阶段判定"前的实跑记录），行为与 report 声称完全一致。

---

## 二、质量

### 1. 176/176（预算顶格）；七类 fixture；legacy/absent checks=12；present checks=137 — 全部独立复现
```
$ wc -l tests/test-claude-session-lifecycle.sh   → 176（design/brief 预算上限 176，余量归零，report 口径属实）
```
用 python3 rindex/index 在摘要 printf 前插桩计数探针（复现 report 步骤 4/5 手法，双流路径与主跑互不复用）：
```
dependency-present 完整矩阵：checks=137，rc=0
--dependency-absent legacy surface：checks=12，rc=0
```
两者均与 report 声称的 N 值逐字一致。七类 fixture（完整 provider、absent、missing-foundation/path/snapshot/signals/remove）通过 `--session-provider-fixture` 六值单跑与主矩阵内表驱动循环两条路径均验证 rc0/固定摘要/marker 行为正确（见"一"节 R2）。

静态检查（固定 shfmt v3.14.0 精确匹配 report 声称版本；本机无法安装官方 pin 的 shellcheck 0.11.0，改用可获取到的 0.9.0 做同参数二次确认，两者均 rc0，无法完全复核 0.11.0 特有规则但风险低）：
```
$ shfmt --version                                    → v3.14.0（与 report 声称版本一致）
$ shfmt -d -i 2 -ci -bn tests/test-claude-session-lifecycle.sh   → 无输出，rc0
$ shellcheck --version                               → 0.9.0（report 声称 0.11.0，本机环境限制未能精确复现该版本）
$ shellcheck -x --severity=warning tests/test-claude-session-lifecycle.sh  → rc0
$ bash -n tests/test-claude-session-lifecycle.sh     → rc0
```

### 2. stdout/stderr 按字节比较 — 通过
`run_hook()` 把 hook 双流重定向到 `$tmp/out`/`$tmp/err` 文件（不经 `$(...)` 捕获 hook 输出本身），`bytes()` 用 `wc -c` 读文件字节数，`stream_is()` 用 `printf '%b' ... | cmp -s` 做逐字节比较（6 处 `stream_is` 调用 + 1 处直接 `cmp -s`），未见用会吞尾随 LF 的 command substitution 验证成功流的模式。`check_eq` 中确有若干 `$(cat "$state/.../feature")` 之类针对**状态文件内容**（非双流）的捕获，这类值本身不含有意义的尾随换行语义，属合理用法。

### 3. 结构核对（compat 字面量、guard marker+API、settings.json 注册）— 独立复现，全部通过
```
compat 字面量: load-feature=1, check-branch-drift=1, session-end=1
guard marker+api: 三 hook 各 marker=1 api=1
settings.json SessionEnd → {"type":"command","command":"${CLAUDE_PROJECT_DIR}/.claude/hooks/session-end.sh"}，python3 json 解析核验为 True
```

### 4. exact6/numstat（对 BASE_SHA=cc04996e..HEAD=5b2e66b）— 独立复现，与 report 一致
```
$ git diff --name-only cc04996e 5b2e66b3
claude-code/features/.harness/hooks/check-branch-drift.sh
claude-code/features/.harness/hooks/load-feature.sh
claude-code/features/.harness/hooks/session-end.sh
claude-code/features/.harness/settings.json
claude-code/run-demo.sh
tests/test-claude-session-lifecycle.sh
$ git diff --numstat cc04996e 5b2e66b3 | awk '{s+=$1+$2} END{print s+0}'   → 367（≤400）
$ 上游十二文件 diff（应为空）→ 空
```

---

## 三、红阶段判定

用 `git worktree add --detach a8d03d1d` 独立复现 TASK_BASE 状态（未触碰主 worktree）：
```
$ test ! -e tests/test-claude-session-lifecycle.sh && echo absent   → file absent confirmed
$ bash tests/test-claude-session-lifecycle.sh
rc=127
stdout 0 字节；sha256 = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855（空串 sha256，与 evidence 文件逐字一致）
stderr = "bash: tests/test-claude-session-lifecycle.sh: No such file or directory"；sha256 = be64cf55a6858e6858847166cf3f2ef89c5c45506b27b64fee9545be9aaed5ee（与 evidence 文件逐字一致）
```
两个 sha256 均与 `evidence/task-1.3-red.txt` 记录逐字节匹配。红阶段判定（文件缺席、rc127、stdout 无 PASS）**属实、可复现**。

---

## 四、findings

未发现阻断级或重要级问题。

### 次要 #1：静态检查工具版本未能精确复现
Report 声称固定版本 ShellCheck `0.11.0`；本机环境（apt 源）只能获取 `0.9.0`。已用 `0.9.0` 以相同参数（`-x --severity=warning`）对候选跑通（rc0），且额外做了一次真实回归注入测试验证矩阵 oracle 有效性（见 R3 段），风险可控，不影响本次 verdict。若 controller/CI 环境已固定精确版本 0.11.0 并通过，此项可忽略；否则建议留意 0.11.0 相比 0.9.0 新增规则是否会对该文件产生新警告。

### 未发现问题项（一并记录，供留痕）
- rc3 shim aggregator 手法核实为"source 真实文件后追加同名函数覆盖，仅 `read` 被替换"，非 awk 抽函数体，符合门槛要求。
- 七类 fixture 的 legacy 触发机制核实为 aggregator 级 fail-closed（非单模块函数缺失导致的部分能力），不存在 partial capability 泄漏。
- demo 收敛、结构核对、CLI 非法表、七类 fixture legal 值、dependency-present/absent 的 checks 计数（137/12）均逐项独立实跑复现，与 report 记录完全吻合，未发现夸大或遗漏。
- 工作树在审查全程保持只读；结束前 `git status --porcelain` 为空，HEAD 仍为 `5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`，未产生任何残留改动。

---

## 结论

候选 `tests/test-claude-session-lifecycle.sh`（176 行，`5b2e66b`）在 R1–R8 全部维度下经独立实跑复现均与 report 记录一致；176 行预算顶格、present/absent checks 计数（137/12）、红阶段 rc127+双流 sha256、exact6/numstat=367、结构核对、demo 收敛均逐项复现通过；唯一次要缺口是本机无法精确复现 pin 的 ShellCheck 0.11.0（已用 0.9.0 替代验证，无异常）。

**verdict: PASS**
