# 2026-09-01-03a1-session-path-race-assurance 实现计划

执行基线固定为进入execute时记录的`BASE_SHA`。五个任务严格串行；每个任务先保存确定性红阶段证据，再由实现agent按`work/2026-09-01-03a1-session-path-race-assurance/round7-prototype/tests/lib/session-path-race-driver.py`的已验证400行蓝图完成最小纵切，提交普通Conventional Commit，最后交给未参与该任务实现的agent做`task BASE..HEAD`独立diff review。controller只维护六列`REVIEW_MANIFEST`、ledger和门禁，不读取或改写生产实现。任何阻断/重要finding未复审PASS时不得派下一任务。

### 任务 1: 固定private CLI与精确双流协议

文件: 创建 `tests/lib/session-path-race-driver.py`
消费: 无
产出: race-cli-v1 —— `protocol`、`self-test FOUNDATION PROVIDER`、`run-matrix FOUNDATION PROVIDER ABSENT_WORKSPACE CASE_TSV CASE_LOG`三种唯一CLI形状与rc/双流分类骨架
需求: R1, R2
必需: 是

- [ ] 步骤 1: 运行`python3 tests/lib/session-path-race-driver.py protocol`，确认红阶段因文件缺席而失败且没有伪造protocol token；保存BASE SHA、tracked foundation/provider SHA和03a2 worktree/branch/spec/work均不存在的起点证据。
- [ ] 步骤 2: 记录上述红阶段rc/stdout/stderr字节数；红证据不得靠临时同名源码或修改上游制造。
- [ ] 步骤 3: 只提取round7蓝图的imports、常量和argv dispatcher；两个执行mode暂以明确`AssertionError("matrix executor incomplete")`进入rc1封套，不打印PASS。关键骨架固定为：
  ```python
  if sys.argv[1:] == ["protocol"]:
      print(PROTOCOL)
      raise SystemExit
  if len(sys.argv) == 4 and sys.argv[1] == "self-test":
      mode = "self-test"
  elif len(sys.argv) == 7 and sys.argv[1] == "run-matrix":
      mode = "run-matrix"
  else:
      raise SystemExit(2)
  ```
- [ ] 步骤 4: 跑`python3 tests/lib/session-path-race-driver.py protocol`并用独立capture验证rc0、stdout逐字28B、stderr 0B；逐个验证无参数、unknown、`protocol extra`及执行mode错arity均rc2且无PASS；正确arity的执行mode均rc1且无PASS；跑`python3 -c 'import ast,pathlib; ast.parse(pathlib.Path("tests/lib/session-path-race-driver.py").read_text(), feature_version=(3,8))'`确认语法门。
- [ ] 步骤 5: 先运行`git add -N tests/lib/session-path-race-driver.py`，再用无遗漏的`git diff --name-only "$BASE_SHA" --`、`git diff --numstat "$BASE_SHA" --`和`git diff --check`确认当前untracked纵切只含driver且累计不超过400；以`test(session): add private race driver protocol`提交。保存实现报告、红日志与SHA，独立review最终PASS后才派任务2。

### 任务 2: 建立matrix能力边界与EIO纵切

文件: 修改 `tests/lib/session-path-race-driver.py`
消费: race-cli-v1 —— `protocol`、`self-test FOUNDATION PROVIDER`、`run-matrix FOUNDATION PROVIDER ABSENT_WORKSPACE CASE_TSV CASE_LOG`三种唯一CLI形状与rc/双流分类骨架
产出: race-matrix-boundary-v1 —— four-column validator、physical absent workspace、新建case-log capability、共享signature/delta原语及`real-eio`纵切
需求: R2, R3, R5, R6
必需: 是

- [ ] 步骤 1: 在系统临时目录准备合法单行`real-eio\treal-eio\tN/A\tN/A\n`、物理workspace parent和缺席leaf/log，运行`python3 tests/lib/session-path-race-driver.py run-matrix common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh "$ABSENT_WORKSPACE" "$CASE_TSV" "$CASE_LOG"`，确认红阶段rc1诊断为executor incomplete、无PASS且无case-log内容。
- [ ] 步骤 2: 用同一命令建立反例表：relative workspace/log、保留`..`、缺失parent、既有/symlink workspace、log直连provider、既有/symlink/hardlink log，以及空/含NUL/非四列/重复ID/未知token/非法组合/非canonical ID TSV；当前均不得假绿，记录provider SHA和0-case证据。
- [ ] 步骤 3: 从round7蓝图提取row枚举、signature/inventory/delta、single-anchor copy和EIO family；路径实现必须保持已实跑结构，不新增逐祖先walker：
  ```python
  parent = workspace.parent
  parent_info = parent.lstat()
  check(workspace.is_absolute() and parent.resolve(strict=True) == parent
        and stat.S_ISDIR(parent_info.st_mode), "physical workspace parent")
  check(not os.path.lexists(workspace) and case_log.parent == workspace
        and not os.path.lexists(case_log), "fresh direct capability")
  workspace.mkdir(mode=0o700, parents=False, exist_ok=False)
  workspace_fd = os.open(workspace, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
  log_fd = os.open(case_log.name, os.O_RDWR | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
                   0o600, dir_fd=workspace_fd)
  ```
  `real-eio`必须只替换OS_ERROR line并核对全N/A hook、空stdout/operation stderr/1、零delta；所有case成功且final provider hash通过后才以持有fd写log。
- [ ] 步骤 4: 跑单行纵切确认rc0、stderr 0B、stdout精确38B、log精确`real-eio\n`、workspace/log模式0700/0600；重跑步骤2反例并确认rc1、无PASS、0 case、provider不变；另验证absolute raw `.`折叠路径成功，而relative或解析后仍不满足physical/direct-child契约者失败。
- [ ] 步骤 5: 用临时`PYTHONPYCACHEPREFIX`运行`python3 -m py_compile tests/lib/session-path-race-driver.py`，再跑`git diff --check`和BASE..working-tree exact1/400；以`test(session): isolate external race matrices`提交。独立review重点核对0-case preflight、hash-before-log、fd-only write和Python 3.8兼容，最终PASS后才派任务3。

### 任务 3: 实现swap、wrong-EUID与EEXIST共享oracle

文件: 修改 `tests/lib/session-path-race-driver.py`
消费: race-matrix-boundary-v1 —— four-column validator、physical absent workspace、新建case-log capability、共享signature/delta原语及`real-eio`纵切
产出: race-primary-families-v1 —— swap9、wrong-EUID3与EEXIST9的single-anchor hook、stream、subtree/inventory/delta oracle
需求: R3, R4, R5, R6
必需: 是

- [ ] 步骤 1: 在临时TSV按需求顺序生成swap9、wrong-EUID3、EEXIST9与real-eio，共22行，运行`run-matrix`确认红阶段在首个`swap-root-safe-dir`失败、无PASS、log 0B且provider SHA不变。
- [ ] 步骤 2: 准备逆序`real-eio`、`swap-root-safe-dir`两行合法子集，运行同一命令确认未实现row不能写入log；保存实际hook/case计数供green逐字对照。
- [ ] 步骤 3: 从round7蓝图提取MANAGED/EXPECTED_EUID hook及swap、wrong-EUID、EEXIST三个family区段；保持共享`exercise`和delta schema，关键期望固定为：
  ```python
  swap_hooks = [f"MANAGED|{layer}|{name}|before_open|0|0"]
  euid_hooks = [f"EXPECTED_EUID|{layer}|{name}|N/A|0|0"]
  eexist_hooks = [f"MANAGED|{layer}|{name}|before_mkdir|0|0",
                  f"MANAGED|{layer}|{name}|after_eexist|0|1"]
  # swap_delta rekeys target/** to target.old/** by identical relative suffix;
  # EEXIST safe/unsafe/disappear authorize only their exact added/removed set.
  ```
  每child只替换一个marker-bearing line；核对stream/rc、victim subtree签名、replacement inode/type/readlink/hash/mode、wrong-EUID无后续创建和EEXIST winner/disappearance。
- [ ] 步骤 4: 跑22-row matrix确认rc0、38B摘要、stderr空、log逐字等于TSV第一列；跑逆序2-row与每family代表子集，确认仅执行输入row、log保持输入顺序；用逆序创建的`z-last/a-first`fixture确认filesystem-bytes inventory canonical。
- [ ] 步骤 5: 跑无range的`git diff --check`、Python 3.8 grammar及BASE..working-tree exact1/400；以`test(session): cover primary path races`提交，并在review package中对`TASK_BASE..TASK_HEAD`重跑diff-check。独立review逐项检查三个family、两类anchor和delta，最终PASS后才派任务4。

### 任务 4: 补齐managed lifecycle并形成精确self-test红灯

文件: 修改 `tests/lib/session-path-race-driver.py`
消费: race-primary-families-v1 —— swap9、wrong-EUID3与EEXIST9的single-anchor hook、stream、subtree/inventory/delta oracle
产出: race-selftest-red-v1 —— 九family完整37 rows已由同一executor执行，self-test只因active self-disproof尚未闭合而确定性失败
需求: R4, R5, R6, R7
必需: 是

- [ ] 步骤 1: 生成完整37-row临时TSV并跑`run-matrix`，确认红阶段在首个`mkdir-replace-root`失败、无PASS且log 0B；同时运行`self-test`确认尚不能声称“只差14项自反证”。
- [ ] 步骤 2: 从round7蓝图提取五个managed lifecycle family、内建`default_rows()`和完整执行集合/ordered hash门；在self-test末尾暂留唯一、可删除的确定性红灯。关键分派为：
  ```python
  managed_specs = {
      "mkdir-replace": (False, unsafe, "before_open", 1),
      "mkdir-failure": (False, operation, "before_mkdir", 0),
      "post-mkdir-disappear": (False, operation, "before_open", 1),
      "open-disappear": (True, operation, "before_open", 0),
      "final-stat-disappear": (True, operation, "before_open", 0),
  }
  check(len(executed) == len(rows) and set(executed) == set(expected_ids), "exact executed case set")
  if mode == "self-test":
      raise AssertionError("self-disproof incomplete")
  ```
  mkdir replacement必须比较runtime original与`.old`完整签名；三类disappearance与mkdir failure严格按设计delta，不在不安全层下创建后续层。
- [ ] 步骤 3: 跑完整37-row `run-matrix`确认rc0、38B摘要、stderr空、log 37行且有序ID hash为`721b3687bda848db7b6481c527f491e6733cf376dbade3dd37b319fce8029bc8`；逐family计数必须为`9/3/9/3/3/3/3/3/1`，1-row与逆序2-row仍成功，provider SHA不变。
- [ ] 步骤 4: 跑主`self-test`，确认37 rows均真实执行后只以精确`self-disproof incomplete`诊断rc1、stdout无PASS；缺case、hook、signature或delta必须在该诊断之前失败，形成任务5可信红因。
- [ ] 步骤 5: 跑`git diff --check`、Python 3.8 grammar、03/03a零diff和BASE..working-tree exact1/400，以`test(session): complete race family matrix`提交；独立review需在10分钟内按五family表和完整matrix检查本次diff，最终PASS后才派任务5。

### 任务 5: 闭合14项自反证与accepted-HEAD门

文件: 修改 `tests/lib/session-path-race-driver.py`
消费: race-selftest-red-v1 —— 九family完整37 rows已由同一executor执行，self-test只因active self-disproof尚未闭合而确定性失败
产出: session-path-race-driver-v1 —— tests/lib/session-path-race-driver.py提供protocol、self-test与run-matrix私有CLI，self-test固定输出RESULT PASS  session path race driver；无运行时API
需求: R1, R2, R4, R5, R6, R7, R8, R9
必需: 是

- [ ] 步骤 1: 运行`python3 tests/lib/session-path-race-driver.py self-test common/.harness/lib/session-state-foundation.sh common/.harness/lib/session-state-path.sh`，确认红阶段在37 rows之后精确因`self-disproof incomplete`而rc1、无PASS；不得借用03a2 matrix或跳过反证转绿。
- [ ] 步骤 2: 删除唯一临时红灯并提取round7的14项active self-disproof；每项只捕获预期`AssertionError`且最后按requirements名称精确比序，落地骨架如下：
  ```python
  probe_before, probe_after, probe_schema = oracle_probe
  protected_path = next(iter(probe_schema["protected"]))
  bad_signature = dict(probe_after)
  bad_signature[protected_path] = ("broken",) + bad_signature[protected_path][1:]
  must_reject(lambda: assert_delta(probe_before, bad_signature, probe_schema, "signature-disproof"), "protected signature")
  bad_inventory = dict(probe_after)
  bad_inventory["unexpected"] = next(iter(probe_after.values()))
  must_reject(lambda: assert_delta(probe_before, bad_inventory, probe_schema, "inventory-disproof"), "unexpected inventory")
  bad_allowed = dict(probe_schema)
  bad_allowed["allowed_changed_paths"] = set()
  must_reject(lambda: assert_delta(probe_before, probe_after, bad_allowed, "allowed-delta-disproof"), "allowed changed paths")
  reject_field("link", 0, 5, "wrong-target", "symlink readlink target")
  reject_field("file", 2, 6, "0" * 64, "regular file hash")
  reject_field("safe-dir", 1, 3, 0o755, "mode")
  reject_field("safe-dir", 1, 2, oracle_probes["safe-dir"][1][oracle_probes["safe-dir"][4]][2] + 1, "inode")
  actual_hooks, expected_hooks = eexist_hook_probe
  must_reject(lambda: assert_hooks(actual_hooks[:1], expected_hooks, "eexist-hook-disproof"), "EEXIST second hook")
  must_reject(lambda: assert_marker_counts(source + markers["MANAGED"]), "marker count")
  must_reject(lambda: assert_hooks([], swap_hook_probe, "sentinel-disproof"), "sentinel")
  phase_parts = swap_hook_probe[0].split("|")
  phase_parts[3] = "after_eexist"
  must_reject(lambda: assert_hooks(["|".join(phase_parts)], swap_hook_probe, "phase-disproof"), "phase")
  made_parts = mkdir_hook_probe[0].split("|")
  made_parts[4] = "0"
  must_reject(lambda: assert_hooks(["|".join(made_parts)], mkdir_hook_probe, "made-disproof"), "made")
  catch_parts = actual_hooks[1].split("|")
  catch_parts[5] = "0"
  must_reject(lambda: assert_hooks([actual_hooks[0], "|".join(catch_parts)], expected_hooks, "catch-disproof"), "catch")
  must_reject(lambda: check(case_ids[:-1] == expected_ids, "case invocation disproof"), "case invocation")
  expected_disproofs = ["protected signature", "unexpected inventory", "allowed changed paths",
                       "symlink readlink target", "regular file hash", "mode", "inode", "EEXIST second hook",
                       "marker count", "sentinel", "phase", "made", "catch", "case invocation"]
  check(self_disproofs == expected_disproofs, "self-disproof execution")
  ```
- [ ] 步骤 3: 跑主验证命令确认rc0、stderr空、stdout逐字38B；再跑合法1/2/37-row `run-matrix`证明self-disproof未泄漏。随后运行下面的隔离mutation harness：对14个具名call site逐个复制driver，把该site替换为`must_reject(lambda: None, label)`，每份copy的self-test都必须rc1、stdout 0B且无PASS；source中每个label必须只命中一个`must_reject`或`reject_field`调用，生产driver/provider SHA全程不变。
  ```python
  labels = ["protected signature", "unexpected inventory", "allowed changed paths", "symlink readlink target",
            "regular file hash", "mode", "inode", "EEXIST second hook", "marker count", "sentinel",
            "phase", "made", "catch", "case invocation"]
  source = driver.read_text()
  for number, label in enumerate(labels):
      lines = source.splitlines(keepends=True)
      hits = [index for index, line in enumerate(lines)
              if label in line and ("must_reject(" in line or "reject_field(" in line)]
      assert len(hits) == 1, (label, hits)
      indent = lines[hits[0]][:len(lines[hits[0]]) - len(lines[hits[0]].lstrip())]
      lines[hits[0]] = f"{indent}must_reject(lambda: None, {label!r})\n"
      mutant = temp_root / f"driver-{number}.py"
      mutant.write_text("".join(lines))
      result = subprocess.run([sys.executable, str(mutant), "self-test", str(foundation), str(provider)],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
      assert result.returncode == 1 and result.stdout == b"" and b"RESULT PASS" not in result.stderr
  ```
  再运行03 foundation、03a path、offline、Python 3.8 grammar、provider SHA、03/03a零diff、无range diff-check和BASE..working-tree exact1/400。本地green后提交`test(session): close race driver assurance`，确认实现worktree clean。
- [ ] 步骤 4: 以该candidate HEAD建立完整临时checkout和真实`git clone --depth 1 file://...` checkout，分别运行`protocol`、主self-test与`bash ./scripts/check.sh --offline`，确认精确双流/rc且不查询固定历史SHA；随后派独立review。若review产生fix commit，必须对新的最终HEAD重跑本步骤和步骤3全部门禁，最终review PASS后才生成本任务manifest行。
- [ ] 步骤 5: controller紧邻ledger写入前显式传入absolute `CONTROL_REPO_ROOT`与`IMPLEMENTATION_WORKTREE`并运行下列fail-closed门；两者必须属于同一Git common-dir，accepted HEAD只从implementation读取，`.spec`与next-spec资产只从controller主仓读取。`BASE_SHA`验证为40位commit，只有`REVIEW_MANIFEST`要求absolute regular file；所有预定03a2路径用`-e || -L`物理缺席判定。命令rc0后才把最终HEAD、五行全PASS manifest、full/depth-1证据写入ledger；ledger写成功后才允许创建03a2。
  ```bash
  set -euo pipefail
  [[ $CONTROL_REPO_ROOT == /* && $IMPLEMENTATION_WORKTREE == /* ]]
  [[ $(git -C "$CONTROL_REPO_ROOT" rev-parse --show-toplevel) == "$CONTROL_REPO_ROOT" ]]
  [[ $(git -C "$IMPLEMENTATION_WORKTREE" rev-parse --show-toplevel) == "$IMPLEMENTATION_WORKTREE" ]]
  CONTROL_COMMON=$(git -C "$CONTROL_REPO_ROOT" rev-parse --path-format=absolute --git-common-dir)
  IMPLEMENTATION_COMMON=$(git -C "$IMPLEMENTATION_WORKTREE" rev-parse --path-format=absolute --git-common-dir)
  [[ $CONTROL_COMMON == "$IMPLEMENTATION_COMMON" ]]
  [[ $BASE_SHA =~ ^[0-9a-f]{40}$ ]]
  git -C "$IMPLEMENTATION_WORKTREE" cat-file -e "${BASE_SHA}^{commit}"
  [[ -n $REVIEW_MANIFEST && $REVIEW_MANIFEST == /* && -f $REVIEW_MANIFEST ]]
  HEAD_SHA=$(git -C "$IMPLEMENTATION_WORKTREE" rev-parse HEAD)
  awk -F '\t' -v base="$BASE_SHA" -v head="$HEAD_SHA" 'NF!=6 || $1!=NR || $2!="task-" NR || $3 !~ /^[0-9a-f]{40}$/ || $4 !~ /^[0-9a-f]{40}$/ || $5=="" || $6!="PASS" {bad=1} NR==1 && $3!=base {bad=1} NR>1 && $3!=prev {bad=1} {prev=$4} END {exit bad || NR!=5 || prev!=head}' "$REVIEW_MANIFEST"
  PROJECT_SPEC_ROOT="$CONTROL_REPO_ROOT/.spec/2026-08-31-aosp-harness-refactor"
  NEXT_ID=2026-09-01-03a2-session-path-race-matrix
  NEXT_SPEC="$PROJECT_SPEC_ROOT/specs/$NEXT_ID"
  NEXT_WORK="$PROJECT_SPEC_ROOT/work/$NEXT_ID"
  NEXT_WORKTREE="$(dirname "$CONTROL_REPO_ROOT")/aosp-harness-demo-03a2-session-path-race-matrix"
  ! git -C "$CONTROL_REPO_ROOT" worktree list --porcelain | grep -F -e "worktree $NEXT_WORKTREE" -e "branch refs/heads/spec/$NEXT_ID"
  ! git -C "$CONTROL_REPO_ROOT" show-ref --verify --quiet "refs/heads/spec/$NEXT_ID"
  absent() { [[ ! -e $1 && ! -L $1 ]]; }
  for path in "$NEXT_SPEC" "$NEXT_WORK" "$NEXT_WORKTREE" \
              "$NEXT_WORK/execution-base.env" "$NEXT_WORK/review-manifest.tsv" "$NEXT_WORK/task-1-brief.md"; do
    absent "$path"
  done
  PROBE_DIR=$(mktemp -d)
  trap 'rm -rf -- "$PROBE_DIR"' EXIT
  ln -s missing "$PROBE_DIR/dangling"
  if absent "$PROBE_DIR/dangling"; then exit 1; fi
  ```
