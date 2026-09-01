# Task 4 v5.5 diff review round 1

## Status

NEEDS_CHANGES

范围：`bbdc50d6ba52b720a2a3fed74215b4199476fe0d..3fd9053d504a2bf48f59e450099ccdabeaf6b22d`。只读审查实现 worktree；除本报告外未修改文件。

严重度：blocker 1 / important 0 / minor 1。

## Standards

### Blocker — 长期回归依赖 execution BASE，当前 CI 的浅克隆必然失败

`tests/test-session-path.sh:47` 在默认路径执行：

```bash
git -C "$ROOT" diff --quiet d68911bde93f72d1e42dc85fba6271159e945170 HEAD -- common/.harness/lib/session-state-foundation.sh tests/test-session-state-foundation.sh
```

这把本片的一次性范围检查固化进了长期、自动发现的离线测试。`.github/workflows/quality.yml:7` 使用未设置 `fetch-depth` 的 `actions/checkout@v4`，而 `scripts/check.sh:27-28` 会执行全部 `tests/test-*.sh`。在本地 `git clone --depth 1` 的反证中，BASE object 不存在，默认 path test 与完整 offline gate 均退出 `1`，stderr 精确包含：

```text
fatal: bad object d68911bde93f72d1e42dc85fba6271159e945170
FAIL foundation files changed
```

这与 requirements `R6`（`requirements.md:29` 的独立离线测试）及主验收命令（`:35-36`, `:49`）冲突。authoritative tasks 已把 exact2/foundation BASE..HEAD 检查放在 controller/提交验收命令中（`tasks.md:107-108`），不要求默认回归自行解析历史 commit。应删除测试中的裸 SHA 检查，并继续在 controller 验收阶段机械执行 foundation diff。

### Minor — `invoke` 保留无效首参

`tests/test-session-path.sh:58-63` 的 `invoke` 忽略 `$1`，但所有调用仍传 `harness`、`xdg`、`tmp`、`default` 等标签并 `shift 3`。这是无效调用协议，降低可读性；可删除该参数并改为 `shift 2`。不影响当前行为。

未发现 `common/AGENTS.md` 硬规范违例；两个提交均符合个人项目 Conventional Commits。

## Spec

除上述 shallow-checkout blocker 外，指定重点均已闭环：

- 原三 finding：真实 foundation 文件缺席的 default/flag 均为 rc `0`、精确 33-byte stdout 和空 stderr；额外 LF 自反证被 default `cmp` 以 rc `1` 拒绝；固定 ShellCheck `0.11.0`、shfmt `v3.14.0` 与规定 argv 实跑通过。
- managed-body location：临时副本把 `before_mkdir` 从 `open_managed` 移入 `dispatch`、保持全局 occurrence 为 1 后，测试 rc `1`、stdout 空、stderr 精确 `FAIL phase before_mkdir global or managed-body count\n`。
- `--case mutations`：rc `1`、stdout 空、stderr 精确 `FAIL option: unsupported case mutations\n`。
- 默认、`source-validate`、`roots-static`、`--dependency-absent`：均 rc `0`、stdout 精确 `RESULT PASS  session path safety\n`（33 bytes）、stderr 空。
- 无 oracle 丢失：task 3 的 anchor-driven mutation selector/driver 按 v5.5 边界删除；source/validate、四级 root、physical parent、危险根、2x2 isolation、三层 link/file/mode、victim/inventory、非-anchor post-mkdir probe均保留；结构 oracle由全局 occurrence 加强为全局+`open_managed`函数体 occurrence。最终 test 与 round2 prototype 除一行 ROOT seam 外逐字一致。
- `git diff --check`、foundation test、完整 offline gate在完整本地历史中通过；task4 未改 provider。全局 BASE..HEAD name-only exact2，numstat为 provider `114` + test `278` = `392/400`；foundation diff空，implementation worktree clean。

## Summary

Standards：2项（最严重为浅克隆/CI blocker）。Spec：1项 blocker（独立离线主验收在当前 CI checkout 形态下失败）；其余要求通过。
