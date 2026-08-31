# 测试、门禁、安全与工程卫生候选结论

本文件只覆盖已确认调研范围中的质量切片。优先级按“可能误操作设备 / 让失败伪装成成功 / 缺少自动门禁 / 可维护性”排序。实测统一引用 `research/raw/quality-evidence.md`；未执行的攻击路径和跨平台结果单列为 `[推断]` 或“未确认”。

## 结论摘要

- 三套离线回归在当前 WSL2/Linux 环境均通过，29 个 Bash 入口 `bash -n` 均通过，说明仓库确实具备无需真机的可执行基线；见 `research/raw/quality-evidence.md#E02` 至 `#E05`。
- 最高风险不在现有 happy path，而在门禁语义和设备选择边界：Claude Code 版未固定 ADB serial；Codex 版在真实模式也允许 `--allow-skip` 返回退出码 0。
- 仓库没有 CI、lint、格式化、静态检查或秘密扫描配置；当前通过完全依赖人工运行脚本。
- Codex 回归对输入边界、会话隔离、ADB 查询失败和临时状态保护覆盖最完整；Claude Code 与 shared 版明显落后，三个实现已经发生安全语义漂移。

## P0 — Claude Code 版没有固定 ADB 目标，部署流程包含破坏性裸 `adb`

源码事实：

- Claude verifier 的真实模式直接执行 `adb shell "$@"` 和 `adb logcat ...`，不要求、校验或传递 `ANDROID_SERIAL`：`claude-code/features/dev-sidebar/verify-sidebar.sh:39`、`claude-code/features/dev-sidebar/verify-sidebar.sh:51`、`claude-code/features/dev-sidebar/verify-sidebar.sh:68`、`claude-code/features/dev-sidebar/verify-sidebar.sh:78`。
- Claude 构建 skill 给出的部署命令是连续裸调用 `adb root`、`adb remount`、`adb push`、`adb reboot`：`claude-code/features/.harness/skills/build-services-jar/SKILL.md:30`。
- sepolicy skill 同样使用未固定目标的裸 ADB 查询：`claude-code/features/.harness/skills/build-sepolicy/SKILL.md:41`。
- 对照之下，Codex verifier 先验证 serial，再构造 `ADB=(adb -s "$serial")`：`codex/features/dev-sidebar/verify-sidebar.sh:47`、`codex/features/dev-sidebar/verify-sidebar.sh:53`；shared verifier 也执行同样约束：`common/.harness/features/dev-sidebar/verify-sidebar.sh:37`、`common/.harness/features/dev-sidebar/verify-sidebar.sh:43`。

实测：mock 只接受不带 `-s` 的调用，并注入 `ANDROID_SERIAL=-s`，Claude verifier 仍返回 `RESULT PASS`、退出码 `0`；见 `research/raw/quality-evidence.md#E07`。该探针没有调用真实设备。

影响：在多设备、模拟器与真机并存时，验证可能读取默认设备；更严重的是 skill 中的 root/remount/push/reboot 可能作用于错误设备。

候选验收：真实模式缺少或含非法 `ANDROID_SERIAL` 时必须在第一次 ADB 调用前退出非零；所有 ADB 命令都必须携带同一个 `-s "$serial"`；回归用 mock 断言零个裸 `adb`。

## P0 — Codex 真实模式可把缺失应用的 SKIP 转成成功退出

源码事实：

- 参数解析接受 `--allow-skip`，但解析后没有限制它必须与 `--demo` 同用：`codex/features/dev-sidebar/verify-sidebar.sh:20`、`codex/features/dev-sidebar/verify-sidebar.sh:45`。
- 应用不存在被记为 SKIP：`codex/features/dev-sidebar/verify-sidebar.sh:289`、`codex/features/dev-sidebar/verify-sidebar.sh:312`。
- 只要没有 FAIL，`allow_skip=1` 会输出 `RESULT PASS (SKIP allowed)` 并自然退出 0：`codex/features/dev-sidebar/verify-sidebar.sh:315`、`codex/features/dev-sidebar/verify-sidebar.sh:325`。
- 文档却规定 `--allow-skip` 仅用于探索，不得作为交付证据：`codex/README.md:123`、`codex/README.md:128`。
- shared 版已经实现正确的 fail-closed 参数约束，并有真实模式负向测试：`common/.harness/features/dev-sidebar/verify-sidebar.sh:32`、`common/tests/test-harness.sh:82`。

实测：隔离 mock 模拟真实模式的四项成功和应用缺失，命令返回 `RESULT PASS (SKIP allowed)`、退出码 `0`；见 `research/raw/quality-evidence.md#E06`。

影响：只以退出码或 `PASS` 前缀判断交付的自动化会把不完整版本判成成功。

候选验收：非 demo 模式传 `--allow-skip` 必须在任何 ADB 调用前以用法错误退出；新增与 shared 版等价的负向回归。

## P1 — 没有 CI、lint、静态检查、格式化或发布门禁

源码事实：shared README 仍把 branch、parity、verifier “纳入 CI”描述为后续动作：`common/README.md:63`。

实测：仓库内未发现 GitHub Actions、Make/Just/Task、pre-commit、ShellCheck、EditorConfig 等配置；当前环境也没有 `shellcheck`、`shfmt`、`actionlint`、`gitleaks` 或 `git-secrets`；见 `research/raw/quality-evidence.md#E01`。

影响：三套回归当前虽通过，但没有自动机制保证提交前或合并前必跑；Shell 脚本新增引号、未定义变量、平台不兼容或秘密时不会被稳定拦截。

候选验收：建立唯一根级离线门禁，至少串行执行 Bash 语法、ShellCheck、三套回归、shared parity、格式检查和有限秘密扫描；任一失败阻止合并。真实设备验证必须是显式、独立且固定目标的阶段。

## P1 — shared 的“交付 verifier”少于两个客户端的关键断言

源码事实：

- shared verifier 只验证 sidebar service、`sys.boot_completed` 和 `system_server`：`common/.harness/features/dev-sidebar/verify-sidebar.sh:65`、`common/.harness/features/dev-sidebar/verify-sidebar.sh:105`。
- 它没有 crash 时间窗检查，也没有 `com.android.sidebar` 安装检查；随后即可输出 `RESULT PASS`：`common/.harness/features/dev-sidebar/verify-sidebar.sh:108`、`common/.harness/features/dev-sidebar/verify-sidebar.sh:120`。
- shared workflow 把 verifier 的严格 `RESULT PASS` 定义为交付证据：`common/.harness/features/dev-sidebar/workflow.md:18`、`common/.harness/features/dev-sidebar/workflow.md:20`。
- Codex verifier 的对应两项检查位于 `codex/features/dev-sidebar/verify-sidebar.sh:188` 至 `codex/features/dev-sidebar/verify-sidebar.sh:261` 以及 `codex/features/dev-sidebar/verify-sidebar.sh:289` 至 `codex/features/dev-sidebar/verify-sidebar.sh:313`。

影响：共用方案被描述为公共事实源，但其 PASS 比客户端 verifier 弱；切换到 shared 入口会丢失“无新增 crash”和“应用存在”证据。

候选验收：定义三版共同的最小断言矩阵和统一结果语义；shared 严格 PASS 至少覆盖 boot、system_server、crash baseline、service、package 五项，并对每个查询失败路径做负向测试。

## P1 — Claude feature 名缺少输入边界，可能逃逸 `features/<feature>`

源码事实：

- Claude `detect_feature` 直接返回 Git 分支名，或对 `CURRENT_FEATURE` 执行删除全部空白后的内容：`claude-code/features/.harness/hooks/feature-common.sh:24`、`claude-code/features/.harness/hooks/feature-common.sh:39`。
- `feature_context_path` 直接拼接 `features/$feature/CLAUDE.md`，只检查最终文件存在：`claude-code/features/.harness/hooks/feature-common.sh:44`、`claude-code/features/.harness/hooks/feature-common.sh:50`。
- `sync_feature_link` 只拒绝以 `/` 开头的绝对目标，不拒绝 `..` 路径组件：`claude-code/features/.harness/hooks/feature-common.sh:67`。
- 对照之下，Codex 用单组件 ASCII 正则校验 feature：`codex/.codex/hooks/feature-common.sh:3`、`codex/.codex/hooks/feature-common.sh:7`、`codex/.codex/hooks/feature-common.sh:55`；shared resolver 也做等价校验：`common/.harness/bin/resolve-feature.sh:48`、`common/.harness/bin/resolve-feature.sh:75`。

[推断] `CURRENT_FEATURE=../../...` 或包含斜杠的分支名可使生成的相对软链目标越出预期 feature 目录；本轮按收口要求未新增利用探针。

候选验收：三版共享同一 feature-name 校验规则；拒绝 NUL、多行、斜杠、`.`、`..`、控制字符和非 ASCII；失败时不得替换根上下文软链。

## P1 — Claude hook 使用固定、跨项目/跨会话临时快照

源码事实：

- SessionStart 将 feature 写到固定的 `${TMPDIR:-/tmp}/.aosp-harness-demo.feature-snapshot`：`claude-code/features/.harness/hooks/load-feature.sh:18`、`claude-code/features/.harness/hooks/load-feature.sh:19`。
- UserPromptSubmit 从同一固定路径读取，不使用 hook payload 中的 session id：`claude-code/features/.harness/hooks/check-branch-drift.sh:8`、`claude-code/features/.harness/hooks/check-branch-drift.sh:13`。
- 源码注释已明确这是“单一快照”的教学简化：`claude-code/features/.harness/hooks/load-feature.sh:18`。

[推断] 并发会话/项目会相互覆盖快照；重定向写固定路径也没有 Codex 版的私有目录、owner/mode、`O_NOFOLLOW` 与原子替换保护，存在同 UID 冲突或软链跟随风险。本轮未执行攻击探针。

候选验收：按项目和 session id 隔离私有 `0700` 状态目录，快照为 `0600`，拒绝软链/非 owner 文件，原子写入；并发双会话回归必须互不干扰。

## P2 — Claude 一键 demo 会写真实 `CURRENT_FEATURE`，并发隔离弱

源码事实：Claude demo 先读取真实文件并注册退出恢复，但演示漂移时仍直接写树内 `CURRENT_FEATURE`：`claude-code/run-demo.sh:13`、`claude-code/run-demo.sh:17`、`claude-code/run-demo.sh:39`、`claude-code/run-demo.sh:41`。Codex demo 则把漂移放在 `mktemp` fixture：`codex/run-demo.sh:13`、`codex/run-demo.sh:75`、`codex/run-demo.sh:114`。

[推断] 两个 Claude demo 并发运行、或进程被无法捕获的终止信号杀死时，可能观察到短暂错误 feature 或遗留修改。正常退出路径有 trap，当前离线回归后没有已跟踪文件变化；见 `research/raw/quality-evidence.md#E10`。

候选验收：demo 只修改私有 fixture；真实 `CURRENT_FEATURE` 的 inode、内容和 mtime 在成功/失败/信号路径前后均保持不变。

## P2 — 平台兼容与测试可诊断性缺少门禁

源码事实：Claude 的软链替换依赖 `mv -Tf`：`claude-code/features/.harness/hooks/feature-common.sh:90`；测试依赖 Bash、Git、Python、`rg`、GNU/BSD 用户态工具组合，但仓库没有版本声明或平台矩阵。Claude 主回归在 `set -e` 下大量使用裸 `test` / `grep`，只有少量显式失败标签：`claude-code/features/.harness/tests/test-harness.sh:1`、`claude-code/features/.harness/tests/test-harness.sh:11`、`claude-code/features/.harness/tests/test-harness.sh:179`。

实测：当前 Linux/WSL2 上 29 个 Bash 文件语法通过，三套回归通过；见 `research/raw/quality-evidence.md#E00` 至 `#E05`。Claude 成功输出只有一行总结果，Codex 和 shared 也未输出逐 case 成功明细。

[推断] `mv -T` 在不支持 GNU `-T` 选项的平台会失败；本轮没有 macOS/BSD/原生 Linux/不同 Bash 版本矩阵，不能把 WSL2 通过外推为跨平台通过。

候选验收：声明支持平台与最低工具版本；至少在 Linux + macOS 跑同一离线套件；每个 case 失败时输出稳定名称、期望、实际与退出码。

## 已确认的正向能力

- 离线可执行：三套测试无需真机均可完成，退出码全为 0：`research/raw/quality-evidence.md#E03`、`#E04`、`#E05`。
- Bash 语法基线：29 个入口全部通过 `bash -n`：`research/raw/quality-evidence.md#E02`。
- Codex 测试纵深较好：47 个命名测试函数、68 次 regression 调用，覆盖非法 feature、NUL、manifest、detached/invalid repo、会话隔离、状态目录、ADB serial、查询失败、crash 纳秒边界和 demo 恢复；数量实测见 `research/raw/quality-evidence.md#E08`，注册入口见 `codex/tests/test-harness.sh:2474` 至 `codex/tests/test-harness.sh:2535`。
- shared 测试使用 `mktemp` fixture 并通过 trap 清理：`common/tests/test-harness.sh:5`、`common/tests/test-harness.sh:6`。
- 有限秘密模式扫描在已跟踪文件中无命中：`research/raw/quality-evidence.md#E09`。

## 冲突

1. Codex 文档规定 `--allow-skip` 仅用于探索，但实现允许真实模式并返回 0；见 P0 第二项及 `research/raw/quality-evidence.md#E06`。
2. shared 将 verifier 的 `RESULT PASS` 定义为交付证据，但断言集合少于两个客户端实现；这是交付强度冲突，不是单纯文案差异。
3. 三版对相同安全边界已有不同答案：shared 禁止真实 `--allow-skip`，Codex 允许；Codex/shared 固定 ADB serial，Claude 不固定；Codex 校验 feature 名，Claude 不校验。

## 未确认

- 按调研边界未连接真实设备，真实 ADB 输出差异、设备重启、SELinux denial、包管理器和 crash buffer 兼容性均未验证。
- 没有覆盖率工具，无法给出行/分支覆盖率；`research/raw/quality-evidence.md#E08` 仅是静态体量。
- 本机缺少 ShellCheck、shfmt、gitleaks、git-secrets；未确认这些工具在其他开发环境或外部 CI 中是否被另行调用，但仓库内未发现配置。
- 未执行 Claude feature 路径逃逸、固定临时文件软链跟随和并发 demo 竞争的利用测试；相关条目严格标为 `[推断]`。
- 未在 macOS、BSD、Windows、原生 Linux或旧版 Bash/Git/Python 上执行，平台兼容性只形成候选风险。
