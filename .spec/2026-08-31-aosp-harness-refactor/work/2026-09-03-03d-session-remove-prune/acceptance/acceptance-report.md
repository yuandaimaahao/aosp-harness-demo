# 03d session-remove-prune 验收报告

- spec: 2026-09-03-03d-session-remove-prune
- 终交付锚点: `session-state-provider-v1`
- execution BASE: `d8c2baaee20c52c2f4bac88eb6d4938af2d61516`
- accepted HEAD: `388a83d5816659428e510bd9540d2a88cc2613e7`（任务 1.3 交付、任务 2.1 审计后固定）

## 交付物

- `common/.harness/lib/session-state-remove.sh`（110 行，任务 1.1，commit `0bb53a040249ddb5fef1a16c89e6d99a7710cd25`）：source-inert 的 remove 模块，`_harness_session_write_with_signals` 单检查 guard 与唯一私有 export `_harness_session_remove_core`；non-creating verified remove + `PRUNE_BEFORE_IDENTITY` 自底向上 prune；unsafe ID/arity rc2 固定 stderr；wrong-mode rc2 不删除。
- `common/.harness/lib/session-state.sh`（46 行，任务 1.2，commit `df38c34513b9c4afed80216214e65f4ea3666869`，amend 单提交）：thin aggregator——preflight 五模块 `[[ -f && -r ]]` → foundation→path→snapshot→signals→remove 唯一顺序静默 source（各 `2>/dev/null`）→ 9 个预期 export 逐个点名 → 全部通过才进入纯四转接定义 + `HARNESS_SESSION_STATE_PROVIDER_VERSION=1` marker 赋值的单临界区；任一失败静默 rc1、双流空、五 API 不定义、marker 不设。
- `tests/test-session-state.sh`（204 行，任务 1.3）与 `tests/coverage.d/03d-session-state.md`（18 行，03d 独占 coverage fragment，不触碰 `tests/COVERAGE.md`），commit `388a83d5816659428e510bd9540d2a88cc2613e7`：默认发现集成测试，只接受无参数/`all`/`--dependency-absent`/`--session-provider-fixture` 五值。

## active 摘要与 checks 口径

- dependency-present default：rc0、stdout 逐字节等于固定摘要 `RESULT PASS  session state\n`（`cmp -s` 通过）、stderr 0B。
- dependency-present all：同上，stdout 与 default 逐字一致。
- checks 计数口径：计数探针（末处 printf 前插 `checks=%d`）default 与 all 的 err 逐字一致，均为 `checks=72`（N=72>0）；本片 dependency-present 完整矩阵口径 checks=72。
- provider-absent 三态（无参数/all/`--dependency-absent`）：同一 inert 摘要、checks=0 探针证实零 active case；signals export 改名抽查同为 inert。
- argv 非法表五行（`--bogus` / `all extra` / `--dependency-absent=x` / `--session-provider-fixture` 缺值 / bogus 值）：均 rc1 且 stdout 不含 PASS。
- 五个 `--session-provider-fixture` 合法取值（missing-foundation/missing-path/missing-snapshot/missing-signals/missing-remove）：各 rc0、stdout 逐字同一固定摘要、stderr 0B。

## 双 anchor 注入机制

- 测试在 `mktemp -d` provider 副本上以 python3 文本注入，不改已提交模块：
  - EIO anchor：`pass  # HARNESS_TEST_MARKER_OS_ERROR` 后注入 `raise OSError(errno.EIO, ...)` → remove rc1、stdout 空、stderr 逐字 `error: session state operation failed\n`。
  - swap anchor：`pass  # PRUNE_BEFORE_IDENTITY` 后注入换入攻击（rename + 同名 mkdir）→ rc2、stderr 逐字 `error: unsafe session state\n`，`session` 与 `session.held` 两目录均保留。

## 两 mutant 自反证（红阶段活性证明）

- mutant-a（删 `PRUNE_BEFORE_IDENTITY` 后 identity 三方核对，直接 rmdir）：确定性 rc1 无 PASS，stdout `RESULT FAIL session state checks=72 failures=3`，stderr 恰三行换入攻击核对 FAIL（`swap rc want=2 got=0` / `swap stderr bytes want=0 got=1` / `swap both dirs retained want=yes got=no`）。
- mutant-b（feature stat ENOENT 分支改为不进入 prune 循环）：确定性 rc1 无 PASS，stdout `RESULT FAIL session state checks=72 failures=1`，stderr 恰一行 `missing feature still prunes want=0 got=1`——幂等 prune 行确定性 FAIL（空层级残留）。
- 两 mutant 均 `git clone --no-local` 内注入，已提交模块零改动，临时 clone 已删除。

## exact4/400

- `git diff --name-only $BASE_SHA $ACCEPTED_HEAD` 恰为 EXACT4 四文件（git 输出序）：`common/.harness/lib/session-state-remove.sh` / `common/.harness/lib/session-state.sh` / `tests/coverage.d/03d-session-state.md` / `tests/test-session-state.sh`。
- `git diff --numstat $BASE_SHA $ACCEPTED_HEAD` 总和 378 ≤ 400（remove 110 + aggregator 46 + fragment 18 + test 204）。
- 上游九 tracked 文件范围 diff 为空；`git diff --check` rc0；worktree clean。

## 六类 inert fixture

- 五 missing-*（missing-foundation/missing-path/missing-snapshot/missing-signals/missing-remove）+ aggregator-absent 自愿加严，共六类：rc 非零、双流空（aggregator-absent 不断言双流）、marker 未设、完整五 API predicate 为 false、同名哨兵函数不被当作 capability。

## 五路验证结论

1. candidate（任务 2.1）：工具版本逐字核 shfmt `v3.14.0` / ShellCheck version field `0.11.0` 后，只对本片三个 shell 文件跑 shfmt/shellcheck/bash -n/`git diff --check` 全过；default 摘要逐字 `RESULT PASS  session state\n`；offline 本入口自动发现恰 1 次（`RESULT PASS  session state$` 行尾锚区别于 foundation 摘要）、末行 PASS；上游九 tracked 文件 SHA-256 测试前后不变。PASS。
2. full checkout（任务 2.2）：`git clone --no-local` 完整历史 checkout，HEAD 逐字等于 ACCEPTED_HEAD、`git rev-list --count HEAD`=198；default 摘要逐字一致、offline 发现恰 1 次末行 PASS、上游九文件 SHA 不变、status/diff clean。PASS。
3. depth-1 checkout（任务 2.3）：`git clone --depth 1 file://...` 真实浅克隆，`git rev-list --count HEAD`=1、`.git/shallow` 恰 1 行；default 摘要逐字一致、offline 发现恰 1 次末行 PASS、上游九文件 SHA 不变、clean。PASS。
4. exact rollback（任务 2.4）：一次性 clone 内 rollback commit 恰为四行 `D`（只删本片四交付文件）；03b 基础测试逐字 `RESULT PASS  session snapshot safety`、03b1 assurance 入口逐字 `RESULT PASS  session snapshot assurance`、03c signals 入口逐字 `RESULT PASS  session write interrupts`、offline 本入口发现 0 次且末行 PASS；rollback commit 不 push、不落真实分支；candidate/full/depth-1 checkout 不被触碰。PASS。
5. 03e 顺序门（任务 2.5）：nullglob off 前提下，下一切片 spec 目录/work 目录缺席、spec 分支零匹配、worktree 零匹配、ledger/dispatch/execution-base 共 17 个限定域文件 scoped rg 零匹配——dependency-present active 证据、exact4/400 与全 PASS manifest 入 ledger 前下一切片资产物理缺席成立。PASS（次要 1：报告未注明 scoped rg 在仓库根跑 17 文件 vs worktree 16 文件，两处均独立复跑零匹配，结论不受影响，备案）。

## 逐任务 review

- review manifest 八行（task-1.1、1.2、1.3、2.1–2.5）全部 reviewer 非空且 PASS；任务 1.2 经两轮独立 review（round1 阻断 finding=语法错模块经 source 泄漏 stderr 违反 R6 双流空，修复为五个 source 各加 `2>/dev/null` 并 amend 保持单提交，全新 reviewer round2 PASS）。
- 本报告与 evidence package 交全新独立 agent review；PASS 后由 controller 追加 manifest 第 9 行（task-2.6）、awk 全量核验、mark 2.6、写 ledger 完成锚点并重跑终门（含 03e 顺序门复核）。

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03d-session-remove-prune/evidence/task-2.6-red.txt
