# 任务 1.1 报告：交付完整 assurance 候选文件

## task

- task-1.1：交付完整 assurance 候选文件 `tests/test-session-snapshot-assurance.sh`（prototype blob 308 行 + E1–E6 机械整合；E3 export 检查行按控制器修订后的 tasks.md/brief 逐字落地）。
- 状态：**DONE**。前一轮 BLOCKED 的 E3 卡点已由控制器修订 brief 解除（修订行与建议逐字一致），本轮按修订后 brief 跑完步骤 1–7 全绿。

## base

- TASK_BASE = `8a164f212c398a95703a38fb919af2b31c6e1662`（分支 `spec/2026-09-02-03b1-session-snapshot-assurance`，提交前 clean HEAD）。

## head

- TASK_HEAD = `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`（commit subject：`test(session): add snapshot assurance matrix`）。

## files

- 创建（已提交）：`tests/test-session-snapshot-assurance.sh`，346 行 = 308 + E1–E6 净增 38 行（≤400）；探针字面量 `printf 'RESULT PASS  session snapshot assurance\n'` 恰 3 处（E3×2 + 末行）。
- 验收资产：
  - `evidence/task-1.1-red.txt`（红阶段证据，六行 schema + assertion 行）
  - `evidence/task-1.1-logs/`（全部命令日志）
  - `evidence/task-1.1-evidence.tsv`（evidence 清单，path/sha256/bytes 三列）
- 未触碰 `common/`、上游六 tracked 文件及任何前序模块；provider SHA-256 运行前后不变（`17dfa03a4126231f4f4afbbee33178c0f109c637355cc222d7f874a7ec4b5d0f`，见 `provider-sha256.log`）。

## commands

1. 红阶段：`test ! -e tests/test-session-snapshot-assurance.sh && bash tests/test-session-snapshot-assurance.sh` → rc127、stdout 0B 无 PASS（`red.stdout`/`red.stderr`，证据文件见末节）。
2. blob 门与整合：`test "$(git show "$PROTO_SHA:$PROTO" | wc -l)" -eq 308` 通过；python3 机械整合（每处锚点 count==1 断言）+ 本轮 E3 修订行替换；`diff` 对 prototype 7 个 hunk 逐一对应 E1/E2/E3/E4/E5/E6a/E6b/E6c/E6d，无其他差异（`integration-diff.log`）；`wc -l` = 346 ≤ 400。
3. 静态门：固定工具目录逐字核 `shfmt --version` = `v3.14.0`、`shellcheck --version` 含 `^version: 0.11.0$`（`tool-versions.log`）；`shfmt -d -i 2 -ci -bn` 无输出 rc0（`shfmt.log`）、`shellcheck -x --severity=warning` rc0（`shellcheck.log`）、`bash -n` rc0、`git diff --check` rc0。
4. dependency-present 实跑：`bash ./tests/test-session-snapshot-assurance.sh` 与 `... all` 均 rc0、stdout 逐字 `RESULT PASS  session snapshot assurance\n`（cmp 通过）、stderr 0B（`default.out/err`、`all.out/err`）；断言计数探针（rindex 末行 printf 前插 `printf 'checks=%d\n' "$checks" >&2`，仓库内 `mktemp -d "$PWD/.count.XXXXXX"` 副本）跑 default 得 `checks=241`（`count.out/err`），临时目录已删；argv 非法表 `--bogus` / `all extra` / `--dependency-absent=x` 逐行 rc1 且 stdout 无 PASS（`argv-invalid.log`、`argv{1,2,3}.{out,err}`）。
5. provider-absent 实跑：`git clone --no-local` 副本中 `rm` provider 后无参数/`all`/`--dependency-absent` 三态均 rc0、stdout 逐字同一 inert 摘要、stderr 0B（`inert-{default,all,flag}.{out,err}`）；零 active case 探针（index 首处 printf 前插两空格缩进 `${checks:-0}` 探针）跑 default 得 rc0、stdout 逐字 inert 摘要、`checks=0`（`inert-count.out/err`）。
6. fail-closed 七类（各自独立 clone + fixture）：(a) provider 为目录、(b) symlink、(c) `bash -n` 失败、(d) source 非零、(e) 三 export 缺一、(f) anchor 两次、(g) `renameat2` 两次——逐类 default 与 `--dependency-absent` 均 rc1 且 stdout 无 PASS（`fail-closed.log`、`fc{1..7}-{default,flag}.{out,err}`）。
7. 提交：`git add -N` 后 working-tree `git diff --name-only` 恰为单文件、numstat 总和 346 ≤400；`git commit -m "test(session): add snapshot assurance matrix"`；BASE→HEAD `git diff --name-only` 恰为 `tests/test-session-snapshot-assurance.sh`（exact1）、numstat 总和 346 ≤400、上游六文件 diff 为空、`git status --porcelain` 为空；提交后复跑主验证命令 rc0 摘要逐字（`post-commit.out/err`）。

## results

- 红阶段：rc127、stdout 无 PASS（成立，先于交付记录）。
- 绿阶段：主验证命令 default/all rc0、stdout 逐字 `RESULT PASS  session snapshot assurance\n`、stderr 空；断言计数 `checks=241`（= prototype 240 + UNLINK_LOG ENOENT oracle 1）；argv 非法三行 rc1 无 PASS；inert 三态逐字同一摘要且 `checks=0`；fail-closed 七类 × default/flag 共 14 行均 rc1 无 PASS；shfmt/shellcheck/bash -n/diff --check 全绿；exact1、numstat 346≤400、上游六文件零变更、worktree clean、provider SHA-256 前后不变。
- 前一轮 BLOCKED 诊断（standalone export 检查 rc1 / 先 source 两上游 lib 后 rc0）经控制器核实，tasks.md 与 brief 的 E3 行已修订为本轮落地版本；本轮全部证据基于修订后候选文件。

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/evidence/task-1.1-red.txt
