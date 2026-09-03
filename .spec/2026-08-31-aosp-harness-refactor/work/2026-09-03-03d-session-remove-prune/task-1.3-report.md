# task-1.3 report: 一次性交付完整默认发现集成测试与 coverage fragment

## task

task-1.3: 创建 `tests/test-session-state.sh`（默认发现集成测试：CLI 四态分流、remove 矩阵、aggregator 发布面、双 anchor 注入行、六类 inert fixture、固定摘要）与 `tests/coverage.d/03d-session-state.md`（03d 独占 coverage fragment，不触碰 `tests/COVERAGE.md`），含红阶段双 mutant 自反证。

## base

df38c34513b9c4afed80216214e65f4ea3666869

## head

388a83d5816659428e510bd9540d2a88cc2613e7

## files

- `tests/test-session-state.sh`（新建，204 行 ≤ 205）
- `tests/coverage.d/03d-session-state.md`（新建，18 行 ≤ 25）
- execution BASE `d8c2baaee20c52c2f4bac88eb6d4938af2d61516`..HEAD 累计恰 EXACT4 四文件（remove 110 + aggregator 46 + fragment 18 + test 204）、numstat 总和 378 ≤ 400，上游九 tracked 文件零变更

## M2 行数纪律（门③遗留）

- 测试文件 204 ≤ 205；fixture 表驱动区段实际消耗：`run_fixture()` 78–103 共 26 行 + 六类循环 195–198 共 4 行；mutant/anchor 注入区段（三树复制循环 + python3 heredoc 三注入）173–189 共 17 行；fragment 18 ≤ 25；累计 numstat 378 ≤ 400。未超预算，无需停手上报；oracle 语义零压缩。

## commands

- 红：`test ! -e tests/test-session-state.sh && bash tests/test-session-state.sh` → rc127，stdout 空（无 PASS），stderr 报文件缺席
- TASK_BASE 衔接：`git rev-parse HEAD` 逐字等于任务 1.2 TASK_HEAD `df38c34513b9c4afed80216214e65f4ea3666869`（manifest 相邻连续）
- 行数门：`wc -l` 测试 204 ≤ 205、fragment 18 ≤ 25；`rg -cF "printf 'RESULT PASS  session state\n'"` = 2（裁定 2 前提：inert 出口第 1 处、active 末行第 2 处）；`git diff --name-only -- tests/COVERAGE.md` 为空
- 静态门：shfmt v3.14.0 `-d -i 2 -ci -bn` 无输出 rc0；ShellCheck 0.11.0 `-x --severity=warning` rc0（两处 `# shellcheck source=/dev/null` 指令：动态 source provider 副本与 aggregator，同 03c 先例）；`bash -n` rc0；`git diff --check` rc0；`! rg -q setsid` 负向断言通过（裁定 4）
- dependency-present 实跑：`bash ./tests/test-session-state.sh` 与 `... all` 各 rc0，stdout 逐字节 `RESULT PASS  session state\n`（cmp 核），stderr 0B
- checks 计数探针：仓库内 `mktemp -d "$PWD/.count.XXXXXX"` 放副本，python3 rindex 定位末处 printf 字面量前插 `printf 'checks=%d\n' "$checks" >&2`，default 与 all 各跑一次：两 err 逐字一致均为 `checks=72`（N=72>0，本片 dependency-present 完整矩阵口径），stdout 与无探针跑逐字一致；临时目录已删除
- argv 非法表五行（`--bogus` / `all extra` / `--dependency-absent=x` / `--session-provider-fixture` 缺值 / `--session-provider-fixture bogus`）：各 rc1 且 stdout 不含 PASS（均 0B）
- 五个 `--session-provider-fixture` 合法取值（missing-foundation/missing-path/missing-snapshot/missing-signals/missing-remove）：各 rc0、stdout 逐字同一固定摘要、stderr 0B
- 双 mutant 自反证（`git clone --no-local` 内注入，已提交模块零改动）：(a) 删 `PRUNE_BEFORE_IDENTITY` 后 identity 三方核对（直接 rmdir）→ 测试 rc1、stdout `RESULT FAIL session state checks=72 failures=3` 无 PASS，stderr 恰 `swap rc want=2 got=0`、`swap stderr bytes want=0 got=1`、`swap both dirs retained want=yes got=no` 三行——换入攻击行确定性 FAIL；(b) feature stat ENOENT 分支改为 `raise SystemExit(0)`（不进入 prune 循环）→ 测试 rc1、stdout `RESULT FAIL session state checks=72 failures=1` 无 PASS，stderr 恰 `missing feature still prunes want=0 got=1` 一行——幂等 prune 行确定性 FAIL（空层级残留）；两 mutant rc/双流落入 `mutant-a.*.log`/`mutant-b.*.log`，临时 clone 已删除
- provider-absent 隔离实跑：clone 内放入候选两文件并删除 aggregator，无参数/`all`/`--dependency-absent` 三者各 rc0、stdout 逐字同一 inert 摘要、stderr 0B；python3 index 首处 printf 字面量前插两空格缩进 `printf 'checks=%d\n' "${checks:-0}" >&2` 探针后 default rc0、stdout 逐字 inert 摘要、err 逐字 `checks=0`（零 active case 机械核验）；另起 clone 把 signals 模块 `_harness_session_write_with_signals` 全局改名后 default 同 rc0、同一 inert 摘要、stderr 0B；两个临时 clone 已删除
- 提交：`git add -N` 核 working-tree name-only 恰两文件（git tree 序 fragment 在前）、numstat 222 ≤ 230 后，真 `git add` 并 `git commit -m "test(session): add complete provider integration matrix"`；execution BASE..HEAD name-only 逐字等于 EXACT4、numstat 378 ≤ 400、`-- $UPSTREAM9` 为空、`git status --porcelain` 为空

## results

- 红阶段：rc127，文件缺席，stdout 无 PASS（证据见下）
- 行数/字面量门：204+18 行、printf 字面量恰 2 处、COVERAGE.md 零变更
- 静态门：shfmt rc0 无输出 / shellcheck rc0 / bash -n rc0 / git diff --check rc0 / 无 setsid
- dependency-present：default 与 all 各 rc0、固定摘要逐字、stderr 0B；checks=72（default/all 探针一致）；argv 非法表 5/5 rc1 无 PASS；五 fixture 取值 5/5 rc0 同一摘要 stderr 0B
- 双 mutant：(a) rc1 failures=3 换入攻击行 FAIL 无 PASS；(b) rc1 failures=1 幂等 prune 行 FAIL 无 PASS——两 oracle 均为确定性自反证
- provider-absent：三 CLI 面 + 改名 clone 全部同一 inert 摘要 rc0 stderr 0B，checks=0 探针证实零 active case
- 提交门：TASK_BASE 衔接任务 1.2 HEAD；working-tree numstat 222 ≤ 230；execution BASE..HEAD 恰 EXACT4、numstat 378 ≤ 400、上游九文件零变更、worktree clean

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/evidence/task-1.3-red.txt
