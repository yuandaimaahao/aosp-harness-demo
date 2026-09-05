# AOSP Harness Demo

这个仓库演示一套可由 Claude Code 与 Codex 共用的 AOSP 工作流：feature registry、会话状态、跨进程资源租约、超时/重试命令运行时，以及统一 verifier。`claude-code/` 和 `codex/` 保留各自可独立阅读的示例；新的公共能力位于 `common/.harness/`。

## 最快开始

无需 AOSP 源码或 Android 设备即可运行全部离线检查：

```bash
bash scripts/check.sh --offline
```

查看两个客户端解析出的当前 feature 合同：

```bash
common/.harness/bin/harness-resolve-contract --client claude --root .
common/.harness/bin/harness-resolve-contract --client codex --root .
```

验证统一入口的离线 demo：

```bash
common/.harness/bin/harness-verify dev-sidebar --demo
```

client launcher 会组合 registry、session state 和 workspace source lease。dry-run 不启动真实客户端：

```bash
HARNESS_SESSION_ID=demo-session \
  common/.harness/bin/harness-client-launch codex --dry-run --
```

## 真机与构建

真实查询必须显式钉住设备 serial、稳定 Android instance ID 和 session ID；instance ID 是 device/CVD 共用的租约键，不能用临时 serial 代替：

```bash
export ANDROID_SERIAL=emulator-5554
export ANDROID_INSTANCE_ID=local-cf
export HARNESS_SESSION_ID=sidebar-check
common/.harness/bin/harness-verify dev-sidebar \
  --session-id "$HARNESS_SESSION_ID" \
  --android-instance-id "$ANDROID_INSTANCE_ID"
```

构建和部署示例见四份 repository skill：

- `claude-code/features/.harness/skills/build-services-jar/SKILL.md`
- `claude-code/features/.harness/skills/build-sepolicy/SKILL.md`
- `codex/.agents/skills/build-services-jar/SKILL.md`
- `codex/.agents/skills/build-sepolicy/SKILL.md`

公共 `run-command.sh` 提供五类命令：`query`、`mutate`、`reconnect`、`build`、`cvd`。query/reconnect 有界重试；其余命令不自动重试。每次 attempt 有独立 process group 和超时，租约会在命令结束后释放。

## 兼容与结果语义

- `contract_version=v2` 表示 registry、session provider 和新版 dispatcher 可用。
- `contract_version=legacy` 或 `compat: ...=legacy` 表示公共 provider 物理缺席，入口走保留的旧实现。
- verifier 只有末行 `RESULT PASS` 且退出码为 0 才代表严格成功；`RESULT INCOMPLETE`、`RESULT FAIL`、超时或 runtime 错误都不是交付证据。
- 旧的三个 `verify-sidebar.sh` 路径继续存在，便于演示和回滚；新调用应优先使用 `common/.harness/bin/harness-verify`。

## 当前验证边界

仓库测试使用 mock ADB/CVD/build 命令，不声称已经验证真实设备性能、AOSP 全量构建耗时或非 Linux 平台。真机执行前应先确认目标、运行对应 build skill，并保留 verifier 的严格 PASS 输出。Python 最低版本为 3.8；CI 固定 ShellCheck 0.11.0、shfmt 3.14.0 和 gitleaks 8.30.1。

更完整的公共层说明见 [`common/README.md`](common/README.md)，verifier 字节与退出码合同见 [`docs/verifier-contract.md`](docs/verifier-contract.md)。
