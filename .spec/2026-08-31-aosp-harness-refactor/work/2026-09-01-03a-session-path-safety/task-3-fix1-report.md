# Task 3 fix round 1 report

## Status

DONE

## Commits

- `37cdf6df8128606daf3930f485cad9c413e55f82` — `fix(session): close race mutation review gaps`

## 红阶段证据

红阶段证据: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-03a-session-path-safety/task-3-fix1-red-mkdir.log`

- mkdir disappearance：`task-3-fix1-red-mkdir.log`，基线返回 unsafe/`2`，而预期为 operation/`1`。
- made 错误：`task-3-fix1-red-made.log`，把生产 `made` 初值改为 true 后，基线 mutation suite 仍假 PASS。
- scoped inventory：`task-3-fix1-red-inventory.log`，注入额外 `unexpected` 对象后，基线 mutation suite 仍假 PASS。
- occurrence 计数：`task-3-fix1-red-occurrence.log`，同一行两个 marker 被旧 `grep -c` 计为 `1`。

以上四份日志均位于本报告所在目录。

## 修复

- mkdir 除 `FileExistsError` 外的 `OSError` 统一映射 `OperationFailure`；selector 与 parent/base 缺席路径仍使用既有 unsafe 分类。
- existing/before_mkdir/after_eexist 注入硬性要求 `not made`，mkdir-success replacement 保持硬性要求 `made`。
- scoped inventory 覆盖相对路径、type、dev、inode、mode、link target 与 regular-file hash；逐例限定允许路径，比较 provider 与 old victim 完整签名，并固定 current replacement 类型、inode、mode/target。
- marker 与三 phase 改为 `grep -Fo ... | wc -l` occurrence 计数。
- 新增 mkdir `FileNotFoundError` 持久回归，逐字断言 operation/`1` 且 scoped inventory 只含 provider copy。

## 测试

- `bash ./tests/test-session-path.sh --case source-validate`：PASS。
- `bash ./tests/test-session-path.sh --case roots-static`：PASS。
- `bash ./tests/test-session-path.sh --case mutations`：PASS。
- made=true、额外 unexpected、同一行重复 marker 三个自反证均返回 `1` 并命中对应 oracle。
- `bash ./tests/test-session-state-foundation.sh`、`bash -n common/.harness/lib/session-state-path.sh tests/test-session-path.sh`：PASS。
- `bash ./common/.harness/bin/check-parity.sh`、`git show --check HEAD`、累计 `git diff --check`：PASS。
- 三个 anchor 与三个 phase occurrence 精确各一次；provider 无 `fchmod`；foundation 两文件 BASE..HEAD diff 为空；实现工作树 clean。

## 累计 name/numstat

全局 BASE：`d68911bde93f72d1e42dc85fba6271159e945170`

```text
114	0	common/.harness/lib/session-state-path.sh
256	0	tests/test-session-path.sh
```

name-only 精确为上述两个 path 文件；累计新增+删除恰为 `370`，满足 fix round `<=370` 硬门。未删除既有 oracle/comment，未实现 task 4 或 03a1，未修改 foundation、发布 public API/provider marker、读取生产测试环境或加入 `fchmod`。

## 顾虑

- 无。
