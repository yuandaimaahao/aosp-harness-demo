# 任务 4：补齐 managed lifecycle 并形成精确 self-test 红灯

只执行本任务，不实现14项active self-disproof，不派subagent。实现worktree为`/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03a1-session-path-race-assurance`，只修改driver；证据/report写controller主仓本brief同目录。`TASK_BASE=e5f4f76f1a44d2fdc757ebb6f7391a9f08887fb0`，提交使用普通Conventional Commit。

完整依据是requirements/design/tasks任务4。可提取round7 prototype的五个managed lifecycle区段、`default_rows()`、完整executed/order/hash门；不得提前加入14项反证，必须在self-test 37 rows及其全部oracle之后留下唯一`AssertionError("self-disproof incomplete")`红灯。

## 红阶段

生成完整37-row外部TSV并运行`run-matrix`，必须在首个`mkdir-replace-root`命中executor incomplete：rc1、无PASS、CASE_LOG 0B、provider不变；保存`task-4-red.log`。另运行当前self-test，确认它还不能声称“37已完成只差self-disproof”。

## 五个 family

- mkdir-replace三层：fresh mkdir后before_open/made=1替换；unsafe/2。rename前记录runtime original完整签名，`.old`必须逐字段相同；replacement为不同inode/0755，不得chmod/跟随；delta只新增target与target.old。
- mkdir-failure三层：before_mkdir/made=0安装一次性真实mkdir ENOENT；operation/1、零delta。
- post-mkdir-disappear三层：before_open/made=1移除新目录；operation/1、零delta。
- open-disappear三层：existing target在before_open/made=0消失；operation/1，只移除target。
- final-stat-disappear三层：只在open/fstat后的name stat处一次删除并抛ENOENT；operation/1，只移除target。

全部复用现有MANAGED anchor、exercise、stream/signature/inventory/delta和provider/hash/log顺序；不得复制第二份family executor，不得在不安全层下创建后续层。

## 内建 self-test 红缝

内建rows顺序固定：swap9、wrong-euid3、eexist9、mkdir-replace3、mkdir-failure3、post-mkdir3、open-disappear3、final-stat3、real-eio1。外部`run-matrix`完整37行成功后，self-test必须自己构造同一rows、真实执行37/37、验证executed集合、有序ID hash `721b3687bda848db7b6481c527f491e6733cf376dbade3dd37b319fce8029bc8`与provider hash，然后在写PASS前唯一失败：

```python
if mode == "self-test":
    raise AssertionError("self-disproof incomplete")
```

缺case/hook/stream/signature/delta必须在此诊断前失败。合法1/2/37-row `run-matrix`不进入该红缝并继续成功。

## Green、提交与报告

完整37-row外部matrix必须rc0/38B/0B、log 37行且ID hash固定，九family计数`9/3/9/3/3/3/3/3/1`；1-row与逆序2-row仍成功，provider不变。self-test必须在证明37已执行后只以精确incomplete诊断rc1、stdout无PASS。运行Python3.8 grammar、03/03a回归、no-range diff-check与execution BASE exact1/400。

提交`test(session): complete race family matrix`。提交后写`task-4-report.md`，包含红/绿证据、TASK_BASE/TASK_HEAD、task/cumulative numstat、self-test精确红因和clean状态；不要写manifest，controller在独立review PASS后处理。
