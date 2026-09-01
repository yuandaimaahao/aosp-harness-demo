# 2026-09-01-03a-session-path-safety 实现计划

执行基线固定为进入execute时记录的`BASE_SHA`。每次提交后controller都运行exact-name与numstat累计检查：只允许`common/.harness/lib/session-state-path.sh`、`tests/test-session-path.sh`，累计达到380行停止扩展并压缩共享helper，超过400立即回PLAN。提交使用个人项目Conventional Commits，不使用公司五段式模板。

### 任务 1: 建立source/inert与validate fail-fast骨架

文件: 创建 `common/.harness/lib/session-state-path.sh` / 创建 `tests/test-session-path.sh`
消费: 无
产出: foundation-contract-v1 —— `harness_validate_feature_name <name>` plus `_harness_session_state_foundation_path <project-id> <session-id>` plus `_harness_session_state_run path <project-id> <session-id>`已由fixture实际验证；path-core-shell-v1 —— `_harness_session_path_core <project-id> <session-id>`的source guard、exact arity与public validate fail-fast骨架
需求: R1, R2, R3, R6
必需: 是

- [ ] 步骤 1: 创建隔离Shell测试，逐字断言依赖齐全source为`0/空双流`且只定义private core，并比较source前后HARNESS/XDG/TMP的`declare -p`、foundation函数体和fixture inventory；public validate或两个private export逐一缺席时source静默inert；包装validate记录project/session并拒绝合法session，PATH内fake`python3`计数必须为0。
- [ ] 步骤 2: 运行`bash ./tests/test-session-path.sh --case source-validate`，确认失败：退出`1`且stderr首行精确为`FAIL source present: provider missing`。
- [ ] 步骤 3: 最小实现三函数`declare -F`guard、private core exact arity、顺序调用`harness_validate_feature_name`并把其双流丢弃后映射为`error: unsafe session state\n`/`2`；source期间不读取根变量、不启动Python、不定义public API/marker。
  ```bash
  if declare -F harness_validate_feature_name >/dev/null && declare -F _harness_session_state_foundation_path >/dev/null && declare -F _harness_session_state_run >/dev/null; then
    _harness_session_path_core() (
      if [[ $# != 2 ]] || ! harness_validate_feature_name "$1" >/dev/null 2>&1 || ! harness_validate_feature_name "$2" >/dev/null 2>&1; then
        printf '%s\n' 'error: unsafe session state' >&2
        return 2
      fi
      printf '%s\n' 'error: session state operation failed' >&2
      return 1
    )
  fi
  ```
- [ ] 步骤 4: 运行`bash ./tests/test-session-path.sh --case source-validate && bash -n common/.harness/lib/session-state-path.sh tests/test-session-path.sh`，确认退出`0`；随后验证BASE..HEAD仍为exact两文件且累计numstat不超过150。
- [ ] 步骤 5: 以`feat(session): add guarded path core`提交并记录红阶段日志、提交SHA与累计numstat；本任务独立review最终PASS后controller才派任务2。

### 任务 2: 实现根选择与统一managed目录校验

文件: 修改 `common/.harness/lib/session-state-path.sh` / 修改 `tests/test-session-path.sh`
消费: foundation-contract-v1 —— `harness_validate_feature_name <name>` plus `_harness_session_state_foundation_path <project-id> <session-id>` plus `_harness_session_state_run path <project-id> <session-id>`已由fixture实际验证；path-core-shell-v1 —— `_harness_session_path_core <project-id> <session-id>`的source guard、exact arity与public validate fail-fast骨架
产出: path-core-managed-v1 —— `_harness_session_path_core <project-id> <session-id>`的完整root selector与`open_managed(parent_fd,name)`
需求: R3, R4, R6
必需: 是

- [ ] 步骤 1: 增加`--case roots-static`测试：HARNESS/XDG/TMP/default与physical symlink parent逐字输出，高优先级时低优先级inventory不变；empty/relative/control/dot-component/root slash/missing parent按优先级逐字断言unsafe/2且零创建；同根2project×2session逐项验证非链接目录/EUID/0700；root/project/session分别预置link/file/wrong-mode并验证unsafe/2、victim与后续inventory零变化。
- [ ] 步骤 2: 运行`bash ./tests/test-session-path.sh --case roots-static`，确认失败：退出`1`且stderr首行精确为`FAIL root HARNESS: python path engine missing`。
- [ ] 步骤 3: 在`umask 077`的embedded Python中实现foundation等价root selector与统一`open_managed`：mkdir(0700)后绝不fchmod，nofollow stat/open/fstat，校验type/dev/inode/EUID/exact0700及final name identity；`ELOOP|ENOTDIR`映射unsafe/2，普通OS错映射operation/1，逆序关闭fd。
  ```python
  def identity(info):
      return info.st_dev, info.st_ino, stat.S_IFMT(info.st_mode)
  def validate_fd(before, child_fd, expected_euid):
      current = os.fstat(child_fd)
      if identity(before) != identity(current) or current.st_uid != expected_euid or stat.S_IMODE(current.st_mode) != 0o700:
          raise UnsafeState
      return current
  def managed_open_error(exc):
      if exc.errno in (errno.ELOOP, errno.ENOTDIR):
          raise UnsafeState from exc
      raise OperationFailure from exc
  ```
- [ ] 步骤 4: 运行`bash ./tests/test-session-path.sh --case source-validate && bash ./tests/test-session-path.sh --case roots-static`，确认全部退出`0`；再运行`! grep -q fchmod common/.harness/lib/session-state-path.sh`并验证累计numstat不超过280。
- [ ] 步骤 5: 以`feat(session): harden managed path traversal`提交并记录红阶段日志、提交SHA与累计numstat；本任务独立review最终PASS后controller才派任务3。

### 任务 3: 加入multi-phase竞态探针与root承重mutation

文件: 修改 `common/.harness/lib/session-state-path.sh` / 修改 `tests/test-session-path.sh`
消费: path-core-managed-v1 —— `_harness_session_path_core <project-id> <session-id>`的完整root selector与`open_managed(parent_fd,name)`
产出: path-core-race-v1 —— `_harness_session_path_core <project-id> <session-id>` plus `HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN`三phase plus `HARNESS_TEST_MARKER_EXPECTED_EUID` plus `HARNESS_TEST_MARKER_OS_ERROR`
需求: R4, R5, R6
必需: 是

- [ ] 步骤 1: 增加`--case mutations`的单一provider-copy/count/replace/sentinel/inventory driver，实际执行root existing safe-dir/link/file swap、EEXIST safe/unsafe/disappearing、mkdir-success replacement、wrong EUID与真实`OSError(errno.EIO)`；逐字断言`0|2|1`、catch/phase sentinel、replacement mode/victim/inventory零变化。
- [ ] 步骤 2: 运行`bash ./tests/test-session-path.sh --case mutations`，确认失败：退出`1`且stderr首行精确为`FAIL marker MANAGED count: expected 1 got 0`，不得把未注入case计为通过。
- [ ] 步骤 3: 实现文本仅一次的no-op `_managed_checkpoint(phase,parent_fd,name,made)`并在三phase调用；EEXIST catch后重取winner且消失映射operation/1；加入唯一EXPECTED_EUID与首个fd操作前OS_ERROR anchor，生产逻辑不读test-only env。
  ```python
  def _managed_checkpoint(phase, parent_fd, name, made):
      pass  # HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN
  _managed_checkpoint("before_mkdir", parent_fd, name, False)
  _managed_checkpoint("after_eexist", parent_fd, name, False)
  _managed_checkpoint("before_open", parent_fd, name, made)
  expected_euid = os.geteuid()  # HARNESS_TEST_MARKER_EXPECTED_EUID
  pass  # HARNESS_TEST_MARKER_OS_ERROR
  ```
- [ ] 步骤 4: 运行`bash ./tests/test-session-path.sh --case mutations && bash ./tests/test-session-path.sh --case roots-static`，确认退出`0`；逐个`grep -c`三个marker均为1、三个phase均存在、provider无`fchmod`，累计numstat不超过370。
- [ ] 步骤 5: 以`test(session): cover path race boundaries`提交并记录红阶段日志、提交SHA与累计numstat；本任务独立review最终PASS后controller才派任务4。

### 任务 4: 闭合回滚入口、公共surface与最终门禁

文件: 修改 `tests/test-session-path.sh` / 验证 `common/.harness/lib/session-state-path.sh`
消费: path-core-race-v1 —— `_harness_session_path_core <project-id> <session-id>` plus `HARNESS_TEST_MARKER_MANAGED_BEFORE_OPEN`三phase plus `HARNESS_TEST_MARKER_EXPECTED_EUID` plus `HARNESS_TEST_MARKER_OS_ERROR`
产出: session-path-delivery-v1 —— _harness_session_path_core <project-id> <session-id>成功path+LF/0或OS错1或安全协议错2 plus三个生产文本唯一anchor plus tests/test-session-path.sh固定PASS摘要
需求: R1, R2, R6, R7
必需: 是

- [ ] 步骤 1: 增加默认全组执行、`--dependency-absent`真实上游缺席fixture、四个public state API与provider marker absent、foundation两文件不变、唯一PASS摘要；测试自身逐字检查双流/rc并清理所有fixture。
- [ ] 步骤 2: 运行`bash ./tests/test-session-path.sh --dependency-absent`，确认失败：退出`1`且stderr首行精确为`FAIL option: --dependency-absent unsupported`；保存红阶段证据。
- [ ] 步骤 3: 最小连接case dispatcher与回滚fixture，不扩入project/session穷举mutation；若累计达到380行先合并共享helper，任何R1–R7 oracle不得删除。
  ```bash
  case ${1:-all} in
    --case) group=${2:?missing case name} ;;
    --dependency-absent) group=dependency-absent ;;
    all) group=all ;;
    *) fail "option: ${1:-empty} unsupported" ;;
  esac
  run_group "$group"
  printf '%s\n' 'RESULT PASS  session path safety'
  ```
- [ ] 步骤 4: 运行`bash ./tests/test-session-path.sh && bash ./tests/test-session-path.sh --dependency-absent && bash ./tests/test-session-state-foundation.sh && bash ./scripts/check.sh --offline && git diff --check`，确认全部退出`0`且两个path命令末行精确PASS；提交前以`EXPECTED=$(printf '%s\n' common/.harness/lib/session-state-path.sh tests/test-session-path.sh); test "$(git diff --name-only "$BASE_SHA" | LC_ALL=C sort)" = "$EXPECTED"; git diff --numstat "$BASE_SHA" | awk 'NF!=3 || $1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+$/ {bad=1} {files++; lines += $1+$2} END {exit bad || files!=2 || lines>400}'`把task4工作区改动纳入exact两文件/400行门。
- [ ] 步骤 5: 以`test(session): close path safety contract`提交并完成本任务独立review；所有review fix提交也最终PASS后，controller只汇总四个最终PASS结果到`$REVIEW_MANIFEST`，再运行`HEAD_SHA=$(git rev-parse HEAD); EXPECTED=$(printf '%s\n' common/.harness/lib/session-state-path.sh tests/test-session-path.sh); test "$(git diff --name-only "$BASE_SHA" "$HEAD_SHA" | LC_ALL=C sort)" = "$EXPECTED"; git diff --numstat "$BASE_SHA" "$HEAD_SHA" | awk 'NF!=3 || $1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+$/ {bad=1} {files++; lines += $1+$2} END {exit bad || files!=2 || lines>400}'; awk -F '\t' -v base="$BASE_SHA" -v head="$HEAD_SHA" 'NF!=6 || $1!=NR || $2!="task-" NR || $3 !~ /^[0-9a-f]{40}$/ || $4 !~ /^[0-9a-f]{40}$/ || $5=="" || $6!="PASS" {bad=1} NR==1 && $3!=base {bad=1} NR>1 && $3!=prev {bad=1} {prev=$4} END {exit bad || NR!=4 || prev!=head}' "$REVIEW_MANIFEST"; test -z "$(git status --porcelain)"`，全部退出`0`后才完成本片。
