# 2026-09-02-03b1-session-snapshot-assurance 验收报告

## 交付物与锚点

- 终交付（唯一源码产出）：`tests/test-session-snapshot-assurance.sh`（346 行）。
- 终交付锚点：`session-snapshot-assurance-v1`。
- accepted HEAD：`c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`（任务 2.1 审计后固定，implementation worktree 当前 HEAD 逐字相等且 clean）。
- execution BASE：`8a164f212c398a95703a38fb919af2b31c6e1662`。
- active 成功唯一摘要（逐字，stdout 精确为该文本加单个 LF，stderr 空，rc0）：

  ```
  RESULT PASS  session snapshot assurance
  ```

## 矩阵结构要点

- 八 anchor 注入点（均非 capability marker，注入前核对原文各精确一次）：`HARNESS_TEST_MARKER_CAPTURE_READY`、`HARNESS_TEST_MARKER_SNAPSHOT_MANAGED_BEFORE_OPEN`、`HARNESS_TEST_MARKER_MANAGED_EXPECTED_EUID`、`HARNESS_TEST_MARKER_SNAPSHOT_EXPECTED_EUID`、`HARNESS_TEST_MARKER_SNAPSHOT_BEFORE_OPEN`、`HARNESS_TEST_MARKER_TEMP_BEFORE_PUBLISH`、`HARNESS_TEST_MARKER_PUBLISH_RESULT`、`HARNESS_TEST_MARKER_OS_ERROR`。
- `ASSURANCE_UNLINK_LOG` ENOENT oracle：rename 已提交窗口行逐字替换 finally 中 owned temp 的 unlink 调用点（exact-once 非 anchor 文本点），副本把 unlink 结果追加到日志；该窗口行核对日志唯一一行恰为 `ENOENT`，非 ENOENT 吞错即 FAIL。
- exact1/400：execution BASE..accepted HEAD `git diff --name-only` 恰为 `tests/test-session-snapshot-assurance.sh` 单文件，`git diff --numstat` 总和 346（≤ 400）。
- 241 断言口径：dependency-present 实跑断言计数恰为 241 = prototype 实跑口径 240 + 设计批准的 1 行 `ASSURANCE_UNLINK_LOG` ENOENT oracle（任务 1.1 `count.out/err` 实测 `checks=241`）。

## 既有任务证据汇总（引用路径 + 关键实测值）

### task-1.1 交付候选文件

- 报告：`task-1.1-report.md`；日志：`evidence/task-1.1-logs/`；review：`task-1.1-review-round-1.md`（PASS）。
- 实测：default/all 均 rc0、stdout 逐字 active 摘要、stderr 0B（`default.out/err`、`all.out/err`）；断言计数 `checks=241`（`count.out/err`）；argv 非法三行（`--bogus`/`all extra`/`--dependency-absent=x`）均 rc1 且 stdout 无 PASS（`argv-invalid.log`）；inert 三态逐字同一摘要且 `checks=0`（`inert-count.out/err`）；fail-closed 七类 × default/flag 共 14 行均 rc1 无 PASS（`fail-closed.log`、`fc{1..7}-*.out/err`）；shfmt v3.14.0 / ShellCheck 0.11.0 / bash -n / `git diff --check` 全绿（`tool-versions.log`、`shfmt.log`、`shellcheck.log`）；provider SHA-256 运行前后不变（`provider-sha256.log`）。

### task-2.1 candidate（R9）

- 报告：`task-2.1-report.md`；日志：`evidence/task-2.1-logs/`；review：`task-2.1-review-round-1.md`（PASS）。
- 实测：candidate worktree default rc0 摘要逐字（`default.out/err`）；`bash ./scripts/check.sh --offline` rc0、本入口发现恰好 1 次、末行 `RESULT PASS  aosp-harness offline quality gate`（`offline.log`）；六上游 tracked 文件 SHA-256 测试前后不变（`upstream-before.sha256`、`upstream-after-check.log`）；BASE..HEAD exact1、numstat 346 ≤ 400（`diff-name-only.log`、`diff-numstat.log`）；worktree clean；固定 ACCEPTED_HEAD=`c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`。

### task-2.2 full checkout（R9）

- 报告：`task-2.2-report.md`；日志：`evidence/task-2.2-logs/`；review：`task-2.2-review-round-1.md`（PASS）。
- 实测：`git clone --no-local` full checkout HEAD 逐字等于 ACCEPTED_HEAD（`clone.log`）；default rc0 摘要逐字（`default.out/err`）；offline rc0、发现恰好 1 次、末行 PASS（`offline.log`）；六上游文件 SHA-256 不变（`upstream-after-check.log`）；status/diff clean（`status.log`、`diff.log`）；checkout 用后已删除。

### task-2.3 depth-1 checkout（R9）

- 报告：`task-2.3-report.md`；日志：`evidence/task-2.3-logs/`；review：`task-2.3-review-round-1.md`（PASS）。
- 实测：真实 `git clone --depth 1 "file://$WORK/worktree"`（`clone.log`）；HEAD 逐字等于 ACCEPTED_HEAD、`git rev-list --count HEAD`=1、`.git/shallow` 非空；default rc0 摘要逐字（`default.out/err`）；offline rc0、发现恰好 1 次、末行 PASS（`offline.log`）；六上游文件 SHA-256 不变（`upstream-after-check.log`）；status/diff clean；checkout 用后已删除。

### task-2.4 exact rollback（R10）

- 报告：`task-2.4-report.md`；日志：`evidence/task-2.4-logs/`；review：`task-2.4-review-round-1.md`（PASS）。
- 实测：rollback commit `cf9828f28c6bc847e1737c353752cdcddfc2fd09`（仅存在于已删除的隔离 clone），`git diff --name-status HEAD~1 HEAD` 恰一行 `D tests/test-session-snapshot-assurance.sh`（`rollback-diff.log`、`rollback-head.txt`）；03b 基础测试 rc0、stdout 逐字 `RESULT PASS  session snapshot safety`（`base.out/err`）；offline rc0 末行 PASS 且 `session snapshot assurance` 0 次匹配（`offline.log`）；入口物理缺席且 clean（`rb-status.log`）；candidate/full/depth-1 checkout 未被触碰，implementation HEAD 不变（`impl-status.log`）。

### task-2.5 03c 顺序门（R10）

- 报告：`task-2.5-report.md`；日志：`evidence/task-2.5-logs/`；review：`task-2.5-review-round-1.md`（PASS）。
- 实测：`$PROJECT/specs/2026-09-02-03c-session-write-interrupts` 与 `$PROJECT/work/$NEXT` 物理缺席（`test ! -e`/`test ! -L` 通过）；`refs/heads/spec/$NEXT` 缺席（`show-ref --verify --quiet` rc1）；`git worktree list --porcelain` 无匹配（`worktree-list.log`）；全仓 13 个存在的 ledger/dispatch/execution-base 文件中三类 `$NEXT` 记录零匹配（`rg-file-list.txt`、`rg-forbidden.log`）。

## 结论

- 前六任务（1.1、2.1–2.5）独立 review 全 PASS，task-2.6 待本轮 review；六行 manifest 已按序追加（task-2.6 行待本报告独立 review PASS 后由控制器追加）。
- inert PASS 未作为本片任何验收证据；全部验收基于 dependency-present 完整矩阵与上述 checkout/rollback/顺序门实测。
- 满足 R9/R10 全部验收项，建议 accept 本片并以 `session-snapshot-assurance-v1` 为终交付锚点收敛 ledger。
