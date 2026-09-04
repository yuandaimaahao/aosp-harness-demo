# 03e claude-session-lifecycle 验收报告（门⑤）

- spec: 2026-09-03-03e-claude-session-lifecycle
- 终交付锚点: `claude-session-lifecycle-v1`
- execution BASE: `cc04996e1e405c00e16be3b57d3ef62d90cd7fd1`
- accepted HEAD: `5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`
- 本报告判据均在 2026-09-04T10:43+08:00 前后由 controller 在 isolation worktree 实跑；不采信实现者/任务 2.5 快照里的「已跑过」。

## closeout-evidence.py 七节回放

命令：`python3 ~/.claude/skills/spec/scripts/closeout-evidence.py <项目目录>`，rc=0。

```
# 收口证据回放

## 调研范围
legacy：无此记录

## 调研深度
legacy：无此记录

## 分类依据
legacy：无此记录

## report review
legacy：无此记录

## 自动通过的门及其依据
- 2026-09-01-03-session-state-safety: 门② — 依据：PLAN v5.1 收窄 requirements 已完成三轮全新上下文独立审查并在熔断后逐项裁定；R1-R9、五 API/信号返回、攻击与规模 oracle 闭合，check-plan/check-req/check-criteria/check-analyze/git diff --check 全部通过
- 2026-09-01-03-session-state-safety: 门③ — 依据：PLAN v5.1 收窄 design 经三轮全新上下文独立审查最终 PASS；R1-R9、八节<absolute-path> marker、3文件359行 sizing 全闭合，全部机械检查通过
- 2026-09-01-03-session-state-safety: 门④ — 依据：三轮全新上下文 tasks review 达熔断上限并融合全部承重 finding；16 个串行任务覆盖 R1-R9、六 marker、BASE 证据和 3文件<absolute-path> diff --check 全通过

## 跳过门禁
无

## 挂账 findings
无
```

对照：脚本只回放了项目级 legacy 门记录，未收录本片 ledger 的「自动通过: 门②/③/④」行。本片门②–④依据以 ledger 原文为准（见第③块引用的自动通过行）。跳过门禁与挂账 findings 两节为空，与 STATE.md SKIPPED 表空、本片无 SKIPPED 一致。七节齐全，可进入六块。

---

## ① 判据执行结果

implementation worktree：
`/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03e-claude-session-lifecycle/worktree`

TOOLS：`shfmt v3.14.0` / ShellCheck `version: 0.11.0`（pin 路径 `.../scratchpad/tools/bin`）。

### HEAD / porcelain / exact6

```
wt_HEAD=5b2e66b3be9079aa31b4b6eba2da88888a3aaeba
porcelain_lines=0
claude-code/features/.harness/hooks/check-branch-drift.sh
claude-code/features/.harness/hooks/load-feature.sh
claude-code/features/.harness/hooks/session-end.sh
claude-code/features/.harness/settings.json
claude-code/run-demo.sh
tests/test-claude-session-lifecycle.sh
NUMSTAT_SUM=367
upstream_changed_lines=0
```

numstat 分解：38+3 / 46+3 / 47+0 / 3+0 / 37+14 / 176+0 = 367 ≤ 400。

### 固定工具 + 五 shell + settings.json

```
shfmt_rc=0
shellcheck_rc=0
bash_n_rc=0
json_ok
compat: load-feature.sh 1 / check-branch-drift.sh 1 / session-end.sh 1
diff_check_rc=0
```

### manifest awk（八行六列）

```
awk_NR=8
awk_prev=5b2e66b3be9079aa31b4b6eba2da88888a3aaeba
manifest_awk_rc=0
```

### checkers（`.claude/skills/spec/scripts`，绝对路径）

```
check-tasks_rc=0
check-req_rc=0
check-criteria_rc=0
check-analyze_rc=0
```

### 主验证（candidate）

`bash ./tests/test-claude-session-lifecycle.sh`

```
default_rc=0
default_stderr_bytes=0
default_bytes b'RESULT PASS  claude session lifecycle\n'
exact True
all_rc=0
all_stderr_bytes=0
default_all_stdout_cmp=0
absent_rc=0
absent_stderr_bytes=0
upstream_sha_cmp=0
porcelain_lines=0
```

`--dependency-absent` 同样 rc0、同一摘要（legacy-only，不计入本片验收、不解除顺序门）。

### 不变量 4：offline

`bash ./scripts/check.sh --offline`

```
offline_rc=0
offline_stderr_bytes=0
lifecycle_discover_count=1
末行: RESULT PASS  aosp-harness offline quality gate
```

### check-converge.py

直接 `--repo` implementation worktree：18 条「验收资产不可用」（资产在主树 work/，worktree 内无这些路径），rc=1。

直接 `--repo` 主工作区：源码 exact6 被另一会话未跟踪/脏文件与未列入验收资产的 brief/review 报成「范围扩张」，rc=1。

隔离取证（`git clone --no-local` worktree，覆盖主树 `tasks.md`/`design.md`，只复制 tasks.md 所列验收资产后跑脚本）：

```
converge_isolated_rc 0
```

源码对账与脚本退 0 同时成立。裁定见第③块。

### full checkout

```
full_HEAD=5b2e66b3be9079aa31b4b6eba2da88888a3aaeba
full_count=208
full_default_rc=0
full_default_exact True
full_stderr_bytes 0
full_offline_rc=0
full_offline_tail=RESULT PASS  aosp-harness offline quality gate
full_discover=1
```

### depth-1

```
d1_HEAD=5b2e66b3be9079aa31b4b6eba2da88888a3aaeba
d1_count=1
d1_shallow_lines=1
d1_default_rc=0
d1_default_exact True
d1_offline_rc=0
d1_discover=1
```

### rollback（隔离 clone，2D+4M）

```
rollback_name_status:
M	claude-code/features/.harness/hooks/check-branch-drift.sh
M	claude-code/features/.harness/hooks/load-feature.sh
D	claude-code/features/.harness/hooks/session-end.sh
M	claude-code/features/.harness/settings.json
M	claude-code/run-demo.sh
D	tests/test-claude-session-lifecycle.sh
rollback_vs_base_bytes=0
rb_snap: b'RESULT PASS  session snapshot safety\n'
rb_as:   b'RESULT PASS  session snapshot assurance\n'
rb_sig:  b'RESULT PASS  session write interrupts\n'
rb_st:   b'RESULT PASS  session state\n'
rb_off_rc=0 末行 PASS  aosp-harness offline quality gate
rb_discover=（rg -c 无匹配，本入口 0 次）
rb_session_end_absent=0
rb_test_absent=0
rb_porcelain=0
```

candidate/full/depth-1 worktree 未被触碰；事后 `wt_HEAD` 仍为 accepted HEAD，porcelain 0。

### 04 顺序门（bash，未开 nullglob；NEXT 仅变量展开）

```
specs_absent_rc=0
work_absent_rc=0
branch_absent_rc=0
wt_absent_rc=0
files_count=18
files_breakdown:
      7 execution-base.env
     11 ledger.md
files_nonempty_rc=0
scoped_rg_absent_rc=0
```

（0 份 dispatch.tsv；18=11+7。本片 ledger 不写 NEXT 规范 ID 全名。）

---

## ② 逐条对照

### R1–R10

- **R1** 三 hook 内联 guard：source aggregator + marker 精确 1 + 五 API `declare -F` 合取才 v1。结构核对 + 默认矩阵（七类 fixture）本消息 default rc0。✅
- **R2** aggregator/模块缺席/非法输入/设计外错误码 → legacy + compat 字面量恰一次 + rc0，无 partial。compat 结构计数三 hook 各 1；default 覆盖七类 fixture。✅
- **R3** SessionStart 五 source 分级、物理根 SHA-256、永不覆盖、compact 缺失不创建。default 矩阵覆盖。✅
- **R4** UPS 无漂移/缺席 rc0；漂移两行告警 exit 2。default 矩阵覆盖。✅
- **R5** SessionEnd 校验先于 remove；非法零删除；settings.json 注册且 json 解析通过。✅
- **R6** legacy 段与 v1 文件隔离；default 含 legacy fixture。✅
- **R7** run-demo 私有 `claude-harness-demo.XXXXXX` + 单 EXIT trap。任务 1.2 独立 review 终判 PASS；R7 括号内三条成立。门⑤不把「mktemp 外净变更=0」写成无条件（见挂账：dry-run 仍会改 tracked `CLAUDE.md` 软链，属 b2fab19 既有、本片未引入）。✅
- **R8** 默认发现测试 176 行顶格；default/all 摘要逐字节 `RESULT PASS  claude session lifecycle\n`；absent 同摘要但不计入验收。checks 口径沿用独立 review：present=137 / absent=12。✅
- **R9** candidate/full/depth-1 默认+offline 全绿，offline 发现本入口恰 1 次；depth-1 count=1、shallow 1 行；上游十二 SHA 候选前后不变；exact6/367≤400；manifest 八行 awk rc0；固定工具后 shfmt/shellcheck/bash-n/json/`git diff --check`/clean。✅
- **R10** rollback 对 BASE diff 空、四前序入口+offline 全绿且本入口发现 0；顺序门五类资产缺席。inert/legacy PASS 未作验收证据。✅

### 验收清单 10 条

与上列 R1–R10 一一对应，本消息实跑覆盖，全部勾选成立。

### 不变量

1. 上游十二 BASE..HEAD 变更数 = 0（`upstream_changed_lines=0`）。
2. SessionStart/SessionEnd 非零次数由 default 矩阵约束为 0，UPS 仅 v1 漂移为 2（套件 rc0 即该 oracle 成立）。
3. demo mktemp 外净变更：定点断言在套件内；无条件 inventory 不成立（见 R7/挂账）。
4. offline 失败数 = 0。

---

## ③ 执行期裁定

ledger 全部 `- 裁定:` 行原样：

1. 执行期一律使用 `~/.claude/skills/spec/scripts/*`，取代 tasks.md 正文里写死的 `/home/zzh0838/.agents/skills/spec/scripts/*` — 依据：两套 skill 安装并存且已实质分叉（`.claude` 于 2026-09-03T17:26 部署、`.agents` 停在 14:30），差异是承重的：`.agents/check-tasks.py` 完全没有 `max_tasks_per_spec` 门（grep 计数 0），对 03d 的九任务 rc0、对本片 tasks.md 反而报出十三条伪 missing（把格式模板当成「任务 1: （名字）」、R2–R10 全判漏做）；本片门②–门④的全部机械证据、route.py 与 brief 切片语义均出自 `.claude` 一侧。如果错了代价：两套混用会让同一份 tasks.md 在不同步骤得到互相矛盾的门禁结论，验收时无法判定哪一次 rc 才算数——已通过全程单一安装消除。

2. 本片执行期不做 main 分支簿记提交，簿记推迟到验收阶段一次性处理 — 依据：主工作树当前有另一会话正在进行的大改（`.spec/2026-09-01-aosp-feature-minimal-checkout` 192 个文件被删除、新建 `.spec/2026-09-03-aosp-minimal-git-checkout`，均非本会话所为），此刻在 main 上提交有把他人未完成改动卷入本片提交的风险；本片实现全部发生在隔离 worktree，不受影响。如果错了代价：簿记延后会让 main 上的 03e 文档暂时停留在门③版本，验收阶段需一次补齐——不影响实现提交链与 exact6 门。

3. 项目 config.yml 增加 `brief_max_bytes: 65536`（覆盖 balanced 默认 32768） — 依据：任务 1.1 覆盖 R1–R6、切片简报实测 55809 bytes 超默认上限，脚本给的两条出路（拆小任务 / 收窄 steering）在本片都不可行——拆任务 1.1 会让任务数回到 9 而撞上 max_tasks_per_spec=8 硬门（本片裁定 9 刚为此合并过任务），本项目无 steering 目录；`brief_max_bytes` 是 _config.py 明列的可覆盖整数键、属派活工效阈值而非门禁，55809 bytes 约 14k token 远在单 subagent 上下文内，本项目前几片在旧安装下的简报实测 88–91KB 亦可正常执行。如果错了代价：上限放宽后可能掩盖「任务过大」的真实信号——已用四条粒度判据在门④三轮独立 review 中单独核过任务 1.1（reviewer round1 §16 明确判定其 review 面 < 10 分钟），且本次只调工效阈值、未动 max_tasks_per_spec/fix_loop_max/review 等任何门禁键。

4. 任务级验收资产（red 证据、green 报告、evidence package、review-manifest.tsv）一律落**主工作树** `$PROJECT/work/<spec-id>/` 下，不落隔离 worktree — 依据见 ledger 原文。

5. 接受实现者对两处 BASE 既有 shfmt 非规范重定向的顺带修正 — 依据见 ledger 原文。

6. I1 的证明强度判定为够用（reviewer 明确「不要求补做任何证明」），并另行采纳其端到端加强版 — 依据见 ledger 原文（shim aggregator，禁止 awk 抽函数体）。

7. 对 round2 的两条次要 S5/S6 立即做 fix round 2，不按「次要挂账到验收」的常规处置 — 依据见 ledger 原文（SessionEnd fail-open → `prc != 0` 零删除 + stdin 排水）。

8. 前两次后台 subagent 的残留进程在 worktree 并发写入 run-demo.sh，导致前台 opus 在执行期间遭遇竞态——依据 reflog 出现 fd1e0be/7bab650/078a52b 三个非本次产生的中间提交。最终 `a8d03d1` 是稳定状态下全部门禁通过的提交。

9. I1 初判为误报——`a8d03d1:claude-code/run-demo.sh:55-61` 已有显式 `set +e / drift_rc=$? / if [[ "$drift_rc" -ne 2 ]]`，全文无 `|| true`。reviewer 终稿自行收回该条并改判 PASS。

tasks.md 编号裁定 1–10（落地策略、compat 恰 1、摘要恰 2、不设 mutant、终交付锚点、NEXT 全名硬禁令 scoped 域、inert 不计验收、sizing M2、任务数硬门合并两 checkout、demo mktemp 前缀）经门④三轮独立 review 成立，见 ledger「自动通过: 门④」。

门⑤新增：

10. `check-converge.py` 在「实现 isolation worktree + 主树并行脏工作区」下不能直接 rc0：`--repo` worktree 读不到主树验收资产；`--repo` 主工作区把另一会话未跟踪文件算范围扩张。源码对账以 `git -C "$WT" diff --name-only "$BASE" "$HEAD"` 恰 exact6 为准；脚本退 0 取证为隔离 clone + 仅复制 tasks 所列验收资产 + 主树 tasks.md/design.md 覆盖。如果错了代价：把另一会话脏文件误判为本片范围扩张而打回——已用隔离 clone 把脚本输入收口到本片 source+asset。

11. 主工作区 HEAD 为 detached `a9d23483`（另一会话 `spec/2026-09-03-01-module-probe`），不得在该树上 `checkout main`。合入在干净附加 worktree 上对记录主干 `main` 做 `merge --ff-only`。如果错了代价：打乱另一会话工作区——附加 worktree 使 `refs/heads/main` 前进而主工作区仍保持 detached。

---

## ④ 跳过的门禁

SKIPPED 表空。无。

---

## ⑤ 挂账 findings

均为独立 review 判次要、未改源码：

- 任务 1.3：审查者本机 ShellCheck 0.9.0 vs pin 0.11.0。本消息用 pin 0.11.0，`shellcheck_rc=0`。
- 任务 1.2 终审重要项（非代码缺陷）：`claude-feature --dry-run` 仍改 tracked `CLAUDE.md`（`sync_feature_link` 在 dry-run 前），b2fab19 既有、本片未引入；R7 括号内三条成立。
- 任务 2.4 / 2.5：把「18 份」误写成全是 `specs/*/ledger.md`。本消息实测 11 ledger + 7 execution-base.env + 0 dispatch。顺序门判定不受影响。

无阻断/重要未修项。

---

## ⑥ 结论

可以验收。accepted HEAD `5b2e66b3` exact6=367≤400，八任务独立 review 全 PASS，本消息主验证/offline/full/depth-1/rollback/顺序门/隔离 converge 全绿；R1–R10 与四不变量对照成立；ledger 裁定已重报；SKIPPED 无。legacy-only PASS 未作本片验收证据，亦未解除后序片顺序门。
