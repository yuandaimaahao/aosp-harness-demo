# 2026-09-01-00-environment-seed-preflight 终止片实现计划

## Sizing 与 review slices

| task | owned files | estimate | summary high | review budget |
|---|---:|---:|---:|---:|
| 1 manifest/core/dispatcher | 3 | 260–320 | 100 | 9 min |
| 2 pre-commit mode | 1 | 60–85 | 80 | 3 min |
| 3 accept mode | 1 | 105–140 | 100 | 5 min |
| 4 self-test mode | 1 | 160–210 | 120 | 7 min |
| cumulative | 6 | 585–755 | each ≤120 | each <10 min |

Tasks-time high `755 <= 800`，每份summary high `<=120 <=160`。四任务文件不重叠；每个任务只实现一个稳定接口slice，并在下一个任务开始前完成独立diff review和修复。

## Controller protocol

门④通过后，controller只stage当前项目process documents/reviews，确认六个implementation paths与`evidence/`尚不存在、cached index此前为空，再创建process baseline commit。随后从exact base创建唯一owned worktree/branch，并断言clean：

```bash
set -euo pipefail
root=$(git rev-parse --show-toplevel)
project=.spec/2026-09-01-aosp-feature-minimal-checkout
test -z "$(git diff --cached --name-only)"
mapfile -t baseline_paths < <(rg --files "$project" | LC_ALL=C sort)
((${#baseline_paths[@]} > 0))
for path in "${baseline_paths[@]}"; do
  [[ "$path" == "$project/"* && "$path" != */evidence/* && "$path" != common/* ]]
done
git add -- "${baseline_paths[@]}"
git diff --cached --check -- . ':(exclude).spec/2026-09-01-aosp-feature-minimal-checkout/research/raw/**'
test "$(git diff --cached --name-only | LC_ALL=C sort)" = "$(printf '%s\n' "${baseline_paths[@]}")"
git commit -m 'docs(spec): freeze aosp minimal-checkout process baseline'
base_sha=$(git rev-parse HEAD)
task_worktree=$(mktemp -d /tmp/aosp-minimal-terminal.XXXXXX)
rmdir "$task_worktree"
task_branch="spec/aosp-minimal-terminal-${base_sha:0:12}"
git worktree add -b "$task_branch" "$task_worktree" "$base_sha"
test "$(git -C "$task_worktree" rev-parse HEAD)" = "$base_sha"
test -z "$(git -C "$task_worktree" status --porcelain)"
```

所有red/green/report/review acceptance assets由controller写到main worktree的同名project目录，不进入task branch/source diff。以下helper对public mode逐字断言rc0、one-line stdout和empty stderr；失败输出留在显式temp files供报告引用：

```bash
run_exact() {
  local expected="$1"
  shift
  local out err
  out=$(mktemp /tmp/aosp-terminal-out.XXXXXX)
  err=$(mktemp /tmp/aosp-terminal-err.XXXXXX)
  "$@" >"$out" 2>"$err"
  test ! -s "$err"
  test "$(wc -l <"$out")" -eq 1
  test "$(sed -n '1p' "$out")" = "$expected"
  rm -f -- "$out" "$err"
}
```

每个任务在`$task_worktree`中记录`task_parent=$(git rev-parse HEAD)`；实现/修复后都用下列base-relative prospective block。review fix只amend当前tip，PASS前不开始下一任务，因此不会重写已消费的reviewed commit。所有path/whitespace/numstat从task parent或frozen base到prospective index计算，不使用隐式`HEAD..index`：

```bash
set -euo pipefail
commit_task() {
  local task_parent="$1" subject="$2" base_sha="$3"
  shift 3
  local -a owned_paths=("$@")
  git add -- "${owned_paths[@]}"
  git diff --cached "$task_parent" --check
  test "$(git diff --cached "$task_parent" --name-only | LC_ALL=C sort)" = "$(printf '%s\n' "${owned_paths[@]}")"
  git diff --cached "$base_sha" --check
  git diff --cached "$base_sha" --numstat | awk 'NF!=3 || $1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+$/ {bad=1} {n+=$1+$2} END {exit bad || n>800}'
  if [[ "$(git rev-parse HEAD)" == "$task_parent" ]]; then
    git commit -m "$subject"
  else
    test "$(git rev-parse HEAD^)" = "$task_parent"
    git commit --amend --no-edit
  fi
}
```

每个candidate由fresh independent reviewer审`task_parent..task_sha`；FAIL时只改当前owned paths、重跑该任务全部oracle和上块、amend、重新生成`<=160`行report并派fresh reviewer。PASS后controller运行`mark-task-done.py`并用`apply_patch`追加唯一`- 任务 N: 完成 commits=[40-lower-hex] report=.spec/2026-09-01-aosp-feature-minimal-checkout/work/2026-09-01-00-environment-seed-preflight/task-N-report.md review=.spec/2026-09-01-aosp-feature-minimal-checkout/work/2026-09-01-00-environment-seed-preflight/review-task-N-PARENT12-SHA12.md`，再用`sync-ledger.py`只读核对。

四任务PASS后，final gate以`pre-commit --require-complete`验证base→tip六路径/≤800，再要求main HEAD仍等于base；main执行`git merge --no-ff "$task_branch" -m 'merge(spec): environment seed supersession validator'`。controller向working ledger追加唯一`- merge: 完成 commits=[MERGE_SHA] parent1=[BASE_SHA] parent2=[TIP_SHA]`，逐字检查四task/merge anchors及report files，然后运行accept。若main漂移则fail closed为`BASE_HEAD_MISMATCH`：保留旧branch证据，从新main重复baseline→四task replay/review，不amend/reparent旧commits。成功accept与retro落盘后，controller执行`git worktree remove "$task_worktree"`和`git branch -d "$task_branch"`；失败时保留该唯一owned worktree，不创建同名重试。

Final exact shape如下。merge前在task worktree运行前两条`run_exact`；merge后从main解析linear task SHAs。controller用`mark-task-done.py`标四个状态并用`apply_patch`写五条由这些变量展开的exact ledger lines，随后每条`grep -Fxc`必须等于1、每个report/review path必须存在，再运行sync/accept：

```bash
run_exact 'RESULT PASS environment-seed-preflight-supersession-self-test' python3 "$task_worktree/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/verify-supersession.py" self-test
run_exact 'RESULT PASS environment-seed-preflight-supersession-pre-commit' python3 "$task_worktree/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/verify-supersession.py" pre-commit --project-root "$task_worktree" --base-commit "$base_sha" --manifest "$task_worktree/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/supersession.json" --require-complete
test "$(git rev-parse HEAD)" = "$base_sha"
git merge --no-ff "$task_branch" -m 'merge(spec): environment seed supersession validator'
merge_sha=$(git rev-parse HEAD)
tip_sha=$(git rev-parse "$task_branch")
task4_sha="$tip_sha"
task3_sha=$(git rev-parse "$task4_sha^")
task2_sha=$(git rev-parse "$task3_sha^")
task1_sha=$(git rev-parse "$task2_sha^")
test "$(git rev-parse "$task1_sha^")" = "$base_sha"
spec="$PWD/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight"
for task_id in 1 2 3 4; do
  python3 /home/zzh0838/.agents/skills/spec/scripts/mark-task-done.py "$spec/tasks.md" "$task_id"
done
# controller apply_patch appends exact task lines derived from task1_sha..task4_sha and their parents,
# then exact: - merge: 完成 commits=[$merge_sha] parent1=[$base_sha] parent2=[$tip_sha]
task_shas=("$task1_sha" "$task2_sha" "$task3_sha" "$task4_sha")
task_parents=("$base_sha" "$task1_sha" "$task2_sha" "$task3_sha")
for index in 0 1 2 3; do
  task_id=$((index + 1))
  sha=${task_shas[$index]}
  parent=${task_parents[$index]}
  report=".spec/2026-09-01-aosp-feature-minimal-checkout/work/2026-09-01-00-environment-seed-preflight/task-$task_id-report.md"
  review=".spec/2026-09-01-aosp-feature-minimal-checkout/work/2026-09-01-00-environment-seed-preflight/review-task-$task_id-${parent:0:12}-${sha:0:12}.md"
  line="- 任务 $task_id: 完成 commits=[$sha] report=$report review=$review"
  test "$(grep -Fxc -- "$line" "$spec/ledger.md")" -eq 1
  test -f "$PWD/$report"
  test -f "$PWD/$review"
done
merge_line="- merge: 完成 commits=[$merge_sha] parent1=[$base_sha] parent2=[$tip_sha]"
test "$(grep -Fxc -- "$merge_line" "$spec/ledger.md")" -eq 1
python3 /home/zzh0838/.agents/skills/spec/scripts/sync-ledger.py "$spec/ledger.md" --repo "$PWD"
run_exact 'RESULT PASS environment-seed-preflight-supersession-acceptance' python3 "$spec/work/verify-supersession.py" accept --project-root "$PWD" --base-commit "$base_sha" --manifest "$spec/supersession.json" --merge-commit "$merge_sha" --ledger "$spec/ledger.md"
```

### 任务 1: 固化 manifest、closed core 与 dispatcher

文件: 创建 `.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/supersession.json`, `.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/supersession_lib.py`, `.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/verify-supersession.py`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-09-01-aosp-feature-minimal-checkout/work/2026-09-01-00-environment-seed-preflight/task-1-red.txt`, `.spec/2026-09-01-aosp-feature-minimal-checkout/work/2026-09-01-00-environment-seed-preflight/task-1-report.md`
消费: 无
产出: `supersession/v1` manifest, `supersession-core/v1` closed loader/PLAN validator
需求: R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, R13, R14, R15, R16, R17, R18, R19, R20, R21, R22, R23, R24, R25, R26, R27
必需: 是

- [ ] 步骤 1: 跑 `python3 .spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/verify-supersession.py self-test`，确认红阶段rc nonzero/Python cannot-open-file/无PASS，并逐字记录`.spec/2026-09-01-aosp-feature-minimal-checkout/work/2026-09-01-00-environment-seed-preflight/task-1-red.txt`。
- [ ] 步骤 2: 创建canonical `supersession.json`，写process base、ordered replacements、R1–R27 owners、exact budgets和design中bytewise-sorted六路径。
- [ ] 步骤 3: 创建`supersession_lib.py`的`ContractError`与duplicate-aware JSON loader，拒绝missing/unknown/duplicate keys、array order/duplicate、bool/negative、owner/DAG/budget/base/path错误并映射design exact codes。
- [ ] 步骤 4: 在`supersession_lib.py`实现`validate_plan`，独立校验PLAN v6、DECISIONS merge裁定、sizing exact values及`check-plan.py` exit0。
- [ ] 步骤 5: 创建`verify-supersession.py` argparse dispatcher，只允许`self-test`、`pre-commit [--require-complete]`、`accept --merge-commit`，按mode exact路径动态加载`work/modes/*.py`；module缺席精确exit1/empty stdout/`RESULT FAIL supersession CAPABILITY_UNAVAILABLE`。
- [ ] 步骤 6: 跑 `python3 -c 'import pathlib,sys; sys.path.insert(0,sys.argv[1]); import supersession_lib as s; m=s.load_and_validate_manifest(pathlib.Path(sys.argv[2])); s.validate_plan(pathlib.Path(sys.argv[3]),m); print("RESULT PASS supersession-core")' "$PWD/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work" "$PWD/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/supersession.json" "$PWD"`，确认exact PASS/empty stderr。
- [ ] 步骤 7: 在同一shell定义`commit_task`后运行 `commit_task "$task_parent" 'docs(spec): add supersession manifest core' "$base_sha" "$manifest_path" "$core_path" "$dispatcher_path"`，写`<=100`行report并交fresh diff review。

### 任务 2: 实现 base-relative pre-commit mode

文件: 创建 `.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/modes/pre_commit.py`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-09-01-aosp-feature-minimal-checkout/work/2026-09-01-00-environment-seed-preflight/task-2-red.txt`, `.spec/2026-09-01-aosp-feature-minimal-checkout/work/2026-09-01-00-environment-seed-preflight/task-2-report.md`
消费: `supersession-core/v1` closed loader/PLAN validator
产出: `pre-commit-mode/v1` linear ancestry/prospective scope gate
需求: R24
必需: 是

- [ ] 步骤 1: 从manifest读取`base_sha`后跑 `python3 "$PWD/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/verify-supersession.py" pre-commit --project-root "$PWD" --base-commit "$base_sha" --manifest "$PWD/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/supersession.json"`，确认红阶段exit1/empty stdout/exact stderr `RESULT FAIL supersession CAPABILITY_UNAVAILABLE`并记录evidence。
- [ ] 步骤 2: 创建`modes/pre_commit.py`的`run(args,context)`，要求base=manifest、HEAD为base的linear no-merge descendant、base→prospective index paths为六路径子集、tracked/untracked common为空；`--require-complete`要求六路径全集和cumulative numstat≤800。
- [ ] 步骤 3: 用temp Git fixture逐项验证base mismatch、merge ancestry、extra path、tracked/untracked common分别精确返回`BASE_HEAD_MISMATCH`/`COMMIT_SCOPE_MISMATCH`/`COMMON_SCOPE_VIOLATION`，合法subset stdout exact pre-commit PASS且stderr empty。
- [ ] 步骤 4: 在同一shell定义`commit_task`后运行 `commit_task "$task_parent" 'feat(spec): add supersession pre-commit mode' "$base_sha" "$precommit_path"`，写`<=80`行report并交fresh diff review。

### 任务 3: 实现 merge acceptance 与 isolated rollback

文件: 创建 `.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/modes/accept.py`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-09-01-aosp-feature-minimal-checkout/work/2026-09-01-00-environment-seed-preflight/task-3-red.txt`, `.spec/2026-09-01-aosp-feature-minimal-checkout/work/2026-09-01-00-environment-seed-preflight/task-3-report.md` / 验证 `common/tests/test-harness.sh`, `common/.harness/bin/check-parity.sh`, `common/.harness/features/dev-sidebar/verify-sidebar.sh`
消费: `supersession-core/v1` closed loader/PLAN validator
产出: `accept-mode/v1` exact ledger/two-parent merge/revert gate
需求: R24, R25
必需: 是

- [ ] 步骤 1: 从manifest读取`base_sha`后跑 `python3 "$PWD/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/verify-supersession.py" accept --project-root "$PWD" --base-commit "$base_sha" --manifest "$PWD/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/supersession.json" --merge-commit 0000000000000000000000000000000000000000 --ledger "$PWD/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/ledger.md"`，确认module缺席红阶段exact `CAPABILITY_UNAVAILABLE`并记录evidence。
- [ ] 步骤 2: 创建`modes/accept.py` exact-line ledger parser，要求四条task anchors与一条merge anchor唯一、lower-hex且SHA/parent/tip一致；missing/duplicate/malformed/wrong分别固定ledger codes。
- [ ] 步骤 3: 实现two-parent merge验证：parent1=base、parent2=task4 tip、parent1→merge path set=manifest六路径、task chain linear且四task commits各只创建其owned paths。
- [ ] 步骤 4: 实现`validate_reverted_paths`与temp worktree `git revert -m 1 --no-edit`，验六路径消失/process baseline仍在；运行三条old harness regression并精确核对rc/末行，finally可靠移除temp worktree。
- [ ] 步骤 5: 运行 `python3 "$PWD/.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/modes/accept.py" self-test`，用synthetic two-parent merge/ledger fixture确认exact `RESULT PASS supersession-accept-mode-self-test`/empty stderr，并覆盖merge parent/scope、ledger grammar、leftover与regression failure codes。
- [ ] 步骤 6: 在同一shell定义`commit_task`后运行 `commit_task "$task_parent" 'feat(spec): add supersession accept mode' "$base_sha" "$accept_path"`，写`<=100`行report并交fresh diff review。

### 任务 4: 实现完整 mutation self-test 与 cumulative gate

文件: 创建 `.spec/2026-09-01-aosp-feature-minimal-checkout/specs/2026-09-01-00-environment-seed-preflight/work/modes/self_test.py`
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-09-01-aosp-feature-minimal-checkout/work/2026-09-01-00-environment-seed-preflight/task-4-red.txt`, `.spec/2026-09-01-aosp-feature-minimal-checkout/work/2026-09-01-00-environment-seed-preflight/task-4-report.md`
消费: `supersession-core/v1` closed loader/PLAN validator, `pre-commit-mode/v1` linear ancestry/prospective scope gate, `accept-mode/v1` exact ledger/two-parent merge/revert gate
产出: `supersession-validator/v1` complete mutation oracle and final six-path gate
需求: R24
必需: 是

- [ ] 步骤 1: 跑dispatcher `self-test`，确认module缺席红阶段exact `CAPABILITY_UNAVAILABLE`并记录evidence。
- [ ] 步骤 2: 创建table-driven manifest/document mutations，独立覆盖duplicate/missing/unknown/type/order、replacement/DAG、owner、budget、path、PLAN、DECISIONS、sizing，每例断言rc1/empty stdout/exact design code stderr。
- [ ] 步骤 3: 创建table-driven Git/accept mutations，独立覆盖base/ancestry/common、merge parent/path、task owned path、ledger exact grammar、post-revert leftover和regression failure；五个承重case必须subprocess穿过真实public mode。
- [ ] 步骤 4: 跑dispatcher `self-test`，用临时stdout/stderr文件逐字确认rc0、stdout只含`RESULT PASS environment-seed-preflight-supersession-self-test`一行、stderr empty。
- [ ] 步骤 5: 在同一shell定义`commit_task`后运行 `commit_task "$task_parent" 'test(spec): cover supersession validator matrix' "$base_sha" "$selftest_path"`，写`<=120`行report并交fresh diff review。
- [ ] 步骤 6: 四任务review PASS后从manifest重读base，跑dispatcher `pre-commit ... --require-complete`并逐字确认rc0/exact one-line pre-commit PASS/empty stderr；以`git diff "$base_sha"..HEAD --numstat`确认六路径cumulative non-generated≤800，才允许controller创建final merge。
