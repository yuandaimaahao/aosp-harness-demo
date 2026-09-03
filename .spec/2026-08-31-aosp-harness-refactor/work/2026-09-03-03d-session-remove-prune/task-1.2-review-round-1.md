# Review: task 1.2 03d-session-remove-prune round 1
verdict: NEEDS_CHANGES
阻断: 1 / 重要: 0 / 次要: 1

## findings

- [阻断] **语法错损坏模块时 aggregator 泄漏 bash 解析错误到 stderr，违反 R6/design「双流空」与必核项 2(b) 的 0B 期望。** 在 mktemp 副本中给模块注入语法错后 source aggregator：snapshot 尾部残缺 → rc1、stderr **85B**（`./session-state-snapshot.sh: line 210: unexpected EOF...`）；remove 中段错 → rc1、stderr **133B**；foundation 尾部错 → rc1、stderr **87B**。rc1、四 public 全缺席、marker 未设均正确，唯一违例是 stderr 非空。权威依据三处均无条件要求该场景双流空：R6「任一模块文件缺席、source非零或预期export缺失……静默返回1、双流空」、design 错误处理表「任一模块 source 非零或 9 export 缺一 → rc1、双流空」、aggregator guard 节「静默、双流空」。其余全部失败模式实测严格 0B（五文件缺席×5、显式 `return 1`、export 缺失×3），说明实现本可满足、唯独未屏蔽 source 的 stderr。合规修复琐碎且无损：&& 链中五个 `source` 各加 `2>/dev/null`（模块契约本身静默，无合法输出被吞），且与 design「missing-module 静默走 legacy」的意图一致。备读：若把「双流空」解释为仅约束 aggregator 自身输出（泄漏字节来自 bash 解释器对损坏文件的诊断），本条可降级——但该读法与三处权威字面及本片字节级契约风格不符，且 1.3 fixture 矩阵只测缺席不测损坏，此缺口不会在后序任务被兜住。
- [次要] **manifest 第 1 行 task-id 列为 `1.1`，与规定格式 `task-1.1` 不符。** `review-manifest.tsv` 现唯一行为 `1<TAB>1.1<TAB>d8c2baae…<TAB>0bb53a04…<TAB>kimi<TAB>PASS`；而 tasks.md 的 printf 模板（`printf '1\ttask-1.1\t…'`、`printf '2\ttask-1.2\t…'`）与任务 2.6 步骤 4 的 awk（`ids="task-1.1 task-1.2 …"`、`$2 != ids[NR]` → bad）均要求带 `task-` 前缀。该行是任务 1.1 收尾时 controller 追加的，不在本任务 diff 面内，但不纠正的话 2.6 终门机械核验必挂；controller 追加第 2 行（`task-1.2`）前建议一并处理。

## 核对记录

**1. 提交面 — 全过。** worktree HEAD=`653e756f136ac755d2e8256045339d9205b9e3b8`（与简报一致）；`git log TASK_BASE..HEAD` 恰 1 提交 `feat(session): add complete-provider aggregator`（Conventional）；`--name-only` 恰 `common/.harness/lib/session-state.sh`；numstat=46≤50；execution BASE `d8c2baae`..HEAD name-only 恰 remove+aggregator 两文件、numstat 110+46=156≤160；`-- $UPSTREAM9` 为空；`git status --porcelain` 空；`git diff --check` rc0。

**2. fail-closed 行为（mktemp 副本亲跑，bash 5.2.21）**
- (a) 五模块各自缺席 ×5：全部 rc1、stdout/stderr 0B、四 public 全缺席、marker 未设（foundation 缺席时 validate 亦缺席）。✓
- (b) source 非零：显式 `return 1` 注入 → rc1、双流 0B、四 public 缺席 ✓；**语法错注入 ×3 → rc1 但 stderr 85/133/87B ✗（阻断 finding）**。
- (c) 预期 export 缺失 ×3（remove core 改名、snapshot read_core 改名、foundation validate 改名；首轮 sed 锚 `^` 未命中缩进定义行已纠正重跑）：全部 rc1、双流 0B、四 public 缺席、marker 未设。✓
- (d) 齐全态（含从外部 cwd 以绝对路径 source）：rc0、双流 0B、`HARNESS_SESSION_STATE_PROVIDER_VERSION` 精确 `1`、五 public API（含 `harness_validate_feature_name`）逐个 `declare -F` 在场，`_harness_session_state_dir` 已 unset。✓
- (e) 四转接：stub 模块逐一定义 9 export 后 source aggregator 实调——`harness_session_state_path p s`→`path_core argc=2`、`write p s f`→`signals_write argc=3`、`read p s`→`snap_read argc=2`、`remove p s`→`remove_core argc=2`，目标与参数透传全部正确；另真实调用 `harness_session_state_remove missing-project missing-session`（隔离 TMPDIR）rc0、双流 0B。✓
- (f) partial capability：所有中途失败场景（缺席×5、return 1、语法错×3、export 缺失×3）四 public 一个都未定义（非仅 marker 未设）。✓
- 附：直接执行模式（非 source）齐全 rc0 / 缺模块 rc1，双流均 0B。✓

**3. 临界区结构 — 过，偏离（2）接受。** 照简报步骤 3 固定 python3 实跑 rc0（last_check=2491 < first_def=2649 < marker=2936，last_def=2896 < marker）。逐行读控制流：else 分支无条件 `return 1 2>/dev/null || exit 1`（sourced 时 return 终止本文件、直接执行时 exit 1），**不存在未通过检查仍执行到临界区的路径**；rg/python 断言的 `^` 行首锚定成立（四定义在第 42–45 行第 0 列）；临界区内仅四个一行转接定义+一个赋值，均无可失败语句。与 design「全部通过才进入单临界区」语义等价。

**4. 静态门 — 过，偏离（1）接受。** 固定 TOOLS 逐字核版本 shfmt `v3.14.0`、ShellCheck `0.11.0`；`shfmt -d -i 2 -ci -bn` 无输出 rc0、`shellcheck -x --severity=warning` rc0、`bash -n` rc0；`! rg -q 'setsid'`/`python3`/`os\.(rmdir|unlink|mkdir)` 均无匹配；wc=46≤50、转接定义=4、marker=1。文件级 `# shellcheck disable=SC1090,SC2034` 单行：SC1090 为 BASH_SOURCE 定位的动态 source（5 处，静态不可解析，行级需 5 条指令、文件级单行实为更窄实践）；SC2034 的 marker 由外部 `declare -p` 消费（export 会改语义，无更窄替代）——两条均确属不可免。

**5. 报告契约 — 全过。** red 记录六行+assertion 齐全；红命令亲跑复现 rc1，stdout 空串 sha `e3b0c442…`、stderr 78B sha `ba75f346…` 与记录逐字一致；green 报告六节（task/base/head/files/commands/results）齐全且 base/head 与 git 实值一致；报告「红阶段证据: 」行 `cat -A` 核行尾零尾随字符（`…red.txt$`，与 03c/task-1.1 既定单行格式一致）；evidence.tsv 18 行逐行重算 sha256/bytes **全部一致**；引用日志 14 个全存在且内容自洽（present/absent inventory、review-package stdout 等抽查）；review 包内嵌 diff 与真实 `git diff TASK_BASE HEAD` 逐字节一致（python 比较 `True`）。manifest 第 2 行未预写（待本 review PASS 后由 controller 追加）符合流程。

**6. 偏离评估。** (1) 文件级 disable：接受（见 4）。(2) 临界区顶层放置：接受（见 3，控制流逐行确认无绕过的路径、锚定成立、语义等价）。语法错 stderr 泄漏不属于已声明偏离，升格为阻断 finding（见上）。
