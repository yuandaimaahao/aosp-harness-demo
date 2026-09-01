# Task 1 fix round 1 report

## Status

DONE

## Commits

- `c77766f26adf939acb3a192946bf2f80e07cda05` — `test(session): harden source fixture oracles`

## 红阶段证据

- 路径：`.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-03a-session-path-safety/task-1-fix1-red.log`
- 命令：`bash ./tests/test-session-path.sh --case source-validate`
- 结果：退出 `1`，stdout 为空，stderr 精确为 `FAIL self-disproof: source fixture failure was masked`。

## 修复内容

- 加入递归自反证：向 source fixture 注入确定性失败，外层必须观察到非零。
- 四个 source case 均用 `|| exit $?` 显式传播失败。
- 每个隔离 shell 在 source path provider 前清除继承的 capability marker、private core 与四个 public 状态函数。
- source 前后比较 foundation 的四个既有函数体，包括 `_harness_component_is_safe`；函数集合必须精确等于 before 加唯一 core，inert 时必须完全相等。

## 测试摘要

- `bash ./tests/test-session-path.sh --case source-validate`：PASS，末行 `RESULT PASS  session path safety`。
- 预置并 export marker、private core 与四个 public 状态函数后重跑 source-validate：PASS。
- `bash -n common/.harness/lib/session-state-path.sh tests/test-session-path.sh`：PASS。
- `bash ./tests/test-session-state-foundation.sh`：PASS，末行 `RESULT PASS  session state foundation`。
- `git diff --check d68911bde93f72d1e42dc85fba6271159e945170 HEAD`：PASS；工作树 clean。

## 累计 name/numstat

BASE：`d68911bde93f72d1e42dc85fba6271159e945170`

```text
16	0	common/.harness/lib/session-state-path.sh
108	0	tests/test-session-path.sh
```

exact name-only 仍为上述两个 path 文件；累计新增+删除 `124`，不超过任务 1 上限 `150`。foundation 文件 BASE..HEAD diff 为空。

## 顾虑

- 无。本轮只修复 task 1 review findings，未实现 task 2 的 root selector 或 managed path 功能。
