# Task 4 独立审查

结论：**PASS**

计数：**blocker 0 / important 0 / minor 3**

审查边界：仅依据 `review-3cc6f8fd-4f0051b7.md` 与 `task-4-report.md`；parent=`3cc6f8fd54bdfe8efb7557409de9989890da7d41`，head=`4f0051b70b3e1d6f83a749289bfd2f2997bc8fd0`，frozen base=`7b46dfba287f2e3e3fb9ca00c3186b69c4720dc7`。未查看 worktree 源码，未另起 diff，未运行 AOSP 命令。

## 规格符合性

- task diff 只有 `work/modes/self_test.py`，单提交、117 additions；与报告的 Task 4 `117/182` 一致。
- closed JSON 的 duplicate/missing/unknown/type/order 均有 mutation 和精确错误码断言；replacement、DAG、missing owner、R owner、budget 801、budget relation、path 也均覆盖。
- PLAN、DECISIONS、sizing 三份文档均以真实临时 fixture 做负向 mutation，并经 `verify-supersession.py pre-commit` 公开入口校验。
- 五个承重 mutation 均落在公开命令路径：missing replacement、R owner、budget 801、`common/evil` 经 `_public()`；fake ledger SHA 由 `accept._fixture()` 生成公开 command，再交 `accept._expect()` 校验。负向 `_public()` 明确要求 `(rc, stdout, stderr) == (1, "", exact error line)`。
- commit/base/merge/path 负向覆盖在本 diff 可见；ledger/revert/accept matrix 复用既有 `accept._self_test()`，报告同时记录 targeted accept self-test exact PASS。报告还记录 full mutation self-test、三个 legacy regression、task-parent/frozen-base/whitespace gates 均通过且 stderr 为空。
- 报告记录 `pre-commit --require-complete` exact one-line PASS、exact six paths、frozen-base cumulative `735/800`；与本任务新增 117 行及 review package 的单路径 stat 无冲突。

规格结论：要求的 mutation、公开入口、精确失败三元组、accept/revert/regression matrix、完整 self-test、完整性门禁和预算结果均有实现或任务执行证据，未发现缺失、错误行为或越界扩展。

## Findings

### Minor 1 — R owner mutation 依赖列表位置

`work/modes/self_test.py:58` 通过 `requirement_owners[0]` 选择目标。对当前冻结 canonical manifest，这已由执行通过证明命中预期错误码；但若以后合法调整列表顺序，测试可能改到别的 requirement，仍得到同一错误码而不再专门保护 R。建议按 requirement ID 查找并断言唯一命中 R。

### Minor 2 — mutation 失败诊断过于统一

`work/modes/self_test.py:21-26,63-64` 精确比较三元组是正确的，但 mismatch 后只抛 `INTERNAL_ERROR`，且循环丢弃 case 名；失败时无法直接知道具体 mutant 或实际三元组。建议在不改变公开最终错误契约的前提下，保留 case/expected/actual 供测试诊断。

### Minor 3 — `_pre_fixture()` 返回未使用的 `base`

`work/modes/self_test.py:93,98,103` 返回 `(command, base)`，两个调用点都丢弃 `base`。这是很小的 YAGNI/接口噪声；建议只返回 command。未发现其他实质性重复、speculative abstraction 或错误路径缺口。

## 质量结论

实现范围集中，mutation 表驱动避免了明显重复，临时目录隔离与 exact stdout/stderr oracle 合理。三个 minor 均为后续可维护性问题，不削弱当前冻结输入下的验收结论，因此总体 **PASS**。
