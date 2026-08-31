# 核心运行时与 ADB 边界调研摘要

范围：静态、只读审查 `common/`、`codex/`、`claude-code/` 三套独立 Demo。未连接真实设备，未执行 ADB/CVD/AOSP 构建，未修改产品源码、测试或规格状态。

## 候选结论

1. **P0：独立 Claude Demo 的真实部署流程未固定设备，可能操作非预期目标。** `claude-code/features/.harness/skills/build-services-jar/SKILL.md:27-34` 使用裸 `adb root/remount/push/reboot`；真实 verifier 也在 `claude-code/features/dev-sidebar/verify-sidebar.sh:39-53,68-79` 使用裸 `adb shell/logcat`。这不是完全不可达的旧代码：`claude-code/README.md:62-71,84-90` 明确给出真实设备运行入口。与 Codex 版的固定 `ANDROID_SERIAL` 规则（`codex/.agents/skills/build-services-jar/SKILL.md:44-57`）冲突。

2. **P1：所有真实设备查询均缺少命令级超时和有限重试，ADB 卡死会让 verifier/部署无限等待。** 现行公共 verifier 的三次调用位于 `common/.harness/features/dev-sidebar/verify-sidebar.sh:74-100`；独立 Codex verifier 的调用位于 `codex/features/dev-sidebar/verify-sidebar.sh:142-171,202-244,271-300`；部署指令位于 `codex/.agents/skills/build-services-jar/SKILL.md:44-57`。全运行时代码中的 `timeout` 仅是 Codex hook 配置的 10 秒（见证据 E2），没有包裹 ADB/CVD/build。

3. **P1：设备失败证据被主动丢弃，错误分类会失真。** 公共 verifier 对所有 ADB 调用 `2>/dev/null`，并在 getprop/pidof 上用 `|| true` 抹平退出码（`common/.harness/features/dev-sidebar/verify-sidebar.sh:74-100`）；service 查询若失败但留下非空 stdout，会进入“service missing”而非“query failed”（同文件 `:74-81`）。Codex 版虽保留退出码，但同样丢弃 stderr，只输出通用中文标签（`codex/features/dev-sidebar/verify-sidebar.sh:142-185,240-258,271-312`）。因此缺少原命令、串号、退出码、stderr、耗时等诊断上下文。

4. **P1：独立 Codex 的部署代码块不是 fail-fast，且 root/reboot 后没有等待、恢复或回滚。** `codex/.agents/skills/build-services-jar/SKILL.md:48-57` 是连续命令但没有 `set -e`/显式状态检查；`adb root` 后立即 remount，push 失败后仍可能继续 reboot，最后一个命令成功可掩盖前序失败。[推断] shell 执行器若默认不中止，存在“部署部分失败但代码块返回成功”的风险。该流程也没有 `wait-for-device`、重试、远端文件备份/校验或 reboot 后验证。

5. **P1：公共版的会话漂移与并发隔离只有文字约束，没有运行时强制。** `common/.harness/common.md:35-39` 要求同一 feature 仅一个客户端写入，并建议真实项目比较 `contract_sha256`；但实际 hooks 只有 SessionStart parity（`common/.claude/settings.json:3-14`、`common/.codex/hooks.json:3-15`），没有 UserPromptSubmit 漂移检查，也没有文件锁、设备锁或 CVD 组租约。`common/README.md:66-69` 明确承认这是 Demo 边界。[推断] 多会话可能并发写同一源码/构建输出或操作同一设备。

6. **P2：公共 verifier 相比独立 Codex 版丢失 crash 与 app 验证，且未消费部署时间基线。** 公共 workflow 要求记录部署基线并构建 `SidebarApp`（`common/.harness/features/dev-sidebar/workflow.md:5-20`），但公共 verifier 仅检查 service、boot_completed、system_server（`common/.harness/features/dev-sidebar/verify-sidebar.sh:65-120`）；独立 Codex verifier还有 `/proc/stat`/`--since` crash 窗口和 package 检查（`codex/features/dev-sidebar/verify-sidebar.sh:188-261,289-313`）。因此公共 `RESULT PASS` 不能证明“部署后无 crash”或 app 已安装。

7. **P2：职责有集中趋势，但仍有高维护成本的重复与弱语义检查。** 公共 Claude/Codex adapter 48 行中仅 client 名与最终 exec 两处不同（证据 E4）；Codex 两个 hook 的 session-id/安全状态目录函数块完全相同（证据 E4）。`codex/.codex/bin/check-process-layer:40-67,96-124` 和 Claude checker `claude-code/features/.harness/bin/check-process-layer:9-33` 主要用 `grep` 检查文字出现，无法证明代码块可执行、fail-fast、带超时或正确清理。[推断] 注释或不可达片段也可能通过工件检查。

8. **P2：资源生命周期不完整。** 公共 parity 临时目录使用 `mktemp -d` + EXIT trap，属于良好基线（`common/.harness/bin/check-parity.sh:4-7`）；但 Claude build 使用固定 `/tmp/build-services.log`（`claude-code/features/.harness/skills/build-services-jar/SKILL.md:17-23`），并发会互相覆盖。Codex build 虽使用 mktemp，却无 signal trap 杀后台 build，成功后也不清日志（`codex/.agents/skills/build-services-jar/SKILL.md:14-39,61-85`）。Codex session snapshot 原子写入且目录权限严格（`codex/.codex/hooks/session-start.sh:35-104,121-159`），但 hooks 只有 Start/Prompt、没有 SessionEnd，最终 `.feature` 文件无删除路径（证据 E5）。

## 已确认的正向约束（重构不应破坏）

- 公共与 Codex verifier 都校验安全串号格式并用数组 `ADB=(adb -s "$serial")` 构造命令，避免 shell 字符串拼接注入：`common/.harness/features/dev-sidebar/verify-sidebar.sh:37-44`、`codex/features/dev-sidebar/verify-sidebar.sh:47-54`。
- wrapper 最终使用 `exec`，能把信号和退出状态交给真实客户端：`common/.claude/bin/claude-feature:47-48`、`common/.codex/bin/codex-feature:47-48`。
- feature 与 manifest repo path 有白名单解析，阻止路径穿越：`common/.harness/bin/resolve-feature.sh:48-75,99-149`。
- verifier 对 FAIL/SKIP 采用严格非零退出；离线观测结果见 E3。

## 原始命令证据

### E1：仓库明确存在三个独立 Demo

命令：`nl -ba README.md | sed -n '1,9p'`

stdout/stderr（原样）：

```text
     1	# AOSP 整机源码 Harness Demo
     2	
     3	本仓库包含两套彼此独立的客户端 Demo，以及一套共用 Harness 方案 Demo：
     4	
     5	- [`claude-code/`](claude-code/)：Claude Code 版本。
     6	- [`codex/`](codex/)：Codex 版本，包含可运行示例和完整探索文档。
     7	- [`common/`](common/)：Claude Code + Codex 共用公共层、两个适配器、parity 检查和同步方案。
     8	
     9	三个 Demo 都不依赖真实 AOSP 源码树或 Android 设备。
```

退出码：`0`。

### E2：超时/重试/锁检索

命令：`rg -n -e 'timeout|retry|重试|flock|lockfile|wait-for-device|get-state' common/.harness common/.claude common/.codex -g '!*.md' || true`

stdout/stderr（原样）：

```text
common/.codex/hooks.json:11:            "timeout": 10
```

退出码：`0`。

### E3：公共 verifier 的安全离线行为

命令：`DEMO_SKIP=1 common/.harness/features/dev-sidebar/verify-sidebar.sh --demo; printf 'exit=%s\n' "$?"; env -u ANDROID_SERIAL common/.harness/features/dev-sidebar/verify-sidebar.sh; printf 'exit=%s\n' "$?"`（在 `set +e` 下）。

stdout/stderr（合并、原样）：

```text
SKIP  sidebar service registration（demo requested skip）
PASS  sys.boot_completed = 1
PASS  system_server pid = 1423
RESULT INCOMPLETE
exit=2
error: 真实模式需要显式设置安全的 ANDROID_SERIAL
exit=2
```

外层命令退出码：`0`。

### E4：重复代码

命令：`diff -u common/.claude/bin/claude-feature common/.codex/bin/codex-feature || true`；`sed -n '11,105p' codex/.codex/hooks/session-start.sh | sha256sum`；`sed -n '12,106p' codex/.codex/hooks/check-branch-drift.sh | sha256sum`。

stdout/stderr（关键原样摘录）：

```text
-  "$ROOT/.harness/bin/resolve-feature.sh" --client claude --contract)"
+  "$ROOT/.harness/bin/resolve-feature.sh" --client codex --contract)"
-exec claude "${args[@]}"
+exec codex "${args[@]}"
a1949f3aece53adadf57f1bb9b18412a488901b27028510e5f903ba084eb7d  -
a1949f3aece53adadf57f1bb9b18412a488901b27028510e5f903ba084eb7d  -
```

退出码：`0`。

### E5：snapshot 生命周期检索

命令：`rg -n -e 'session_id|[.]feature|unlink|remove|rm |SessionEnd|SessionStart|UserPromptSubmit' codex/.codex/hooks.json codex/.codex/hooks/*.sh`

stdout/stderr（关键原样摘录）：

```text
codex/.codex/hooks/session-start.sh:133:destination = os.path.join(state_dir, session_id + ".feature")
codex/.codex/hooks/session-start.sh:156:            os.unlink(temporary)
codex/.codex/hooks.json:4:    "SessionStart": [{
codex/.codex/hooks.json:13:    "UserPromptSubmit": [{
codex/.codex/hooks/check-branch-drift.sh:154:snapshot="$STATE_DIR/$session_id.feature"
```

退出码：`0`。

### E6：静态语法基线

命令：对 `common codex claude-code` 下非测试 `*.sh` 和 `*/bin/*` 逐个执行 `bash -n`。

stdout/stderr（摘要，原命令逐文件均输出 `OK <path>`）：`24` 个运行时脚本全部 `OK`，无 stderr。

退出码：`0`。首次在 zsh 中误用只读变量名 `status` 的编排命令退出 `1`，修正为 `rc_overall` 后得到上述结果；该失败不是仓库脚本失败。

## 冲突与未确认

- 冲突：根 README 称三个 Demo 不依赖设备（`README.md:9`），这是“一键 Demo 默认路径”的事实；Claude README 又明确提供去掉 demo 后的真实 ADB 入口（`claude-code/README.md:71,90`）。因此不能据前者把裸 ADB 风险排除为死代码。
- 冲突：公共 workflow 要求“记录部署时间基线”（`common/.harness/features/dev-sidebar/workflow.md:13-16`），公共 verifier 却无 `--since`/crash 检查；独立 Codex verifier 有对应实现。
- [未确认] 未在真机上验证 ADB server 卡死、root 重连时间、logcat 版本兼容、CVD selector 语法及多设备行为；这些需要隔离设备农场或完整 mock 才能定量。
- [未确认] 未执行真实 build，后台 shell 收到 SIGINT/SIGTERM 时子进程是否成为孤儿取决于调用宿主和进程组行为；这里只确认代码无显式 signal cleanup。
- [未确认] `contract_sha256` 通过直接拼接五个文件内容计算（`common/.harness/bin/resolve-feature.sh:151-156`），存在无边界 framing 的理论歧义；未构造满足各文件语法的可利用碰撞，故不升级为已证实缺陷。
