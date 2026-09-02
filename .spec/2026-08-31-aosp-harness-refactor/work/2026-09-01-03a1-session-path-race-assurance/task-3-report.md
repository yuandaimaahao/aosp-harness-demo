# 03a1 Task 3 implementation report

## Status

DONE

## Commits

- `e5f4f76f1a44d2fdc757ebb6f7391a9f08887fb0` — `test(session): cover primary path races`

## Red evidence

红阶段证据: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-03a1-session-path-race-assurance/task-3-red.log`

在`TASK_BASE=565008482663664d9192817ccff9810993ca8ba0`运行按需求排序的swap 9、wrong-EUID 3、EEXIST 9、real-EIO 1共22行：首个`swap-root-safe-dir`命中`matrix executor incomplete`，rc `1`、stdout `0B`、无PASS、CASE_LOG `0B`，provider SHA前后均为`07af7800401608fd679c1244854ab1852daa2a98c459a0cff053c1b0e07c4b64`。逆序`real-eio,swap-root-safe-dir`子集同样rc `1`且log `0B`，同时EIO hook真实写入1行，排除“未执行首行”的假红。

## Implementation

- 只扩展`tests/lib/session-path-race-driver.py`，新增unsafe精确双流、MANAGED/EXPECTED_EUID两个single-anchor注入，以及共享`setup`、`exercise`、hook、signature/inventory/delta oracle；Task 2的真实EIO路径保留。
- swap 9按`target/** -> target.old/**`相对suffix重键并逐对象比对完整签名；safe-dir/link/file replacement分别核对0700、readlink target、0600空文件hash、EUID和不同inode，delta同时拒绝后续层或额外对象。
- wrong-EUID 3核对逐字`EXPECTED_EUID|layer|name|N/A|0|0`、unsafe stream和零delta；EEXIST 9核对有序`before_mkdir/0/0`与`after_eexist/0/1`、safe path、unsafe 0755 winner、disappear operation及各自精确delta。
- executor按TSV输入顺序分派并要求`executed == expected_ids`，最终provider bytes通过后才以Task 2持有fd一次写入有序CASE_LOG。五个managed lifecycle family与`self-test`仍保持rc1/无PASS/log 0B，未实现Task 4/5内容。

## Green verification

提交前与提交后门禁通过：

- 22-row matrix：22/22 PASS，family计数`9/3/9/1`，stdout精确`38B`、stderr `0B`、CASE_LOG逐字等于TSV第一列；22个hook文件共31行（MANAGED 27、EXPECTED_EUID 3、OS_ERROR 1），EEXIST双hook共18行。
- 逆序`real-eio,swap-root-safe-dir`：rc0、stdout `38B`、stderr `0B`、两个case均执行且CASE_LOG保持输入顺序。swap三variant、wrong-EUID、EEXIST三variant与real-EIO共8个代表性1-row子集均PASS且只产生自身hook/log。
- 独立提取实际`inventory()`对逆序创建的`z-last,a-first` fixture运行，canonical key顺序逐字为`a-first,z-last`。
- 15个尚未实现的managed lifecycle合法row逐个rc1、stdout `0B`、无PASS、CASE_LOG `0B`、hook `0`；正确arity `self-test`仍rc1/无PASS。
- production provider SHA始终为`07af7800401608fd679c1244854ab1852daa2a98c459a0cff053c1b0e07c4b64`；临时`PYTHONPYCACHEPREFIX` compile、Python 3.8 grammar、`tests/test-session-state-foundation.sh`和`tests/test-session-path.sh`均PASS。
- `git diff --check TASK_BASE TASK_HEAD`、exact1、03/foundation与03a provider/core test零diff、提交后clean均PASS。

## Diff and repository state

- `TASK_BASE`: `565008482663664d9192817ccff9810993ca8ba0`
- `TASK_HEAD`: `e5f4f76f1a44d2fdc757ebb6f7391a9f08887fb0`
- Task diff name-only: exact `tests/lib/session-path-race-driver.py`
- Task diff numstat: `152  19  tests/lib/session-path-race-driver.py`，总计`171 <= 400`
- Execution BASE `c959efaf9887808621852aff28073cf1f8789ca7`到HEAD：exact同一driver，numstat `316  0`，累计`316 <= 400`；driver当前316行。
- 实现worktree最终`git status --porcelain`为`0B`，clean。

## Concerns

None. 五个managed lifecycle family与内建self-test/14项active self-disproof仍是Task 4/5的显式红缝。
