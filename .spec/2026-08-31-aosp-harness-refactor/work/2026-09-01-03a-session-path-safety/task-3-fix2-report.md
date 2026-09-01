# Task 3 fix round 2 report

## Status

DONE

## Commits

- `bbdc50d6ba52b720a2a3fed74215b4199476fe0d` — `test(session): pin mutation object signatures`

## 红阶段证据

红阶段证据: `/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo/.spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-03a-session-path-safety/task-3-fix2-red-hit-symlink.log`

- `task-3-fix2-red-hit-symlink.log`：把允许路径 `hit` 换为 symlink 后，round1 mutation suite 仍假 PASS。
- `task-3-fix2-red-mkdir-type.log`：把 mkdir current replacement 换为 mode `0755` regular file 后，round1 mutation suite 仍假 PASS。
- `task-3-fix2-red-swap-file-hash.log`：向 swap file current replacement 写入 `evil` 后，round1 mutation suite 仍假 PASS。

以上三份日志均位于本报告所在目录。

## 修复

- 新增共享 `empty_regular` oracle，固定 `hit/caught/gone` 为非链接、空内容、mode `0600` 的 regular file；dev/inode 作为每次新建唯一允许变化，path/link/hash 仍由 scoped inventory 记录。
- swap file current replacement 固定为非链接 regular file、mode `0600`、空内容 SHA-256；current dev/inode 必须不同于 old victim。
- mkdir current replacement 固定为非链接目录、mode `0755`、不同于 old inode；unsafe EEXIST winner 同样固定为非链接目录。
- provider 与 old victim 继续比较包含 type/dev/inode/mode/link/hash 的完整 scoped signature；安全目录由成功 core 的 nofollow/EUID/0700/identity 校验承重。

## 测试

- `bash ./tests/test-session-path.sh --case source-validate`：PASS。
- `bash ./tests/test-session-path.sh --case roots-static`：PASS。
- `bash ./tests/test-session-path.sh --case mutations`：PASS。
- hit symlink、mkdir replacement regular file、swap file 非空内容三类自反证均返回 `1` 并命中对应 oracle。
- `bash ./tests/test-session-state-foundation.sh`、`bash -n common/.harness/lib/session-state-path.sh tests/test-session-path.sh`：PASS。
- `bash ./common/.harness/bin/check-parity.sh`、`git show --check HEAD`、累计 `git diff --check`：PASS。
- 三个 anchor 与三个 phase occurrence 精确各一次；provider 无 `fchmod`；foundation 两文件 BASE..HEAD diff 为空；实现工作树 clean。

## 累计 name/numstat

全局 BASE：`d68911bde93f72d1e42dc85fba6271159e945170`

```text
114	0	common/.harness/lib/session-state-path.sh
256	0	tests/test-session-path.sh
```

name-only 精确为上述两个 path 文件；累计新增+删除恰为 `370`。本 fix 为测试文件等行替换，未删除既有 oracle/comment，未修改生产 provider/foundation，未实现 task 4 或 03a1。

## 顾虑

- 无。
