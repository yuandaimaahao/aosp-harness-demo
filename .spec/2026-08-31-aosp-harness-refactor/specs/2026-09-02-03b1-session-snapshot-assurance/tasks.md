# 2026-09-02-03b1-session-snapshot-assurance 实现计划

03b 三轮 tasks review 证明逐函数拼装中间代码会制造假红；本片最终文件不是现成 blob，而是 runnable prototype 308 行加约 41 行机械整合。熔断裁定：任务 1.1 一次性交付完整候选文件（以 prototype blob 为基座，整合点 E1–E6 逐处给出确切代码或确切转换规则），随后 candidate/full/depth-1/rollback/order/terminal 六个零 delta controller 验证任务；共七个任务严格串行。实现提交使用普通 Conventional Commit。每个任务均保存 red 记录、green 报告和 evidence package，交全新独立 agent review；Blocking/Important 修复后必须由另一全新 agent re-review。

固定变量与 blob 门：

```bash
PROJECT=.spec/2026-08-31-aosp-harness-refactor
SPEC=$PROJECT/specs/2026-09-02-03b1-session-snapshot-assurance
WORK=$PROJECT/work/2026-09-02-03b1-session-snapshot-assurance
TASKS=$SPEC/tasks.md
LEDGER=$SPEC/ledger.md
MANIFEST=$WORK/review-manifest.tsv
PROTO_SHA=cbdbdde0e1e3ff4ceb2dc0279b1db83127a0ea9e
PROTO_ASSURANCE=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/prototype/snapshot-assurance-r1.sh
test "$(git show "$PROTO_SHA:$PROTO_ASSURANCE" | wc -l)" -eq 308
```

controller 在门④通过后固定 `IMPLEMENTATION_WORKTREE` 与 `TASK_BASE`（execution BASE，即任务 1.1 提交前的 clean HEAD），并令 `BASE_SHA=$TASK_BASE`。

red记录固定六行：`task=`、`command=`、`expected=`、`rc=`、`stdout_sha256=`、`stderr_sha256=`，末加`assertion=`；green报告固定含task/base/head/files/commands/results。evidence package为TSV三列`path<TAB>sha256<TAB>bytes`，列出brief、report和全部日志；reviewer拿这三个路径，而不是依赖base=head的空diff。

manifest固定六列`seq<TAB>task-id<TAB>base<TAB>head<TAB>reviewer<TAB>PASS`。每个任务独立review PASS后先追加本行，再分别执行：

```bash
python3 /home/zzh0838/.agents/skills/spec/scripts/mark-task-done.py "$TASKS" TASK_ID
# controller用apply_patch向ledger增加：- 任务 TASK_ID: 完成 commits=[TASK_HEAD]
python3 /home/zzh0838/.agents/skills/spec/scripts/sync-ledger.py "$LEDGER" --repo "$IMPLEMENTATION_WORKTREE"
```

裁定（定死，依据随条给出）：

1. 落地策略：任务 1.1 单任务交付完整候选文件，禁止逐段拼装。依据：03b 教训——拼装中间代码制造未定义引用、截断 builder 与假红；prototype 已在当前 main 固定格式实跑 rc0，机械整合可把差异面压到 `diff` 逐 hunk 可核。
2. 整合后 dependency-present 实跑断言计数恰为 241 = prototype 实跑口径 240 加设计批准的 1 行 `ASSURANCE_UNLINK_LOG` ENOENT oracle。依据：design 测试策略 sizing 节——240 断言对应无该 oracle 的 308 行 prototype，「该注入替换与一行日志核对合计约 8 行」计入约 92 行整合预算。sizing 证据文档 `cbdbdde0e1e3ff4ceb2dc0279b1db83127a0ea9e:.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/prototype/round3-assurance-sizing-evidence.md` 正文所记 293 行/236 断言为修复旧 close 顺序 mutant 之前的早期测量，已过期；现行口径以 requirements 与 PLAN v5.7 确认的 308/400 行、240 断言为准（review round 1 实跑复现 rc0 与 checks=240）。
3. fail-closed 七类硬检查先于 `--dependency-absent` inert 分支执行；inert 判定用 `! -e` 与 `! -L` 双判，dangling symlink 走 fail-closed 而非 inert。依据：R2「provider 路径存在但损坏一律 rc1 无 PASS」不含 flag 例外；inert PASS 本来不作本片验收证据，flag 不应放行损坏 provider。
4. E1–E6 是允许的全部整合点；prototype blob 与候选文件的 `diff` 除 E1–E6 外必须为零，防止顺手改动打散 240 断言口径与实跑证据。
5. 终交付锚点 `session-snapshot-assurance-v1` 记入本文、ledger 完成锚点与 acceptance 报告；任务 2.6 的「产出」字段写 `tests/test-session-snapshot-assurance.sh`。依据：check-tasks 的孤儿产出检查只认 requirements 验收标准节正文，该路径在「主验证命令」行逐字出现，而锚点名只出现在 requirements frontmatter。

### 任务 1.1: 交付完整assurance候选文件

文件: 创建 `tests/test-session-snapshot-assurance.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/evidence/task-1.1-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/task-1.1-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/review-manifest.tsv`
消费: 无
产出: snapshot-assurance-matrix-v1
需求: R1, R2, R3, R4, R5, R6, R7, R8
必需: 是

候选文件 = `git show "$PROTO_SHA:$PROTO_ASSURANCE"`（308 行）加以下且仅以下六处整合。每处给出确切代码或确切转换规则；整合后全文约 349 行，必须 ≤400。

E1（CLI 解析与结构注释）：在 prototype 第 4 行 `repo=$(git -C "$here" rev-parse --show-toplevel)` 之后插入：

```bash
# 03b1 session snapshot assurance: provider-copy 动态矩阵。
# 结构: CLI 分流 -> inert/fail-closed -> 注入副本 -> 动态矩阵 -> 固定摘要。
# 成功唯一摘要: RESULT PASS  session snapshot assurance
# 注意: 注释只写摘要文字，不得包含固定摘要的 printf 调用（步骤 4/5 探针按该调用字面量的出现次数定位）。
case ${1-} in
  '' | all) ;;
  --dependency-absent) mode=absent ;;
  *) exit 1 ;;
esac
[[ $# -le 1 ]] || exit 1
```

E2（provider 路径固定到 repo root）：把 prototype 第 5 行 `provider=${SNAPSHOT_CORE:-$here/snapshot-core-r2.sh}` 整行替换为：

```bash
provider=$repo/common/.harness/lib/session-state-snapshot.sh
```

E3（inert 分流与 fail-closed 七类）：紧随 E2 之后插入：

```bash
if [[ ! -e $provider && ! -L $provider ]]; then
  printf 'RESULT PASS  session snapshot assurance\n'
  exit 0
fi
[[ -f $provider && ! -L $provider ]] || exit 1
bash -n "$provider" 2>/dev/null || exit 1
bash -c 'source "$1"' _ "$provider" >/dev/null 2>&1 || exit 1
for fn in _harness_session_snapshot_worker _harness_session_snapshot_write_core _harness_session_snapshot_read_core; do
  bash -c 'source "$1" && declare -F "$2" >/dev/null' _ "$provider" "$fn" >/dev/null 2>&1 || exit 1
done
for marker in CAPTURE_READY SNAPSHOT_MANAGED_BEFORE_OPEN MANAGED_EXPECTED_EUID \
  SNAPSHOT_EXPECTED_EUID SNAPSHOT_BEFORE_OPEN TEMP_BEFORE_PUBLISH PUBLISH_RESULT OS_ERROR; do
  [[ $(rg -c "HARNESS_TEST_MARKER_$marker" "$provider") == 1 ]] || exit 1
done
[[ $(rg -c 'renameat2' "$provider") == 1 ]] || exit 1
if rg -q 'os\.(replace|link|rename)\(' "$provider"; then exit 1; fi
if [[ ${mode-} == absent ]]; then
  printf 'RESULT PASS  session snapshot assurance\n'
  exit 0
fi
```

E4（注入自身失败即 rc1）：把 prototype 中 `python3 - "$provider" "$copy" <<'PY'` 行替换为 `python3 - "$provider" "$copy" <<'PY' || exit 1`，heredoc 正文逐字不动。

E5（`ASSURANCE_UNLINK_LOG` 注入点）：在 prototype 的 python heredoc `replacements` 字典中、键为 `"    raise Interrupted"` 的条目之后，插入一个条目（确切文本）：

```python
    "                try: os.unlink(temp, dir_fd=dir_fd)\n                except OSError as exc:": """                try:
                    os.unlink(temp, dir_fd=dir_fd)
                    if os.environ.get("ASSURANCE_UNLINK_LOG"): open(os.environ["ASSURANCE_UNLINK_LOG"], "a").write("success\\n")
                except OSError as exc:
                    if os.environ.get("ASSURANCE_UNLINK_LOG"): open(os.environ["ASSURANCE_UNLINK_LOG"], "a").write(errno.errorcode.get(exc.errno, "EUNKNOWN") + "\\n")""",
```

E6（rename 已提交窗口 ENOENT oracle）：对 prototype 信号窗口循环做四处逐字替换：(a) 把 `cleanup_log=$tmp/cleanup-log` 替换为 `cleanup_log=$tmp/cleanup-log` 加一行 `unlink_log=$tmp/unlink-log`（prototype 原文为连字符 `cleanup-log`，下划线写法在 308 行全文中出现 0 次）；(b) 把循环内 `  : >"$cleanup_log"` 替换为 `  : >"$cleanup_log"` 加一行 `  : >"$unlink_log"`；(c) 把 `    publish-success) ASSURANCE_PUBLISH=signal-success run_rc 143 _harness_session_snapshot_write_core project session alpha ;;` 替换为 `    publish-success) ASSURANCE_PUBLISH=signal-success ASSURANCE_UNLINK_LOG=$unlink_log run_rc 143 _harness_session_snapshot_write_core project session alpha ;;`；(d) 在 `  [[ $action != cleanup-close ]] || check_eq "$action all close attempts" 5 "$(wc -l <"$cleanup_log" | xargs)"` 行之后插入 `  [[ $action != publish-success ]] || check_eq "$action unlink errno" ENOENT "$(<"$unlink_log")"`。

- [ ] 步骤 1: 运行`test ! -e tests/test-session-snapshot-assurance.sh && bash tests/test-session-snapshot-assurance.sh`，确认红阶段失败为文件缺席 rc127、stdout 无 PASS；按固定六行 schema 写`$WORK/evidence/task-1.1-red.txt`并核`test -s "$WORK/evidence/task-1.1-red.txt"`。
- [ ] 步骤 2: 运行`test "$(git show "$PROTO_SHA:$PROTO_ASSURANCE" | wc -l)" -eq 308`核 blob 门；用 apply_patch 创建`tests/test-session-snapshot-assurance.sh`，内容 = prototype blob + E1–E6；运行`diff <(git show "$PROTO_SHA:$PROTO_ASSURANCE") tests/test-session-snapshot-assurance.sh`把 hunks 落日志，逐 hunk 核对只含 E1–E6、无其他差异，并核`test "$(wc -l <tests/test-session-snapshot-assurance.sh)" -le 400`。
- [ ] 步骤 3: 运行`test "$(shfmt --version)" = "v3.14.0"`与`shellcheck --version | rg -q '^version: 0.11.0$'`逐字核固定工具版本；对该单文件跑`shfmt -d -i 2 -ci -bn tests/test-session-snapshot-assurance.sh`（无输出）、`shellcheck -x --severity=warning tests/test-session-snapshot-assurance.sh`（rc0）、`bash -n tests/test-session-snapshot-assurance.sh`与`git diff --check`，全部通过。
- [ ] 步骤 4: dependency-present 实跑——分别运行`bash ./tests/test-session-snapshot-assurance.sh`与`bash ./tests/test-session-snapshot-assurance.sh all`，各自`>out 2>err`落盘后核 rc0、`printf 'RESULT PASS  session snapshot assurance\n' | cmp -s - out`、`test ! -s err`；断言计数：在仓库内`mktemp -d "$PWD/.count.XXXXXX"`中放目标副本，用 python3 把最后一处`printf 'RESULT PASS  session snapshot assurance\n'`前插入`printf 'checks=%d\n' "$checks" >&2`，跑 default 核`test "$(<err)" = "checks=241"`，随后删除临时目录。该定位的前提是全文恰 3 处此字面量：E3 的 provider-absent inert 分支（第 1 处）与 mode-absent inert 分支（第 2 处）、prototype 末行 active 出口（第 3 处）；计数对象是统一 `check_eq`/`run_rc` 计数器的累加值，E1 注释按 E1 内嵌约束只含摘要文字、不含此 printf 字面量，故 rindex 即末行 active 出口。argv 非法表`bash ./tests/test-session-snapshot-assurance.sh --bogus`、`bash ./tests/test-session-snapshot-assurance.sh all extra`、`bash ./tests/test-session-snapshot-assurance.sh --dependency-absent=x`逐行核 rc1 且 stdout 不含 PASS。
- [ ] 步骤 5: provider-absent 实跑——`git clone --no-local . "$tmp/r"`后`cp tests/test-session-snapshot-assurance.sh "$tmp/r/tests/"`并`rm "$tmp/r/common/.harness/lib/session-state-snapshot.sh"`，在`$tmp/r`分别跑无参数、`all`、`--dependency-absent`，核三者 rc0、stdout 逐字同一`RESULT PASS  session snapshot assurance\n`、stderr 0B。零 active case 的机械核验：对该副本用 python3 在第一处`printf 'RESULT PASS  session snapshot assurance\n'`（`index`，即 E3 provider-absent inert 分支）前插入`  printf 'checks=%d\n' "${checks:-0}" >&2`（两空格缩进与该分支一致；`set -u` 下 `checks=0` 在 prototype 第 97 行才初始化，inert 分支在其之前，必须用`${checks:-0}`；不能用步骤 4 的 rindex/`"$checks"` 探针——inert 流程在 E3 即`exit 0`，末行探针不可达、提前引用`"$checks"`会 unbound 崩溃），跑 default 核 rc0、stdout 逐字 inert 摘要、`test "$(<err)" = "checks=0"`。
- [ ] 步骤 6: fail-closed 七类逐类实跑——每类独立`git clone --no-local . "$tmp/fN"`、`cp`目标文件后造 fixture：(a)`rm` provider 后`mkdir`同名目录；(b)`rm`后`ln -s /dev/null`同名 symlink；(c)`printf 'if\n' >>`provider（bash -n 失败）；(d)`printf 'false\n' >>`provider（source 非零）；(e)`sed -i 's/_harness_session_snapshot_read_core/_harness_session_snapshot_read_core_x/g' provider`（三 export 缺一）；(f)`printf '# HARNESS_TEST_MARKER_OS_ERROR\n' >>`provider（anchor 两次）；(g)`printf '# renameat2\n' >>`provider（renameat2 两次）；逐类跑 default 核 rc1 且`! rg -q PASS out`，再跑`--dependency-absent`核同样 rc1 无 PASS（裁定 3）。
- [ ] 步骤 7: 提交——`git add -N tests/test-session-snapshot-assurance.sh`后核 working-tree `git diff --name-only`恰为该单文件、`git diff --numstat | awk '{s+=$1} END {print s+0}'`≤400；`git commit -m "test(session): add snapshot assurance matrix"`；设`TASK_HEAD=$(git rev-parse HEAD)`并核`git diff --name-only "$TASK_BASE" "$TASK_HEAD"`恰为该单文件、numstat 总和≤400、`git diff --name-only "$TASK_BASE" "$TASK_HEAD" -- common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh tests/lib/session-path-race-driver.py tests/test-session-path-races.sh common/.harness/lib/session-state-snapshot.sh tests/test-session-snapshot.sh`为空、`git status --porcelain`为空。
- [ ] 步骤 8: 生成 task brief/report、`review-package.sh TASK_BASE TASK_HEAD`及 evidence package，取得独立 diff review PASS；有 fix 则更新`TASK_HEAD`、重跑步骤 3–7 并交全新 reviewer。PASS 后运行`printf '1\ttask-1.1\t%s\t%s\t%s\tPASS\n' "$TASK_BASE" "$TASK_HEAD" "$REVIEWER" >>"$MANIFEST"`；随后分别 mark 1.1、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 2.1: 审计candidate并固定accepted HEAD

文件: 测试 `tests/test-session-snapshot-assurance.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/evidence/task-2.1-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/task-2.1-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/review-manifest.tsv`
消费: snapshot-assurance-matrix-v1
产出: assurance-accepted-head-v1
需求: R9
必需: 是

- [ ] 步骤 1: 运行`test -s "$WORK/task-2.1-report.md"`确认红阶段失败为报告缺席，按固定六行 schema 写 red 文件并核`test -s`；核 implementation clean 且`git rev-parse HEAD`为任务 1.1 的`TASK_HEAD`。
- [ ] 步骤 2: 保存六上游文件 before SHA（`sha256sum common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh tests/lib/session-path-race-driver.py tests/test-session-path-races.sh common/.harness/lib/session-state-snapshot.sh tests/test-session-snapshot.sh`）；核`test "$(shfmt --version)" = "v3.14.0"`与`shellcheck --version | rg -q '^version: 0.11.0$'`；只对 exact 单文件跑`shfmt -d -i 2 -ci -bn`、`shellcheck -x --severity=warning`、`bash -n`；分别运行 default 入口与`bash ./scripts/check.sh --offline`到独立日志，核 default 摘要逐字、`test "$(rg -c 'RESULT PASS  session snapshot assurance' offline.log)" = 1"`（offline 发现恰一次）且 offline 末行 PASS；再`sha256sum -c`比较 after SHA。
- [ ] 步骤 3: 核`git diff --name-only "$BASE_SHA" HEAD`恰为`tests/test-session-snapshot-assurance.sh`、numstat 总和≤400、`git diff --check`、clean，生成 green 报告和 evidence package；若发现源码缺陷则回流任务 1.1 修复并重 review，不在本任务改变 HEAD。
- [ ] 步骤 4: 交独立 reviewer 审 brief/report/evidence package 并取得 PASS，把当前 40 位 clean HEAD 固定为`ACCEPTED_HEAD`。
- [ ] 步骤 5: 运行`printf '2\ttask-2.1\t%s\t%s\t%s\tPASS\n' "$TASK_HEAD" "$TASK_HEAD" "$REVIEWER" >>"$MANIFEST"`；随后分别 mark 2.1、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 2.2: 验证完整历史checkout

文件: 测试 `tests/test-session-snapshot-assurance.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/evidence/task-2.2-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/task-2.2-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/review-manifest.tsv`
消费: assurance-accepted-head-v1
产出: assurance-full-checkout-v1
需求: R9
必需: 是

- [ ] 步骤 1: 运行`test -s "$WORK/task-2.2-report.md"`确认红阶段失败为报告缺席并写 red 文件；核 implementation `git rev-parse HEAD`逐字等于`ACCEPTED_HEAD`。
- [ ] 步骤 2: 创建临时目录，运行`git clone --no-local "$IMPLEMENTATION_WORKTREE" "$tmp/full"`并核 full 的`git rev-parse HEAD`逐字等于`ACCEPTED_HEAD`。
- [ ] 步骤 3: 在 full 中保存六上游文件 before SHA，分别运行 default 入口与`bash ./scripts/check.sh --offline`到独立日志；核 default 固定摘要逐字、`test "$(rg -c 'RESULT PASS  session snapshot assurance' offline.log)" = 1"`且 offline 末行 PASS，再比较 after SHA、`git status --porcelain`与`git diff` clean。
- [ ] 步骤 4: 写 green 报告/evidence package 并删除 full checkout；独立 review PASS 后运行`printf '3\ttask-2.2\t%s\t%s\t%s\tPASS\n' "$ACCEPTED_HEAD" "$ACCEPTED_HEAD" "$REVIEWER" >>"$MANIFEST"`。
- [ ] 步骤 5: 分别 mark 2.2、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 2.3: 验证真实depth-1 checkout

文件: 测试 `tests/test-session-snapshot-assurance.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/evidence/task-2.3-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/task-2.3-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/review-manifest.tsv`
消费: assurance-full-checkout-v1
产出: assurance-depth1-checkout-v1
需求: R9
必需: 是

- [ ] 步骤 1: 运行`test -s "$WORK/task-2.3-report.md"`确认红阶段失败为报告缺席并写 red 文件。
- [ ] 步骤 2: 运行`git clone --depth 1 "file://$IMPLEMENTATION_WORKTREE" "$tmp/depth1"`，核`git rev-parse HEAD`逐字等于`ACCEPTED_HEAD`、`test "$(git rev-list --count HEAD)" = 1`及`test -s .git/shallow`。
- [ ] 步骤 3: 保存六上游文件 before SHA，分别运行 default 入口与`bash ./scripts/check.sh --offline`到独立日志，核 default 固定摘要逐字、`test "$(rg -c 'RESULT PASS  session snapshot assurance' offline.log)" = 1"`且 offline 末行 PASS；比较 after SHA、diff/status clean。
- [ ] 步骤 4: 写 green 报告/evidence package 并删除 depth checkout；独立 review PASS 后运行`printf '4\ttask-2.3\t%s\t%s\t%s\tPASS\n' "$ACCEPTED_HEAD" "$ACCEPTED_HEAD" "$REVIEWER" >>"$MANIFEST"`。
- [ ] 步骤 5: 分别 mark 2.3、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 2.4: 验证exact rollback

文件: 测试 `tests/test-session-snapshot-assurance.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/evidence/task-2.4-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/task-2.4-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/review-manifest.tsv`
消费: assurance-depth1-checkout-v1
产出: assurance-rollback-v1
需求: R10
必需: 是

- [ ] 步骤 1: 运行`test -s "$WORK/task-2.4-report.md"`确认红阶段失败为报告缺席并写 red 文件。
- [ ] 步骤 2: 从 implementation `git clone --no-local "$IMPLEMENTATION_WORKTREE" "$tmp/rollback"`并核 HEAD=`ACCEPTED_HEAD`；运行`git rm tests/test-session-snapshot-assurance.sh`后提交普通 rollback commit，核`git diff --name-status HEAD~1 HEAD`恰为一行`D	tests/test-session-snapshot-assurance.sh`。
- [ ] 步骤 3: 在 rollback 运行`bash tests/test-session-snapshot.sh`（03b 基础测试，核逐字`RESULT PASS  session snapshot safety`）与`bash ./scripts/check.sh --offline`；核全绿、`! rg -q 'session snapshot assurance' offline.log`（assurance 摘要与发现 0 次）、`test ! -e tests/test-session-snapshot-assurance.sh`且 clean；candidate/full/depth-1 checkout 不被触碰。
- [ ] 步骤 4: 写 green 报告/evidence package 并删除 rollback；独立 review PASS 后运行`printf '5\ttask-2.4\t%s\t%s\t%s\tPASS\n' "$ACCEPTED_HEAD" "$ACCEPTED_HEAD" "$REVIEWER" >>"$MANIFEST"`。
- [ ] 步骤 5: 分别 mark 2.4、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 2.5: 验证03c顺序门

文件: 测试 `tests/test-session-snapshot-assurance.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/evidence/task-2.5-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/task-2.5-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/review-manifest.tsv`
消费: assurance-rollback-v1
产出: assurance-order-gate-v1
需求: R10
必需: 是

- [ ] 步骤 1: 运行`test -s "$WORK/task-2.5-report.md"`确认红阶段失败为报告缺席并写 red 文件。
- [ ] 步骤 2: 定义完整 ID`NEXT=2026-09-02-03c-session-write-interrupts`；运行`test ! -e "$PROJECT/specs/$NEXT"`、`test ! -e "$PROJECT/work/$NEXT"`，并要求`git show-ref --verify --quiet "refs/heads/spec/$NEXT"`返回 1。
- [ ] 步骤 3: 核`git worktree list --porcelain`不含`branch refs/heads/spec/$NEXT`及约定 worktree 绝对路径；若未来 work 目录缺席则 execution-base/manifest/task-brief 自然缺席，若存在任何同名或 symlink 立即失败。
- [ ] 步骤 4: 仅对`$PROJECT/specs/*/ledger.md`与`$PROJECT/work/*/{dispatch.tsv,execution-base.env}`存在文件运行 rg，禁止匹配`dispatch.*$NEXT|execution BASE.*$NEXT|spec/$NEXT`；不得搜索 PLAN/requirements 中的合法规划文字。
- [ ] 步骤 5: 写 green 报告/evidence package 并取得独立 review PASS；运行`printf '6\ttask-2.5\t%s\t%s\t%s\tPASS\n' "$ACCEPTED_HEAD" "$ACCEPTED_HEAD" "$REVIEWER" >>"$MANIFEST"`。
- [ ] 步骤 6: 分别 mark 2.5、apply_patch 写 ledger 锚点、sync-ledger。

### 任务 2.6: 收敛manifest、ledger与终交付

文件: 测试 `tests/test-session-snapshot-assurance.sh`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/evidence/task-2.6-red.txt` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/task-2.6-report.md` / 修改 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/review-manifest.tsv` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/acceptance/acceptance-report.md`
消费: assurance-order-gate-v1
产出: tests/test-session-snapshot-assurance.sh（终交付锚点 session-snapshot-assurance-v1 记入 ledger 完成锚点与 acceptance 报告）
需求: R9, R10
必需: 是

- [ ] 步骤 1: 运行`test -s "$WORK/acceptance/acceptance-report.md"`确认红阶段失败为报告缺席并写 red 文件；核`git rev-parse HEAD`=`ACCEPTED_HEAD`与 clean。
- [ ] 步骤 2: 汇总 candidate/full/depth/rollback/order 日志到 green 与 acceptance 报告（含 accepted HEAD、active 摘要、八 anchor 注入、`ASSURANCE_UNLINK_LOG` ENOENT oracle、exact1/400、241 断言口径），生成 evidence package 并取得独立 review PASS。
- [ ] 步骤 3: 运行`printf '7\ttask-2.6\t%s\t%s\t%s\tPASS\n' "$ACCEPTED_HEAD" "$ACCEPTED_HEAD" "$REVIEWER" >>"$MANIFEST"`。
- [ ] 步骤 4: 运行以下完整 manifest 核验（七行、六列、相邻连续、reviewer 非空、全 PASS）：

  ```bash
  awk -F '\t' -v base="$BASE_SHA" -v head="$ACCEPTED_HEAD" '
    BEGIN { split("task-1.1 task-2.1 task-2.2 task-2.3 task-2.4 task-2.5 task-2.6", ids, " ") }
    NF != 6 || $1 != NR || $2 != ids[NR] || $3 !~ /^[0-9a-f]{40}$/ || $4 !~ /^[0-9a-f]{40}$/ || $5 == "" || $6 != "PASS" { bad=1 }
    NR == 1 && $3 != base { bad=1 }
    NR > 1 && $3 != prev { bad=1 }
    { prev=$4 }
    END { exit bad || NR != 7 || prev != head }
  ' "$MANIFEST"
  ```

- [ ] 步骤 5: mark 任务 2.6 完成；用 apply_patch 写 ledger 完成锚点及 accepted HEAD、active 摘要、八 anchor、`ASSURANCE_UNLINK_LOG` 注入点、exact1/400、241 断言、full/depth/rollback/order 证据，再运行 sync-ledger。
- [ ] 步骤 6: 重跑`python3 /home/zzh0838/.agents/skills/spec/scripts/check-tasks.py "$TASKS"`、`python3 /home/zzh0838/.agents/skills/spec/scripts/check-req.py "$SPEC/requirements.md"`、`python3 /home/zzh0838/.agents/skills/spec/scripts/check-criteria.py "$SPEC/requirements.md"`、`python3 /home/zzh0838/.agents/skills/spec/scripts/check-analyze.py "$SPEC/requirements.md"`、candidate default/offline、`git diff --check`、clean 与任务 2.5 的 03c 顺序门；全部通过才进入 accept，任何 inert PASS 不得作为本片验收证据或解除后序门。
