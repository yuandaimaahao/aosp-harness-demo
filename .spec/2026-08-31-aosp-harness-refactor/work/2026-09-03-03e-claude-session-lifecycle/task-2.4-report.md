# 任务 2.4 报告：验证04顺序门

## 概述

本任务验证 R10 所要求的「04-runtime-resource-leases 顺序门」：在 03e 尚未产出
dependency-present active 证据入 ledger 前，规范 ID 片段 `04-runtime-resource-leases`
（日期前缀由创建日决定，本片不预知）对应的 spec 目录、work 目录、`spec/` 分支、
git worktree、以及 ledger/dispatch/execution-base 三类记录必须机械核对为物理缺席。

所有命令均在 `bash` 下执行（禁止 zsh，因 zsh 的 NOMATCH 会整条中止赋值、且不对
未加引号的 `$files` 做词分割，两者都会把门变成假绿；执行 shell 未开 nullglob）。

## 红阶段证据

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-03-03e-claude-session-lifecycle/evidence/task-2.4-red.txt

红阶段失败原因：`task-2.4-report.md` 在本任务开始前物理缺席（`test -s` 对不存在
文件返回非零）。完整记录见 evidence 文件。

## 执行环境

- 主仓根：`/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo`
- PROJECT（能定位到 `specs/` 的路径，取主仓根下相对路径展开后的绝对路径）：
  `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor`
- 执行 shell：`bash`（未开 nullglob）
- 变量：`NEXT="04-runtime-resource-leases"`（日期无关规范 ID 片段，间接引用，
  不在本报告任何命令行中内联字面全名扩散到 04 的 ledger/dispatch/execution-base
  scoped 域，仅通过变量展开）

## 步骤与结果

### 步骤 2：spec/work 目录物理缺席

```
! ls -d "$PROJECT"/specs/*"$NEXT" 2>/dev/null   → rc=0（ls 未匹配任何路径，! 取反后为真，缺席确认）
! ls -d "$PROJECT"/work/*"$NEXT" 2>/dev/null    → rc=0（同上，work 目录缺席确认）
```

结果：**PASS**。`"$PROJECT"/specs/` 与 `"$PROJECT"/work/` 下均不存在任何以
`"$NEXT"` 结尾的目录。

### 步骤 3：分支与 worktree 零匹配

在主仓（与 implementation worktree 共享同一 `.git`）执行：

```
test -z "$(git show-ref | rg "refs/heads/spec/.*$NEXT")"        → rc=0（零匹配确认）
test -z "$(git worktree list --porcelain | rg "$NEXT")"         → rc=0（零匹配确认）
```

结果：**PASS**。不存在名称含 `"$NEXT"` 的 `spec/` 分支或 git worktree。

### 步骤 4：ledger/dispatch/execution-base 三类记录零匹配

```
files=$(ls "$PROJECT"/specs/*/ledger.md "$PROJECT"/work/*/dispatch.tsv "$PROJECT"/work/*/execution-base.env 2>/dev/null)
```

（`ls` 多参数单列一行，未使用 `&&` 链式调用）

- `test -n "$files"` → rc=0（`$files` 非空，正向断言成立；实测收集到 18 行文件路径，
  均来自 `specs/*/ledger.md`，覆盖已有全部 spec 目录，满足「至少十份」预期）
- `! rg -q "$NEXT" $files` → rc=0（对 `$files` 做未加引号展开以获得词分割，
  在全部 ledger.md / dispatch.tsv / execution-base.env 文件中对 `"$NEXT"`
  字面量零匹配确认）

结果：**PASS**。ledger/dispatch/execution-base 三类记录中均未出现
`04-runtime-resource-leases` 字样。本步骤未搜索 PLAN/requirements/design/tasks
等规划文档（裁定 6：这些文档允许出现 NEXT 全名，禁令只针对 ledger/dispatch/
execution-base 三类记录）。

## 04 顺序门结论

五类资产（spec 目录、work 目录、`spec/` 分支、git worktree、ledger/dispatch/
execution-base 记录）在本次核对时刻均物理缺席/零匹配，符合 R10 对 03e 尚未产出
dependency-present active 证据前 04 顺序门必须保持关闭的要求。本任务仅做只读机械
核对，不创建、不修改任何 04 相关资产，也未修改 implementation 源码或移动
implementation worktree 的 HEAD。

## 环境不变量核对

- implementation worktree HEAD：`5b2e66b3be9079aa31b4b6eba2da88888a3aaeba`（核对前后一致）
- implementation worktree `git status --porcelain`：空（核对前后一致）
- 本任务未修改 `claude-code/`、`common/`、`tests/` 等 implementation 源码文件

## 状态

DONE

## Commits

无（本任务未产生任何 implementation 源码 commit，仅新增验收资产文件：
`evidence/task-2.4-red.txt`、本报告 `task-2.4-report.md`）。

## 一行测试摘要

4 项机械核对（specs 缺席 / work 缺席 / 分支零匹配+worktree 零匹配 / ledger-dispatch-execution-base 零匹配），全部 PASS。

## 顾虑

无。
