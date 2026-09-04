# task-2.1 report: 审计candidate并固定accepted HEAD

## task

task-2.1 — 零 delta controller 验证：不改源码、不产生提交，审计 implementation worktree candidate，验证任务 1.1/1.2/1.3 交付的三 hook + settings.json + run-demo.sh + 默认发现生命周期测试在 candidate checkout 中全绿，并在报告中声明当前 HEAD 供 controller 在 review PASS 后固定为 ACCEPTED_HEAD（消费 claude-session-lifecycle-matrix-v1，产出 claude-lifecycle-accepted-head-v1）。

## base

- base（execution BASE，累计断言口径）: `cc04996e1e405c00e16be3b57d3ef62d90cd7fd1`

## head

- head（零 delta，candidate HEAD，声明供固定为 ACCEPTED_HEAD）: `5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`（任务 1.3 的 TASK_HEAD、40 位、worktree clean、`git status --porcelain` 为空）

## files

- 审计对象（本片 exact 六文件，只读）: `claude-code/features/.harness/hooks/check-branch-drift.sh`、`claude-code/features/.harness/hooks/load-feature.sh`、`claude-code/features/.harness/hooks/session-end.sh`、`claude-code/features/.harness/settings.json`、`claude-code/run-demo.sh`、`tests/test-claude-session-lifecycle.sh`
- 本任务不创建/修改任何源码文件；`git diff --name-only $BASE_SHA HEAD` 逐字恰为上述六文件（`sort` 后与 `EXACT6` diff 零差异）；numstat 总和 367 ≤400；UPSTREAM12 范围 diff 为空；`git diff --check` rc0；worktree clean

## commands

- 红阶段: `test -s "$WORK/task-2.1-report.md"` → rc1、双流空（报告缺席）
- HEAD/clean 核对: `git rev-parse HEAD` 逐字等于任务 1.3 TASK_HEAD、`git status --porcelain` 为空
- 上游 SHA 基线: worktree 内 `sha256sum $UPSTREAM12 >"$tmp/before.sha"`（测试后 `sha256sum -c` 复核，结束删临时目录）
- 工具版本逐字断言: `test "$("$TOOLS/shfmt" --version)" = "v3.14.0"`、`"$TOOLS/shellcheck" --version | rg -q '^version: 0.11.0$'`
- 静态门（只对 exact 六文件中五个 shell 文件）: `shfmt -d -i 2 -ci -bn`、`shellcheck -x --severity=warning`、`bash -n` 五文件；`python3 -c 'import json; json.load(open("claude-code/features/.harness/settings.json"))'` 核验 settings.json
- default 入口: `bash ./tests/test-claude-session-lifecycle.sh` 落盘后 `printf 'RESULT PASS  claude session lifecycle\n' | cmp -s - out`、stderr 0B
- offline: `bash ./scripts/check.sh --offline` 落盘（`$tmp` 内，非工作树根裸 `offline.log`）后 `rg -c 'RESULT PASS  claude session lifecycle$' "$tmp/candidate-offline.log"` 恰为 1、末行 PASS
- 累计断言: `git diff --name-only "$BASE_SHA" HEAD` 恰六文件、`git diff --numstat "$BASE_SHA" HEAD | awk '{s+=$1+$2} END {print s+0}'` ≤400、`git diff --name-only "$BASE_SHA" HEAD -- $UPSTREAM12` 为空、`git diff --check`、clean

## results

- 红阶段: rc1、stdout 0B（sha256=`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`）、stderr 0B（同上 sha256），证据见下
- HEAD/clean: HEAD=`5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`、clean，双双通过
- 工具版本: shfmt 逐字 `v3.14.0`、ShellCheck version field `0.11.0`，双双通过
- 静态门: shfmt rc0 无输出、shellcheck rc0 无输出、bash -n 五文件各 rc0、`python3 json.load` settings.json rc0、`git diff --check` rc0
- default 入口: rc0、stdout 逐字节等于固定摘要 `RESULT PASS  claude session lifecycle\n`（`cmp -s` 通过）、stderr 0B
- offline: rc0、stderr 0B、offline 日志中本入口摘要恰出现 1 次（自动发现恰一次）、末行 `RESULT PASS  aosp-harness offline quality gate`
- 上游十二文件 SHA-256: 测试前后 `sha256sum -c` 全部 OK（十二文件不变）
- 累计断言: name-only 恰六文件（`check-branch-drift.sh`/`load-feature.sh`/`session-end.sh`/`settings.json`/`run-demo.sh`/`tests/test-claude-session-lifecycle.sh`）、numstat 总和 `367` ≤400、UPSTREAM12 空、`git diff --check` rc0、clean
- 清理: mktemp 临时目录已删除，测试后 worktree clean（`git status --porcelain` 为空）

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03e-claude-session-lifecycle/evidence/task-2.1-red.txt
