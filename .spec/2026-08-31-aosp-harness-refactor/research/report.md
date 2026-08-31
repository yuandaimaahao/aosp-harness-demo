# AOSP Harness 工程调研报告

## 结论

### 1. 工程形态与单一真相源（`research/raw/architecture-summary.md`）

仓库当前是 `claude-code/`、`codex/`、`common/` 三套并列 Demo，而非一套共享核心加薄适配器的工程。三者分别维护 feature、manifest、verifier 和 hook，甚至同一 `dev-sidebar` manifest 存在不同 schema；修改一套不会自动覆盖另两套。`common` 已具备清晰的 resolver/contract 边界，可作为后续收敛公共逻辑的现有基础。（`README.md:3-9`；`common/.harness/bin/resolve-feature.sh:42-165`；`research/raw/architecture-summary.md`）

`common` 启动链会解析 feature、校验 manifest/workflow/verifier 并生成哈希契约，但 parity 检查和交付 verifier 是另外的命令，启动 adapter 不会自动执行它们。因此现有绿色 contract 不等于已通过分支、parity 和设备交付验收。（`common/.claude/bin/claude-feature:28-48`；`common/.harness/bin/check-parity.sh:9-40`；`common/run-demo.sh:19-38`）

### 2. 安全与结果语义的高优先级缺陷（`research/raw/quality-findings.md`）

独立 Claude 版的真实 verifier 和部署 skill 使用裸 `adb`，不要求、校验或传递 `ANDROID_SERIAL`；隔离 mock 实测证明，即使注入不安全的 serial，脚本仍会通过不带 `-s` 的 ADB 路径并返回 0。在多设备环境中，`root/remount/push/reboot` 因此可能作用于非预期目标。（`claude-code/features/dev-sidebar/verify-sidebar.sh:39-79`；`claude-code/features/.harness/skills/build-services-jar/SKILL.md:27-34`；`research/raw/quality-evidence.md#E07`）

独立 Codex 版的真实模式接受 `--allow-skip`，并可在应用缺失时输出 `RESULT PASS (SKIP allowed)`、退出 0；这与文档规定的“只用于探索，不可作为交付证据”相冲突。隔离 mock 已稳定复现该成功退出。（`codex/features/dev-sidebar/verify-sidebar.sh:20-45`；`codex/features/dev-sidebar/verify-sidebar.sh:289-325`；`codex/README.md:123-128`；`research/raw/quality-evidence.md#E06`）

Claude feature 名直接来自 Git 分支或 `CURRENT_FEATURE`，后续用于拼接 `features/$feature/CLAUDE.md`，且软链接仅拒绝绝对路径，没有像 Codex/common 一样限制为安全单路径组件。（`claude-code/features/.harness/hooks/feature-common.sh:24-50`；`claude-code/features/.harness/hooks/feature-common.sh:67-90`；`codex/.codex/hooks/feature-common.sh:3-55`；`common/.harness/bin/resolve-feature.sh:48-75`）

### 3. ADB 可靠性与可诊断性（`research/raw/runtime-summary.md`）

三套实现的真实设备路径普遍没有命令级超时、有界重试或重连策略；运行时非 Markdown 代码中检索到的唯一 `timeout` 是 Codex hook 的 10 秒配置，未包裹 ADB/CVD/build。`adb root` 和 reboot 后也没有统一的 `wait-for-device`、恢复等待或回滚。（`common/.harness/features/dev-sidebar/verify-sidebar.sh:74-100`；`codex/features/dev-sidebar/verify-sidebar.sh:142-300`；`research/raw/runtime-summary.md#E2`）

公共 verifier 对 ADB 调用丢弃 stderr，部分命令还用 `|| true` 抹平退出码；Codex 版也丢弃 stderr 并主要输出通用错误标签。当设备离线、权限失败或命令不兼容时，现有输出不足以保留串号、命令、退出码、stderr 和耗时等诊断上下文。（`common/.harness/features/dev-sidebar/verify-sidebar.sh:74-100`；`codex/features/dev-sidebar/verify-sidebar.sh:142-185`；`codex/features/dev-sidebar/verify-sidebar.sh:240-312`）

### 4. 验收强度与契约漂移（`research/raw/runtime-summary.md`）

`common` verifier 只检查 service、`sys.boot_completed` 和 `system_server`，没有消费 workflow 要求的部署时间基线，也没有检查 crash 时间窗和 `com.android.sidebar` 安装状态；独立 Codex verifier 已包含后两项。因此当前 common 的严格 `RESULT PASS` 强度低于客户端实现，不能作为完整交付证据的单一真相源。（`common/.harness/features/dev-sidebar/workflow.md:5-20`；`common/.harness/features/dev-sidebar/verify-sidebar.sh:65-120`；`codex/features/dev-sidebar/verify-sidebar.sh:188-313`）

公共层对“同一 feature 仅一个客户端写入”和会话中 contract 不漂移的保障主要是文字约定：实际 hook 只在 SessionStart 做 parity，没有 prompt 级 contract 检查，也没有源码、构建输出、设备或 CVD 的租约/锁。（`common/.harness/common.md:35-39`；`common/.claude/settings.json:3-14`；`common/.codex/hooks.json:3-15`；`common/README.md:66-69`）

### 5. 资源生命周期、重复代码与扩展点（`research/raw/runtime-summary.md`）

Claude hook 使用全局固定临时快照 `${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot`，不按项目或 session 隔离；Claude build 也使用固定 `/tmp/build-services.log`。Codex 的 session 快照已采用私有目录和原子写，但没有 SessionEnd 清理路径；其后台 build 也没有 signal trap 统一清理子进程。（`claude-code/features/.harness/hooks/load-feature.sh:18-24`；`claude-code/features/.harness/skills/build-services-jar/SKILL.md:17-23`；`codex/.codex/hooks/session-start.sh:35-159`；`research/raw/runtime-summary.md#E5`）

公共 Claude/Codex adapter 主体重复，两个 Codex hook 的 session 状态函数块完全相同；同时 resolver、parity 和 branch checker 将 `claude|codex` 写死，新 backend 需要同步修改多个文件而非新增一个可枚举实现。（`common/.harness/bin/resolve-feature.sh:34-40`；`common/.harness/bin/check-parity.sh:9-40`；`common/.harness/bin/check-branches.sh:7-12`；`research/raw/runtime-summary.md#E4`）

### 6. 工程门禁、可复现性与当前基线（`research/raw/quality-evidence.md`）

仓库内未发现 CI、ShellCheck、格式化、静态检查、秘密扫描或根级统一验收入口；主要 README 也没有声明并锁定 Bash/Python/Git/coreutils/ADB/客户端版本或支持平台矩阵。当前环境缺少 `shellcheck`、`shfmt`、`actionlint` 和秘密扫描工具。（`common/README.md:63-69`；`research/raw/quality-evidence.md#E00`；`research/raw/quality-evidence.md#E01`；`research/raw/architecture-summary.md`）

现有离线基线是绿色的：29 个 Bash 入口全部通过 `bash -n`，Claude、Codex、common 三套回归均退出 0，common contract/parity 与三套 demo verifier/process checker 也通过。这些实测只覆盖脚本、静态工件、mock 和确定性样例，不能外推为真实 AOSP 构建、设备部署或客户端 hook 信任已通过。（`research/raw/quality-evidence.md#E02`；`research/raw/quality-evidence.md#E03`；`research/raw/quality-evidence.md#E04`；`research/raw/quality-evidence.md#E05`；`research/raw/architecture-summary.md`）

### 7. 文档漂移（`research/raw/architecture-summary.md`）

文档与实际工件存在可复现的漂移：Claude feature 上下文引用了不存在的 native 编译 skill；common 长文将客户端 skills 描述为已存在的适配层，实际目录中没有；`docs/` 文章链接不存在的同目录 README，且 Codex 长文的两份副本已有 9 行增删差异。（`claude-code/features/dev-sidebar/CLAUDE.md:74-80`；`claude-code/README.md:31-34`；`common/Claude-Codex共用Harness方案.md:9-16`；`docs/AOSP整机源码Harness工程探索-codex版.md:9`；`research/raw/architecture-summary.md`）

## 未解决冲突

- 根 README 说三套 Demo 不依赖 Android 设备，Claude README 又明确给出真实 ADB 入口。前者可解释为默认演示路径，但项目定位没有明确区分“只是教学样例”与“可用于真实部署”。（`README.md:9`；`claude-code/README.md:62-90`）
- common 被定位为共用事实源，但它的 verifier 断言集弱于独立 Codex 版；当前“共用”与“最强交付证据”并不等价。（`common/.harness/features/dev-sidebar/verify-sidebar.sh:65-120`；`codex/features/dev-sidebar/verify-sidebar.sh:188-313`）
- Codex 文档规定真实交付不可使用 `--allow-skip`，代码却允许并返回 0。（`codex/README.md:123-128`；`codex/features/dev-sidebar/verify-sidebar.sh:315-325`；`research/raw/quality-evidence.md#E06`）
- 三套并列 Demo 可能是有意保留的教学对照，也可能是尚未完成收敛的过渡状态；仓库内没有权威决策记录说明重构后是否必须永久保留三套可运行实现。（`README.md:3-9`；`research/raw/architecture-summary.md`）

## 我没能确认的

- [推断] 本次未连接真实设备、Cuttlefish 或完整 AOSP 树，因此无法确认 ADB server 卡死、root 重连、logcat 版本差异、Soong 编译及部署后恢复的真实时序和成功率。（`research/raw/runtime-summary.md`；`research/raw/quality-findings.md`）
- [推断] 未执行 macOS、BSD、Windows、原生 Linux 或旧版 Bash/Git/Python 矩阵，不能确认 `mv -Tf` 等 GNU 语义在所有目标环境上可用。（`research/raw/quality-evidence.md#E00`；`claude-code/features/.harness/hooks/feature-common.sh:85-103`）
- [推断] 未运行覆盖率工具，现有测试函数和调用数只能表示体量，不能确认行/分支覆盖率。（`research/raw/quality-evidence.md#E08`）
- [推断] Claude feature 路径逃逸、固定临时快照的软链跟随、双会话 demo 竞争尚未用攻击/并发探针复现；静态源码边界已定位，实际影响仍需专项负向测试。（`research/raw/quality-findings.md`）
- [推断] 是否保留三套 Demo 作为教学对照，还是把 common 设为唯一可运行内核、另两套仅保留薄适配入口，无法从当前仓库内权威文档得出。（`README.md:3-9`；`research/raw/architecture-summary.md`）
