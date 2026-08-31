# 架构调研摘要（只读证据）

调研切片：工程定位、目录/依赖边界、主要执行链、复现与可移植性、新 feature/backend 扩展阻碍。未修改产品源码、测试或规格状态。

## 结论

1. **仓库是三套并列教学 Demo，不是单一可部署 Harness。** 根 README 明确列出独立的 `claude-code/`、`codex/` 和共用方案 `common/`，并把它们定位为无需真实 AOSP/设备的 Demo（`README.md:3-9`）。三处各有 `CURRENT_FEATURE`，三处又各自维护 manifest/verifier；同一 `dev-sidebar` 清单甚至有三种 schema：Claude 为按空白拆分的四列（`claude-code/features/dev-sidebar/repos.tsv:1-8`、`claude-code/features/dev-sidebar/check-branch.sh:16-21`），Codex 为三列 TSV（`codex/features/dev-sidebar/repos.tsv:1-6`、`codex/features/dev-sidebar/check-branch.sh:51-82`），common 为四列 TSV（`common/.harness/features/dev-sidebar/repos.tsv:1-6`、`common/.harness/bin/resolve-feature.sh:119-146`）。因此修复或扩展其中一套不会自动覆盖另两套。

2. **`common` 的核心执行链边界清楚，但启动、parity、验证是分离的门禁。** 两个 adapter 先调用共享 resolver，只有检测到 `.repo/` 才调用 branch checker，之后输出 contract，非 dry-run 才 `exec claude|codex`（`common/.claude/bin/claude-feature:28-48`、`common/.codex/bin/codex-feature:28-48`）。resolver 校验 `CURRENT_FEATURE`、manifest、workflow、恰好一个可执行 verifier，并输出哈希契约（`common/.harness/bin/resolve-feature.sh:42-97,99-165`）。parity 另行硬编码调用 canonical/Claude/Codex 三份输出（`common/.harness/bin/check-parity.sh:9-27`），verifier 也只由 demo/人工另行调用（`common/run-demo.sh:19-38`）；启动 adapter 本身不会执行 parity 或 verifier。

3. **独立 Claude/Codex 实现与 common 不是同一后端的薄适配。** Claude/Codex wrapper 都从四个硬编码锚点仓探测 feature，再回退 `CURRENT_FEATURE`（`claude-code/features/.harness/hooks/feature-common.sh:24-41`、`codex/.codex/hooks/feature-common.sh:10-48`），同步根上下文软链后启动客户端（`claude-code/features/.harness/bin/claude-feature:20-44`、`codex/.codex/bin/codex-feature:15-56`）。common 则只读 `CURRENT_FEATURE`，不复用这两套探测、hook、process checker 或 verifier。Claude hook 使用全局临时快照（`claude-code/features/.harness/hooks/load-feature.sh:18-24`），Codex hook 使用按 session 的受限状态目录（`codex/.codex/hooks/session-start.sh:8-10,107-163`），行为边界也不等价。

4. **当前离线 Demo 在本机可运行，但绿色结果不证明真实 AOSP 构建/部署可复现。** README 明示 Codex demo 不启动 Codex、不跑 AOSP、不访问 ADB/CVD（`codex/README.md:1-3,20`），common 设计也明确离线且不依赖真实客户端/设备（`docs/superpowers/specs/2026-07-22-shared-claude-codex-harness-design.md:9-17`）。本次实测全部 shell 通过 `bash -n`，common contract/parity/regression、三套 demo verifier 和两套 process checker均通过（原始输出见下）。这些检查验证的是脚本/静态工件/确定性样本，不覆盖真实 `repo` 树、Soong、设备或客户端 hook 信任。

5. **复现环境没有声明或锁定。** 四份主要 README 只有运行命令，没有 Bash/Python/Git/coreutils/ADB/客户端版本或支持平台矩阵（`claude-code/README.md:46-72`、`codex/README.md:5-20`、`common/README.md:7-19`）。运行时实际依赖 Bash、Python 3、Git、awk/sed/grep/find/diff、SHA 工具和 mktemp；真实模式还依赖 ADB，非 dry-run 依赖 `claude`/`codex`（例如 `common/.harness/bin/resolve-feature.sh:48-72,99-156`、`common/.harness/bin/check-branches.sh:19-48`、`common/.harness/features/dev-sidebar/verify-sidebar.sh:37-44`）。Claude 链使用 GNU 风格 `mv -Tf`（`claude-code/features/.harness/hooks/feature-common.sh:85-103`）。仓库未发现 CI、容器、tool-version 或依赖清单；因此跨 Linux/macOS/不同工具版本的可移植性为 **[推断] 未被项目自身证明**。

6. **新增 feature 有约定式入口，但仍绑定“目录名=所有仓目标分支”和单 verifier。** common 可发现 `.harness/features/<feature>/`，但强制 `target_branch=feature`、恰好一个可执行 `verify-*.sh`（`common/.harness/bin/resolve-feature.sh:78-97,158-164`），branch checker把同一个目标分支应用于全部仓（`common/.harness/bin/check-branches.sh:19-47`）；方案文档也承认更复杂项目需扩展 manifest 分支列（`common/Claude-Codex共用Harness方案.md:100-120`）。独立实现还要求复制 feature context、checker、verifier，且维护各自不同的 manifest parser。

7. **新增 backend/client 没有注册表或可枚举插件边界。** resolver 仅接受 `claude|codex`（`common/.harness/bin/resolve-feature.sh:34-40`）；parity 直接写死两个 adapter、两份 context 文件和两个客户端目录（`common/.harness/bin/check-parity.sh:9-18,29-40`）；branch checker甚至固定以 `--client claude` 取得公共契约（`common/.harness/bin/check-branches.sh:7-12`）。新增 backend 至少要同步修改 resolver、parity、adapter、context、tests 和文档，结构上不是“新增一个目录即可”。

8. **文档存在已证实的结构漂移。** Claude feature 上下文声称 `frameworks/native` 有“对应 native 编译 skill”（`claude-code/features/dev-sidebar/CLAUDE.md:74-80`），实际只有 `build-services-jar` 与 `build-sepolicy` 两个 skill（`claude-code/README.md:31-34`，文件清单见原始输出）。共用长文说客户端适配层拥有各自的 `skills`（`common/Claude-Codex共用Harness方案.md:9-16`），实际 `common/.claude`/`.codex` 只有 wrapper 与 settings/hooks。`docs/AOSP整机源码Harness工程探索-codex版.md:9` 还链接同目录 `README.md`，但 `docs/README.md` 不存在；Codex 长文的 docs 副本与 `codex/` 主副本已有 9 行增删漂移（原始输出见下）。

## 关键命令原始输出

### 工作树基线

命令：`git status --short --branch`  
stdout/stderr：
```text
## main...github/main
?? .spec/
```
退出码：`0`

### common contract、parity 与 verifier

命令：`cd common && ./.claude/bin/claude-feature --dry-run --contract`  
stdout/stderr：
```text
client=claude
feature=dev-sidebar
target_branch=dev-sidebar
manifest=.harness/features/dev-sidebar/repos.tsv
workflow=.harness/features/dev-sidebar/workflow.md
verifier=.harness/features/dev-sidebar/verify-sidebar.sh
repositories=frameworks/base,frameworks/native,packages/apps/SidebarApp,build/make,system/sepolicy
contract_sha256=42c3e86e2bdfc69468b4319894ca75192caf97b2b86b32249769dad51cadf02d
```
退出码：`0`

命令：`cd common && ./.harness/bin/check-parity.sh`  
stdout/stderr：
```text
PARITY PASS  Claude/Codex 共享同一公共契约
```
退出码：`0`

命令：`cd common && ./.harness/features/dev-sidebar/verify-sidebar.sh --demo`  
stdout/stderr：
```text
PASS  sidebar service registered
PASS  sys.boot_completed = 1
PASS  system_server pid = 1423
RESULT PASS
```
退出码：`0`

命令：`cd common && ./tests/test-harness.sh`  
stdout/stderr：
```text
RESULT PASS  shared Harness regression suite
```
退出码：`0`

### 独立实现的离线检查

命令：`cd claude-code && ./.claude/bin/check-process-layer`  
stdout/stderr：
```text
PASS  build-services-jar skill 工件完整
PASS  build-sepolicy skill 工件完整
RESULT PASS
```
退出码：`0`

命令：`cd codex && ./.codex/bin/check-process-layer`  
stdout/stderr：
```text
PASS  build-services-jar skill 工件完整
PASS  build-sepolicy skill 工件完整
RESULT PASS
```
退出码：`0`

命令：对 `claude-code/`、`codex/`、`common/` 下全部 Bash shebang 文件逐个执行 `bash -n`  
stdout/stderr：29 行均为 `PASS <path>`，包括三套 wrapper、hooks、verifier、demo 和 tests；无 stderr。  
退出码：`0`

### 环境与文档漂移

命令：工具存在性与版本检查  
stdout/stderr摘录（原样）：
```text
bash       FOUND /usr/bin/bash
python3    FOUND /usr/bin/python3
git        FOUND /usr/bin/git
adb        FOUND /usr/bin/adb
claude     FOUND /home/zzh0838/.local/bin/claude
codex      FOUND /home/zzh0838/.local/bin/codex
shellcheck MISSING
GNU bash, version 5.2.21(1)-release (x86_64-pc-linux-gnu)
Python 3.12.3
git version 2.43.0
```
退出码：`0`

命令：`git diff --no-index --stat docs/AOSP整机源码Harness工程探索-codex版.md codex/AOSP整机源码Codex-Harness工程探索.md`  
stdout/stderr：
```text
 .../AOSP整机源码Codex-Harness工程探索.md               | 18 +++++++++---------
 1 file changed, 9 insertions(+), 9 deletions(-)
```
退出码：`1`（`git diff --no-index` 发现差异的约定退出码）

## 冲突与未确认

- 冲突：`common` 文档把 adapter skills 作为边界描述，当前目录却没有任何 skill；Claude feature 又引用不存在的 native skill。以上是事实冲突，不推断作者意图。
- 冲突：`docs/` Codex 长文声称可运行代码与 README 在“本文同目录”，但运行代码与 README 实际在 `codex/`。
- [推断] 三套实现可能刻意保留作教学对照；是否在重构后删除独立 Demo、只保留 common，需由目标规格决定。
- [推断] `mv -Tf`、GNU 测试命令以及未锁版本会阻碍 macOS/非 GNU 环境，但本次只在 Linux/WSL2、Bash 5.2、Python 3.12、Git 2.43 上实测。
- 未确认：真实 AOSP `.repo` 工作树、Soong 编译、ADB 设备、Cuttlefish、Claude/Codex hook 信任均未运行；离线 PASS 不应外推为真实部署 PASS。
