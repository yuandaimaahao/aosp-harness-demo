# 任务 2.5「验证 03d 顺序门」独立 Review 报告

**结论：PASS**（阻断 0 / 重要 0 / 次要 0）

审查对象：03c-session-write-interrupts 任务 2.5，ACCEPTED_HEAD=`648fe667396e6273f7d497479f16d7daf4560d18`。全部复核均为 reviewer 独立实跑，未采信报告转述。

## 1. 红证据复核 — 通过

- `evidence/task-2.5-red.txt` 恰为固定六行 schema（task/command/expected/rc/stdout_sha256/stderr_sha256）+ 末行 `assertion=`，共 7 行。
- `stdout_sha256`/`stderr_sha256` 均为空流哈希 `e3b0c44…b855`，对 `task-2.5-logs/red.{stdout,stderr}` 实算 sha256 逐字一致（两文件 0B）。
- 红原因为报告缺席：`red.txt` 与红日志 mtime `05:03:08` 早于 `task-2.5-report.md` `05:04:32`，红先绿后时序成立。`rc=1` 本身因报告现已存在无法 retro 重跑，属该工作流固有限制，其余均可核实。

## 2. 顺序门独立重跑（主仓库根，NEXT=03d-session-remove-prune）— 全部门禁通过

- (a) `shopt nullglob` → `off`（执行 shell 默认 off），`shopt -q nullglob` rc1。
- (b) `! ls -d "$PROJECT"/specs/*"$NEXT" 2>/dev/null` → rc0；work 目录同款 → rc0。spec/work 目录均缺席。
- (c) `git show-ref | rg "refs/heads/spec/.*$NEXT"` 零输出（rg rc1），`test -z` 门 rc0。
- (d) `git worktree list --porcelain | rg "$NEXT"` 零输出（rg rc1），`test -z` 门 rc0。
- (e) `files=$(ls …/specs/*/ledger.md …/work/*/dispatch.tsv …/work/*/execution-base.env 2>/dev/null)` 实收 15 个文件（9 ledger + 6 execution-base.env，无 dispatch.tsv 存在），`rg "$NEXT" $files` 零匹配（rc1），门 `test -z "$files" || ! rg -q "$NEXT" $files` rc0。

与日志证据一致：`nullglob.stdout` 内容为 `nullglob off`；`spec-dir/work-dir/branch/worktree/branch-match/worktree-match/scoped-rg/scoped-gate` 的 stdout/stderr 全 0B；`scoped-files.stdout` 恰 15 行与实收清单逐字一致。

## 3. 裁定 6 遵守核验 — 通过

- (a) 对 `$WORK` 下 report/red/logs 独立 rg 字面全名：`task-2.5-report.md` 仅第 28 行 `NEXT=03d-session-remove-prune` 定义行（步骤 2 本身要求定义该变量），report 其余命令记录（第 29–36 行）全部为 `"$NEXT"` 间接形式；`task-2.5-red.txt` 与 36 个日志零命中。各 task brief 中的字面全名是 spec 原文（R8/裁定 6/步骤 2）的逐字内嵌，非本任务证据文件、不违反裁定。
- (b) scoped rg 域 15 文件零匹配已实跑复核（见 2e）；本片自身 `specs/2026-09-03-03c-session-write-interrupts/ledger.md` 对字面全名单独 rg **零命中**——历史问题行确已修为间接形式，现状干净。
- (c) 日志为纯双流落盘、不含命令文本；report 命令记录均为 `"$NEXT"` 间接形式，符合裁定 6 后半段约束。

## 4. 证据一致性 — 通过

- `task-2.5-evidence.tsv` 40 行（brief + report + red + review 包 + 36 日志），逐行重算 sha256 与 bytes：**ok=40 bad=0**。
- report 含固定六节 task/base/head/files/commands/results；base=head=ACCEPTED_HEAD；红阶段证据独占行（末行）经 `od -c` 核结尾为 `\n` 无尾随字符，全文无行尾空白。
- review 包 `review-648fe667-648fe667.md` 106B、sha256 `cbbb1550…7080`，与 task-2.1/2.2/2.3/2.4 各 evidence.tsv 中同名行五处完全一致（同名同 sha256 同 106B）。
- 日志抽查：`impl-head.stdout` 41B 内容为 `648fe667…0d18\n`；`review-package.stdout` 指向该 review 包路径；均与 report 声明一致。

## 5. 零 delta 纪律 — 通过

- implementation worktree：`git rev-parse HEAD` = `648fe667396e6273f7d497479f16d7daf4560d18`（= ACCEPTED_HEAD，未变），`git status --porcelain` 空。
- 主仓库：当前 `git status --porcelain | sha256sum` = `787ec6f1…7825`，与日志中 `main-status-before.stdout`/`main-status-after.stdout` 的 sha256 逐字一致（两快照亦 `cmp` 完全相同），本任务未向主仓库引入任何变化。
- 本任务无 commit，manifest 追加/mark/ledger 锚点依 report 声明留待 controller，符合任务书步骤 5–6 的职责划分。

## Findings

无。

## 复核过程关键输出（可复现）

```bash
# 门重跑（主仓库根，均实跑通过，输出见上第 2 节）
cd /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo
shopt nullglob                      # off
NEXT=03d-session-remove-prune; PROJECT=.spec/2026-08-31-aosp-harness-refactor
! ls -d "$PROJECT"/specs/*"$NEXT" 2>/dev/null   # rc0
! ls -d "$PROJECT"/work/*"$NEXT" 2>/dev/null    # rc0
test -z "$(git show-ref | rg "refs/heads/spec/.*$NEXT")"            # rc0
test -z "$(git worktree list --porcelain | rg "$NEXT")"             # rc0
files=$(ls "$PROJECT"/specs/*/ledger.md "$PROJECT"/work/*/dispatch.tsv "$PROJECT"/work/*/execution-base.env 2>/dev/null)
test -z "$files" || ! rg -q "$NEXT" $files      # rc0（15 文件零匹配）
```

**最终裁定：PASS**，计数 阻断 0 / 重要 0 / 次要 0。
