# 任务 1：固定 private CLI 与精确双流协议

只执行本任务，不提前实现任务2–5，不派subagent。实现只允许在`/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo-03a1-session-path-race-assurance`中新增`tests/lib/session-path-race-driver.py`；证据和报告写到controller主仓本brief同目录。提交使用个人项目普通Conventional Commit，不用公司五段式模板。

执行BASE固定为`c959efaf9887808621852aff28073cf1f8789ca7`。完整依据是controller主仓同spec目录的`requirements.md`、`design.md`、`tasks.md`，本任务只实现tasks的任务1。

## 红阶段

运行`python3 tests/lib/session-path-race-driver.py protocol`，必须因文件缺席失败且没有protocol token。把命令、rc和stdout/stderr字节数保存为`task-1-red.log`；不得用临时同名源码或改上游制造红灯。

## 实现

只提取round7蓝图的imports、常量和argv dispatcher：

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

两个正确arity的执行mode暂以明确`AssertionError("matrix executor incomplete")`进入rc1且不得打印PASS。`protocol`必须不stat/read依赖，rc0、stderr 0B、stdout精确`session-path-race-driver-v1\n`（28B）。无参数、unknown、`protocol extra`及执行mode错arity均rc2、无PASS。不import未来03a2，不定义运行时API/capability marker，保持Python 3.8 grammar兼容。

## Green与提交

按tasks任务1步骤4逐项capture验证。先`git add -N tests/lib/session-path-race-driver.py`，再验证BASE到working tree只含该driver、numstat不超过400、`git diff --check`通过。提交消息固定为`test(session): add private race driver protocol`。

提交后把红/绿命令、结果、`TASK_BASE`、`TASK_HEAD`、name-only/numstat、worktree status写入`task-1-report.md`并回报；不要创建review manifest行，controller会在独立review PASS后写。
