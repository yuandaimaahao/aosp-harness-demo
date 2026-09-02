# Task 1.2 Report: 机械落地默认基础测试

## task

任务 1.2（八任务中的第二个），spec `2026-09-02-03b-session-snapshot-safety`，项目
`.spec/2026-08-31-aosp-harness-refactor`。产出 `snapshot-default-matrix-v1`（唯一交付源码文件
`tests/test-session-snapshot.sh`），消费任务 1.1 的 `session-snapshot-runtime-v2`。本报告只覆盖
控制器分配给实现 agent 的步骤 1–5；步骤 6（独立 review）与步骤 7（mark/ledger/manifest）由控制器执行。

## base / head

- `TASK_BASE` = `192fa1e133c50625ac5a6d1ce14f9a5df8502f72`（任务 1.1 accepted head，本任务 base；
  实测：commit 前 `IMPL` HEAD 即此值，working tree clean）
- `BASE_SHA` (execution BASE，exact2/400 门用) = `3d15a0d76c2a2e6c8541c5d47001a55f0ca18649`
- `TASK_HEAD` = `ab1e870ece16bbc24e1a86f84110366f84aae0d9`（本任务提交后的 IMPL HEAD）
- `PROTO_SHA` = `a708ce6f0979c6644292b58b4a7b0d4afcdf821d`
- `PROTO_TEST` blob = `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/prototype/snapshot-test-prototype.sh`（192 行，已用 `git show "$PROTO_SHA:$PROTO_TEST" | wc -l` 核对）

## files

- 创建（提交进 IMPL）：`tests/test-session-snapshot.sh`（192 行，模式 100755，
  sha256 = `725358357555df4c1920478b769450d3708b3e6a81a9017291fcce447ef78ab7`）
- 测试但未修改：`common/.harness/lib/session-state-snapshot.sh`（208 行，任务 1.1 交付，
  sha256 = `17dfa03a4126231f4f4afbbee33178c0f109c637355cc222d7f874a7ec4b5d0f`，本任务未触碰）
- 证据（`$WORK`，不在 git 工作树内）：
  - `evidence/task-1.2-red.txt`（红阶段证据，六行 schema + assertion）
  - `evidence/task-1.2-logs/`（全部分离 rc/stdout/stderr 日志，见下）
  - 本报告 `task-1.2-report.md`

## commands（关键命令与对应日志路径）

所有命令均在 `$IMPL` 内以 `cd "$IMPL"` 执行，日志落 `$WORK/evidence/task-1.2-logs/`。

### 步骤 1（红阶段）

```
test ! -e tests/test-session-snapshot.sh
bash tests/test-session-snapshot.sh   # -> rc127, stderr="bash: tests/test-session-snapshot.sh: No such file or directory"
SNAPSHOT_CORE=<runtime> bash <proto-test-blob>   # 前置核对：prototype test 打在任务1.1 runtime 上仍 PASS
```
日志：`red-stdout.txt` `red-stderr.txt`；前置核对日志 `precondition-stdout.txt` `precondition-stderr.txt`。
红证据文件：`evidence/task-1.2-red.txt`。

### 步骤 2（机械转换落地）

```
git show "$PROTO_SHA:$PROTO_TEST" > proto-test-blob.sh   # 192 行
sed 's#core=${SNAPSHOT_CORE:-$here/snapshot-core-prototype.sh}#core=${SNAPSHOT_CORE:-$repo/common/.harness/lib/session-state-snapshot.sh}#' proto-test-blob.sh > expected-target.sh
diff proto-test-blob.sh expected-target.sh   # 唯一 1 行差异，即第13行 core= 赋值
cp expected-target.sh "$IMPL/tests/test-session-snapshot.sh"
cmp -s expected-target.sh "$IMPL/tests/test-session-snapshot.sh"   # OK
wc -l "$IMPL/tests/test-session-snapshot.sh"   # 192
```
日志：`expected-target.sh`（临时 expected，仅落在 `$WORK`，未纳入 diff）。

### 步骤 3（argv 全表 / dependency-present / provider-absent / source 四态 / self-disproof）

```
bash tests/test-session-snapshot.sh              # argv-none
bash tests/test-session-snapshot.sh all          # argv-all
bash tests/test-session-snapshot.sh --dependency-absent   # argv-absent
bash tests/test-session-snapshot.sh bogus                 # argv-unknown
bash tests/test-session-snapshot.sh all extra             # argv-extra
bash tests/test-session-snapshot.sh --dependency-absent=1 # argv-flagvalue
bash tests/test-session-snapshot.sh --dependency-absent --dependency-absent  # argv-doubleflag
bash tests/test-session-snapshot.sh '' all                # argv-emptyplusall
```
日志目录：`step3/argv-*.{stdout,stderr,rc}`。

隔离 provider-absent（独立 git 仓库副本，`sed` 改名 `harness_validate_feature_name`→
`harness_validate_feature_name_disabled`、`_harness_session_path_core`→
`_harness_session_path_core_disabled`，syntax 经 `bash -n` 核对）：

```
rsync -a --exclude='.git' "$IMPL"/ "$ISO"/ && (cd "$ISO" && git init -q && git add -A && git commit -q -m "iso snapshot")
sed -i 's/harness_validate_feature_name/harness_validate_feature_name_disabled/g' "$ISO/common/.harness/lib/session-state-foundation.sh"
sed -i 's/_harness_session_path_core/_harness_session_path_core_disabled/g' "$ISO/common/.harness/lib/session-state-path.sh"
bash tests/test-session-snapshot.sh                  # iso-absent-default
bash tests/test-session-snapshot.sh --dependency-absent  # iso-absent-flag
bash tests/test-session-snapshot.sh all              # iso-absent-all
```
日志目录：`step3/iso-absent-*.{stdout,stderr,rc}`。`cmp -s` 确认 default/flag/all 三者 stdout 逐字节相同。

Failure-stdout / source-rc self-disproof（证明测试不是空转，能检出违约）：

```
# broken-source-rc.sh = runtime + 追加 `return 1`（迫使 source rc!=0）
# broken-stdout.sh    = `echo BROKEN_STDOUT` + runtime（迫使 source 期间 stdout 非空）
SNAPSHOT_CORE=broken-source-rc.sh bash tests/test-session-snapshot.sh   # selfdisproof-source-rc
SNAPSHOT_CORE=broken-stdout.sh    bash tests/test-session-snapshot.sh   # selfdisproof-stdout
```
日志目录：`step3/selfdisproof-*.{stdout,stderr,rc}`；损坏 core 副本落
`evidence/task-1.2-logs/broken-cores/`（仅供本次验证，未提交、未修改 tracked runtime）。

### 步骤 4（并发/攻击/PID/首信号/anchor/misuse-zero-state）

同/异值并发、managed/snapshot 攻击表、真实 Python PID 探测（TEMP barrier）与首信号锁存均编译在
`tests/test-session-snapshot.sh` 单次运行内部（见 blob 第64–192行），已通过步骤3的
`argv-none`/`argv-all` 及以下重复运行验证其稳定性（非 flaky）：

```
for i in 1 2 3; do bash tests/test-session-snapshot.sh; done   # 3 次全部 rc0 且摘要逐字相同
```
日志：`step4/repeat-{1,2,3}.{stdout,stderr}`。

八 anchor exact-once（对 tracked runtime 直接核验，独立于测试内部对 probe_core 副本的核验）：

```
for marker in CAPTURE_READY SNAPSHOT_MANAGED_BEFORE_OPEN MANAGED_EXPECTED_EUID \
  SNAPSHOT_EXPECTED_EUID SNAPSHOT_BEFORE_OPEN TEMP_BEFORE_PUBLISH PUBLISH_RESULT OS_ERROR; do
  rg -c "HARNESS_TEST_MARKER_$marker" common/.harness/lib/session-state-snapshot.sh   # 每个=1
done
rg -n -i 'fallback' common/.harness/lib/session-state-snapshot.sh tests/test-session-snapshot.sh   # 无匹配
```

strict misuse 零 state（`bogus` 参数在 argv case 检查之前即 `exit 1`，未到 `mktemp -d`）：

```
before=$(find /tmp -maxdepth 1 | wc -l); bash tests/test-session-snapshot.sh bogus; after=$(find /tmp -maxdepth 1 | wc -l)
# before == after == 254
```
日志：`step4/`（anchor 与 fallback 检查为终端输出，已在本报告结果节复述；misuse-zero-state 计数见结果节）。

### 步骤 5（工具/提交/门禁）

```
export PATH=<pinned tools>:$PATH
shfmt --version    # v3.14.0
shellcheck --version   # version: 0.11.0
git add -N tests/test-session-snapshot.sh
git diff --name-only "$BASE_SHA" -- .    # exact 2 files
git diff --numstat "$BASE_SHA" -- .      # 208+192=400
shfmt -d -i 2 -ci -bn common/.harness/lib/session-state-snapshot.sh tests/test-session-snapshot.sh
shellcheck -x --severity=warning common/.harness/lib/session-state-snapshot.sh tests/test-session-snapshot.sh
bash -n common/.harness/lib/session-state-snapshot.sh
bash -n tests/test-session-snapshot.sh
git diff --check "$BASE_SHA" -- .
bash tests/test-session-snapshot.sh            # precommit-default
bash tests/test-session-snapshot.sh all        # precommit-all
bash ./scripts/check.sh --offline              # precommit-offline
sha256sum <upstream 4 files>                   # before-commit snapshot
git add tests/test-session-snapshot.sh
git commit -m "test(session): add snapshot safety matrix"$'\n\n'"Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"$'\n'"Claude-Session: https://claude.ai/code/session_011s6gitkgEpJucnW53k1Ced"
git diff --name-only "$TASK_BASE" "$TASK_HEAD"   # exact 1: tests/test-session-snapshot.sh
git diff --numstat "$BASE_SHA" "$TASK_HEAD"      # 208+192=400
git status --short                               # clean
sha256sum <upstream 4 files>                     # after-commit, unchanged
bash tests/test-session-snapshot.sh              # postcommit-default
bash tests/test-session-snapshot.sh all          # postcommit-all
bash ./scripts/check.sh --offline                # postcommit-offline
```
日志目录：`step5/*.{stdout,stderr,rc}`、`step5/shfmt.diff`、`step5/shellcheck.{out,err}`、
`step5/diffcheck.{out,err}`、`step5/upstream-sha-before-commit.txt`。

## results

- 红阶段：`bash tests/test-session-snapshot.sh`（文件缺席）rc=127，stdout 空（无 PASS），
  stderr=`bash: tests/test-session-snapshot.sh: No such file or directory`。前置核对：
  prototype test blob 打在任务1.1 runtime 上 rc=0，stdout 逐字
  `RESULT PASS  session snapshot safety\n`，stderr 空——证明任务1.1的4处内联
  `2>/dev/null` stderr 抑制修复未与 prototype 断言冲突，无需 BLOCKED。
- 机械转换：`diff` 仅第13行 `core=` 赋值一处差异，`cmp -s` 落地文件与临时 expected 完全一致，
  `wc -l` = 192。
- argv 全表：`''`/`all`/`--dependency-absent` 均 rc0、stdout 逐字
  `RESULT PASS  session snapshot safety\n`、stderr 空；`bogus`/`all extra`/
  `--dependency-absent=1`/`--dependency-absent --dependency-absent`/`'' all` 均 rc1、stdout 空、
  无 PASS。
- 隔离 provider-absent（真实 harness_validate_feature_name/_harness_session_path_core 改名缺席）：
  default/`--dependency-absent`/`all` 三者 rc0，stdout 逐字节相同（`cmp -s` 通过）且均为固定 PASS
  摘要，stderr 全空——证明真实 provider 缺席时 default 与显式 flag 落在同一 inert surface。
- self-disproof：强制 source rc≠0（`broken-source-rc.sh`）与强制 source 期间 stdout 非空
  （`broken-stdout.sh`）两种人为破坏 core 的情形，测试均正确判定 rc=1、stdout 空、无 PASS——
  证明测试并非空转，能检出对 R1 契约的违反。
- 并发/攻击/PID/信号：内嵌在单次 `bash tests/test-session-snapshot.sh` 运行中，重复 3 次全部
  rc0 且摘要逐字节相同，未出现 flaky 失败；测试内部对 winner/victim/temp 的
  `tree_state`/`object_state`/`temp_count` 前后比对均以 `failures` 计数器归零收敛到最终 PASS。
- 八 anchor：对 tracked runtime 直接 `rg -c` 核对，`CAPTURE_READY`/
  `SNAPSHOT_MANAGED_BEFORE_OPEN`/`MANAGED_EXPECTED_EUID`/`SNAPSHOT_EXPECTED_EUID`/
  `SNAPSHOT_BEFORE_OPEN`/`TEMP_BEFORE_PUBLISH`/`PUBLISH_RESULT`/`OS_ERROR` 各恰好 1 次；
  `rg -i fallback` 对两文件均无匹配。
- strict misuse 零 state：`bogus` 参数运行前后 `/tmp` 顶层条目数均为 254，无残留（misuse 分支在
  `mktemp -d` 之前即 `exit 1`）。
- 固定工具版本：`shfmt --version` = `v3.14.0`，`shellcheck --version` 的 `version:` 字段 =
  `0.11.0`，逐字匹配。
- 静态检查：对 exact 两文件 `shfmt -d -i 2 -ci -bn` 无差异（rc0）、
  `shellcheck -x --severity=warning` 无诊断（rc0）、`bash -n` 两文件均 rc0。
- `git diff --check "$BASE_SHA" -- .` rc0，无空白错误。
- 门禁计数：`BASE_SHA..TASK_HEAD` name-only exact 两文件
  （`common/.harness/lib/session-state-snapshot.sh`、`tests/test-session-snapshot.sh`），
  numstat 208+192=**400**（零余量，与 R8/R7 exact2/400 门吻合）；`TASK_BASE..TASK_HEAD`
  name-only exact 1 文件（`tests/test-session-snapshot.sh`）。
- 提交前后 `bash tests/test-session-snapshot.sh`、`bash tests/test-session-snapshot.sh all`
  均 rc0、stdout 逐字 `RESULT PASS  session snapshot safety\n`、stderr 空；
  `bash ./scripts/check.sh --offline` 提交前后均 rc0，输出中
  `RESULT PASS  session snapshot safety` 恰好出现 1 次，末行为
  `RESULT PASS  aosp-harness offline quality gate`。
- 上游四文件（`session-state-foundation.sh`、`session-state-path.sh`、
  `session-path-race-driver.py`、`test-session-path-races.sh`）SHA-256 在提交前后逐字节不变。
- 提交后 `git status --short` 输出为空（clean）。
- Commit：`ab1e870ece16bbc24e1a86f84110366f84aae0d9`，message 首行逐字
  `test(session): add snapshot safety matrix`，普通 Conventional Commit（非 amend），仅暂存并提交
  `tests/test-session-snapshot.sh` 一个文件（`1 file changed, 192 insertions(+)`，
  `create mode 100755`）。未 push，未触碰 main。

红阶段证据: /home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03b-session-snapshot-safety/evidence/task-1.2-red.txt

## 顾虑

- 未发现与「任务1.1已修复的4处内联 `2>/dev/null` stderr 抑制」冲突的 prototype 断言；红阶段前置
  核对（prototype test 直接指向任务1.1 runtime）rc0/PASS/双流按预期，因此本任务未触发 BLOCKED
  分支。
- 步骤 6（独立 review）与步骤 7（mark-task-done / ledger 锚点 / sync-ledger）按契约由控制器执行，
  本报告不包含这两步的产出。
