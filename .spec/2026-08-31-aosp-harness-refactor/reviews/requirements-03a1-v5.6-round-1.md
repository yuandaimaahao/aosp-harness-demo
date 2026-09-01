# 03a1 requirements v5.6 review — round 1

Reviewer: `review_design_03a_r1`

Verdict: **PASS** — blocker 0 / important 0 / minor 0

## Round 1 findings and closure

本轮初审发现两项important，controller在同轮回写后均已闭合：

1. 原R2把“protocol内容不匹配”写成03a1 driver自身必须返回1，但`protocol`没有外部协议内容输入；round7反证把常量改为v0后，driver实际仍rc0并输出v0，文本不匹配的rc1属于未来03a2 consumer。当前R2与验收清单已改为：03a1只保证protocol精确stdout；unknown/arity/extra返2，row/oracle/执行失败返1。这样没有把03a2 protocol消费职责带回本片。
2. 原R3承诺CASE_TSV“精确LF”并拒绝未定义的“非安全workspace”，超出PLAN与round7行为。实测round7的`read_text().splitlines()`对CRLF和缺末尾LF都执行37/37、rc0并输出38-byte摘要。当前R3已收窄为无NUL四列枚举、拒绝空/额外列与非法组合、workspace调用前物理不存在并由driver以0700创建，与prototype及PLAN private CLI边界一致。

修复后未发现新finding。

## Coverage review

- R1与frontmatter把owner精确限制为`tests/lib/session-path-race-driver.py`；不进入默认发现、不修改03/03a、不读未来03a2 entrypoint、不发布public API/capability。超出范围明确排除root shell、外部matrix生成及所有inert dispatcher，未把03a2职责带回。
- R2–R3逐字固定`protocol`、`self-test`、`run-matrix`形状，成功摘要分别为protocol v1与38-byte private PASS；`ABSENT_WORKSPACE`、四列TSV、case-log顺序和0/1/2语义均可用独立fixture验收。
- R4的九类按需求顺序为`9/3/9/3/3/3/3/3/1`，总计37；各family的stdout/stderr/rc分类完整。
- R5覆盖三个唯一anchor、MANAGED/EXPECTED_EUID/OS_ERROR字段、EEXIST有序双hook、only-anchor替换、case invocation与provider hash。
- R6覆盖完整type/dev/inode/mode/uid/readlink/hash签名、scoped inventory、added/removed/replaced/protected/post-predicate、swap subtree rekey与mkdir runtime-original。
- R7逐项且按顺序固定14类active self-disproof；未知异常不能被当成预期拒绝吞掉。
- R8–R9覆盖accepted HEAD的full/depth-1 private self-test、offline不发现Python driver、exact1、numstat `<=400`、03/03a零diff、六列manifest连续性、ledger与03a2 worktree/base/dispatch顺序门。独立回滚由本片“唯一非默认发现文件”边界与PLAN的03a1删除driver/03a2 inert契约共同闭合，不要求03a1实现未来consumer fixture。

## Mechanical and execution-backed checks

- `check-req.py`: rc0
- `check-criteria.py`: rc0
- `check-analyze.py`: rc0
- `check-plan.py`: rc0
- `git diff --check`: rc0
- round7 private self-test在staged full checkout（99 commits）和真实file-URL depth-1 checkout（1 commit、`.git/shallow`非空）均rc0、stdout 38 bytes、stderr 0。
- 针对性反证确认修复依据：protocol常量篡改时driver进程仍rc0并输出变更文本；CRLF与缺末尾LF的37-row TSV均被round7接受并真实执行37 case。因此当前requirements不再宣称这两项不存在的driver行为。
