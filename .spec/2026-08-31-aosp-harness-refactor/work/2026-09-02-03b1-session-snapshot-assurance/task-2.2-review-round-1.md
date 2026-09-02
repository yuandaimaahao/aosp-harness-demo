# task 2.2 review: 2026-09-02-03b1-session-snapshot-assurance round 1

- 审查人： 独立 reviewer（全新上下文，与执行者/控制器无关）
- 日期： 2026-09-02
- 对象： spec 任务 2.2「验证完整历史 checkout」（R9 full-checkout，零 delta）
  - brief: `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/task-2.2-brief.md`
  - report: 同目录 `task-2.2-report.md`
  - evidence: 同目录 `evidence/task-2.2-red.txt`、`evidence/task-2.2-logs/`、`evidence/task-2.2-evidence.tsv`
  - 源 worktree: 同目录 `worktree`（HEAD 须 = `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`）

## 结论

**PASS** — 阻断 0 / 重要 0 / 次要 0。

全部必做核验均由本人独立实跑通过，不采信报告自述：报告契约 rc0、红证据 schema 与时序成立、evidence.tsv 逐行与磁盘实算一致、独立 clone 复现 default/offline 全绿且六文件 SHA 不变、执行者临时目录已删除、源 worktree HEAD 不变且 clean。零 delta 成立（本任务无 commit，manifest 当前仅 1.1/2.1 两行，第 3 行待本 PASS 后由控制器追加，符合流程）。

## 逐项核验

1. **报告契约（check-task-report.py）**：从仓库根运行 `python3 /home/zzh0838/.agents/skills/spec/scripts/check-task-report.py .../task-2.2-report.md`，**rc=0**。报告含 task/base/head/files/commands/results 六节；红证据路径（`evidence/task-2.2-red.txt`）在 task 节独占一行（report 第 6 行）。

2. **红证据 schema 与时序**：`task-2.2-red.txt` 恰为固定六行（`task=/command=/expected=/rc=/stdout_sha256=/stderr_sha256=`）+ 末行 `assertion=`；rc=1，stdout/stderr sha256 均为空文件哈希 `e3b0c44…b855`，与 `red.stdout`/`red.stderr`（均 0 字节）实算一致。时序：红证据 23:14（红日志 23:13）先于绿报告 23:17，clone/default/offline 日志 23:14–23:16 居中，红先于绿成立。

3. **evidence.tsv 三列与磁盘实算**：15 行全部 `path<TAB>sha256<TAB>bytes` 三列（awk NF 校验无异常行）；逐行 `sha256sum` 与 `stat -c%s` 实算，**15/15 OK 无 MISMATCH**，覆盖 brief、report、red.txt 及全部 12 个日志文件。

4. **独立复现（临时目录，用后已删除）**：
   - 执行者临时目录 `/tmp/tmp.QyMJupZoUz`（见 `clone.log`）已物理删除（`test ! -e` 成立）。
   - 本人新建 `mktemp -d`，`git clone --no-local <worktree> $tmp/full` rc0；full HEAD 逐字 = `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`，`git rev-list --count HEAD` = 181（确为完整历史 clone，含 execution BASE `8a164f2` 及更早历史）。
   - `bash ./tests/test-session-snapshot-assurance.sh`：rc=0；stdout 与 `printf 'RESULT PASS  session snapshot assurance\n'` **逐字节一致**（`cmp -s` 通过）；stderr 0 字节。
   - `bash ./scripts/check.sh --offline`：rc=0，stderr 0 字节；`rg -c 'RESULT PASS  session snapshot assurance'` = **1**（自动发现恰好一次）；末行逐字 `RESULT PASS  aosp-harness offline quality gate`。
   - 六上游 tracked 文件 before SHA → 测试后 `sha256sum -c` 六行全 OK（前后不变）。
   - `git status --porcelain` 为空；复核命令执行完毕后 `rm -rf` 临时目录并核 `test ! -e` 通过。
   - 附带核验：执行者留存的 `upstream-before.sha256` 在源 worktree 中 `sha256sum -c` 六行全 OK，与本人复现口径一致。
   - 备注：报告所记 `…/scratchpad/tools/bin`（shfmt v3.14.0 / ShellCheck 0.11.0）仍在盘上且版本逐字相符；但 `--offline` 路径（读 `scripts/check.sh` 确认）不经 `quality_run_static`/`quality_run_secrets`，不依赖 shfmt/shellcheck/gitleaks，复现不受影响。

5. **源 worktree 状态**：`git rev-parse HEAD` 逐字 = ACCEPTED_HEAD；`git status --porcelain` 为空。任务前后 HEAD 未移动，零 delta（无 commit）成立。`review-manifest.tsv` 当前仅 task-1.1/task-2.1 两行 PASS 记录，与「2.2 待本 review PASS 后追加第 3 行」的报告自述一致，无越权追加。

## Findings

### 阻断

无。

### 重要

无。

### 次要

无。

## 附：复核命令

以下命令在 `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo` 下实跑（临时 clone 用后已删除）：

````bash
# 0. 固定变量
WORK=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance
ACCEPTED=c7a18edf2f6b3a2fec02b917d37fe5098dd1974a

# 1. 报告契约
python3 /home/zzh0838/.agents/skills/spec/scripts/check-task-report.py "$WORK/task-2.2-report.md"   # rc=0

# 2. 红证据：六行 schema + assertion；空流哈希 = e3b0c44…b855；mtime 23:14 < report 23:17
cat "$WORK/evidence/task-2.2-red.txt"
sha256sum "$WORK/evidence/task-2.2-logs/red.stdout" "$WORK/evidence/task-2.2-logs/red.stderr"

# 3. evidence.tsv 逐行实算
cd "$WORK" && while IFS=$'\t' read -r p sha bytes; do
  [ "$sha" = "$(sha256sum "$p" | cut -d' ' -f1)" ] && [ "$bytes" = "$(stat -c%s "$p)" ] || echo "MISMATCH $p"
done < evidence/task-2.2-evidence.tsv   # 无输出 = 15/15 OK
awk -F'\t' 'NF!=3 {print "BAD-COLS",NR}' evidence/task-2.2-evidence.tsv   # 无输出

# 4. 独立复现
test ! -e /tmp/tmp.QyMJupZoUz   # 执行者临时目录已删除
tmp=$(mktemp -d)
git clone --no-local "$OLDPWD/worktree" "$tmp/full"
cd "$tmp/full"
git rev-parse HEAD              # = ACCEPTED_HEAD；git rev-list --count HEAD = 181
sha256sum common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh \
  tests/lib/session-path-race-driver.py tests/test-session-path-races.sh \
  common/.harness/lib/session-state-snapshot.sh tests/test-session-snapshot.sh > "$tmp/before.sha256"
bash ./tests/test-session-snapshot-assurance.sh >"$tmp/o" 2>"$tmp/e"   # rc=0
printf 'RESULT PASS  session snapshot assurance\n' | cmp -s - "$tmp/o" && test ! -s "$tmp/e"
bash ./scripts/check.sh --offline >"$tmp/off" 2>"$tmp/offerr"          # rc=0，stderr 空
test "$(rg -c 'RESULT PASS  session snapshot assurance' "$tmp/off")" = 1
tail -1 "$tmp/off"              # RESULT PASS  aosp-harness offline quality gate
sha256sum -c "$tmp/before.sha256"   # 六行全 OK
git status --porcelain          # 空
cd / && rm -rf "$tmp" && test ! -e "$tmp"

# 5. 源 worktree
cd "$WORK/worktree" && git rev-parse HEAD   # = ACCEPTED_HEAD
git status --porcelain                      # 空
sha256sum -c ../evidence/task-2.2-logs/upstream-before.sha256   # 六行全 OK
````
