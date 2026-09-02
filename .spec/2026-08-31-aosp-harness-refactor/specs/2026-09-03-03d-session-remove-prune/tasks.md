# 2026-09-03-03d-session-remove-prune 实现计划

03b/03c 多轮 tasks review 证明逐函数拼装中间代码会制造假红；本片四个交付文件均为新写完整文件，无 prototype blob——design sizing 节明确为纯分解预算（同构实际尺寸外推），候选文件以 design「组件与接口」节为唯一权威结构。熔断裁定：任务 1.1 一次性交付完整 remove 模块（≤110 行，单任务落地）、任务 1.2 一次性交付完整 aggregator（≤50 行，单任务落地）、任务 1.3 一次性交付完整集成测试与 coverage fragment（≤205+≤25 行，含红阶段双 mutant 自反证），禁止逐段拼装；随后 candidate/full/depth-1/rollback/order/terminal 六个零 delta controller 验证任务；共九个任务严格串行。实现提交使用普通 Conventional Commit。每个任务均保存 red 记录、green 报告和 evidence package，交全新独立 agent review；Blocking/Important 修复后必须由另一全新 agent re-review。

固定变量与工具门：

```bash
PROJECT=.spec/2026-08-31-aosp-harness-refactor
SPEC=$PROJECT/specs/2026-09-03-03d-session-remove-prune
WORK=$PROJECT/work/2026-09-03-03d-session-remove-prune
TASKS=$SPEC/tasks.md
LEDGER=$SPEC/ledger.md
MANIFEST=$WORK/review-manifest.tsv
TOOLS=/tmp/claude-1000/-home-zzh0838-CareerDevelop-AI2D-aosp-harness-demo/bdc6e669-9154-4030-a9db-78dc599ab491/scratchpad/tools/bin
UPSTREAM9="common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh tests/lib/session-path-race-driver.py tests/test-session-path-races.sh common/.harness/lib/session-state-snapshot.sh tests/test-session-snapshot.sh tests/test-session-snapshot-assurance.sh common/.harness/lib/session-state-signals.sh tests/test-session-signals.sh"
EXACT4="common/.harness/lib/session-state-remove.sh common/.harness/lib/session-state.sh tests/coverage.d/03d-session-state.md tests/test-session-state.sh"
test "$("$TOOLS/shfmt" --version)" = "v3.14.0"
"$TOOLS/shellcheck" --version | rg -q '^version: 0.11.0$'
```

controller 在门④通过后固定 `IMPLEMENTATION_WORKTREE` 与 `TASK_BASE`（execution BASE，即任务 1.1 提交前的 clean HEAD），并令 `BASE_SHA=$TASK_BASE`；任务 1.2 开始时重取 `TASK_BASE=$(git rev-parse HEAD)` 为任务 1.1 的 `TASK_HEAD`，任务 1.3 同理衔接任务 1.2，保证 manifest 相邻连续。

red记录固定六行：`task=`、`command=`、`expected=`、`rc=`、`stdout_sha256=`、`stderr_sha256=`，末加`assertion=`；green报告固定含task/base/head/files/commands/results。报告契约（03c 执行期教训，定死）：报告中「红阶段证据: 」一行的路径必须独占一行、行尾零尾随字符（`cat -A` 核）。evidence package为TSV三列`path<TAB>sha256<TAB>bytes`，列出brief、report和全部日志；package 生成后其中收录的任何文件再被改动（含 fix round 更新 report 或追加日志），必须重算并更新对应行，不得留下陈旧 sha256/bytes。reviewer拿这三个路径，而不是依赖base=head的空diff。

manifest固定六列`seq<TAB>task-id<TAB>base<TAB>head<TAB>reviewer<TAB>PASS`，manifest 行一律由 controller 在该任务独立 review PASS 后追加（实现者不预知 review 结果，03c 报告契约）。任务简报由 controller 以 `python3 /home/zzh0838/.agents/skills/spec/scripts/task-brief.py "$TASKS" <任务号> --out "$PROJECT/work"` 生成，任务号格式为 `1.1` 样式（不带 `task-` 前缀）；review 包真实签名为 4 参：`/home/zzh0838/.agents/skills/spec/scripts/review-package.sh <BASE> <HEAD> "$PROJECT/work" 2026-09-03-03d-session-remove-prune`（03c tasks 中的 2 参写法是执行期修订前的笔误，本片直接写正确签名）。每个任务 PASS 后先追加本行，再分别执行：

```bash
python3 /home/zzh0838/.agents/skills/spec/scripts/mark-task-done.py "$TASKS" TASK_ID
# controller用apply_patch向ledger增加：- 任务 TASK_ID: 完成 commits=[TASK_HEAD]
python3 /home/zzh0838/.agents/skills/spec/scripts/sync-ledger.py "$LEDGER" --repo "$IMPLEMENTATION_WORKTREE"
```

裁定（定死，依据随条给出）：

1. 落地策略：任务 1.1/1.2/1.3 各以单任务一次性交付完整候选文件，禁止逐段拼装。依据：03b/03c 教训——拼装中间代码制造未定义引用与假红；本片无 prototype blob，候选文件以 design「组件与接口」节为唯一权威结构。组1 拆三个交付任务而非两个的理由：design 四文件中有两个独立生产模块（remove ≤110、aggregator ≤50），各自有独立 source 契约与静态门可独立判定成败，合并会让实现者在无中间验证下连写两个模块、违背「先验证核心」且单任务 review 面超过 10 分钟；fragment ≤25 行是纯文档、无独立验证面，拆开会出现没有有效验证步骤的空任务，故并入任务 1.3。sizing 预算：110+50+205+25=390，对 exact4/400 门保留 ≥10 行余量。
2. 探针字面量前提：测试文件中 `printf 'RESULT PASS  session state\n'` 调用字面量恰 2 处——依赖缺席 inert 出口（第 1 处）与 active 出口（末行，第 2 处）。dependency-present 实跑用 rindex 定位末处、在其前插入 `printf 'checks=%d\n' "$checks" >&2` 探针；inert 实跑用 index 定位首处、插入 `  printf 'checks=%d\n' "${checks:-0}" >&2` 探针（两空格缩进与该分支一致）——inert 流程在计数器初始化前即 `exit 0`，末行探针不可达、提前引用 `"$checks"` 会 unbound 崩溃（03b1/03c 同款约束）。结构注释只写摘要文字，不得逐字包含该 printf 调用字面量，否则 rindex/index 定位失效（03b1 M1/03c 裁定 2 同款）。
3. mutant 设计：任务 1.3 红阶段含两个 mutant 自反证（design 测试策略节已定，不另设 aggregator mutant——partial-capability 不可能性由临界区 rg 文本顺序结构核对加六类 inert fixture 机械覆盖）。(a) 删 `PRUNE_BEFORE_IDENTITY` identity 核对 mutant：provider 副本中删除 checkpoint 后的 held child fd fstat 与 name 重取 stat 三方核对（直接 rmdir）；该 mutant 在换入攻击行必须 rc1/无 PASS——换入的新同名空目录被误删或 rc 不符即被抓。(b) feature 缺失不 prune mutant：provider 副本中把 feature stat ENOENT 分支改为直接成功返回、不进入 prune 循环；该 mutant 在 feature 缺失幂等 prune 行必须 rc1/无 PASS——空层级残留 oracle FAIL。注入机制：在 `mktemp -d` 内复制整棵 lib 树（provider 副本）后编辑 remove 副本，不改动已提交模块；生产模块不读取任何测试环境变量（design 分层节），故不设 03c `SIGNALS_MODULE` 式 env override，测试一律经 fixture/副本注入。两 mutant 的 rc/双流落入日志并写入 green 报告。
4. `setsid` 不适用本片：remove 唯一外部进程是同步前台 embedded python3，无 background child、无信号转发义务（R3/R4 错误表无 129|130|143 分支，write 信号语义独占于 03c facade），aggregator 纯 source 组合，测试无 process-group 行；design 分层节明确不引入 mktemp/rm/setsid。仍以 `! rg -q 'setsid'` 对三个 shell 交付文件负向断言防回归。
5. 终交付锚点 `session-state-provider-v1` 记入本文、ledger 完成锚点与 acceptance 报告；任务 2.6 的「产出」字段写 `tests/test-session-state.sh`。依据：check-tasks 的孤儿产出检查只认 requirements 验收标准节正文，该路径在「主验证命令」行逐字出现，而锚点名只出现在 requirements frontmatter（03b1/03c 裁定 5 同款）。
6. `03e-claude-session-lifecycle` 字面全名的硬禁令只覆盖 scoped rg 实际搜索的文件——`$PROJECT/specs/*/ledger.md`、`$PROJECT/work/*/dispatch.tsv`、`$PROJECT/work/*/execution-base.env`；这些文件只写「03e 顺序门」字样，本片自身 ledger 若含该字面全名，任务 2.6 终门重跑顺序门会自命中制造假红。requirements/design/tasks 等 spec 文档允许出现 NEXT 全名（R11）。green/red 报告与运行日志不在 rg 域内、不受硬禁令约束，但任务 2.5 的报告与日志中命令一律以步骤 2 已定义的 `"$NEXT"` 间接形式记录、不内联字面全名，以降低误写扩散风险。
7. inert PASS 不作为本片验收证据，也不解除 03e 顺序门；只有 dependency-present active 证据、exact4/400 与全 PASS manifest 入 ledger 后才可创建 03e 的 spec 目录/分支/worktree/ledger BASE/dispatch 记录（R11）。

### 任务 1.1: 一次性交付完整remove模块

文件: 创建 `common/.harness/lib/session-state-remove.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/evidence/task-1.1-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/task-1.1-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/review-manifest.tsv`
消费: 无
产出: session-remove-core-runtime-v1
需求: R1, R2, R3, R4
必需: 是

候选文件权威结构（design「组件与接口」节，唯一 export、不新增辅助函数）：source 守卫单一 `declare -F _harness_session_write_with_signals` 检查，缺席则静默返回 0、双流空，不定义 remove export、四个状态 public API 与 `HARNESS_SESSION_STATE_PROVIDER_VERSION`，不读写文件、不覆写依赖；在场则定义 `_harness_session_remove_core <project-id> <session-id>`——bash 层做 exact arity 与 `_harness_component_is_safe` 双 ID 校验（失败 rc2 + `error: unsafe session state\n`）、`umask 077` 后 heredoc embedded python3（唯一外部进程）；python 侧复刻 path 同源 root 选择（`HARNESS_STATE_ROOT` exact 且拒 `/`、否则 `XDG_RUNTIME_DIR`/非空 `TMPDIR`/`/tmp` 拼 `aosp-harness-<euid>`，physical parent 必须 strict resolve 存在），non-creating 打开 root/project/session 链——每层 `stat(name, dir_fd, follow_symlinks=False)`→拒绝非目录/链接→`open(O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC)`+`fstat`→after stat 三方 dev/inode/type 一致且 EUID/0700 通过才继续，任一层 ENOENT 幂等 0，链接/非目录/owner/mode/identity 不符 rc2；feature 删除先 stat 验 regular/EUID/0600/nlink1 后 `os.unlink("feature", dir_fd=session_fd)`，ENOENT 幂等继续 prune，unsafe 对象 rc2 不删；prune 对 (project_fd, session_fd, session)、(root_fd, project_fd, project)、(parent_fd, root_fd, root_leaf) 三步，每步 `pass  # PRUNE_BEFORE_IDENTITY` checkpoint 后 name 重取 stat 与 held child fd fstat 核 dev/inode/type，一致才 `os.rmdir(name, dir_fd=parent_fd)`，ENOENT/ENOTEMPTY 幂等成功停止，identity 不符 rc2，EIO 及其他 OSError rc1 + `error: session state operation failed\n`；OS 错注入 anchor `pass  # HARNESS_TEST_MARKER_OS_ERROR`（沿 path/snapshot 先例）与 `pass  # PRUNE_BEFORE_IDENTITY` 各 exact-once；永不触碰 physical parent 本身，finally 逆序关闭全部 fd；stdout 恒空、不存在 rc3 分支。remove 矩阵的行为正确性（R3/R4）由任务 1.3 封闭，本任务只做 source 契约与静态门，避免在无矩阵覆盖下制造假绿。

- [ ] 步骤 1: 运行`test ! -e common/.harness/lib/session-state-remove.sh && bash -c 'source common/.harness/lib/session-state-remove.sh'`，确认红阶段失败为文件缺席 rc1、stdout 无 PASS；按固定六行 schema 写`$WORK/evidence/task-1.1-red.txt`并核`test -s "$WORK/evidence/task-1.1-red.txt"`。
- [ ] 步骤 2: 核`git rev-parse HEAD`逐字等于门④固定的 execution BASE 并设`TASK_BASE=$(git rev-parse HEAD)`；用 apply_patch 一次性创建`common/.harness/lib/session-state-remove.sh`完整候选（禁止逐段拼装），核`test "$(wc -l <common/.harness/lib/session-state-remove.sh)" -le 110`、`test "$(rg -cF 'pass  # PRUNE_BEFORE_IDENTITY' common/.harness/lib/session-state-remove.sh)" = 1"`、`test "$(rg -cF 'pass  # HARNESS_TEST_MARKER_OS_ERROR' common/.harness/lib/session-state-remove.sh)" = 1"`、`test "$(rg -c '^[a-z_0-9]+\(\)' common/.harness/lib/session-state-remove.sh)" = 1"`（唯一函数定义）、`! rg -q 'setsid' common/.harness/lib/session-state-remove.sh`、`! rg -q 'HARNESS_SESSION_STATE_PROVIDER_VERSION' common/.harness/lib/session-state-remove.sh`、`! rg -q 'mktemp' common/.harness/lib/session-state-remove.sh`。
- [ ] 步骤 3: 逐字核固定工具版本`test "$("$TOOLS/shfmt" --version)" = "v3.14.0"`与`"$TOOLS/shellcheck" --version | rg -q '^version: 0.11.0$'`；对该单文件跑`"$TOOLS/shfmt" -d -i 2 -ci -bn common/.harness/lib/session-state-remove.sh`（无输出）、`"$TOOLS/shellcheck" -x --severity=warning common/.harness/lib/session-state-remove.sh`（rc0）、`bash -n common/.harness/lib/session-state-remove.sh`与`git diff --check`，全部通过。
- [ ] 步骤 4: source 契约实跑——依赖齐全态运行`bash -c 'source common/.harness/lib/session-state-foundation.sh && source common/.harness/lib/session-state-path.sh && source common/.harness/lib/session-state-snapshot.sh && source common/.harness/lib/session-state-signals.sh && source common/.harness/lib/session-state-remove.sh' >out 2>err`核 rc0、`test ! -s out`、`test ! -s err`；export inventory 核`declare -F _harness_session_remove_core`在场、`harness_session_state_path`/`harness_session_state_write`/`harness_session_state_read`/`harness_session_state_remove`逐个缺席、`declare -p HARNESS_SESSION_STATE_PROVIDER_VERSION`非 0；export 缺席抽查态在`mktemp -d`中复制 signals 模块并把`_harness_session_write_with_signals`全局改名，source foundation/path/snapshot/改名副本/remove 五文件核 rc0、双流空且`declare -F _harness_session_remove_core`缺席，结束后删除临时目录；完整 inert fixture 矩阵由任务 1.3 封闭，本步只做单点抽查。
- [ ] 步骤 5: 提交——`git add -N common/.harness/lib/session-state-remove.sh`后核 working-tree `git diff --name-only`恰为该单文件、`git diff --numstat | awk '{s+=$1} END {print s+0}'`≤110；`git add common/.harness/lib/session-state-remove.sh`（intent-to-add 不入提交，必须真 add，03c task-1.1 实测教训）后`git commit -m "feat(session): add non-creating verified remove module"`；设`TASK_HEAD=$(git rev-parse HEAD)`并核`git diff --name-only "$TASK_BASE" "$TASK_HEAD"`恰为该单文件、`git diff --numstat "$TASK_BASE" "$TASK_HEAD" | awk '{s+=$1} END {print s+0}'`≤110、`git diff --name-only "$TASK_BASE" "$TASK_HEAD" -- $UPSTREAM9`为空、`git status --porcelain`为空。
- [ ] 步骤 6: 生成 task brief/report、4 参`review-package.sh "$TASK_BASE" "$TASK_HEAD" "$PROJECT/work" 2026-09-03-03d-session-remove-prune`及 evidence package，取得独立 diff review PASS；有 fix 则更新`TASK_HEAD`、重跑步骤 3–5 并交全新 reviewer。PASS 后由 controller 运行`printf '1\ttask-1.1\t%s\t%s\t%s\tPASS\n' "$TASK_BASE" "$TASK_HEAD" "$REVIEWER" >>"$MANIFEST"`；随后分别 mark 1.1、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 1.2: 一次性交付完整aggregator模块

文件: 创建 `common/.harness/lib/session-state.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/evidence/task-1.2-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/task-1.2-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/review-manifest.tsv`
消费: session-remove-core-runtime-v1
产出: session-state-aggregator-runtime-v1
需求: R5, R6, R7
必需: 是

候选文件权威结构（design「组件与接口」节）：preflight 先验证五个模块文件路径（`common/.harness/lib/` 下 foundation/path/snapshot/signals/remove 五文件均 `[[ -f && -r ]]`，路径常量由 `BASH_SOURCE` 定位），再按 foundation→path→snapshot→signals→remove 唯一顺序逐个 source 并核 rc0，随后逐个点名 `declare -F` 核对 9 个预期 export——`harness_validate_feature_name`、`_harness_session_state_run`、`_harness_session_state_foundation_path`、`_harness_session_path_core`、`_harness_session_snapshot_worker`、`_harness_session_snapshot_write_core`、`_harness_session_snapshot_read_core`、`_harness_session_write_with_signals`、`_harness_session_remove_core`；任一文件缺席/不可读、source 非零或 export 缺失则 `return 1 2>/dev/null || exit 1`，静默、双流空，不设置 marker、不定义四个状态 public API；全部在场才进入单个临界区——只含四个一行转接函数定义（`harness_session_state_path`→`_harness_session_path_core "$@"`、`harness_session_state_write`→`_harness_session_write_with_signals "$@"`、`harness_session_state_read`→`_harness_session_snapshot_read_core "$@"`、`harness_session_state_remove`→`_harness_session_remove_core "$@"`）与 `HARNESS_SESSION_STATE_PROVIDER_VERSION=1` 赋值，无任何可失败语句，partial capability 物理不可能；`harness_validate_feature_name` 继续由 foundation 单独提供，aggregator 不重定义、不复制任何模块内部逻辑（无 root selector/rmdir/heredoc python 片段）。aggregator 发布面与六类 inert fixture 的行为正确性由任务 1.3 封闭，本任务只做 source 契约、临界区文本顺序结构核对与静态门。

- [ ] 步骤 1: 运行`test ! -e common/.harness/lib/session-state.sh && bash -c 'source common/.harness/lib/session-state.sh'`，确认红阶段失败为文件缺席 rc1、stdout 无 PASS；按固定六行 schema 写`$WORK/evidence/task-1.2-red.txt`并核`test -s "$WORK/evidence/task-1.2-red.txt"`。
- [ ] 步骤 2: 设`TASK_BASE=$(git rev-parse HEAD)`并核其逐字等于任务 1.1 的`TASK_HEAD`（manifest 相邻连续）；用 apply_patch 一次性创建`common/.harness/lib/session-state.sh`完整候选（禁止逐段拼装），核`test "$(wc -l <common/.harness/lib/session-state.sh)" -le 50`、`test "$(rg -c '^harness_session_state_(path|write|read|remove)\(\)' common/.harness/lib/session-state.sh)" = 4"`（恰四个 public 转接定义）、`test "$(rg -c 'HARNESS_SESSION_STATE_PROVIDER_VERSION=1' common/.harness/lib/session-state.sh)" = 1"`（marker 赋值 exact-once）、`! rg -q 'setsid' common/.harness/lib/session-state.sh`、`! rg -q 'python3' common/.harness/lib/session-state.sh`、`! rg -q 'os\.(rmdir|unlink|mkdir)' common/.harness/lib/session-state.sh`（无模块内部逻辑副本）。
- [ ] 步骤 3: 临界区文本顺序结构核对（裁定 3，替代 aggregator mutant）——跑以下 python3 核对，确认最后一个 export 点名检查的偏移先于首个 public 函数定义、首个 public 函数定义先于 marker 赋值，且四个 public 定义与 marker 赋值构成连续临界区：

  ```bash
  python3 - <<'EOF'
  import re, sys
  t = open("common/.harness/lib/session-state.sh").read()
  last_check = max(m.end() for m in re.finditer(r"declare -F", t))
  first_def = re.search(r"^harness_session_state_path\(\)", t, re.M).start()
  marker = re.search(r"HARNESS_SESSION_STATE_PROVIDER_VERSION=1", t).start()
  last_def = max(m.end() for m in re.finditer(r"^harness_session_state_\w+\(\)", t, re.M))
  sys.exit(0 if last_check < first_def < marker and last_def < marker else 1)
  EOF
  ```

- [ ] 步骤 4: 逐字核固定工具版本`test "$("$TOOLS/shfmt" --version)" = "v3.14.0"`与`"$TOOLS/shellcheck" --version | rg -q '^version: 0.11.0$'`；对该单文件跑`"$TOOLS/shfmt" -d -i 2 -ci -bn common/.harness/lib/session-state.sh`（无输出）、`"$TOOLS/shellcheck" -x --severity=warning common/.harness/lib/session-state.sh`（rc0）、`bash -n common/.harness/lib/session-state.sh`与`git diff --check`，全部通过。
- [ ] 步骤 5: source 契约实跑——依赖齐全态运行`bash -c 'source common/.harness/lib/session-state.sh' >out 2>err`核 rc0、`test ! -s out`、`test ! -s err`、`test "$HARNESS_SESSION_STATE_PROVIDER_VERSION" = 1"`、五个 public API（`harness_validate_feature_name` 与四个状态 API）逐个`declare -F`在场；转接抽查一例：`harness_session_state_remove` 对缺失目标调用核 rc0、双流空（remove 缺失幂等 0 透传）；missing-module 抽查态在`mktemp -d`中复制整棵 lib 树并删除其中 remove 模块，source 该树 aggregator 核 rc1、双流空、marker 未设置、完整五 API predicate 为 false，结束后删除临时目录；完整五模块各自缺席与 aggregator 缺席 fixture 矩阵由任务 1.3 封闭，本步只做单点抽查。
- [ ] 步骤 6: 提交——`git add -N common/.harness/lib/session-state.sh`后核 working-tree `git diff --name-only`恰为该单文件、`git diff --numstat | awk '{s+=$1} END {print s+0}'`≤50；`git add common/.harness/lib/session-state.sh`（intent-to-add 不入提交，必须真 add，03c task-1.1 实测教训）后`git commit -m "feat(session): add complete-provider aggregator"`；设`TASK_HEAD=$(git rev-parse HEAD)`并核`git diff --name-only "$BASE_SHA" "$TASK_HEAD"`恰为`common/.harness/lib/session-state-remove.sh`与`common/.harness/lib/session-state.sh`两文件、`git diff --numstat "$BASE_SHA" "$TASK_HEAD" | awk '{s+=$1} END {print s+0}'`≤160、`git diff --name-only "$BASE_SHA" "$TASK_HEAD" -- $UPSTREAM9`为空、`git status --porcelain`为空（累计断言必须用 execution BASE `$BASE_SHA`——`$TASK_BASE` 是任务 1.1 的 HEAD，仅保留给步骤 7 的 manifest 行与相邻连续性）。
- [ ] 步骤 7: 生成 task brief/report、4 参`review-package.sh "$TASK_BASE" "$TASK_HEAD" "$PROJECT/work" 2026-09-03-03d-session-remove-prune`及 evidence package，取得独立 diff review PASS；有 fix 则更新`TASK_HEAD`、重跑步骤 3–6 并交全新 reviewer。PASS 后由 controller 运行`printf '2\ttask-1.2\t%s\t%s\t%s\tPASS\n' "$TASK_BASE" "$TASK_HEAD" "$REVIEWER" >>"$MANIFEST"`；随后分别 mark 1.2、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 1.3: 一次性交付完整默认发现集成测试与coverage fragment

文件: 创建 `tests/test-session-state.sh` / 创建 `tests/coverage.d/03d-session-state.md`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/evidence/task-1.3-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/task-1.3-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/review-manifest.tsv`
消费: session-state-aggregator-runtime-v1
产出: session-state-matrix-v1
需求: R1, R2, R3, R4, R5, R6, R7, R8, R9
必需: 是

候选文件权威结构（design「默认发现测试」「测试策略」与「独占 coverage fragment」节）：CLI 只接受无参数、`all`、唯一 `--dependency-absent` 或唯一 `--session-provider-fixture <missing-foundation|missing-path|missing-snapshot|missing-signals|missing-remove>`，unknown/extra/flag 带值 rc1 且不打印 PASS；依赖探测要求 aggregator 文件在场且在隔离 shell source 后 marker 精确为 1，真实 provider 缺席时默认与 `--dependency-absent` 走同一零 active case inert surface，打印 inert 出口摘要（printf 调用字面量第 1 处）；active 路径覆盖：remove 矩阵——feature 存在删除并自底向上 prune 空 session/project/root（namespace inventory 前后比较只差被删 feature 与被删空目录）、feature 缺失幂等 0 且安全目录存在时仍 prune 空层级、并发非空成功且不删他项（前后完整 namespace inventory 逐字比较仅差被删 feature 与被删的 session 目录）、rc 表逐字（合法 0/双流空、unsafe ID 与 unsafe 对象 rc2 固定 stderr、provider 副本在 OS 错 anchor 注入 EIO 得 rc1 固定 stderr、`rg` 证明生产文本无 rc3 映射）、`PRUNE_BEFORE_IDENTITY` 换入攻击行 rc2 且新旧目录均保留；aggregator 发布面——五 public API 逐个在场、marker 精确为 1、四个转接行为等价各取一例透传 rc/双流、validate 由 foundation 提供、aggregator 生产文本 rg 证明无模块内部逻辑副本；六类 inert fixture——`--session-provider-fixture` 五值（mktemp 内复制 lib 树移除对应模块，source 其中 aggregator rc1、双流空、marker 未设置、完整五 API predicate 为 false、预置同名家哨兵函数不被当作 capability）加 aggregator 缺席 fixture（自愿加严：lib 树无 `session-state.sh`，source 尝试返回非零、marker 未设置、五 API predicate 为 false，不断言双流空）；stdout/stderr 一律落文件按字节比较，禁止用吞尾随 LF 的 command substitution 验证成功流；active 出口打印末行摘要（printf 调用字面量第 2 处），全文恰 2 处（裁定 2）；coverage fragment 登记 R1–R9 到测试用例区段的映射表，不触碰 `tests/COVERAGE.md`。门③ design review M2 纪律（必须正面落实）：测试文件预算 205 行偏紧，实现者必须最先落定六类 fixture 表驱动循环与 mutant/anchor 注入的真实行数消耗——候选创建后立即核行数并把 fixture 循环区段与注入区段的实际行数记入 green 报告；若任一区段迫使测试文件超过 205 行或 numstat 总和预计超过 400，立即停手上报 controller 回 PLAN 拆片（备选：把 remove 动态攻击行拆为独立 assurance 片），禁止压缩任何 oracle 语义。

- [ ] 步骤 1: 运行`test ! -e tests/test-session-state.sh && bash tests/test-session-state.sh`，确认红阶段失败为文件缺席 rc127、stdout 无 PASS；按固定六行 schema 写`$WORK/evidence/task-1.3-red.txt`并核`test -s "$WORK/evidence/task-1.3-red.txt"`。
- [ ] 步骤 2: 设`TASK_BASE=$(git rev-parse HEAD)`并核其逐字等于任务 1.2 的`TASK_HEAD`（manifest 相邻连续）；用 apply_patch 一次性创建`tests/test-session-state.sh`完整候选（禁止逐段拼装），创建后**立即**核行数消耗（M2 纪律）：`test "$(wc -l <tests/test-session-state.sh)" -le 205`、`test "$(rg -cF "printf 'RESULT PASS  session state\n'" tests/test-session-state.sh)" = 2"`（裁定 2 前提）；把 fixture 表驱动循环区段与 mutant/anchor 注入区段的实际起止行号与行数记入 green 报告草稿；任一行数断言不过即停手上报 controller，不得删减 oracle 用例。
- [ ] 步骤 3: 用 apply_patch 一次性创建`tests/coverage.d/03d-session-state.md`（R1–R9 到测试用例区段的映射表），核`test "$(wc -l <tests/coverage.d/03d-session-state.md)" -le 25`，并跑`git diff --name-only -- tests/COVERAGE.md`核为空（02 的既有汇总文件零变更）。
- [ ] 步骤 4: 逐字核固定工具版本`test "$("$TOOLS/shfmt" --version)" = "v3.14.0"`与`"$TOOLS/shellcheck" --version | rg -q '^version: 0.11.0$'`；对测试单文件跑`"$TOOLS/shfmt" -d -i 2 -ci -bn tests/test-session-state.sh`（无输出）、`"$TOOLS/shellcheck" -x --severity=warning tests/test-session-state.sh`（rc0）、`bash -n tests/test-session-state.sh`与`git diff --check`，并核`! rg -q 'setsid' tests/test-session-state.sh`（裁定 4 对第三个 shell 交付文件的负向断言），全部通过。
- [ ] 步骤 5: dependency-present 实跑——分别运行`bash ./tests/test-session-state.sh`与`bash ./tests/test-session-state.sh all`，各自`>out 2>err`落盘后核 rc0、`printf 'RESULT PASS  session state\n' | cmp -s - out`、`test ! -s err`；断言计数：在仓库内`mktemp -d "$PWD/.count.XXXXXX"`中放目标副本，用 python3 以 rindex 定位最后一处`printf 'RESULT PASS  session state\n'`并在其前插入`printf 'checks=%d\n' "$checks" >&2`，跑 default 与 all 各一次，核两次`err`逐字一致且为`checks=N`（N>0），把 N 记入 green 报告作为本片 dependency-present 完整矩阵口径，随后删除临时目录；argv 非法表`bash ./tests/test-session-state.sh --bogus`、`bash ./tests/test-session-state.sh all extra`、`bash ./tests/test-session-state.sh --dependency-absent=x`、`bash ./tests/test-session-state.sh --session-provider-fixture`（缺值）、`bash ./tests/test-session-state.sh --session-provider-fixture bogus`逐行核 rc1 且 stdout 不含 PASS；五个`--session-provider-fixture`合法取值（missing-foundation/missing-path/missing-snapshot/missing-signals/missing-remove）逐行跑，核各自 rc0、stdout 逐字同一`RESULT PASS  session state\n`、stderr 0B。
- [ ] 步骤 6: mutant 自反证与 anchor 注入构造（裁定 3，以下注入均发生在`mktemp -d`内复制的整棵 lib 树 provider 副本上，变量名以 design 数据流节的`name`/`parent_fd`/`session`为准、按候选实际命名对齐）——先跑正确模块的两个注入行核 oracle 本身有效：(i) EIO 注入行：provider 副本在`pass  # HARNESS_TEST_MARKER_OS_ERROR`行后插入`raise OSError(errno.EIO, "injected EIO")`，经该副本 aggregator 调`harness_session_state_remove`核 rc1、stdout 空、stderr 逐字`error: session state operation failed\n`；(ii) 换入攻击行：provider 副本在`pass  # PRUNE_BEFORE_IDENTITY`行后插入下列换入代码，核 rc2、stderr 逐字`error: unsafe session state\n`，且`session`与`session.held`两目录均在：

  ```python
  if name == session:
      os.rename(name, name + ".held", src_dir_fd=parent_fd, dst_dir_fd=parent_fd)
      os.mkdir(name, 0o700, dir_fd=parent_fd)
  ```

  (iii) 并发非空行：provider 副本在同一 checkpoint 行后插入下列代码（prune session 层时在 project 下确定性制造非空），核 rc0、双流空、root 未被尝试、前后完整 namespace inventory 逐字比较仅差被删的 feature 文件与被删的空 session 目录（该行 setup 含 feature），且`concurrent`目录保留：

  ```python
  if name == session:
      os.mkdir("concurrent", 0o700, dir_fd=parent_fd)
  ```

  再跑双 mutant：(a) provider 副本删除`PRUNE_BEFORE_IDENTITY`后的 identity 三方核对（直接 rmdir）并叠加 (ii) 换入注入，跑测试核换入攻击行 FAIL、整体 rc1 且 stdout 无 PASS；(b) provider 副本把 feature stat ENOENT 分支改为直接成功返回（不进入 prune 循环），跑测试核 feature 缺失幂等 prune 行 FAIL（空层级残留）、整体 rc1 且无 PASS；两 mutant 的 rc/双流落入日志并写入 green 报告，结束后删除临时目录。
- [ ] 步骤 7: provider-absent 隔离实跑——`git clone --no-local . "$tmp/r"`后以`cp`把候选测试文件与 coverage fragment 放入 clone，删除`$tmp/r/common/.harness/lib/session-state.sh`（真实依赖缺席态），在`$tmp/r`分别跑无参数、`all`、`--dependency-absent`，核三者 rc0、stdout 逐字同一`RESULT PASS  session state\n`、stderr 0B；零 active case 机械核验：对该副本用 python3 以 index 在第一处`printf 'RESULT PASS  session state\n'`（inert 出口）前插入`  printf 'checks=%d\n' "${checks:-0}" >&2`（两空格缩进与该分支一致，裁定 2），跑 default 核 rc0、stdout 逐字 inert 摘要、`test "$(<err)" = "checks=0"`；再另起`git clone --no-local . "$tmp/e"`并放入候选文件，把`$tmp/e`中 signals 模块的`_harness_session_write_with_signals`全局改名，跑 default 核同样 rc0、同一 inert 摘要、stderr 0B；结束后删除两个临时 clone。
- [ ] 步骤 8: 提交——`git add -N tests/test-session-state.sh tests/coverage.d/03d-session-state.md`后核 working-tree `git diff --name-only`（git tree 序）恰为`tests/coverage.d/03d-session-state.md`与`tests/test-session-state.sh`两文件、`git diff --numstat | awk '{s+=$1} END {print s+0}'`≤230；`git add tests/test-session-state.sh tests/coverage.d/03d-session-state.md`（intent-to-add 不入提交，必须真 add，03c task-1.1 实测教训）后`git commit -m "test(session): add complete provider integration matrix"`；设`TASK_HEAD=$(git rev-parse HEAD)`并核`git diff --name-only "$BASE_SHA" "$TASK_HEAD"`逐字等于`$EXACT4`四文件、`git diff --numstat "$BASE_SHA" "$TASK_HEAD" | awk '{s+=$1} END {print s+0}'`≤400、`git diff --name-only "$BASE_SHA" "$TASK_HEAD" -- $UPSTREAM9`为空、`git status --porcelain`为空（exact4/≤400 断言必须用 execution BASE `$BASE_SHA`——`$TASK_BASE` 是任务 1.2 的 HEAD，该范围只含本任务单提交；`$TASK_BASE` 仅保留给步骤 9 的 manifest 行与相邻连续性）。
- [ ] 步骤 9: 生成 task brief/report、4 参`review-package.sh "$TASK_BASE" "$TASK_HEAD" "$PROJECT/work" 2026-09-03-03d-session-remove-prune`及 evidence package，取得独立 diff review PASS；有 fix 则更新`TASK_HEAD`、重跑步骤 4–8 并交全新 reviewer。PASS 后由 controller 运行`printf '3\ttask-1.3\t%s\t%s\t%s\tPASS\n' "$TASK_BASE" "$TASK_HEAD" "$REVIEWER" >>"$MANIFEST"`；随后分别 mark 1.3、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 2.1: 审计candidate并固定accepted HEAD

文件: 测试 `common/.harness/lib/session-state-remove.sh` / 测试 `common/.harness/lib/session-state.sh` / 测试 `tests/test-session-state.sh` / 测试 `tests/coverage.d/03d-session-state.md`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/evidence/task-2.1-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/task-2.1-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/review-manifest.tsv`
消费: session-state-matrix-v1
产出: provider-accepted-head-v1
需求: R10
必需: 是

- [ ] 步骤 1: 运行`test -s "$WORK/task-2.1-report.md"`确认红阶段失败为报告缺席，按固定六行 schema 写 red 文件并核`test -s`；核 implementation clean 且`git rev-parse HEAD`为任务 1.3 的`TASK_HEAD`。
- [ ] 步骤 2: 创建临时目录`tmp=$(mktemp -d)`；保存九上游文件 before SHA（`sha256sum $UPSTREAM9 >"$tmp/before.sha"`）；逐字核`test "$("$TOOLS/shfmt" --version)" = "v3.14.0"`与`"$TOOLS/shellcheck" --version | rg -q '^version: 0.11.0$'`；只对 exact 四文件中三个 shell 文件跑`"$TOOLS/shfmt" -d -i 2 -ci -bn common/.harness/lib/session-state-remove.sh common/.harness/lib/session-state.sh tests/test-session-state.sh`、`"$TOOLS/shellcheck" -x --severity=warning common/.harness/lib/session-state-remove.sh common/.harness/lib/session-state.sh tests/test-session-state.sh`、`bash -n common/.harness/lib/session-state-remove.sh`与`bash -n common/.harness/lib/session-state.sh`与`bash -n tests/test-session-state.sh`；分别运行 default 入口与`bash ./scripts/check.sh --offline`到独立日志，核 default 摘要逐字`RESULT PASS  session state\n`、`test "$(rg -c 'RESULT PASS  session state$' offline.log)" = 1"`（offline 发现恰一次，`$`锚定行尾以区别于 foundation 摘要）且 offline 末行 PASS；再`sha256sum -c "$tmp/before.sha"`比较 after SHA，结束后删除临时目录。
- [ ] 步骤 3: 核`git diff --name-only "$BASE_SHA" HEAD`逐字等于`$EXACT4`四文件、`git diff --numstat "$BASE_SHA" HEAD | awk '{s+=$1} END {print s+0}'`≤400、`git diff --name-only "$BASE_SHA" HEAD -- $UPSTREAM9`为空、`git diff --check`、clean，生成 green 报告和 evidence package；若发现源码缺陷则回流任务 1.1/1.2/1.3 修复并重 review，不在本任务改变 HEAD。
- [ ] 步骤 4: 交独立 reviewer 审 brief/report/evidence package 并取得 PASS，把当前 40 位 clean HEAD 固定为`ACCEPTED_HEAD`。
- [ ] 步骤 5: 由 controller 运行`printf '4\ttask-2.1\t%s\t%s\t%s\tPASS\n' "$TASK_HEAD" "$TASK_HEAD" "$REVIEWER" >>"$MANIFEST"`；随后分别 mark 2.1、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 2.2: 验证完整历史checkout

文件: 测试 `common/.harness/lib/session-state-remove.sh` / 测试 `common/.harness/lib/session-state.sh` / 测试 `tests/test-session-state.sh` / 测试 `tests/coverage.d/03d-session-state.md`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/evidence/task-2.2-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/task-2.2-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/review-manifest.tsv`
消费: provider-accepted-head-v1
产出: provider-full-checkout-v1
需求: R10
必需: 是

- [ ] 步骤 1: 运行`test -s "$WORK/task-2.2-report.md"`确认红阶段失败为报告缺席并写 red 文件；核 implementation `git rev-parse HEAD`逐字等于`ACCEPTED_HEAD`。
- [ ] 步骤 2: 创建临时目录，运行`git clone --no-local "$IMPLEMENTATION_WORKTREE" "$tmp/full"`并核 full 的`git rev-parse HEAD`逐字等于`ACCEPTED_HEAD`。
- [ ] 步骤 3: 在 full 中保存九上游文件 before SHA，分别运行 default 入口与`bash ./scripts/check.sh --offline`到独立日志；核 default 固定摘要逐字`RESULT PASS  session state\n`、`test "$(rg -c 'RESULT PASS  session state$' offline.log)" = 1"`且 offline 末行 PASS，再`sha256sum -c`比较 after SHA、`git status --porcelain`与`git diff` clean。
- [ ] 步骤 4: 写 green 报告/evidence package 并删除 full checkout；独立 review PASS 后由 controller 运行`printf '5\ttask-2.2\t%s\t%s\t%s\tPASS\n' "$ACCEPTED_HEAD" "$ACCEPTED_HEAD" "$REVIEWER" >>"$MANIFEST"`。
- [ ] 步骤 5: 分别 mark 2.2、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 2.3: 验证真实depth-1 checkout

文件: 测试 `common/.harness/lib/session-state-remove.sh` / 测试 `common/.harness/lib/session-state.sh` / 测试 `tests/test-session-state.sh` / 测试 `tests/coverage.d/03d-session-state.md`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/evidence/task-2.3-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/task-2.3-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/review-manifest.tsv`
消费: provider-full-checkout-v1
产出: provider-depth1-checkout-v1
需求: R10
必需: 是

- [ ] 步骤 1: 运行`test -s "$WORK/task-2.3-report.md"`确认红阶段失败为报告缺席并写 red 文件。
- [ ] 步骤 2: 运行`git clone --depth 1 "file://$IMPLEMENTATION_WORKTREE" "$tmp/depth1"`，核`git rev-parse HEAD`逐字等于`ACCEPTED_HEAD`、`test "$(git rev-list --count HEAD)" = 1`及`test -s .git/shallow`。
- [ ] 步骤 3: 保存九上游文件 before SHA，分别运行 default 入口与`bash ./scripts/check.sh --offline`到独立日志，核 default 固定摘要逐字`RESULT PASS  session state\n`、`test "$(rg -c 'RESULT PASS  session state$' offline.log)" = 1"`且 offline 末行 PASS；比较 after SHA、diff/status clean。
- [ ] 步骤 4: 写 green 报告/evidence package 并删除 depth checkout；独立 review PASS 后由 controller 运行`printf '6\ttask-2.3\t%s\t%s\t%s\tPASS\n' "$ACCEPTED_HEAD" "$ACCEPTED_HEAD" "$REVIEWER" >>"$MANIFEST"`。
- [ ] 步骤 5: 分别 mark 2.3、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 2.4: 验证exact rollback

文件: 测试 `common/.harness/lib/session-state-remove.sh` / 测试 `common/.harness/lib/session-state.sh` / 测试 `tests/test-session-state.sh` / 测试 `tests/coverage.d/03d-session-state.md`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/evidence/task-2.4-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/task-2.4-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/review-manifest.tsv`
消费: provider-depth1-checkout-v1
产出: provider-rollback-v1
需求: R11
必需: 是

- [ ] 步骤 1: 运行`test -s "$WORK/task-2.4-report.md"`确认红阶段失败为报告缺席并写 red 文件。
- [ ] 步骤 2: 从 implementation `git clone --no-local "$IMPLEMENTATION_WORKTREE" "$tmp/rollback"`并核 HEAD=`ACCEPTED_HEAD`；运行`git rm common/.harness/lib/session-state-remove.sh common/.harness/lib/session-state.sh tests/test-session-state.sh tests/coverage.d/03d-session-state.md`后提交普通 rollback commit，核`git diff --name-status HEAD~1 HEAD`恰为四行`D`且路径逐字等于`$EXACT4`。
- [ ] 步骤 3: 在 rollback 运行`bash tests/test-session-snapshot.sh`（03b 基础测试，核逐字`RESULT PASS  session snapshot safety`）、`bash tests/test-session-snapshot-assurance.sh`（03b1 assurance 入口，核逐字`RESULT PASS  session snapshot assurance`）、`bash tests/test-session-signals.sh`（03c signals 入口，核逐字`RESULT PASS  session write interrupts`）与`bash ./scripts/check.sh --offline`；核全绿、`! rg -q 'RESULT PASS  session state$' offline.log`（本入口发现 0 次）、`test ! -e common/.harness/lib/session-state-remove.sh`、`test ! -e common/.harness/lib/session-state.sh`、`test ! -e tests/test-session-state.sh`、`test ! -e tests/coverage.d/03d-session-state.md`且 clean；candidate/full/depth-1 checkout 不被触碰。
- [ ] 步骤 4: 写 green 报告/evidence package 并删除 rollback checkout；独立 review PASS 后由 controller 运行`printf '7\ttask-2.4\t%s\t%s\t%s\tPASS\n' "$ACCEPTED_HEAD" "$ACCEPTED_HEAD" "$REVIEWER" >>"$MANIFEST"`。
- [ ] 步骤 5: 分别 mark 2.4、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 2.5: 验证03e顺序门

文件: 测试 `common/.harness/lib/session-state-remove.sh` / 测试 `common/.harness/lib/session-state.sh` / 测试 `tests/test-session-state.sh` / 测试 `tests/coverage.d/03d-session-state.md`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/evidence/task-2.5-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/task-2.5-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/review-manifest.tsv`
消费: provider-rollback-v1
产出: provider-order-gate-v1
需求: R11
必需: 是

- [ ] 步骤 1: 运行`test -s "$WORK/task-2.5-report.md"`确认红阶段失败为报告缺席并写 red 文件。
- [ ] 步骤 2: 定义日期无关规范 ID 片段`NEXT=03e-claude-session-lifecycle`（日期前缀由创建日决定，本片不预知，R11）；前提：执行 shell 不得开 nullglob——未匹配 glob 需按字面传给 `ls`、由其 rc2 经 `!` 判缺席；在 implementation worktree 运行`! ls -d "$PROJECT"/specs/*"$NEXT" 2>/dev/null`与`! ls -d "$PROJECT"/work/*"$NEXT" 2>/dev/null`核 spec/work 目录缺席。
- [ ] 步骤 3: 运行`test -z "$(git show-ref | rg "refs/heads/spec/.*$NEXT")"`核分支零匹配；运行`test -z "$(git worktree list --porcelain | rg "$NEXT")"`核 worktree 零匹配。
- [ ] 步骤 4: 收集限定域文件后跑 scoped rg——`files=$(ls "$PROJECT"/specs/*/ledger.md "$PROJECT"/work/*/dispatch.tsv "$PROJECT"/work/*/execution-base.env 2>/dev/null)`（ls 多参数单列一行，禁止 `&&` 链 ls），然后`test -z "$files" || ! rg -q "$NEXT" $files`核 ledger/dispatch/execution-base 记录零匹配；不得搜索 PLAN/requirements/design/tasks 中的合法规划文字（裁定 6）。
- [ ] 步骤 5: 写 green 报告/evidence package 并取得独立 review PASS；由 controller 运行`printf '8\ttask-2.5\t%s\t%s\t%s\tPASS\n' "$ACCEPTED_HEAD" "$ACCEPTED_HEAD" "$REVIEWER" >>"$MANIFEST"`。
- [ ] 步骤 6: 分别 mark 2.5、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 2.6: 收敛manifest、ledger与终交付

文件: 测试 `common/.harness/lib/session-state-remove.sh` / 测试 `common/.harness/lib/session-state.sh` / 测试 `tests/test-session-state.sh` / 测试 `tests/coverage.d/03d-session-state.md`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/evidence/task-2.6-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/task-2.6-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/review-manifest.tsv` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/acceptance/acceptance-report.md`
消费: provider-order-gate-v1
产出: tests/test-session-state.sh（终交付锚点 session-state-provider-v1 记入 ledger 完成锚点与 acceptance 报告）
需求: R10, R11
必需: 是

- [ ] 步骤 1: 运行`test -s "$WORK/acceptance/acceptance-report.md"`确认红阶段失败为报告缺席并写 red 文件；核`git rev-parse HEAD`=`ACCEPTED_HEAD`与 clean。
- [ ] 步骤 2: 汇总 candidate/full/depth/rollback/order 日志到 green 与 acceptance 报告（含 accepted HEAD、active 摘要、双 anchor 注入行、两 mutant 自反证、checks 计数口径、exact4/400、六类 inert fixture），生成 evidence package 并取得独立 review PASS。
- [ ] 步骤 3: 由 controller 运行`printf '9\ttask-2.6\t%s\t%s\t%s\tPASS\n' "$ACCEPTED_HEAD" "$ACCEPTED_HEAD" "$REVIEWER" >>"$MANIFEST"`。
- [ ] 步骤 4: 运行以下完整 manifest 核验（九行、六列、相邻连续、reviewer 非空、全 PASS）：

  ```bash
  awk -F '\t' -v base="$BASE_SHA" -v head="$ACCEPTED_HEAD" '
    BEGIN { split("task-1.1 task-1.2 task-1.3 task-2.1 task-2.2 task-2.3 task-2.4 task-2.5 task-2.6", ids, " ") }
    NF != 6 || $1 != NR || $2 != ids[NR] || $3 !~ /^[0-9a-f]{40}$/ || $4 !~ /^[0-9a-f]{40}$/ || $5 == "" || $6 != "PASS" { bad=1 }
    NR == 1 && $3 != base { bad=1 }
    NR > 1 && $3 != prev { bad=1 }
    { prev=$4 }
    END { exit bad || NR != 9 || prev != head }
  ' "$MANIFEST"
  ```

- [ ] 步骤 5: mark 任务 2.6 完成；用 apply_patch 写 ledger 完成锚点及 accepted HEAD、active 摘要、双 anchor、mutant 证据、checks 计数、exact4/400、full/depth/rollback/order 证据（遵守裁定 6，不逐字包含 03e 规范 ID 全名），再运行 sync-ledger。
- [ ] 步骤 6: 重跑`python3 /home/zzh0838/.agents/skills/spec/scripts/check-tasks.py "$TASKS"`、`python3 /home/zzh0838/.agents/skills/spec/scripts/check-req.py "$SPEC/requirements.md"`、`python3 /home/zzh0838/.agents/skills/spec/scripts/check-criteria.py "$SPEC/requirements.md"`、`python3 /home/zzh0838/.agents/skills/spec/scripts/check-analyze.py "$SPEC/requirements.md"`、candidate default/offline、`git diff --check`、clean 与任务 2.5 的 03e 顺序门；全部通过才进入 accept，任何 inert PASS 不得作为本片验收证据或解除后序门。
