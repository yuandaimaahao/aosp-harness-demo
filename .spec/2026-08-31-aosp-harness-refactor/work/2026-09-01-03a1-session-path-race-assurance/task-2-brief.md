# 任务 2：建立 matrix 能力边界与 EIO 纵切

只执行本任务，不提前实现任务3–5，不派subagent。实现只允许在`/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03a1-session-path-race-assurance`修改`tests/lib/session-path-race-driver.py`；证据和报告写到controller主仓本brief同目录。`TASK_BASE=d79de6bb6b10bce9ffd4238b071656cf7089db88`，提交使用普通Conventional Commit。

完整依据是当前spec的requirements/design/tasks，尤其tasks任务2；可从round7 400行prototype提取对应实现，但不得整体复制并提前带入其他race family或14项self-disproof。

## 红阶段

在系统临时目录创建合法单行TSV `real-eio\treal-eio\tN/A\tN/A\n`、已存在的physical parent以及缺席workspace/log，运行正确arity `run-matrix`。必须命中Task1的`matrix executor incomplete`红缝：rc1、无PASS、无case-log内容。保存为`task-2-red.log`。

同时建立可重复的preflight反例矩阵：relative workspace/log、保留`..`、missing parent、existing/symlink workspace、log直接等于provider、existing/symlink/hardlink log，以及空/含NUL/非四列/重复ID/未知token/非法组合/非canonical ID TSV。记录0-case与production provider SHA。

## 实现边界

交付four-column validator、physical absent workspace、新建case-log capability、共享signature/inventory/delta原语、single-anchor copy以及唯一`real-eio`family。路径逐字沿用round7：`parent.lstat()` + `workspace.is_absolute()` + `parent.resolve(strict=True) == parent`，不得新增逐祖先walker；workspace `parents=False`新建并验证0700/EUID；case-log必须direct child，通过workspace fd用`O_CREAT|O_EXCL|O_NOFOLLOW`创建并验证0600/EUID/link-count，全程只用持有fd读写。

TSV至少一行、无NUL、exact四列、ID唯一，机械验证全部family/layer/variant枚举及canonical ID，即便本任务只执行`real-eio`。在任何case前拒绝所有非法row/path/capability；失败时provider hash不变。

`real-eio`只替换生产provider中精确一次的OS_ERROR marker-bearing line，在隔离copy执行真实EIO，hook必须逐字`OS_ERROR|N/A|N/A|N/A|N/A|N/A`，结果必须rc1/空stdout/operation stderr，before/after inventory零delta。只有执行集合与输入一致且最终production provider hash通过后，才能通过held fd一次写`real-eio\n`并打印38B private PASS。

不要实现swap、wrong-EUID、EEXIST、managed lifecycle、内建37 rows或self-disproof；这些输入在本任务可被row validator接受，但进入executor必须rc1、无PASS、log 0B。

## Green、提交与报告

单行EIO必须rc0、stdout38B、stderr0B、log精确且workspace/log为0700/0600。全部preflight反例必须rc1、无PASS、0 case、provider不变；absolute raw `.`折叠路径成功，relative/保留`..`失败。用临时`PYTHONPYCACHEPREFIX`跑py_compile，另跑Python3.8 grammar、`git diff --check`、BASE execution到working-tree exact1/400、03/03a零diff。

提交消息固定`test(session): isolate external race matrices`。提交后写`task-2-report.md`，包含红/绿矩阵、TASK_BASE/TASK_HEAD、name-only/numstat、provider SHA和clean状态；不要写manifest，controller在独立review PASS后处理。
