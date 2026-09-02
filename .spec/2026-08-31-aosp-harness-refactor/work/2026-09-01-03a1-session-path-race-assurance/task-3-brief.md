# 任务 3：实现 swap、wrong-EUID 与 EEXIST 共享 oracle

只执行本任务，不提前实现任务4–5，不派subagent。实现worktree为`/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03a1-session-path-race-assurance`，只修改`tests/lib/session-path-race-driver.py`；证据/report写controller主仓本brief同目录。`TASK_BASE=565008482663664d9192817ccff9810993ca8ba0`，提交使用普通Conventional Commit。

完整依据是当前requirements/design/tasks的任务3。可提取round7 prototype对应的MANAGED/EXPECTED_EUID、swap、wrong-euid、eexist、共享exercise/delta区段；本任务的MANAGED hook只实现swap/EEXIST需要的分支，不提前加入五个managed lifecycle family或self-disproof。

## 红阶段

在临时TSV按需求顺序生成swap 9、wrong-euid 3、eexist 9、real-eio 1，共22行。运行`run-matrix`必须在首个`swap-root-safe-dir`确定性rc1、无PASS、CASE_LOG 0B、production provider SHA不变；保存为`task-3-red.log`。另以输入顺序`real-eio`、`swap-root-safe-dir`的2-row子集证明EIO即使已执行，未实现swap仍使log 0B。

## 实现边界

每child只count/copy/replace一个marker-bearing line，三个生产marker仍各精确一次，不替换普通needle：

- swap：MANAGED hook逐字`layer/name/before_open/0/0`；safe-dir/link/file均返回unsafe/2，victim subtree按相对suffix从`target/**`重键到`target.old/**`且完整签名不变；replacement inode必须不同，link target、empty file hash/mode与safe-dir 0700逐项核对，无后续层。
- wrong-euid：EXPECTED_EUID hook逐字`layer/name/N/A/0/0`，三层均unsafe/2、before inventory零delta且无后续层。
- EEXIST：两个有序MANAGED hook固定为`before_mkdir/0/0`与`after_eexist/0/1`；safe为path+LF/0并只新增安全suffix，unsafe为unsafe/2且winner保持0755，disappear为operation/1且零delta。

所有family复用Task2的validator、provider copy、independent stream capture、filesystem-byte inventory、signature、delta schema、final provider hash与held-fd log，不复制第二份executor。保留真实EIO。合法但尚未实现的五个managed lifecycle row必须仍rc1、无PASS、log 0B。

## Green、提交与报告

22-row matrix必须rc0、stdout38B、stderr0B、CASE_LOG逐字等于TSV第一列。逆序`real-eio,swap-root-safe-dir`、各family代表1-row子集都必须只执行输入row并按输入顺序写log。逆序创建`z-last/a-first`fixture必须得到filesystem-bytes canonical inventory。逐family核对9/3/9/1计数、所有hook/stream/delta及provider SHA。

运行Python3.8 grammar、无range`git diff --check`、03/03a零diff、execution BASE到working-tree exact1/400；提交`test(session): cover primary path races`。提交后写`task-3-report.md`，包含红/绿矩阵、TASK_BASE/TASK_HEAD、task/cumulative numstat、provider SHA和clean状态；不要写manifest，controller在独立review PASS后处理。
