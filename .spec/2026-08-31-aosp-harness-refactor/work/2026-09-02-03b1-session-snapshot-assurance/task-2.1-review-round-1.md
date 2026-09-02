# task 2.1 review: 2026-09-02-03b1-session-snapshot-assurance round 1

- 审查人： 独立 reviewer（全新上下文，非执行者/控制器）
- 日期： 2026-09-02
- 审查对象： `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo` 下 `task-2.1-brief.md` / `task-2.1-report.md` / `evidence/`（`task-2.1-red.txt`、`task-2.1-logs/`、`task-2.1-evidence.tsv`）及 candidate worktree `…/2026-09-02-03b1-session-snapshot-assurance/worktree`
- 审查方式： 不采信报告自述，全部必做项独立实跑复核。

## 结论

**PASS** —— 阻断 0 / 重要 0 / 次要 1。

所有必做核验项独立实跑通过：报告结构校验 rc=0；红证据 schema 齐全且红先于绿；evidence.tsv 16 行全部与磁盘实算一致；candidate worktree HEAD 恰为 `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`、跑前跑后 clean；主验证命令与 offline 实测符合逐字口径；六上游文件 SHA-256 测试前后不变；exact1（346 ≤ 400）与静态门（固定工具目录、版本逐字）实测全绿。零 delta 成立，ACCEPTED_HEAD 可固定为 `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`。

## 逐项核验（实测命令 + 输出摘要）

1. **报告六节 + check-task-report.py**
   - 报告含 `## task` / `## base` / `## head` / `## files` / `## commands` / `## results` 六节，红阶段证据行指向 `evidence/task-2.1-red.txt`。
   - 从仓库根运行 `python3 ~/.agents/skills/spec/scripts/check-task-report.py .spec/…/task-2.1-report.md` → **rc=0**。（注意：该脚本按 CWD 解析报告内相对路径，必须从仓库根运行；从其他目录运行会误报红文件缺席，属脚本行为而非交付缺陷。）

2. **红证据六行 schema + assertion + 红先于绿**
   - `task-2.1-red.txt` 恰含 `task=`/`command=`/`expected=`/`rc=1`/`stdout_sha256=`/`stderr_sha256=` 六行加 `assertion=`；两个 sha256 均为空串哈希 `e3b0c44…`，与 `red.stdout`/`red.stderr` 两个 0 字节日志一致。
   - 时间戳：red.stdout 22:58:21、red.txt 22:58:33 → 绿日志 22:59–23:00 → 报告 23:03:15 → evidence.tsv 23:03:29，红严格先于绿。

3. **evidence.tsv 三列与磁盘实算**
   - 16 行（brief、report、red、13 个日志），逐行 `sha256sum` + `stat -c%s` 实算比对：**16/16 OK**，无 mismatch、无遗漏文件。

4. **candidate worktree 独立实跑**
   - `git rev-parse HEAD` = `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`（恰为要求值）；分支 `spec/2026-09-02-03b1-session-snapshot-assurance`。
   - 跑前自存六文件 `sha256sum` → 跑后 `sha256sum -c` **六文件全 OK**。
   - `bash ./tests/test-session-snapshot-assurance.sh` → rc=0；`printf 'RESULT PASS  session snapshot assurance\n' | cmp -s - out` 逐字节一致；stderr 0 字节。
   - `bash ./scripts/check.sh --offline` → rc=0、stderr 0 字节；`rg -c 'RESULT PASS  session snapshot assurance' offline.log` = **1**（恰好发现一次）；末行 `RESULT PASS  aosp-harness offline quality gate`。
   - 两轮测试后 `git status --porcelain` 为空、HEAD 未变 —— worktree clean、零 delta。

5. **exact1 与静态门抽查**
   - `git diff --name-only 8a164f212c398a95703a38fb919af2b31c6e1662 HEAD` 输出恰一行 `tests/test-session-snapshot-assurance.sh`；numstat 总和 **346 ≤ 400**；`git diff --check` rc=0。BASE 与 `execution-base.env` 的 `BASE_SHA` 一致。
   - 固定工具目录 `/tmp/claude-1000/-home-zzh0838-CareerDevelop-AI2D-aosp-harness-demo/bdc6e669-9154-4030-a9db-78dc599ab491/scratchpad/tools/bin` 存在且含 shfmt/shellcheck；`shfmt --version` 逐字 `v3.14.0`；`shellcheck --version` 含逐字行 `version: 0.11.0`。
   - `shfmt -d -i 2 -ci -bn` rc=0 且输出 0 字节；`shellcheck -x --severity=warning` rc=0 输出 0 字节；`bash -n` rc=0（均只对本片 exact 单文件）。
   - 与执行者日志交叉一致：`tool-versions.log`（31B）、`default.out`（40B）、`offline.log`（471B）、`diff-numstat.log`（`346`）内容与本 reviewer 实测相同。

## Findings

### 阻断

无。

### 重要

无。

### 次要

- 报告 `## commands` 节用省略号 `…/scratchpad/tools/bin` 指代固定工具目录，未写全绝对路径；完整路径需结合 brief 或 tool-versions.log 推断。不影响机械核验（实测已独立确认目录与版本），仅降低报告自含性。

## 附：复核命令

````bash
# 0. 变量
REPO=/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo
WORK=$REPO/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance
W=$WORK/worktree
TOOLS=/tmp/claude-1000/-home-zzh0838-CareerDevelop-AI2D-aosp-harness-demo/bdc6e669-9154-4030-a9db-78dc599ab491/scratchpad/tools/bin
BASE=8a164f212c398a95703a38fb919af2b31c6e1662
SIX="common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh tests/lib/session-path-race-driver.py tests/test-session-path-races.sh common/.harness/lib/session-state-snapshot.sh tests/test-session-snapshot.sh"

# 1. 报告结构校验（必须从仓库根跑，脚本按 CWD 解析相对路径）
cd "$REPO" && python3 /home/zzh0838/.agents/skills/spec/scripts/check-task-report.py \
  .spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/task-2.1-report.md

# 2. evidence.tsv 逐行实算比对
cd "$WORK" && while IFS=$'\t' read -r p h b; do
  [ "$(sha256sum "$p" | cut -d' ' -f1)" = "$h" ] && [ "$(stat -c%s "$p")" = "$b" ] \
    && echo "OK $p" || echo "MISMATCH $p"
done < evidence/task-2.1-evidence.tsv

# 3. 红先于绿（时间戳）
stat -c '%y %n' "$WORK/evidence/task-2.1-red.txt" "$WORK"/evidence/task-2.1-logs/* "$WORK/task-2.1-report.md"

# 4. worktree 状态与实跑
cd "$W" && git rev-parse HEAD && git status --porcelain
sha256sum $SIX > /tmp/before.sha256
export PATH="$TOOLS:$PATH"
test "$(shfmt --version)" = "v3.14.0" && shellcheck --version | rg -q '^version: 0.11.0$'
shfmt -d -i 2 -ci -bn tests/test-session-snapshot-assurance.sh
shellcheck -x --severity=warning tests/test-session-snapshot-assurance.sh
bash -n tests/test-session-snapshot-assurance.sh
bash ./tests/test-session-snapshot-assurance.sh >/tmp/default.out 2>/tmp/default.err
printf 'RESULT PASS  session snapshot assurance\n' | cmp -s - /tmp/default.out && test ! -s /tmp/default.err
bash ./scripts/check.sh --offline >/tmp/offline.log 2>/tmp/offline.err
test "$(rg -c 'RESULT PASS  session snapshot assurance' /tmp/offline.log)" = 1
sha256sum -c /tmp/before.sha256
git status --porcelain   # 必须为空

# 5. exact1 / numstat / diff --check
cd "$W" && git diff --name-only "$BASE" HEAD
git diff --numstat "$BASE" HEAD | awk '{s+=$1} END {print s+0}'
git diff --check "$BASE" HEAD
````
