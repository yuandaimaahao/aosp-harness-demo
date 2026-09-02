# 03a1 Task 4 implementation report

## Status

DONE

## Commits

- `f72aaefddd4fa6e06c6c156ff1f3df58b5f27ca9` — `test(session): complete race family matrix`

## Red evidence

红阶段证据: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-03a1-session-path-race-assurance/task-4-red.log`

在`TASK_BASE=e5f4f76f1a44d2fdc757ebb6f7391a9f08887fb0`运行固定顺序的外部37-row matrix：前21个primary rows真实执行后，首个`mkdir-replace-root`命中`matrix executor incomplete`，rc `1`、stdout `0B`、无PASS、CASE_LOG `0B`，provider SHA前后均为`07af7800401608fd679c1244854ab1852daa2a98c459a0cff053c1b0e07c4b64`。当前self-test亦为rc1/stdout0，但仍是旧`matrix executor incomplete`，尚不能声称37已完成。

## Implementation

- 只修改`tests/lib/session-path-race-driver.py`：扩展现有MANAGED single-anchor hook和共享`exercise`/inventory/delta executor，新增mkdir-replace、mkdir-failure、post-mkdir-disappear、open-disappear、final-stat-disappear各三层；未复制executor。
- mkdir-replace在fresh mkdir后的`before_open/made=1`记录runtime original `kind/dev/inode/mode/uid`，rename到`.old`后由完整directory signature与精确hook共同闭合；replacement保持不同inode/EUID/0755，delta只允许target与target.old。
- mkdir-failure安装一次性真实ENOENT mkdir；post-mkdir移除新建目录；open/final-stat分别在open前和open/fstat后的name stat移除existing target。五类均核对逐字MANAGED phase/made/catch、operation/unsafe双流和零delta或只移除target的精确delta。
- 新增固定`default_rows()`和self-test私有workspace：按`9/3/9/3/3/3/3/3/1`构造37 rows，与外部matrix复用同一顺序executor，检查executed逐字顺序、provider bytes、CASE_LOG与固定SHA；完成全部oracle后仅以`AssertionError("self-disproof incomplete")`失败。
- 未新增`must_reject`、`reject_field`、self-disproof列表或14项active mutation；Task 5红缝在源码中精确一次。

## Green verification

提交前及提交后门禁均通过：

- 外部37-row：rc0、stdout精确`38B`、stderr `0B`、CASE_LOG 37行逐字等于TSV第一列，SHA-256精确`721b3687bda848db7b6481c527f491e6733cf376dbade3dd37b319fce8029bc8`；九family计数`9/3/9/3/3/3/3/3/1`，37个hook文件共46行。
- 五个managed family代表1-row、单行real-EIO与逆序`real-eio,swap-root-safe-dir`均rc0/38B/0B，CASE_LOG只含输入row且保持输入顺序；Task 3 primary rows与EIO保持green。
- self-test：rc1、stdout `0B`、无PASS，stderr末行逐字`AssertionError: self-disproof incomplete`。独立strace记录46次hook append、CASE_LOG唯一一次780B写入，证明37 rows及双hook EEXIST已在红缝前真实执行；有序hash和provider检查也位于该红缝之前。
- production provider SHA始终为`07af7800401608fd679c1244854ab1852daa2a98c459a0cff053c1b0e07c4b64`；临时`PYTHONPYCACHEPREFIX` compile、Python 3.8 grammar、`tests/test-session-state-foundation.sh`与`tests/test-session-path.sh`均PASS。
- `git diff --check TASK_BASE TASK_HEAD`、execution BASE exact1/400、03/foundation与03a provider/core test零diff、提交后clean均PASS。

## Diff and repository state

- `TASK_BASE`: `e5f4f76f1a44d2fdc757ebb6f7391a9f08887fb0`
- `TASK_HEAD`: `f72aaefddd4fa6e06c6c156ff1f3df58b5f27ca9`
- Task diff name-only: exact `tests/lib/session-path-race-driver.py`
- Task diff numstat: `98  14  tests/lib/session-path-race-driver.py`，总计`112 <= 400`
- Execution BASE `c959efaf9887808621852aff28073cf1f8789ca7`到HEAD：exact同一driver，numstat `400  0`，累计及物理行数均`400/400`。
- 实现worktree最终`git status --porcelain`为`0B`，clean。

## Concerns

None. 唯一预期红因是Task 5将闭合的14项active self-disproof；所有case executor与object oracle均已green，不得为Task 5行数删除oracle。
