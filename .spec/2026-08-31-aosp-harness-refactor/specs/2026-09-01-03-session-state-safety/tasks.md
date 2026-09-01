# 03-session-state-safety foundation 实现计划

## Foundation 实现

### 任务 1.1: 锁定名称并保存执行基线

文件: `common/.harness/lib/session-state-foundation.sh`、`tests/test-session-state-foundation.sh`
消费: 无
产出: execution-base-v1 —— `execution-base.env` 唯一一行 `BASE_SHA=<40hex>`；session-validate-v1 —— `harness_validate_feature_name <name>` 与静默 `_harness_component_is_safe <value>`
需求: R1, R3, R4, R5
必需: 是
状态: 完成

- [ ] 步骤 1: controller 记录 BASE；测试建立文件级双流比较、source fixture、完整名称表和清理。
- [ ] 步骤 2: 跑 `bash ./tests/test-session-state.sh`，确认红阶段失败且首错为 `FAIL validate valid: provider missing`。
- [ ] 步骤 3: 实现 C-locale 1..128 bytes 完整 regex 与 public validate。
  ```bash
  _harness_component_is_safe() { LC_ALL=C; [[ $# == 1 && ${#1} -ge 1 && ${#1} -le 128 && $1 =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; }
  harness_validate_feature_name() { [[ $# == 1 ]] && _harness_component_is_safe "$1" || { printf '%s\n' 'error: invalid feature name' >&2; return 2; }; }
  ```
- [ ] 步骤 4: 跑 `bash -n common/.harness/lib/session-state.sh && bash -n tests/test-session-state.sh && bash ./tests/test-session-state.sh`，确认名称表和source零副作用通过。
- [ ] 步骤 5: 普通 Conventional Commits 提交并由独立 reviewer 最终 PASS；controller 把 base/head/reviewer/status 记入 manifest素材。

### 任务 1.2: 实现私有四级根与 fresh fd 链

文件: `common/.harness/lib/session-state-foundation.sh`、`tests/test-session-state-foundation.sh`
消费: session-validate-v1 —— `harness_validate_feature_name <name>` 与静默 `_harness_component_is_safe <value>`
产出: foundation-root-v1 —— 四级root selector、physical parent和fresh root/project/session fd链已实现且测试隔离/零副作用oracle通过
需求: R2, R4, R5
必需: 是
状态: 完成

- [ ] 步骤 1: 加 path arity/ID、HARNESS/XDG/TMP/default 成功与危险矩阵、inventory/低优先级 untouched、fresh nonlink/type/EUID/0700、physical parent、两项目×两会话和预存默认根保留测试。
- [ ] 步骤 2: 跑 `bash ./tests/test-session-state.sh`，确认红阶段失败且首错为 `FAIL path HARNESS precedence: function missing`。
- [ ] 步骤 3: 实现 embedded Python root selector、strict physical parent、只创建root leaf和relative fresh fd链；既有对象hardening明确留给03a。
  ```python
  def select_root(env, euid):
      if "HARNESS_STATE_ROOT" in env: return checked_exact(env["HARNESS_STATE_ROOT"], reject_root=True)
      if "XDG_RUNTIME_DIR" in env: return checked_base(env["XDG_RUNTIME_DIR"]) / f"aosp-harness-{euid}"
      return checked_base(env.get("TMPDIR") or "/tmp") / f"aosp-harness-{euid}"
  def fresh_path(project, session):
      parent_fd, leaf, physical = open_physical_parent(select_root(os.environ, os.geteuid()))
      return open_fresh_chain(parent_fd, (leaf, project, session), physical)
  ```
- [ ] 步骤 4: 跑 `bash ./tests/test-session-state.sh && bash ./scripts/check.sh --offline && git diff --check`，确认完整矩阵、预存root和mutation oracle通过。
- [ ] 步骤 5: 普通 Conventional Commits 提交并由独立 reviewer 最终 PASS；controller 把base/head/reviewer/status记入manifest素材。

### 任务 1.3: 封闭 public surface 并交付 foundation

文件: `common/.harness/lib/session-state-foundation.sh`、`tests/test-session-state-foundation.sh`
消费: foundation-root-v1 —— 四级root selector、physical parent和fresh root/project/session fd链已实现且测试隔离/零副作用oracle通过；session-validate-v1 —— `harness_validate_feature_name <name>`与静默predicate；execution-base-v1 —— `execution-base.env`唯一一行`BASE_SHA=<40hex>`
产出: harness_validate_feature_name —— foundation唯一public API；_harness_session_state_foundation_path —— 03a消费的私有fresh-root facade；_harness_session_state_run —— 03a消费且仅允许path op的私有dispatcher；tests/test-session-state-foundation.sh —— 成功末行`RESULT PASS  session state foundation`；review-manifest-v1 —— controller在review PASS后写入的六列三任务连续链
需求: R2, R3, R4, R5, R6
必需: 是
状态: 完成

- [ ] 步骤 1: 先按`work/2026-09-01-03-session-state-safety/task-1.3-sizing.md`复核118+255=373基线与126+267=393目标。在测试首次成功source provider后、任何validate/private/marker/path断言前，按以下顺序加入public循环，使当前实现的首错确定为path absent；然后再增加`assert_call`helper复用十组相邻capture/assert，最多删除8个冗余空行但不拼接语句、不删注释/oracle。其后逐个断言两个private export和marker，把现有path矩阵改调private facade并明确补齐arity参数数`0/1/3`，dispatcher表覆盖参数数`0/1/2/4`、非法op、非法project、非法session及合法0；同一provider-copy EIO mutation分别覆盖两export的operation/1；补source rc0/双流空和export sentinel`declare -p`不变；成功末行改为foundation摘要。
  ```bash
  for public_name in harness_session_state_path harness_session_state_write harness_session_state_read harness_session_state_remove; do
    if declare -F "$public_name" >/dev/null; then
      fail "public surface: $public_name must be absent"
    fi
  done
  ```
- [ ] 步骤 2: 跑 `bash ./tests/test-session-state.sh`，确认红阶段失败且首错精确为 `FAIL public surface: harness_session_state_path must be absent`。
- [ ] 步骤 3: 把临时public path facade改为private foundation facade；在`_harness_session_state_run`启动Python前先分支检查exact arity，再检查exact`path`和两个C-locale ID并映射固定unsafe错误，避免`set -u`下展开缺失位置参数；embedded Python逻辑不扩张。随后用`git mv`把provider/test改为独占foundation文件名并修正测试source路径。不得加入existing-object、snapshot、signal、remove、aggregator或coverage。
  ```bash
  _harness_session_state_foundation_path() {
    [[ $# == 2 ]] && _harness_component_is_safe "$1" && _harness_component_is_safe "$2" || { printf '%s\n' 'error: unsafe session state' >&2; return 2; }
    _harness_session_state_run path "$1" "$2"
  }
  ```
  `_harness_session_state_run`入口同样必须在启动Python前复用`_harness_component_is_safe`校验两个ID，不能只依赖private facade；先独立判断`$#`再读取`$1..$3`。
- [ ] 步骤 4: controller dispatch固定绝对execution/worktree环境。一次执行提交前验证：`WORKTREE_ROOT=/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03-session-state-safety; EXECUTION_BASE_FILE=/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-03-session-state-safety/execution-base.env; bash -n "$WORKTREE_ROOT/common/.harness/lib/session-state-foundation.sh" && bash -n "$WORKTREE_ROOT/tests/test-session-state-foundation.sh" && bash "$WORKTREE_ROOT/tests/test-session-state-foundation.sh" && bash "$WORKTREE_ROOT/scripts/check.sh" --offline && git -C "$WORKTREE_ROOT" diff --check; BASE_SHA=$(sed -n 's/^BASE_SHA=//p' "$EXECUTION_BASE_FILE"); EXPECTED=$(printf '%s\n' common/.harness/lib/session-state-foundation.sh tests/test-session-state-foundation.sh); test "$(git -C "$WORKTREE_ROOT" diff --name-only "$BASE_SHA" | LC_ALL=C sort)" = "$EXPECTED"; git -C "$WORKTREE_ROOT" diff --numstat "$BASE_SHA" | awk 'NF!=3 || $1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+$/ {bad=1} {files++; lines += $1+$2} END {exit bad || files!=2 || lines>400}'`。若失败或需删oracle/comment、拼接语句才能通过，立即报告BLOCKED并回PLAN。
- [ ] 步骤 5: 一次执行提交与提交后门：`WORKTREE_ROOT=/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03-session-state-safety; EXECUTION_BASE_FILE=/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-03-session-state-safety/execution-base.env; git -C "$WORKTREE_ROOT" add common/.harness/lib/session-state-foundation.sh tests/test-session-state-foundation.sh && git -C "$WORKTREE_ROOT" commit -m 'refactor(session): publish private foundation module' && git -C "$WORKTREE_ROOT" show --check --oneline --stat HEAD; BASE_SHA=$(sed -n 's/^BASE_SHA=//p' "$EXECUTION_BASE_FILE"); HEAD_SHA=$(git -C "$WORKTREE_ROOT" rev-parse HEAD); EXPECTED=$(printf '%s\n' common/.harness/lib/session-state-foundation.sh tests/test-session-state-foundation.sh); test "$(git -C "$WORKTREE_ROOT" diff --name-only "$BASE_SHA" "$HEAD_SHA" | LC_ALL=C sort)" = "$EXPECTED"; git -C "$WORKTREE_ROOT" diff --numstat "$BASE_SHA" "$HEAD_SHA" | awk 'NF!=3 || $1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+$/ {bad=1} {files++; lines += $1+$2} END {exit bad || files!=2 || lines>400}'; test -z "$(git -C "$WORKTREE_ROOT" status --porcelain)"`。
- [ ] 步骤 6: 独立reviewer PASS后，controller在主仓创建六列manifest三行并一次执行最终完整门：`EXECUTION_BASE_FILE=/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-03-session-state-safety/execution-base.env; REVIEW_MANIFEST=/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-03-session-state-safety/review-manifest.tsv; WORKTREE_ROOT=/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03-session-state-safety; BASE_SHA=$(sed -n 's/^BASE_SHA=//p' "$EXECUTION_BASE_FILE"); HEAD_SHA=$(git -C "$WORKTREE_ROOT" rev-parse HEAD); EXPECTED=$(printf '%s\n' common/.harness/lib/session-state-foundation.sh tests/test-session-state-foundation.sh); awk -F '\t' -v base="$BASE_SHA" -v head="$HEAD_SHA" 'NF!=6 || $1 != NR || $2 != "1." NR || $3 !~ /^[0-9a-f]{40}$/ || $4 !~ /^[0-9a-f]{40}$/ || $5=="" || $6!="PASS" {bad=1} NR==1 && $3!=base {bad=1} NR>1 && $3!=prev {bad=1} {prev=$4} END {exit bad || NR!=3 || prev!=head}' "$REVIEW_MANIFEST"; test "$(git -C "$WORKTREE_ROOT" diff --name-only "$BASE_SHA" "$HEAD_SHA" | LC_ALL=C sort)" = "$EXPECTED"; git -C "$WORKTREE_ROOT" diff --numstat "$BASE_SHA" "$HEAD_SHA" | awk 'NF!=3 || $1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+$/ {bad=1} {files++; lines += $1+$2} END {exit bad || files!=2 || lines>400}'; test -z "$(git -C "$WORKTREE_ROOT" status --porcelain)"`。
