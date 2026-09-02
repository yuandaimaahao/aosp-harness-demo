# 2026-09-02-03a2-session-path-race-matrix 实现计划

执行基线固定为进入execute时的`BASE_SHA`。三个任务严格串行；每个任务先保存真实红阶段证据，再由实现agent参考`work/2026-09-02-03a2-session-path-race-matrix/prototype/tests/test-session-path-races.sh`的137行可执行蓝图完成最小纵切，提交普通Conventional Commit，最后交给未参与该任务实现的agent做`TASK_BASE..TASK_HEAD`独立diff review。controller只维护六列`review-manifest.tsv`、ledger与门禁，不读取或改写生产实现。任何blocker/important finding未复审PASS时不得派下一任务。

### 任务 1: 固定CLI、37-row matrix与最小inert表面

文件: 创建 `tests/test-session-path-races.sh`
消费: 无
产出: matrix-gate-v1
需求: R1, R2, R3, R4
必需: 是

- [ ] 步骤 1: controller在派发前从implementation worktree只读记录`BASE_SHA=$(git rev-parse HEAD)`，验证为40位commit并把同一immutable值显式传入每个任务brief/report与最终controller命令；同时记录tracked foundation/provider/driver的SHA-256及目标文件物理缺席。运行`bash tests/test-session-path-races.sh`，红阶段必须因文件缺席而非临时同名源码失败，stdout不含`RESULT PASS`。
- [ ] 步骤 2: 只提取prototype的root/temp/argv、`write_matrix`、`check_matrix`、`inert_surface`与provider-absent分支。matrix顺序固定为swap9、wrong-euid3、eexist9、mkdir-replace3、mkdir-failure3、post-mkdir-disappear3、open-disappear3、final-stat-disappear3、real-eio1；在读取任何dependency前校验37行、37唯一ID及`9/3/9/3/3/3/3/3/1`。
- [ ] 步骤 3: 保留test-only `HARNESS_TEST_MATRIX_DAMAGE=duplicate`，parent把入口复制到provider缺席的隔离root并只给child设置该变量；child必须rc1/stdout0/no-PASS，且不得引入skip-fixture seam。provider物理缺席则在新Bash进程证明core、四public API及marker全缺席后输出唯一41B摘要；provider存在的临时过渡分支必须rc1诊断`dependency classifier incomplete`，不允许假绿。

  本片在matrix/inert helper之后的可直接落地收口固定为：

  ```bash
  validate_matrix || fail '37 unique rows and nine category counts'
  matrix_self_disproof
  if [[ ! -e $PROVIDER && ! -L $PROVIDER ]]; then
    pass_inert
  fi
  fail 'dependency classifier incomplete'
  ```
- [ ] 步骤 4: 在同一个provider物理缺席的隔离root中分别运行no-arg、`all`和`--dependency-absent`三种调用，均要求rc0、stdout逐字41B、stderr0；不得把provider-present误解为inert。unknown、`all extra`、`--dependency-absent value`均rc1/stdout0/no-PASS；matrix duplicate同时删除provider/foundation/driver仍在inert前rc1。在真实repo验证只因过渡诊断失败，不执行driver case。
- [ ] 步骤 5: 先`git add -N tests/test-session-path-races.sh`，再跑`bash -n`、`git diff --check`、BASE..working-tree exact1/400与dependency SHA不变；以`test(session): add race matrix gate`提交。保存red/green日志、实现报告和SHA，独立review最终PASS后才派任务2。

### 任务 2: 建立provider/driver/core优先级分类器

文件: 修改 `tests/test-session-path-races.sh`
消费: matrix-gate-v1
产出: dependency-classifier-v1
需求: R4, R5, R7
必需: 是

- [ ] 步骤 1: 在真实dependency-present repo运行`bash tests/test-session-path-races.sh`，确认当前红阶段精确因`dependency classifier incomplete`而rc1、stdout0/no-PASS；记录driver未被调用与provider/driver SHA不变。
- [ ] 步骤 2: 按设计固定顺序实现：provider缺席inert → provider存在则三anchor各exact1 → driver缺席inert/symlink或nonregular fail → `python3 DRIVER protocol`精确rc0/stdout28B/stderr0 → flag/foundation缺席/core不可用inert。protocol必须用分离临时文件捕获stdout/stderr与rc，不得用丢失末LF的command substitution判等。

  本片用下列完整顺序替换任务1的过渡收口，不提前加入`run-matrix`：

  ```bash
  for marker in HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN HARNESS_TEST_MARKER_EXPECTED_EUID HARNESS_TEST_MARKER_OS_ERROR; do
    count=$(grep -Fo "$marker" "$PROVIDER" | wc -l)
    [[ $count == 1 ]] || fail 'provider anchors: expected each exactly once'
  done
  if [[ -L $DRIVER || (-e $DRIVER && ! -f $DRIVER) ]]; then
    fail 'race driver: expected regular non-symlink file'
  fi
  if [[ ! -e $DRIVER ]]; then
    pass_inert
  fi
  printf '%s\n' "$DRIVER_PROTOCOL" >"$TMP_TEST/protocol.expected"
  if ! python3 "$DRIVER" protocol >"$TMP_TEST/protocol.out" 2>"$TMP_TEST/protocol.err"; then
    fail 'race driver protocol execution'
  fi
  [[ ! -s $TMP_TEST/protocol.err ]] && cmp -s "$TMP_TEST/protocol.out" "$TMP_TEST/protocol.expected" || fail 'race driver protocol bytes'
  if [[ $GROUP == dependency-absent ]] || ! core_available; then
    pass_inert
  fi
  fail 'race adapter incomplete'
  ```
- [ ] 步骤 3: dependency-present分支暂以唯一`race adapter incomplete`诊断rc1/no-PASS收口。用`.spec` controller隔离fixture表验证：provider absent；三anchor各missing/duplicate与foundation missing/core unavailable/flag的18组交叉；driver absent/symlink/directory/protocol mismatch/syntax/rc/stderr；foundation absent/core unavailable/flag。healthy-provider过渡红、provider-absent与18个anchor组合都替换为同一可记录fake driver，每个case使用独立`FAKE_DRIVER_ARGV_LOG`；生产diff不得加入fixture或controller。
- [ ] 步骤 4: 要求healthy-provider过渡红、provider-absent与anchor 18组的argv log物理缺席或0B，从而机械证明driver零调用；driver物理缺席inert且log 0行，其余损坏type/protocol状态fail closed；flag/foundation/core只inert且argv log精确一行`protocol`、无`run-matrix/self-test`，inert surface仍缺core/四API/marker。
- [ ] 步骤 5: 跑`bash -n`、`git diff --check`、BASE..working-tree exact1/400、03/03a/03a1限定路径零diff与dependency SHA不变；以`test(session): classify race dependencies`提交。独立review重点查顺序、精确双流和inert surface，最终PASS后才派任务3。

### 任务 3: 闭合run-matrix、case-log与accepted-HEAD门

文件: 修改 `tests/test-session-path-races.sh`
消费: dependency-classifier-v1
产出: session-path-race-matrix-v1
需求: R1, R2, R3, R5, R6, R7, R8, R9, R10
必需: 是
验收资产（不纳入源码文件清单）: 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03a2-session-path-race-matrix/acceptance/accepted-default.out` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03a2-session-path-race-matrix/acceptance/fake-driver.argv` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03a2-session-path-race-matrix/acceptance/matrix.tsv` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03a2-session-path-race-matrix/acceptance/case-log.expected` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03a2-session-path-race-matrix/acceptance/acceptance-report.md` / 创建 `.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03a2-session-path-race-matrix/review-manifest.tsv`

- [ ] 步骤 1: 在真实dependency-present repo运行`bash tests/test-session-path-races.sh`，确认当前红阶段精确因`race adapter incomplete`而rc1、stdout0/no-PASS；controller同时独立确认driver `protocol`与`self-test FOUNDATION PROVIDER`均绿，证明红因只在入口adapter。
- [ ] 步骤 2: 删除唯一过渡红灯，调用且只调用一次`python3 DRIVER run-matrix FOUNDATION PROVIDER ABSENT_WORKSPACE CASE_TSV CASE_LOG`；workspace为临时owner的physical absent直接子路径，case-log位于workspace内。分离捕获rc/stdout/stderr，只receive rc0、38B driver摘要和0B stderr。
- [ ] 步骤 3: 驱动成功后从TSV第一列生成expected log并`cmp`实际CASE_LOG，再核对37行、37唯一ID与九类连续计数，任何driver rc/stderr/summary或log缺失/重复/额外/乱序都rc1/no-PASS。fake driver argv log必须逐字只有`protocol`、`run-matrix`两行，绝无`self-test`。

  本片只删除`race adapter incomplete`并在原位落下以下终态adapter：

  ```bash
  printf '%s\n' "$DRIVER_SUMMARY" >"$TMP_TEST/driver.expected"
  if ! python3 "$DRIVER" run-matrix "$FOUNDATION" "$PROVIDER" "$TMP_TEST/driver" "$CASE_TSV" "$CASE_LOG" >"$TMP_TEST/driver.out" 2>"$TMP_TEST/driver.err"; then
    fail 'race driver execution'
  fi
  [[ ! -s $TMP_TEST/driver.err ]] && cmp -s "$TMP_TEST/driver.out" "$TMP_TEST/driver.expected" || fail 'race driver result bytes'
  cut -f1 "$CASE_TSV" >"$TMP_TEST/cases.expected"
  cmp -s "$CASE_LOG" "$TMP_TEST/cases.expected" || fail '37-case ordered log'
  validate_matrix || fail 'post-driver matrix validation'
  [[ $(wc -l <"$CASE_LOG") == 37 && $(sort -u "$CASE_LOG" | wc -l) == 37 ]] || fail '37 unique executed cases'
  printf '%s\n' "$SUMMARY"
  ```
- [ ] 步骤 4: 跑真实no-arg/all，均得rc0/stdout41B/stderr0，CASE_LOG 37/37与`9/3/9/3/3/3/3/3/1`证据齐全；复跑全部inert/fail-closed表、参数、matrix damage、driver result/log damage、03 foundation、03a path、driver protocol/self-test和offline。fake fixture必须用`FAKE_DRIVER_ARGV_LOG`、`FAKE_DRIVER_MATRIX_EVIDENCE`与`FAKE_DRIVER_CASE_LOG_EVIDENCE`分别保存到已声明的`fake-driver.argv`、`matrix.tsv`与`case-log.expected`，controller以下列双仓骨架逐字复核。验证`shfmt --version`=`v3.14.0`与ShellCheck version field=`0.11.0`后，只对entrypoint运行`shfmt -d -i 2 -ci -bn`、`shellcheck -x --severity=warning`、`bash -n`。
- [ ] 步骤 5: 跑无range `git diff --check`、dependency前后SHA不变、BASE..working-tree exact1/400与旧模块零diff；以`test(session): execute session path race matrix`提交并保持implementation worktree clean。以candidate HEAD建立full checkout和真实`git clone --depth 1 file://...`，在两者独立验证protocol/self-test/default/offline、当前tracked dependency SHA不变、depth commit-count=1与clean；再建隔离rollback checkout，只删除entrypoint并证明driver self-test 38B、offline PASS、race发现0次且03b物理缺席。若review产生fix commit，对新最终HEAD重跑本步与步骤4全部门禁。
- [ ] 步骤 6: 独立review PASS后，controller验证六列manifest恰好3行、首行base=`BASE_SHA`、相邻连续、末行head=当前accepted HEAD、reviewer非空且全PASS；在ledger写入accepted HEAD、dependency-present 37/37、九类计数、full/depth-1/rollback证据之前，物理验证03b spec/worktree/branch/execution-base/dispatch全缺席。只有ledger成功落盘后才允许选中03b；任何inert PASS不得代替dependency-present证据。

  controller在写ledger之前必须以下列双仓、accepted-HEAD和fail-closed骨架为唯一收口；`CONTROL_REPO_ROOT`、`IMPLEMENTATION_WORKTREE`与任务1派发前锁定的40位`BASE_SHA`由controller显式传入，不从当前目录或未定义资产猜测：

  ```bash
  set -euo pipefail
  [[ $CONTROL_REPO_ROOT == /* && $IMPLEMENTATION_WORKTREE == /* ]]
  [[ $(git -C "$CONTROL_REPO_ROOT" rev-parse --show-toplevel) == "$CONTROL_REPO_ROOT" ]]
  [[ $(git -C "$IMPLEMENTATION_WORKTREE" rev-parse --show-toplevel) == "$IMPLEMENTATION_WORKTREE" ]]
  [[ $(git -C "$CONTROL_REPO_ROOT" rev-parse --path-format=absolute --git-common-dir) == \
     $(git -C "$IMPLEMENTATION_WORKTREE" rev-parse --path-format=absolute --git-common-dir) ]]

  WORK="$CONTROL_REPO_ROOT/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-02-03a2-session-path-race-matrix"
  ACCEPT="$WORK/acceptance"
  MANIFEST="$WORK/review-manifest.tsv"
  mkdir -p "$ACCEPT"
  [[ $BASE_SHA =~ ^[0-9a-f]{40}$ ]]
  git -C "$IMPLEMENTATION_WORKTREE" cat-file -e "${BASE_SHA}^{commit}"
  HEAD_SHA=$(git -C "$IMPLEMENTATION_WORKTREE" rev-parse HEAD)
  FOUNDATION="$IMPLEMENTATION_WORKTREE/common/.harness/lib/session-state-foundation.sh"
  PROVIDER="$IMPLEMENTATION_WORKTREE/common/.harness/lib/session-state-path.sh"
  DRIVER="$IMPLEMENTATION_WORKTREE/tests/lib/session-path-race-driver.py"
  ENTRY="$IMPLEMENTATION_WORKTREE/tests/test-session-path-races.sh"
  printf 'session-path-race-driver-v1\n' >"$ACCEPT/protocol.expected"
  printf 'RESULT PASS  session path race driver\n' >"$ACCEPT/selftest.expected"
  printf 'RESULT PASS  session path race assurance\n' >"$ACCEPT/default.expected"

  capture_exact() {
    local label=$1 expected=$2 rc
    shift 2
    set +e
    "$@" >"$ACCEPT/$label.out" 2>"$ACCEPT/$label.err"
    rc=$?
    set -e
    [[ $rc == 0 && ! -s $ACCEPT/$label.err ]]
    cmp -s "$ACCEPT/$label.out" "$expected"
  }
  dependency_before=$(sha256sum "$PROVIDER" "$DRIVER")
  capture_exact protocol "$ACCEPT/protocol.expected" python3 "$DRIVER" protocol
  capture_exact selftest "$ACCEPT/selftest.expected" python3 "$DRIVER" self-test "$FOUNDATION" "$PROVIDER"
  capture_exact accepted-default "$ACCEPT/default.expected" bash "$ENTRY"
  set +e
  (cd "$IMPLEMENTATION_WORKTREE" && bash ./scripts/check.sh --offline) >"$ACCEPT/offline.out" 2>"$ACCEPT/offline.err"
  offline_rc=$?
  set -e
  [[ $offline_rc == 0 && ! -s $ACCEPT/offline.err ]]
  [[ $(grep -Fxc 'RESULT PASS  session path race assurance' "$ACCEPT/offline.out") == 1 ]]
  [[ $(tail -n 1 "$ACCEPT/offline.out") == 'RESULT PASS  aosp-harness offline quality gate' ]]
  dependency_after=$(sha256sum "$PROVIDER" "$DRIVER")
  [[ $dependency_after == "$dependency_before" ]]
  [[ -z $(git -C "$IMPLEMENTATION_WORKTREE" status --porcelain) ]]

  [[ -s $ACCEPT/fake-driver.argv && -s $ACCEPT/matrix.tsv && -s $ACCEPT/case-log.expected ]]
  awk -F '\t' 'NR==1 {ok=($0=="protocol")} NR==2 {ok=ok && $1=="run-matrix" && NF==6} END {exit !(ok && NR==2)}' "$ACCEPT/fake-driver.argv"
  [[ $(wc -l <"$ACCEPT/matrix.tsv") == 37 ]]
  [[ $(cut -f1 "$ACCEPT/matrix.tsv" | sort -u | wc -l) == 37 ]]
  counts=$(cut -f2 "$ACCEPT/matrix.tsv" | uniq -c | awk '{$1=$1; print}' | paste -sd, -)
  [[ $counts == '9 swap,3 wrong-euid,9 eexist,3 mkdir-replace,3 mkdir-failure,3 post-mkdir-disappear,3 open-disappear,3 final-stat-disappear,1 real-eio' ]]
  cut -f1 "$ACCEPT/matrix.tsv" | cmp -s - "$ACCEPT/case-log.expected"

  TMP_ACCEPT=$(mktemp -d "${TMPDIR:-/tmp}/03a2-accept.XXXXXX")
  trap 'rm -rf -- "$TMP_ACCEPT"' EXIT
  verify_checkout() {
    local label=$1 checkout=$2 before after rc
    before=$(sha256sum "$checkout/common/.harness/lib/session-state-path.sh" "$checkout/tests/lib/session-path-race-driver.py")
    python3 "$checkout/tests/lib/session-path-race-driver.py" protocol >"$TMP_ACCEPT/$label.protocol" 2>"$TMP_ACCEPT/$label.protocol.err"
    cmp -s "$TMP_ACCEPT/$label.protocol" "$ACCEPT/protocol.expected" && [[ ! -s $TMP_ACCEPT/$label.protocol.err ]]
    python3 "$checkout/tests/lib/session-path-race-driver.py" self-test "$checkout/common/.harness/lib/session-state-foundation.sh" "$checkout/common/.harness/lib/session-state-path.sh" >"$TMP_ACCEPT/$label.selftest" 2>"$TMP_ACCEPT/$label.selftest.err"
    cmp -s "$TMP_ACCEPT/$label.selftest" "$ACCEPT/selftest.expected" && [[ ! -s $TMP_ACCEPT/$label.selftest.err ]]
    bash "$checkout/tests/test-session-path-races.sh" >"$TMP_ACCEPT/$label.default" 2>"$TMP_ACCEPT/$label.default.err"
    cmp -s "$TMP_ACCEPT/$label.default" "$ACCEPT/default.expected" && [[ ! -s $TMP_ACCEPT/$label.default.err ]]
    set +e
    (cd "$checkout" && bash ./scripts/check.sh --offline) >"$TMP_ACCEPT/$label.offline" 2>"$TMP_ACCEPT/$label.offline.err"
    rc=$?
    set -e
    [[ $rc == 0 && ! -s $TMP_ACCEPT/$label.offline.err ]]
    [[ $(grep -Fxc 'RESULT PASS  session path race assurance' "$TMP_ACCEPT/$label.offline") == 1 ]]
    [[ $(tail -n 1 "$TMP_ACCEPT/$label.offline") == 'RESULT PASS  aosp-harness offline quality gate' ]]
    after=$(sha256sum "$checkout/common/.harness/lib/session-state-path.sh" "$checkout/tests/lib/session-path-race-driver.py")
    [[ $after == "$before" && -z $(git -C "$checkout" status --porcelain) ]]
  }
  git clone --no-local "$IMPLEMENTATION_WORKTREE" "$TMP_ACCEPT/full"
  git clone --depth 1 "file://$IMPLEMENTATION_WORKTREE" "$TMP_ACCEPT/depth1"
  verify_checkout full "$TMP_ACCEPT/full"
  verify_checkout depth1 "$TMP_ACCEPT/depth1"
  [[ $(git -C "$TMP_ACCEPT/depth1" rev-list --count HEAD) == 1 && -s $TMP_ACCEPT/depth1/.git/shallow ]]

  git clone --no-local "$IMPLEMENTATION_WORKTREE" "$TMP_ACCEPT/rollback"
  git -C "$TMP_ACCEPT/rollback" rm tests/test-session-path-races.sh
  git -C "$TMP_ACCEPT/rollback" -c user.name=03a2-controller -c user.email=controller@example.invalid commit -m 'revert: remove race matrix entrypoint'
  python3 "$TMP_ACCEPT/rollback/tests/lib/session-path-race-driver.py" self-test "$TMP_ACCEPT/rollback/common/.harness/lib/session-state-foundation.sh" "$TMP_ACCEPT/rollback/common/.harness/lib/session-state-path.sh" >"$TMP_ACCEPT/rollback.selftest" 2>"$TMP_ACCEPT/rollback.selftest.err"
  cmp -s "$TMP_ACCEPT/rollback.selftest" "$ACCEPT/selftest.expected" && [[ ! -s $TMP_ACCEPT/rollback.selftest.err ]]
  (cd "$TMP_ACCEPT/rollback" && bash ./scripts/check.sh --offline) >"$TMP_ACCEPT/rollback.offline" 2>"$TMP_ACCEPT/rollback.offline.err"
  [[ ! -s $TMP_ACCEPT/rollback.offline.err ]]
  [[ $(grep -Fxc 'RESULT PASS  session path race assurance' "$TMP_ACCEPT/rollback.offline" || :) == 0 ]]
  [[ $(tail -n 1 "$TMP_ACCEPT/rollback.offline") == 'RESULT PASS  aosp-harness offline quality gate' ]]
  [[ ! -e $TMP_ACCEPT/rollback/common/.harness/lib/session-state-snapshot.sh && ! -L $TMP_ACCEPT/rollback/common/.harness/lib/session-state-snapshot.sh ]]
  [[ ! -e $TMP_ACCEPT/rollback/tests/test-session-snapshot.sh && ! -L $TMP_ACCEPT/rollback/tests/test-session-snapshot.sh ]]
  [[ -z $(git -C "$TMP_ACCEPT/rollback" status --porcelain) ]]

  awk -F '\t' -v base="$BASE_SHA" -v head="$HEAD_SHA" 'NF!=6 || $1!=NR || $2!="task-" NR || $3 !~ /^[0-9a-f]{40}$/ || $4 !~ /^[0-9a-f]{40}$/ || $5=="" || $6!="PASS" {bad=1} NR==1 && $3!=base {bad=1} NR>1 && $3!=prev {bad=1} {prev=$4} END {exit bad || NR!=3 || prev!=head}' "$MANIFEST"
  [[ $(git -C "$IMPLEMENTATION_WORKTREE" diff --name-only "$BASE_SHA" "$HEAD_SHA" --) == tests/test-session-path-races.sh ]]
  [[ $(git -C "$IMPLEMENTATION_WORKTREE" diff --numstat "$BASE_SHA" "$HEAD_SHA" -- | awk '{sum+=$1+$2} END {print sum+0}') -le 400 ]]
  [[ -z $(git -C "$IMPLEMENTATION_WORKTREE" status --porcelain) ]]

  PROJECT_SPEC_ROOT="$CONTROL_REPO_ROOT/.spec/2026-08-31-aosp-harness-refactor"
  NEXT_ID=2026-09-02-03b-session-snapshot-safety
  NEXT_SPEC="$PROJECT_SPEC_ROOT/specs/$NEXT_ID"
  NEXT_WORK="$PROJECT_SPEC_ROOT/work/$NEXT_ID"
  NEXT_WORKTREE="$(dirname "$CONTROL_REPO_ROOT")/aosp-harness-demo-03b-session-snapshot-safety"
  absent() { [[ ! -e $1 && ! -L $1 ]]; }
  worktree_listing=$(git -C "$CONTROL_REPO_ROOT" worktree list --porcelain)
  if grep -F -e "worktree $NEXT_WORKTREE" -e "branch refs/heads/spec/$NEXT_ID" <<<"$worktree_listing"; then
    exit 1
  fi
  set +e
  git -C "$CONTROL_REPO_ROOT" show-ref --verify --quiet "refs/heads/spec/$NEXT_ID"
  next_ref_rc=$?
  set -e
  [[ $next_ref_rc == 1 ]]
  for path in "$NEXT_SPEC" "$NEXT_WORK" "$NEXT_WORKTREE" "$NEXT_WORK/execution-base.env" "$NEXT_WORK/review-manifest.tsv" "$NEXT_WORK/task-1-brief.md"; do
    absent "$path"
  done
  [[ -s $ACCEPT/accepted-default.out && -s $ACCEPT/matrix.tsv && -s $ACCEPT/case-log.expected && -s $ACCEPT/acceptance-report.md ]]
  ```
