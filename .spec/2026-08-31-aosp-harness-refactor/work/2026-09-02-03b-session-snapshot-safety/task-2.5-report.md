# 任务 2.5 报告: 验证03b1与03c顺序门

## task

- 任务: task-2.5（spec 2026-09-02-03b-session-snapshot-safety，需求 R9）
- 范围: 只执行步骤 1–5 的实现者部分（红证据 → NEXT1/NEXT2 的 specs/work 目录与分支缺席核对 → worktree list 核对 → 限定域 rg 核对 → green 报告与 evidence package）；独立 review、manifest 行追加、mark/ledger/sync 由控制器执行
- 本任务不创建任何 commit、不改任何 spec 资产，纯只读核对 + 写自己的证据文件
- NEXT1=`2026-09-02-03b1-session-snapshot-assurance`，NEXT2=`2026-09-02-03c-session-write-interrupts`

## base

- execution BASE: `3d15a0d76c2a2e6c8541c5d47001a55f0ca18649`（execution-base.env 的 BASE_SHA）

## head

- ACCEPTED_HEAD: `ab1e870ece16bbc24e1a86f84110366f84aae0d9`（任务 2.1 固定；implementation worktree 当前 HEAD 逐字等于该值且 `git status --porcelain` 0 行，日志 `evidence/task-2.5-logs/impl-head.txt` / `impl-clean.txt`）

## files

本任务不修改任何源码文件。验收资产（不纳入源码文件清单）:

- 创建 `evidence/task-2.5-red.txt`
- 创建 `task-2.5-report.md`（本文件）
- 创建 `evidence/task-2.5-evidence.tsv`
- 创建 `evidence/task-2.5-logs/`（每次运行分离保存 rc/stdout/stderr）
- `review-manifest.tsv` 由控制器在独立 review PASS 后修改

## commands

红阶段证据: `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/evidence/task-2.5-red.txt`

步骤 1（红，日志 `red.*`）:
- `test -s $WORK/task-2.5-report.md` → rc1，双流空（报告缺席，红成立）
- 前置: implementation worktree HEAD = ACCEPTED_HEAD 且 clean

步骤 2（目录与分支缺席，对 NEXT1/NEXT2 逐一，日志 `03b1-*` / `03c-*`）:
- `test ! -e "$PROJECT/specs/$id"` → rc0（缺席）；`test ! -L "$PROJECT/specs/$id"` → rc0（非 symlink）
- `test ! -e "$PROJECT/work/$id"` → rc0（缺席）；`test ! -L "$PROJECT/work/$id"` → rc0（非 symlink）
- `git show-ref --verify --quiet "refs/heads/spec/$id"` → rc1（分支缺席，符合要求）

步骤 3（worktree 核对，日志 `worktree-list.*` 与 `*-wt-*.rc`）:
- `git worktree list --porcelain` → rc0，输出保存为 `worktree-list.txt`
- 对两者逐一: 输出不含 `branch refs/heads/spec/$id`（rc0=未命中）、不含约定 worktree 绝对路径 `$PROJECT/work/$id/worktree`（rc0=未命中）、兜底 `grep -F "$id"` 全文未命中（rc0）
- work 目录缺席 ⇒ 未来 execution-base/manifest/task-brief 自然缺席；未发现任何同名文件/目录/symlink

步骤 4（限定域 rg，日志 `rg-files.txt` / `03b1-rg.*` / `03c-rg.*`）:
- 搜索域仅含存在文件: `$PROJECT/specs/*/ledger.md`（7 个）与 `$PROJECT/work/*/{dispatch.tsv,execution-base.env}`（dispatch.tsv 均不存在，execution-base.env 4 个），清单见 `rg-files.txt`
- `rg --no-heading -N -n "dispatch.*$id|execution BASE.*$id|spec/$id" <files>` → 对 NEXT1/NEXT2 均 rc1（零匹配）、双流空
- 未搜索 PLAN/requirements 中的合法规划文字

## results

全部通过:

| 检查 | 结果 |
|---|---|
| 红: report 缺席 | rc1，双流空 ✓ |
| 前置: implementation HEAD=ACCEPTED_HEAD + clean | ✓ |
| NEXT1 specs 目录缺席 | `test ! -e` + `test ! -L` rc0 ✓ |
| NEXT1 work 目录缺席 | `test ! -e` + `test ! -L` rc0 ✓ |
| NEXT1 分支缺席 | `git show-ref --verify --quiet refs/heads/spec/2026-09-02-03b1-session-snapshot-assurance` rc1 ✓ |
| NEXT1 worktree 缺席 | porcelain 无 branch 行、无约定路径、全文无 id ✓ |
| NEXT1 ledger/dispatch/BASE 无记录 | 限定域 rg rc1，零匹配，双流空 ✓ |
| NEXT2 specs 目录缺席 | `test ! -e` + `test ! -L` rc0 ✓ |
| NEXT2 work 目录缺席 | `test ! -e` + `test ! -L` rc0 ✓ |
| NEXT2 分支缺席 | `git show-ref --verify --quiet refs/heads/spec/2026-09-02-03c-session-write-interrupts` rc1 ✓ |
| NEXT2 worktree 缺席 | porcelain 无 branch 行、无约定路径、全文无 id ✓ |
| NEXT2 ledger/dispatch/BASE 无记录 | 限定域 rg rc1，零匹配，双流空 ✓ |
| 无 commit / 无 spec 资产变更 | 本任务只读核对 + 只写自身 evidence 文件 ✓ |

测试摘要: 03b1 与 03c 的 spec 目录、work 目录、`spec/<id>` 分支、worktree（branch 行与约定绝对路径）及全部既有 ledger/dispatch/execution-BASE 记录均机械核对缺席，顺序门保持关闭；任一 inert PASS 不影响本结论。
