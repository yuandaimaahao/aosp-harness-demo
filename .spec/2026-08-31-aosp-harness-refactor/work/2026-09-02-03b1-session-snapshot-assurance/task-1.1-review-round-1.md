# task 1.1 review: 2026-09-02-03b1-session-snapshot-assurance round 1

- 审查人：独立 reviewer（全新上下文 subagent，与实现者/控制器无关）
- 日期：2026-09-02
- 对象：spec 任务 1.1「交付完整 assurance 候选文件」
  - brief：`/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/task-1.1-brief.md`
  - 报告：同目录 `task-1.1-report.md`
  - 证据包：同目录 `evidence/`（task-1.1-red.txt、task-1.1-logs/、task-1.1-evidence.tsv）
  - 交付 commit：worktree 分支 `spec/2026-09-02-03b1-session-snapshot-assurance` 的 `c7a18edf2f6b3a2fec02b917d37fe5098dd1974a`（TASK_BASE=`8a164f212c398a95703a38fb919af2b31c6e1662`）

## 结论

**PASS**（阻断 0 / 重要 0 / 次要 1）

所有七项必做核验均独立实跑通过，未采信报告自述。E3 修订经独立复核：(a) 修订正确且最小（实测旧 standalone 检查对健康 provider 误拒 rc=1、修订后 rc=0，且只增加 source 两个 provider 真实依赖的上游 lib）；(b) 候选文件该行与修订后 brief/tasks.md 逐字一致；(c) fail-closed 七类语义未破坏（export 缺席 fixture 在修订后检查下仍 rc1 无 PASS）。

## 逐项核验

### 1. exact1 / numstat / 上游六文件 / clean — 通过

- `git diff --name-only 8a164f2..c7a18ed` 恰为单行 `tests/test-session-snapshot-assurance.sh`。
- numstat：`346 0`，总和 346 ≤ 400。
- 上游六文件（foundation/path/race-driver/test-session-path-races/snapshot/test-session-snapshot）diff 为空。
- worktree 内 `git status --porcelain` 为空；HEAD=`c7a18ed`，commit subject `test(session): add snapshot assurance matrix`。

### 2. 候选文件对 prototype blob 的 diff — 通过

- blob 门：`git show cbdbdde0…:…/prototype/snapshot-assurance-r1.sh | wc -l` = 308；候选文件 346 行（308+38）。
- 独立 `diff` 恰 7 个 hunk：`5c5,35`（E1+E2+E3，因相邻合并为一 hunk）、`10c40`（E4）、`82a113,117`（E5）、`268a304`（E6a）、`271a308`（E6b）、`276c313`（E6c）、`282a320`（E6d），无其他差异。逐 hunk 与 brief E1–E6 的确切代码/转换规则逐字比对一致（含 E6a 连字符 `cleanup-log` 前提）。
- 探针字面量 `printf 'RESULT PASS  session snapshot assurance\n'` 恰 3 处：第 17、33 行（E3 两处 inert 分支）与第 346 行（末行 active 出口）；E1 注释只含摘要文字、不含该 printf 字面量。

### 3. 红绿证据 — 通过

- `task-1.1-red.txt` 七行：六行 schema（task/command/expected/rc/stdout_sha256/stderr_sha256）+ assertion；rc=127、stdout 为空哈希 `e3b0c44…`、stderr 哈希与 `logs/red.stderr`（"No such file or directory"）一致。
- 红先于绿：red.stdout 时间戳 22:18、red.txt 22:19，绿阶段日志自 22:35 起。
- `task-1.1-evidence.tsv` 62 行全部三列（path/sha256/bytes），对全部 62 行（非抽查）重算 sha256 与字节数，零不匹配。

### 4. 实跑（全部独立重跑于临时目录，用后已清理）— 通过

- dependency-present（worktree 内）：`bash ./tests/test-session-snapshot-assurance.sh` 与 `... all` 均 rc=0、stdout 与 `printf 'RESULT PASS  session snapshot assurance\n'` cmp 逐字一致、stderr 0 字节。
- 断言计数探针（rindex 末行前插 `printf 'checks=%d\n' "$checks" >&2`，仓库内 `mktemp -d "$PWD/.count.XXXXXX`，用后删除、worktree 仍 clean）：rc=0、stdout 逐字摘要、stderr 恰 `checks=241`。
- argv 非法三行（`--bogus` / `all extra` / `--dependency-absent=x`）：逐行 rc=1、stdout PASS 计数 0、stderr 0 字节。
- inert 三态（`git clone --no-local` 后 `rm` provider）：default/all/`--dependency-absent` 均 rc=0、stdout 逐字同一固定摘要、stderr 0 字节；index 探针（两空格缩进、`${checks:-0}`）rc=0、stdout 逐字 inert 摘要、stderr 恰 `checks=0`。
- fail-closed 七类（每类独立 clone + 按 brief 步骤 6 fixture）：(a) 目录、(b) symlink→/dev/null、(c) 追加 `if`（bash -n 失败）、(d) 追加 `false`（source 非零）、(e) sed 改名 read_core（export 缺席）、(f) anchor 两次、(g) renameat2 两次——default 与 `--dependency-absent` 各 7 行全部 rc=1、stdout 无 PASS。其中 (e) 在**修订后** E3 检查下仍正确 rc1。
- E3 修订前提实测：对当前健康 provider，旧式 `source provider && declare -F fn` 三个 export 均 rc=1（旧检查会误拒健康 provider，即原 brief 确有缺陷）；修订式（先 source foundation+path）三个 export 均 rc=0。

### 5. 静态门 — 通过

- 固定工具目录 `/tmp/claude-1000/…/tools/bin`：`shfmt --version` 逐字 `v3.14.0`；`shellcheck --version` 含 `version: 0.11.0`。
- `shfmt -d -i 2 -ci -bn` 无输出 rc=0；`shellcheck -x --severity=warning` rc=0；`bash -n` rc=0；`git diff --check` rc=0（均只对本片单文件）。

### 6. 报告六节 — 通过

- 报告含 task/base/head/files/commands/results 六节与红阶段证据行；base/head SHA、346 行、探针 3 处、`checks=241`、七类×2 fail-closed、工具版本、provider SHA-256（`17dfa03a…`，实测当前 provider 文件同值）均与实测一致；`integration-diff.log` 的 7 个 hunk 头与独立 diff 完全一致。

### 7. 一致性 — 通过

- 候选文件第 24 行 E3 export 检查与修订后 brief（E3 块）及 tasks.md:82 逐字一致（直接字节比对）。
- 与 R1–R10 及 design 的 inert/fail-closed 语义一致：CLI 四态、inert 三态同一固定摘要 rc0、fail-closed 七类先于 inert 分支执行（`--dependency-absent` 不放行损坏 provider，实测确认）、R3 静态核对（八 marker/renameat2 各一次、无 `os.replace/link/rename` fallback）均在候选文件中落地且经 (f)(g) 两类 fixture 实跑验证。

## Findings

### 阻断

无。

### 重要

无。

### 次要

1. brief/PLAN 中「整合后全文约 349 行」与实际 346 行差 3 行。brief 原文为「约 349 行」且硬约束 ≤400 成立（346），E1–E6 逐字落地无遗漏，属估算误差，不影响验收；仅记录备查，无需修复。

## 附：复核命令

````bash
# ---- 1. exact1 / clean（worktree 内）----
WT=/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b1-session-snapshot-assurance/worktree
cd "$WT"
git rev-parse HEAD                                            # c7a18edf2f6b…
git diff --name-only 8a164f212c398a95703a38fb919af2b31c6e1662 c7a18edf2f6b3a2fec02b917d37fe5098dd1974a
git diff --numstat 8a164f2 c7a18ed                            # 346 0
git diff --name-only 8a164f2 c7a18ed -- common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh tests/lib/session-path-race-driver.py tests/test-session-path-races.sh common/.harness/lib/session-state-snapshot.sh tests/test-session-snapshot.sh   # 空
git status --porcelain                                        # 空

# ---- 2. prototype diff / 探针计数 ----
PROTO_SHA=cbdbdde0e1e3ff4ceb2dc0279b1db83127a0ea9e
PROTO=.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/prototype/snapshot-assurance-r1.sh
git show "$PROTO_SHA:$PROTO" | wc -l                          # 308
wc -l < tests/test-session-snapshot-assurance.sh              # 346
grep -cF "printf 'RESULT PASS  session snapshot assurance\n'" tests/test-session-snapshot-assurance.sh   # 3
git show "$PROTO_SHA:$PROTO" > /tmp/proto-r1.sh
diff /tmp/proto-r1.sh tests/test-session-snapshot-assurance.sh   # 恰 7 hunk: 5c5,35 / 10c40 / 82a113,117 / 268a304 / 271a308 / 276c313 / 282a320

# ---- 3. 证据包 ----
cat ../evidence/task-1.1-red.txt                              # 六行 schema + assertion, rc=127
awk -F'\t' 'NF!=3{bad=1} END{exit bad}' ../evidence/task-1.1-evidence.tsv
while IFS=$'\t' read -r p s b; do
  [ "$(sha256sum "$p" | cut -d' ' -f1)" = "$s" ] && [ "$(stat -c%s "$p")" = "$b" ] || echo "MISMATCH: $p"
done < ../evidence/task-1.1-evidence.tsv                      # 62 行零不匹配

# ---- 4. dependency-present / argv / checks=241 ----
bash ./tests/test-session-snapshot-assurance.sh >o 2>e; echo $?           # 0
printf 'RESULT PASS  session snapshot assurance\n' | cmp -s - o; test ! -s e
bash ./tests/test-session-snapshot-assurance.sh all >o2 2>e2              # 同上
bash ./tests/test-session-snapshot-assurance.sh --bogus                   # rc1 无 PASS
bash ./tests/test-session-snapshot-assurance.sh all extra                 # rc1 无 PASS
bash ./tests/test-session-snapshot-assurance.sh --dependency-absent=x     # rc1 无 PASS
D=$(mktemp -d "$PWD/.count.XXXXXX"); cp tests/test-session-snapshot-assurance.sh "$D/probe.sh"
python3 - "$D/probe.sh" <<'PY'   # rindex 前插 printf 'checks=%d\n' "$checks" >&2
import sys
p=sys.argv[1]; s=open(p).read()
n="printf 'RESULT PASS  session snapshot assurance\\n'"; assert s.count(n)==3
i=s.rindex(n); open(p,"w").write(s[:i]+"printf 'checks=%d\\n' \"$checks\" >&2\n"+s[i:])
PY
bash "$D/probe.sh" >"$D/out" 2>"$D/err"; cat "$D/err"         # checks=241
rm -rf "$D"; git status --porcelain                           # 仍 clean

# ---- 5. inert 三态 + checks=0（临时 clone，用后 rm -rf）----
T=$(mktemp -d); git clone --no-local -q . "$T/r"; rm "$T/r/common/.harness/lib/session-state-snapshot.sh"
cd "$T/r"
bash ./tests/test-session-snapshot-assurance.sh                # rc0 逐字 inert 摘要 stderr 空
bash ./tests/test-session-snapshot-assurance.sh all            # 同上
bash ./tests/test-session-snapshot-assurance.sh --dependency-absent   # 同上
# index 探针（两空格缩进 ${checks:-0}）→ rc0、stderr 恰 checks=0

# ---- 6. fail-closed 七类（每类独立 clone + fixture）----
# (a) rm provider; mkdir 同名   (b) ln -s /dev/null   (c) printf 'if\n' >>
# (d) printf 'false\n' >>       (e) sed 改名 read_core (f) 追加 '# HARNESS_TEST_MARKER_OS_ERROR'
# (g) 追加 '# renameat2'；逐类 default 与 --dependency-absent 均 rc1 且 stdout 无 PASS

# ---- 7. E3 修订前提 ----
P=common/.harness/lib/session-state-snapshot.sh
bash -c 'source "$1" && declare -F "$2" >/dev/null' _ "$P" _harness_session_snapshot_worker    # rc1（旧检查误拒）
bash -c 'source "$1/common/.harness/lib/session-state-foundation.sh" && source "$1/common/.harness/lib/session-state-path.sh" && source "$2" && declare -F "$3" >/dev/null' _ "$WT" "$P" _harness_session_snapshot_worker   # rc0（修订后正确）
# tasks.md 逐字一致性
sed -n '82p' /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/specs/2026-09-02-03b1-session-snapshot-assurance/tasks.md
sed -n '24p' tests/test-session-snapshot-assurance.sh          # 逐字相同

# ---- 8. 静态门 ----
TOOLS=/tmp/claude-1000/-home-zzh0838-CareerDevelop-AI2D-aosp-harness-demo/bdc6e669-9154-4030-a9db-78dc599ab491/scratchpad/tools/bin
"$TOOLS/shfmt" --version                                       # v3.14.0
"$TOOLS/shellcheck" --version | grep '^version:'               # version: 0.11.0
"$TOOLS/shfmt" -d -i 2 -ci -bn tests/test-session-snapshot-assurance.sh   # 无输出 rc0
"$TOOLS/shellcheck" -x --severity=warning tests/test-session-snapshot-assurance.sh   # rc0
bash -n tests/test-session-snapshot-assurance.sh               # rc0
git diff --check                                               # rc0
sha256sum common/.harness/lib/session-state-snapshot.sh        # 17dfa03a…（运行后不变）
````
