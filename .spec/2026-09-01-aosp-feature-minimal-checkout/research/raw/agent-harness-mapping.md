# Harness 现状测绘：feature / framework / AOSP 源码与构建入口

调研日期：2026-09-01  
工作区：`/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo`  
性质：只读源码测绘；除本报告外未修改产品代码。  
选取 feature：`dev-sidebar`。  

## 结论先行

1. **已经支持“按 feature 选择逻辑契约”**：共享版从 `CURRENT_FEATURE` 得到 feature 名，要求存在 `.harness/features/<feature>/repos.tsv`、`workflow.md` 和唯一可执行的 `verify-*.sh`，再把涉及仓路径、目标分支、工作流和 verifier 输出为同一份客户端契约。
2. **尚未支持“按 feature 获取/物化 Git 单仓”**：`repos.tsv` 只是仓路径清单；现有代码只检查这些目录是否已经是 Git 仓且分支是否等于 feature 名。没有 remote/revision/project 映射，没有 `repo init/sync`、`git clone`、partial/sparse checkout、worktree、缓存或回退逻辑。
3. **尚未支持“按 feature 机器选择构建框架并求依赖闭包”**：feature 确实选择了一个自由文本 `workflow.md`，其中写着固定的 AOSP `source build/envsetup.sh`、`lunch`、`m ...` 命令；但 resolver 不解析构建目标、产物、构建系统或依赖。Codex 旧版的两个 build skill 也是仓库级全局工件，由 feature 指令人工路由，并非由 manifest 机器选择。
4. **没有业务源码文件注入**：未找到 feature source-to-destination 清单、patch 套用、复制/链接业务文件的实现。旧 Codex/Claude demo 的“注入”仅是把树根 `AGENTS.md`/`CLAUDE.md` 软链到 feature 上下文；共享版甚至改为静态客户端指引 + 公共 contract。AOSP 源码本身在 demo 中只有 `frameworks/base` 和 `frameworks/native` 占位文件，且不存在真实 `Android.bp`、`Android.mk`、`build/envsetup.sh`。
5. `dev-sidebar` 的五仓清单是**人工声明的影响面/允许修改范围，不是编译闭包**。共享构建命令为 `m services SidebarApp selinux_policy`，没有显式 native target；同时实际 AOSP 构建必需但清单未列出的 `build/soong`、prebuilts/toolchain、根构建文件等没有任何闭包表达或校验。因此不能从当前数据模型推导“只下载哪些 Git 单仓即可成功单编”。

## 当前实现的组织结构

仓库中有三套演示：`claude-code/`、`codex/` 和较新的共享版 `common/`。本报告以 `common/` 的公共实现为当前事实源，并用 `codex/` 的 feature 指令/skills 追踪更完整的构建语义。

| 关注点 | 当前共享版落点 | 作用 | 不具备的能力 |
|---|---|---|---|
| active feature | `common/CURRENT_FEATURE` | 单行 feature 名 | 不含 remote/revision/product |
| feature 公共事实 | `common/.harness/features/<feature>/` | `repos.tsv`、`workflow.md`、唯一 verifier | 不含源文件注入表、构建 DAG |
| feature 解析 | `common/.harness/bin/resolve-feature.sh` | 校验名称/文件/schema，输出 contract 和 hash | 不 checkout、不解析 workflow |
| AOSP Git 仓检查 | `common/.harness/bin/check-branches.sh` | 对已有仓检查 `.git` 和分支 | 不创建、不 fetch、不切分支 |
| 客户端入口 | `common/.codex/bin/codex-feature`、`.claude/bin/claude-feature` | 解析 contract；真实 `.repo` 树才做分支检查；启动客户端 | 不准备源码或构建环境 |
| 构建入口 | feature 的 `workflow.md` | 人读命令 `envsetup` / `lunch` / `m` | 无结构化 target/artifact/dependency |
| 旧版 build framework | `codex/.agents/skills/build-*` | 固定 services.jar / sepolicy 流程 | 不是 feature-local，也不从 manifest 选择 |
| AOSP 源码 | demo 下 `frameworks/*/PLACEHOLDER.*` | 说明独立 AOSP 仓应处的位置 | 不是真实 AOSP、不可实际编译 |

## `dev-sidebar` 静态追踪

### 1. 声明与选择

- `common/CURRENT_FEATURE:1` 是 `dev-sidebar`。
- `common/.harness/common.md:9-13` 定义：feature 从 `CURRENT_FEATURE` 读；目标分支等于 feature 名；仓清单、构建/部署事实和 verifier 分别来自 feature 目录。
- `common/.harness/bin/resolve-feature.sh:42-87` 读取并严格校验 feature 名，然后定位 `repos.tsv`、`workflow.md`、`common.md`。
- `common/.harness/bin/resolve-feature.sh:89-97` 要求 feature 目录恰好存在一个可执行 `verify-*.sh`。
- `common/.harness/bin/resolve-feature.sh:99-149` 只从 manifest 解析并校验四列中的第一列仓路径；`158-165` 输出 feature contract。
- 实际 dry-run contract 选择了五个仓：`frameworks/base`、`frameworks/native`、`packages/apps/SidebarApp`、`build/make`、`system/sepolicy`。

### 2. 仓与依赖声明

`common/.harness/features/dev-sidebar/repos.tsv:2-6` 的五条记录分别标记为 source/source/source/build/policy；schema 是 `path, convention, tags, description`，没有 remote、revision、clone depth、partial clone filter、sparse path、build target 或 dependency 字段。

旧 Codex feature 的人工上下文进一步说明了业务依赖：

- `codex/features/dev-sidebar/AGENTS.md:31-35`：目标是系统服务、native 合成和常驻边栏应用；允许修改的就是上述五仓。
- `:43-45`：`frameworks/base` 新增 `SidebarService`、`ISidebar.aidl` 并从 `SystemServer` 注册；public/System API 触发 `m update-api`。
- `:47-49`：`frameworks/native` 新增 SidebarFlinger 并接入启动链。
- `:51-53`：SidebarApp 通过 `ISidebar` 调服务，另依赖平台签名、privapp 权限、产品安装位置和进程策略。
- `:55-57`：`build/make` 负责模块及产品配置接入。
- `:59-61`：`system/sepolicy` 负责 service_contexts、service type、域访问和 allow 规则。

这些是文字约束，不是可执行依赖边。

### 3. 文件注入

没有业务文件注入链。证据：

- 搜索 shell/Markdown/TSV 中的 `repo init/sync`、`git clone/worktree/checkout/sparse-checkout`、复制/rsync、`Android.bp`/`Android.mk` 等，只命中了 Harness 自己的上下文软链和文档中的构建命令，没有源码获取或业务文件安装逻辑。
- `codex/frameworks/base/PLACEHOLDER.java:1-4` 与 `codex/frameworks/native/PLACEHOLDER.cpp:1-3` 明确只是独立源码仓的 demo placeholder。
- 在 `codex/`、`claude-code/` 三层深度内没有 `Android.bp`、`Android.mk`、`build/envsetup.sh` 或内嵌 `.git`。
- 旧 Codex 上下文注入链仅为：`codex/.codex/bin/codex-feature:15-33` 选择 feature，`:48-49` 调 `sync_feature_link`；`codex/.codex/hooks/feature-common.sh:50-58` 把目标解析为 `features/<feature>/AGENTS.md`，`:60-109` 原子更新根 `AGENTS.md` 软链。
- 共享版 wrapper `common/.codex/bin/codex-feature:28-41` 仅解析并打印 contract；`:47-48` 直接在根目录启动 Codex，没有 feature 源码注入步骤。

### 4. 编译命令与“构建框架”

共享事实 `common/.harness/features/dev-sidebar/workflow.md:5-9` 只有：

```bash
source build/envsetup.sh
lunch <product>-userdebug
m services SidebarApp selinux_policy
```

这说明当前构建框架默认是完整 AOSP 的 envsetup/lunch/`m` 前端，而不是本 Harness 自带的构建器。

旧 Codex feature 通过 `AGENTS.md:37-41` 人工路由两个仓库级 skill：改 `frameworks/base/services/**` 用 `$build-services-jar`，改 `system/sepolicy/**` 用 `$build-sepolicy`。对应实际命令和产物：

- `codex/.agents/skills/build-services-jar/SKILL.md:14-42`：固定 lunch `aosp_cf_x86_64_phone-trunk_staging-userdebug`，运行 `m services`，检查 `out/target/product/vsoc_x86_64/system/framework/services.jar`。
- 同文件 `:94-98`：public/System API 要 `m update-api`；服务注册/访问契约还依赖 SELinux，jar-only 不足。
- `codex/.agents/skills/build-sepolicy/SKILL.md:27-57`：运行 `m selinux_policy`，检查 `plat_sepolicy.cil`。
- 同文件 `:59-94`：策略部署要求完整 `system.img`，不是单推 jar。

这里的 skill 是客户端流程说明，feature manifest 没有指向它们；`resolve-feature.sh` 也不读取 `.agents/skills`。因此“选择 feature 后选择 workflow 文档”成立，“机器选择/执行构建框架”不成立。

### 5. 验证链

- resolver 强制发现唯一 verifier。
- `common/.harness/features/dev-sidebar/verify-sidebar.sh:37-44` 在真实模式要求显式安全的 `ANDROID_SERIAL`。
- `:65-82` 检查 sidebar 服务注册；`:84-105` 检查 boot complete 和 system_server PID；`:108-120` 只在无 FAIL、无严格 SKIP 时给 `RESULT PASS`。
- 实际 `--demo` 返回三项 PASS 和 `RESULT PASS`。

该 verifier 验证运行时表象，不验证 Git checkout 的最小性、源码文件是否注入、构建目标覆盖所有列出仓或依赖闭包是否完整。

## 对“按 feature 选择 Git 单仓与构建框架”的精确判断

### 已支持

- feature 名可以选择一份 feature-specific manifest、workflow 和 verifier。
- manifest 可以只写一个仓；`common/tests/test-harness.sh:159-173` 用 `dev-next` + 单条 `frameworks/base` fixture 证明解析器可发现另一 feature 的资源。
- 对**已经存在**的多个独立 Git 仓，可按 feature 目标分支做 fail-closed 检查；`check-branches.sh:19-48` 遍历 contract 中的仓路径，`:23-46` 判断 missing/invalid/detached/drift。
- 自由文本 workflow 可以为不同 feature 写不同 AOSP 命令。

### 未支持

- 从 manifest project/remote/revision 到 Git 单仓的解析、下载和落盘。
- “只取一个仓”的可用性判断；现有逻辑只知道 path，不知道该仓构建时要哪些其他 project。
- 源码/patch/生成文件从 feature 仓注入目标 AOSP 仓。
- Soong/Make module 到 Git project 的依赖闭包，以及 generated sources、tools、prebuilts、host tools、product config、API stubs 等公共依赖。
- 根据 feature/仓自动选择 build skill、lunch target、module target、artifact 和部署策略。
- declared repo 与 compile target 的覆盖关系校验：`frameworks/native` 在 `m services SidebarApp selinux_policy` 中没有显式 native 模块目标。
- 真实最小 checkout 验收；当前 demo 连可编译 AOSP 树都没有。

## 可供后续 spec 使用的最小验收草案

这些是基于现状缺口给出的候选，不代表已实现：

1. `resolve-feature --feature dev-sidebar --format json` 应输出结构化的 project remote/revision、checkout 策略、source injections、build provider/product/targets/artifacts，以及依赖闭包来源。
2. 在空目录执行 feature materializer 后，`find <workspace> -name .git` 的集合应与解析后的 project 闭包一致；不得静默依赖工作区外完整 AOSP。
3. 对每个 build target 运行 dry-run/query，证明所有输入 project 都在闭包内；缺任一 project 时应给出确定的依赖边和非零退出，而不是在编译深处随机失败。
4. `dev-sidebar` 至少要补出 native 合成模块的显式 target，或明确它由哪个已选 target 传递构建并给出查询证据。

## 未确认项

- 仓库没有真实 AOSP checkout，无法从真实 `Android.bp`/`Android.mk` 查询 `services`、`SidebarApp`、`selinux_policy` 与 SidebarFlinger 的实际 module/project 闭包。
- `SidebarApp`、SidebarFlinger、`SidebarService` 都是教学 feature 描述；仓库中没有其业务实现，无法确认具体源文件目的路径、模块名和 generated/API 依赖。
- `<product>-userdebug` 与旧 skill 中固定的 Cuttlefish lunch target 不一致；无法从当前数据确定哪个才是 intended product contract。
- `repos.tsv` 的 `convention/tags` 是否计划演化为构建策略字段，现有源码没有解释或消费者。
- 没有运行真实构建、ADB 或 CVD；只执行了 dry-run、静态流程自检和 verifier demo。

## 源码事实索引（文件:行号）

- `common/README.md:21-33`：共享层目录职责。
- `common/README.md:50-64`：manifest/workflow、branch check、wrapper、verifier 的日常顺序。
- `common/.harness/common.md:7-14`：active feature 公共契约。
- `common/.harness/common.md:16-24`：manifest 四列 schema 和唯一事实源语义。
- `common/.harness/features/dev-sidebar/repos.tsv:1-6`：五仓声明。
- `common/.harness/features/dev-sidebar/workflow.md:5-20`：build/deploy/verify 事实。
- `common/.harness/bin/resolve-feature.sh:42-97`：feature 资源发现。
- `common/.harness/bin/resolve-feature.sh:99-165`：仓路径解析、hash 和 contract 输出。
- `common/.harness/bin/check-branches.sh:19-48`：只检查现有 Git 仓和分支。
- `common/.codex/bin/codex-feature:28-48`：共享 Codex wrapper。
- `codex/features/dev-sidebar/AGENTS.md:31-61`：旧版 feature 的人工依赖与流程路由。
- `codex/.codex/bin/codex-feature:15-55`、`codex/.codex/hooks/feature-common.sh:50-109`：旧版 context 软链注入。
- `codex/.agents/skills/build-services-jar/SKILL.md:14-42,94-98`：services build/artifact/dependencies。
- `codex/.agents/skills/build-sepolicy/SKILL.md:27-61,96-107`：policy build/image/verification。
- `common/.harness/features/dev-sidebar/verify-sidebar.sh:37-120`：feature verifier。
- `common/tests/test-harness.sh:24-61,159-199`：契约一致性、单一事实源、feature-specific 资源发现。

## 实际执行命令与原始结果

说明：`exec_command` 返回一个合并的 output 字段，未单独标注 fd；下列命令均未观察到 stderr 文本。脚本中明确写向 stdout 的失败状态（例如 `MISSING ...`）仍列为 stdout。每条列出 exit code。

### 命令 1

```bash
sed -n '1,240p' /home/zzh0838/.agents/skills/research/SKILL.md
```

stdout：

```text
---
name: research
description: Investigate a question against high-trust primary sources and capture the findings as a Markdown file in the repo. Use when the user wants a topic researched, docs or API facts gathered, or reading legwork delegated to a background agent.
---

Spin up a **background agent** to do the research, so you keep working while it reads.

Its job:

1. Investigate the question against **primary sources** (official docs, source code, specs, first-party APIs), not a secondary write-up of them. Follow every claim back to the source that owns it.
2. Write the findings to a single Markdown file, citing each claim's source.
3. Save it where the repo already keeps such notes; match the existing convention, and if there is none, put it somewhere sensible and say where.
```

stderr：空。exit code：`0`。

### 命令 2

```bash
pwd
```

stdout：

```text
/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo
```

stderr：空。exit code：`0`。

### 命令 3

```bash
git status --short && rg --files -g 'AGENTS.md' -g '!research/raw/*' -g '!.spec/**/research/raw/*'
```

stdout：

```text
 M .spec/2026-08-31-aosp-harness-refactor/specs/2026-09-01-03a-session-path-safety/ledger.md
 M .spec/2026-08-31-aosp-harness-refactor/specs/2026-09-01-03a-session-path-safety/tasks.md
?? .spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-03a-session-path-safety/
?? .spec/2026-09-01-aosp-feature-minimal-checkout/
common/AGENTS.md
codex/features/dev-sidebar/AGENTS.md
```

stderr：空。exit code：`0`。这些既有改动均未触碰。

### 命令 4

```bash
find common codex claude-code -type f -not -path '*/research/raw/*' | sort
```

stdout：

```text
claude-code/.gitignore
claude-code/CURRENT_FEATURE
claude-code/README.md
claude-code/features/.gitignore
claude-code/features/.harness/bin/check-process-layer
claude-code/features/.harness/bin/claude-feature
claude-code/features/.harness/hooks/check-branch-drift.sh
claude-code/features/.harness/hooks/feature-common.sh
claude-code/features/.harness/hooks/load-feature.sh
claude-code/features/.harness/settings.json
claude-code/features/.harness/skills/build-sepolicy/SKILL.md
claude-code/features/.harness/skills/build-services-jar/SKILL.md
claude-code/features/.harness/tests/test-harness.sh
claude-code/features/.harness/tests/test-install-harness.sh
claude-code/features/.harness/tests/test-link-migration-safety.sh
claude-code/features/dev-sidebar/CLAUDE.md
claude-code/features/dev-sidebar/check-branch.sh
claude-code/features/dev-sidebar/repos.tsv
claude-code/features/dev-sidebar/verify-sidebar.sh
claude-code/features/install-harness.sh
claude-code/frameworks/base/PLACEHOLDER.java
claude-code/frameworks/native/PLACEHOLDER.cpp
claude-code/run-demo.sh
codex/.agents/skills/build-sepolicy/SKILL.md
codex/.agents/skills/build-services-jar/SKILL.md
codex/.codex/bin/check-process-layer
codex/.codex/bin/codex-feature
codex/.codex/hooks.json
codex/.codex/hooks/check-branch-drift.sh
codex/.codex/hooks/feature-common.sh
codex/.codex/hooks/session-start.sh
codex/AOSP整机源码Codex-Harness工程探索.md
codex/CURRENT_FEATURE
codex/README.md
codex/features/dev-sidebar/AGENTS.md
codex/features/dev-sidebar/check-branch.sh
codex/features/dev-sidebar/repos.tsv
codex/features/dev-sidebar/verify-sidebar.sh
codex/frameworks/base/PLACEHOLDER.java
codex/frameworks/native/PLACEHOLDER.cpp
codex/run-demo.sh
codex/tests/test-harness.sh
common/.claude/bin/claude-feature
common/.claude/settings.json
common/.codex/bin/codex-feature
common/.codex/hooks.json
common/.harness/bin/check-branches.sh
common/.harness/bin/check-parity.sh
common/.harness/bin/resolve-feature.sh
common/.harness/common.md
common/.harness/features/dev-sidebar/repos.tsv
common/.harness/features/dev-sidebar/verify-sidebar.sh
common/.harness/features/dev-sidebar/workflow.md
common/.harness/lib/session-state-foundation.sh
common/AGENTS.md
common/CLAUDE.md
common/CURRENT_FEATURE
common/Claude-Codex共用Harness方案.md
common/README.md
common/run-demo.sh
common/tests/test-harness.sh
```

stderr：空。exit code：`0`。

### 命令 5

```bash
./common/.codex/bin/codex-feature --dry-run --contract
```

stdout：

```text
client=codex
feature=dev-sidebar
target_branch=dev-sidebar
manifest=.harness/features/dev-sidebar/repos.tsv
workflow=.harness/features/dev-sidebar/workflow.md
verifier=.harness/features/dev-sidebar/verify-sidebar.sh
repositories=frameworks/base,frameworks/native,packages/apps/SidebarApp,build/make,system/sepolicy
contract_sha256=42c3e86e2bdfc69468b4319894ca75192caf97b2b86b32249769dad51cadf02d
```

stderr：空。exit code：`0`。

### 命令 6

```bash
ls -ld codex/AGENTS.md claude-code/CLAUDE.md claude-code/.claude common/AGENTS.md common/CLAUDE.md && readlink codex/AGENTS.md && readlink claude-code/CLAUDE.md && readlink claude-code/.claude
```

stdout：

```text
lrwxrwxrwx 1 zzh0838 zzh0838  17 Aug 10 14:26 claude-code/.claude -> features/.harness
lrwxrwxrwx 1 zzh0838 zzh0838  30 Aug 10 14:22 claude-code/CLAUDE.md -> features/dev-sidebar/CLAUDE.md
lrwxrwxrwx 1 zzh0838 zzh0838  30 Aug 10 14:22 codex/AGENTS.md -> features/dev-sidebar/AGENTS.md
-rw-r--r-- 1 zzh0838 zzh0838 788 Aug 10 14:22 common/AGENTS.md
-rw-r--r-- 1 zzh0838 zzh0838 751 Aug 10 14:22 common/CLAUDE.md
features/dev-sidebar/AGENTS.md
features/dev-sidebar/CLAUDE.md
features/.harness
```

stderr：空。exit code：`0`。

### 命令 7

```bash
nl -ba common/CURRENT_FEATURE && find common -maxdepth 3 -type d | sort && find common -maxdepth 3 -type f | sort
```

stdout：

```text
     1	dev-sidebar
common
common/.claude
common/.claude/bin
common/.codex
common/.codex/bin
common/.harness
common/.harness/bin
common/.harness/features
common/.harness/features/dev-sidebar
common/.harness/lib
common/tests
common/.claude/bin/claude-feature
common/.claude/settings.json
common/.codex/bin/codex-feature
common/.codex/hooks.json
common/.harness/bin/check-branches.sh
common/.harness/bin/check-parity.sh
common/.harness/bin/resolve-feature.sh
common/.harness/common.md
common/.harness/lib/session-state-foundation.sh
common/AGENTS.md
common/CLAUDE.md
common/CURRENT_FEATURE
common/Claude-Codex共用Harness方案.md
common/README.md
common/run-demo.sh
common/tests/test-harness.sh
```

stderr：空。exit code：`0`。

### 命令 8

```bash
nl -ba codex/frameworks/base/PLACEHOLDER.java && nl -ba codex/frameworks/native/PLACEHOLDER.cpp && find codex -maxdepth 3 -type d -name .git -o -type f -name Android.bp -o -type f -name Android.mk -o -type f -name envsetup.sh | sort && find claude-code -maxdepth 3 -type d -name .git -o -type f -name Android.bp -o -type f -name Android.mk -o -type f -name envsetup.sh | sort
```

stdout：

```text
     1	// Demo placeholder for the independent frameworks/base source repository.
     2	// The active feature guidance comes from the root AGENTS.md symlink; this file
     3	// does not imply that Codex discovers additional instructions in this folder.
     4	class Placeholder {}
     1	// Demo placeholder for the independent frameworks/native source repository.
     2	// Follow the active root AGENTS.md guidance when working in this source area;
     3	// this placeholder does not claim nested instruction discovery.
```

stderr：空。exit code：`0`。两个 `find` 均无额外输出。

### 命令 9

```bash
rg -n "SidebarService|SidebarFlinger|SidebarApp|selinux|service list|cmd sidebar|m services|m selinux_policy|update-api|artifact|dependency|依赖" codex/features/dev-sidebar codex/.agents/skills common/.harness/features/dev-sidebar common/.harness/common.md
```

stdout：

```text
codex/.agents/skills/build-services-jar/SKILL.md:3:description: Build and deploy AOSP services.jar after changes under frameworks/base/services, including SystemServer services; use for compile targets, artifacts, push steps, ART cache risks, and feature verification.
codex/.agents/skills/build-services-jar/SKILL.md:18:artifact="out/target/product/vsoc_x86_64/system/framework/services.jar"
codex/.agents/skills/build-services-jar/SKILL.md:23:  m services
codex/.agents/skills/build-services-jar/SKILL.md:37:[[ -f "$artifact" ]] || exit 1
codex/.agents/skills/build-services-jar/SKILL.md:38:printf "artifact: %s\n" "$artifact"
codex/.agents/skills/build-services-jar/SKILL.md:42:Build success requires the child exit status, the explicit `#### build completed successfully ####` marker, and the artifact `out/target/product/vsoc_x86_64/system/framework/services.jar`.
codex/.agents/skills/build-services-jar/SKILL.md:65:image_artifact="out/target/product/vsoc_x86_64/system.img"
codex/.agents/skills/build-services-jar/SKILL.md:84:[[ -f "$image_artifact" ]] || exit 1
codex/.agents/skills/build-services-jar/SKILL.md:96:- Run `m update-api` when a change affects a public or System API.
codex/.agents/skills/build-services-jar/SKILL.md:97:- Update and build SELinux policy when the service registration or access contract requires it; a jar-only change cannot satisfy that dependency.
codex/.agents/skills/build-sepolicy/SKILL.md:3:description: Build and verify AOSP SELinux policy after changes under system/sepolicy, especially new system services requiring service_contexts, service types, allow rules, denial checks, and full feature verification.
codex/.agents/skills/build-sepolicy/SKILL.md:35:artifact="out/target/product/vsoc_x86_64/system/etc/selinux/plat_sepolicy.cil"
codex/.agents/skills/build-sepolicy/SKILL.md:40:  m selinux_policy
codex/.agents/skills/build-sepolicy/SKILL.md:54:[[ -f "$artifact" ]] || exit 1
codex/.agents/skills/build-sepolicy/SKILL.md:55:printf "artifact: %s\n" "$artifact"
codex/.agents/skills/build-sepolicy/SKILL.md:67:image_artifact="out/target/product/vsoc_x86_64/system.img"
codex/.agents/skills/build-sepolicy/SKILL.md:86:[[ -f "$image_artifact" ]] || exit 1
codex/.agents/skills/build-sepolicy/SKILL.md:104:adb -s "$device_serial" shell service list | grep -F sidebar
common/.harness/features/dev-sidebar/repos.tsv:4:packages/apps/SidebarApp	source	app	sidebar 应用与资源
common/.harness/features/dev-sidebar/repos.tsv:6:system/sepolicy	policy	selinux,service_contexts	服务上下文与 SELinux 策略
common/.harness/features/dev-sidebar/workflow.md:9:    m services SidebarApp selinux_policy
common/.harness/features/dev-sidebar/workflow.md:15:3. Push only the artifacts built for the selected product.
codex/features/dev-sidebar/AGENTS.md:8:- `envsetup.sh` 必须在 bash 中 `source`，不要依赖调用者的默认 shell；`source` 后不要直接接管道，避免函数落入子 shell。
codex/features/dev-sidebar/AGENTS.md:11:- 修改 public/System API 后必须运行 `m update-api`，否则 checkapi 会阻断构建。
codex/features/dev-sidebar/AGENTS.md:35:允许修改的仓库只有：`frameworks/base`、`frameworks/native`、`packages/apps/SidebarApp`、`build/make`、`system/sepolicy`。机器可读清单位于 `features/dev-sidebar/repos.tsv`；开始工作前用 `./features/dev-sidebar/check-branch.sh` 检查所有涉及仓是否位于 `dev-sidebar` 分支。
codex/features/dev-sidebar/AGENTS.md:45:新增 `SidebarService` 和 `ISidebar.aidl`，并在 `SystemServer` 注册 `sidebar` 服务。AIDL 进入 public/System API 时必须运行 `m update-api`；服务实现和 `SystemServer` 变更遵循 `$build-services-jar`。
codex/features/dev-sidebar/AGENTS.md:49:新增 SidebarFlinger native 合成实现并接入合成服务启动链。使用唯一类名、全限定 C++ 方法和注册点导航；若触及缩放态触摸坐标映射，先明确 input 链路影响面。
codex/features/dev-sidebar/AGENTS.md:51:### packages/apps/SidebarApp
common/.harness/features/dev-sidebar/verify-sidebar.sh:74:  if service_output="$("${ADB[@]}" shell service list 2>/dev/null)" &&
codex/features/dev-sidebar/repos.tsv:2:frameworks/base	dev-sidebar	SidebarService、SystemServer 注册和 public/System API
codex/features/dev-sidebar/repos.tsv:3:frameworks/native	dev-sidebar	SidebarFlinger native 合成实现
codex/features/dev-sidebar/repos.tsv:4:packages/apps/SidebarApp	dev-sidebar	常驻边栏应用
codex/features/dev-sidebar/verify-sidebar.sh:276:elif service_list="$("${ADB[@]}" shell service list 2>/dev/null)"; then
codex/features/dev-sidebar/verify-sidebar.sh:287:  fail 'service list 查询失败'
```

stderr：空。exit code：`0`。

### 命令 10

```bash
./codex/.codex/bin/check-process-layer
```

stdout：

```text
PASS  build-services-jar skill 工件完整
PASS  build-sepolicy skill 工件完整
RESULT PASS
```

stderr：空。exit code：`0`。此命令仅静态检查 skill 文本，不运行 AOSP 构建。

### 命令 11

```bash
./common/.harness/features/dev-sidebar/verify-sidebar.sh --demo
```

stdout：

```text
PASS  sidebar service registered
PASS  sys.boot_completed = 1
PASS  system_server pid = 1423
RESULT PASS
```

stderr：空。exit code：`0`。

### 命令 12

```bash
HARNESS_ROOT="$PWD/common" ./common/.harness/bin/check-branches.sh
```

stdout：

```text
MISSING frameworks/base
MISSING frameworks/native
MISSING packages/apps/SidebarApp
MISSING build/make
MISSING system/sepolicy
```

stderr：空。exit code：`1`。这证明 checker 期望仓已经物化，只报告缺失，不负责获取。

### 命令 13

```bash
rg -n "repo (init|sync)|git (clone|worktree|checkout|sparse-checkout)|cp |rsync|ln -s|Android\.bp|Android\.mk|build/envsetup\.sh|lunch |m (services|selinux_policy|SidebarApp)" common codex claude-code -g '*.sh' -g '*.md' -g '*.tsv' -g '!**/tests/**'
```

stdout：

```text
codex/run-demo.sh:29:          ln -s -- "$ORIGINAL_AGENTS_TARGET" AGENTS.md || cleanup_rc=1
codex/run-demo.sh:35:        ln -s -- "$ORIGINAL_AGENTS_TARGET" AGENTS.md || cleanup_rc=1
claude-code/features/install-harness.sh:32:if ! ln -s "$SOURCE_REL" "$LINK"; then
codex/AOSP整机源码Codex-Harness工程探索.md:37:Java 调用可能经 AIDL 进入 Binder，再由 JNI 注册名跨到 native；一个 C++ 方法名可能在多个服务里重复；Soong 通过 `Android.bp`、产品变量和生成代码建立边。若一开始用 `onTransact` 这类泛词扫全树，海量命中会把真正需要的事实淹没。
codex/AOSP整机源码Codex-Harness工程探索.md:69:`m services` 成功只能证明某个目标编译完成，不能证明：
codex/AOSP整机源码Codex-Harness工程探索.md:379:| `$build-services-jar` | 修改 `frameworks/base/services` 或 `SystemServer` 服务 | `m services`、产物、ADB push、ART 风险、全镜像恢复、最终 verifier |
codex/AOSP整机源码Codex-Harness工程探索.md:380:| `$build-sepolicy` | 修改 `system/sepolicy` 或新增系统服务策略 | service type、`m selinux_policy`、完整镜像、denial 与注册验证 |
codex/AOSP整机源码Codex-Harness工程探索.md:403:  source build/envsetup.sh >/dev/null 2>&1 &&
codex/AOSP整机源码Codex-Harness工程探索.md:404:  lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 &&
codex/AOSP整机源码Codex-Harness工程探索.md:405:  m services
codex/AOSP整机源码Codex-Harness工程探索.md:428:m selinux_policy
codex/AOSP整机源码Codex-Harness工程探索.md:475:`.codex/bin/check-process-layer` 不运行 AOSP 构建，而是静态检查两个 skills 是否仍包含关键协议：Bash envsetup、lunch 目标、构建命令、retained wait、唯一日志、成功标记、artifact、设备 pin、CVD group、SELinux canonical pattern 和最终 `RESULT PASS`。
claude-code/features/dev-sidebar/CLAUDE.md:16:bash -c 'source build/envsetup.sh >/dev/null 2>&1 \
claude-code/features/dev-sidebar/CLAUDE.md:17:  && lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 \
claude-code/features/dev-sidebar/CLAUDE.md:18:  && m services' > /tmp/build.log 2>&1 &   # 后台 + 日志轮询，看到 build completed successfully 才算完
claude-code/features/dev-sidebar/CLAUDE.md:22:- lunch 目标是三段式 `product-release-variant`，release 段如 `trunk_staging`（可从 `out/soong.log` 的 `TARGET_RELEASE=` 反查）。
claude-code/features/dev-sidebar/CLAUDE.md:72:- 编译/push/验证通用流程见 skill **`build-services-jar`**（Read `services/**` 时自动激活）：单编 `m services`、产物 `services.jar`、push 清单、ART 缓存坑。
```

stderr：空。exit code：`0`。

### 命令 14

```bash
find .spec/2026-09-01-aosp-feature-minimal-checkout -maxdepth 3 -type d | sort
```

stdout：

```text
.spec/2026-09-01-aosp-feature-minimal-checkout
.spec/2026-09-01-aosp-feature-minimal-checkout/decisions
.spec/2026-09-01-aosp-feature-minimal-checkout/research
.spec/2026-09-01-aosp-feature-minimal-checkout/research/raw
.spec/2026-09-01-aosp-feature-minimal-checkout/specs
.spec/2026-09-01-aosp-feature-minimal-checkout/work
```

stderr：空。exit code：`0`。

### 其余源码读取命令

下列命令均 exit code `0`、stderr 空；stdout 是带 `nl -ba` 行号的源码原文，相关结论与逐行位置已完整收录在上文“源码事实索引”和各追踪段落。之所以单列，是避免把数千行源码在同一 raw 报告中重复一遍；命令本身保持原样：

```bash
find . -maxdepth 3 -type f -not -path './.git/*' -not -path './.spec/*/research/raw/*' | sort
nl -ba common/AGENTS.md && nl -ba common/README.md && nl -ba common/run-demo.sh
nl -ba codex/README.md && nl -ba claude-code/README.md
nl -ba common/.harness/common.md && nl -ba common/.harness/features/dev-sidebar/repos.tsv && nl -ba common/.harness/features/dev-sidebar/workflow.md && nl -ba common/.harness/bin/resolve-feature.sh
nl -ba common/.codex/bin/codex-feature && nl -ba common/.claude/bin/claude-feature && nl -ba common/.harness/bin/check-branches.sh
nl -ba codex/features/dev-sidebar/AGENTS.md && nl -ba codex/features/dev-sidebar/repos.tsv && nl -ba codex/.agents/skills/build-services-jar/SKILL.md && nl -ba codex/.agents/skills/build-sepolicy/SKILL.md && nl -ba codex/.codex/bin/check-process-layer
nl -ba .spec/2026-09-01-aosp-feature-minimal-checkout/PLAN.md && nl -ba .spec/2026-09-01-aosp-feature-minimal-checkout/STATE.md && nl -ba .spec/2026-09-01-aosp-feature-minimal-checkout/DECISIONS.md
nl -ba codex/CURRENT_FEATURE && nl -ba codex/.codex/bin/codex-feature && nl -ba codex/.codex/hooks/feature-common.sh && nl -ba codex/.codex/hooks/session-start.sh
nl -ba common/.harness/features/dev-sidebar/verify-sidebar.sh | sed -n '1,150p' && nl -ba codex/features/dev-sidebar/check-branch.sh | sed -n '1,180p'
rg -n "CURRENT_FEATURE|repos.tsv|workflow.md|repositories=|MISSING|target_branch|verify-\\*|multiple|feature" common/tests/test-harness.sh | sed -n '1,220p'
nl -ba common/tests/test-harness.sh | sed -n '1,70p;159,205p;255,275p'
```

> 完整性说明：这些较长命令的 stdout 已在文末“长源码读取命令的逐条完整重放”中逐条原样追加；这里保留命令索引，便于先快速浏览。

### 报告落盘校验

```bash
git diff --check -- .spec/2026-09-01-aosp-feature-minimal-checkout/research/raw/agent-harness-mapping.md && wc -l .spec/2026-09-01-aosp-feature-minimal-checkout/research/raw/agent-harness-mapping.md && git status --short -- .spec/2026-09-01-aosp-feature-minimal-checkout/research/raw/agent-harness-mapping.md
```

stdout：

```text
556 .spec/2026-09-01-aosp-feature-minimal-checkout/research/raw/agent-harness-mapping.md
?? .spec/2026-09-01-aosp-feature-minimal-checkout/research/raw/agent-harness-mapping.md
```

stderr：空。exit code：`0`。`git diff --check` 无输出即通过。

## 长源码读取命令的逐条完整重放

以下为前述命令的只读重放；stdout 按工具返回原样保存，stderr 均为空。

### 完整重放 1

```bash
find . -maxdepth 3 -type f -not -path './.git/*' -not -path './.spec/*/research/raw/*' | sort
```

stdout：

```text
./.github/workflows/quality.yml
./.gitignore
./.gitleaks.toml
./.spec/2026-08-31-aosp-harness-refactor/DECISIONS.md
./.spec/2026-08-31-aosp-harness-refactor/PLAN-history.md
./.spec/2026-08-31-aosp-harness-refactor/PLAN.md
./.spec/2026-08-31-aosp-harness-refactor/STATE.md
./.spec/2026-08-31-aosp-harness-refactor/config.yml
./.spec/2026-08-31-aosp-harness-refactor/excluded.md
./.spec/2026-09-01-aosp-feature-minimal-checkout/DECISIONS.md
./.spec/2026-09-01-aosp-feature-minimal-checkout/PLAN-history.md
./.spec/2026-09-01-aosp-feature-minimal-checkout/PLAN.md
./.spec/2026-09-01-aosp-feature-minimal-checkout/STATE.md
./.spec/2026-09-01-aosp-feature-minimal-checkout/config.yml
./.spec/2026-09-01-aosp-feature-minimal-checkout/excluded.md
./README.md
./claude-code/.gitignore
./claude-code/CURRENT_FEATURE
./claude-code/README.md
./claude-code/features/.gitignore
./claude-code/features/install-harness.sh
./claude-code/run-demo.sh
./codex/.codex/hooks.json
./codex/AOSP整机源码Codex-Harness工程探索.md
./codex/CURRENT_FEATURE
./codex/README.md
./codex/run-demo.sh
./codex/tests/test-harness.sh
./common/.claude/settings.json
./common/.codex/hooks.json
./common/.harness/common.md
./common/AGENTS.md
./common/CLAUDE.md
./common/CURRENT_FEATURE
./common/Claude-Codex共用Harness方案.md
./common/README.md
./common/run-demo.sh
./common/tests/test-harness.sh
./docs/AOSP整机源码Harness工程探索-claude-codex共用版.md
./docs/AOSP整机源码Harness工程探索-claude版.md
./docs/AOSP整机源码Harness工程探索-codex版.md
./scripts/check.sh
./scripts/shell-quality-baseline.tsv
./tests/COVERAGE.md
./tests/test-device-safety.sh
./tests/test-quality-gate.sh
./tests/test-session-state-foundation.sh
```

stderr：空。exit code：`0`。

### 完整重放 2

```bash
nl -ba common/AGENTS.md && nl -ba common/README.md && nl -ba common/run-demo.sh
```

stdout：

```text
     1	# Shared Harness Codex adapter
     2	
     3	本文件是 Codex 的客户端适配层，不是公共事实源。
     4	
     5	- 公共 feature、涉及仓、验证入口和同步规则：阅读 .harness/common.md。
     6	- 公共 manifest：只读 wrapper 输出的 .harness/features/<feature>/repos.tsv。
     7	- Codex 每次运行前必须通过 .codex/bin/codex-feature 固定工作目录并输出公共
     8	  契约；AGENTS.md 指令链不会在会话中途热重载。
     9	- .codex/hooks.json 只维护 Codex 能理解的配置；不要把 Claude settings schema
    10	  当成 Codex 的契约。
    11	- 本 Demo 的 SessionStart 只校验启动时 parity；真实项目继续使用 Codex 专属
    12	  UserPromptSubmit hook 比较会话快照与公共 contract_sha256。
    13	- 完成前运行 .harness/bin/check-parity.sh 和公共 verifier。
     1	# Claude Code + Codex 共用 Harness Demo
     2	
     3	这个目录模拟一个真实 AOSP 树根：公共层放在 .harness/，Claude Code 和
     4	Codex 各自只保留适配层。它解决的是“一个项目中如何同步两个 Harness 工程”，
     5	而不是把两个客户端配置文件强行做成同一份。
     6	
     7	## 一键运行
     8	
     9	从仓库根目录执行：
    10	
    11	    ./common/run-demo.sh
    12	
    13	或者：
    14	
    15	    cd common
    16	    ./run-demo.sh
    17	
    18	Demo 不启动 Claude/Codex，不运行 AOSP 编译，也不访问 ADB；它会演示两个
    19	wrapper 输出同一份公共契约、parity 检查、严格 verifier、SKIP 语义和回归测试。
    20	
    21	## 目录职责
    22	
    23	    .harness/
    24	      common.md                         公共事实和同步规则
    25	      features/dev-sidebar/repos.tsv    唯一涉及仓 manifest
    26	      features/dev-sidebar/workflow.md  共享构建、部署与验证事实
    27	      features/dev-sidebar/verify-sidebar.sh
    28	      bin/resolve-feature.sh            两个 adapter 共用的解析器
    29	      bin/check-branches.sh             真实 repo 树的共享分支检查
    30	      bin/check-parity.sh               公共契约一致性检查
    31	    .claude/                            Claude 专属 wrapper/settings
    32	    .codex/                             Codex 专属 wrapper/hooks
    33	    CLAUDE.md / AGENTS.md                各自客户端上下文，不做字节同步
    34	
    35	## 日常使用顺序
    36	
    37	    ./.claude/bin/claude-feature --dry-run --contract
    38	    ./.codex/bin/codex-feature --dry-run --contract
    39	    ./.harness/bin/check-parity.sh
    40	    ./.harness/features/dev-sidebar/verify-sidebar.sh --demo
    41	
    42	真实 AOSP 树中，最后一个命令去掉 --demo 并要求显式安全的 ANDROID_SERIAL。
    43	公共 verifier 的结果语义是：
    44	
    45	- RESULT PASS：所有断言通过，可以作为交付证据。
    46	- RESULT FAIL：至少一项失败，必须修复。
    47	- RESULT INCOMPLETE：默认存在 SKIP 也失败。
    48	- RESULT EXPLORATION (SKIP allowed)：只允许 --demo 探索使用，不是交付 PASS。
    49	
    50	## 一个项目中同步两个 Harness
    51	
    52	1. 将 .harness/ 纳入项目级版本控制，Claude 与 Codex 都从同一树根启动。
    53	2. 只在 .harness/features/<feature>/repos.tsv 维护涉及仓、约定、标签和说明。
    54	3. 在 workflow.md 维护两个客户端共同遵循的编译、部署和验证事实；目标分支
    55	   默认等于 CURRENT_FEATURE。
    56	4. 两个客户端的 wrapper 都先读取 CURRENT_FEATURE，再输出公共契约；不要各自
    57	   复制 manifest 或 verifier。
    58	5. 真实 repo 树存在 .repo/ 时，两个 wrapper 会先调用共享 check-branches.sh，
    59	   缺仓、detached HEAD 或分支漂移都会阻止启动。
    60	6. 修改公共层后先跑 parity，再选择一个客户端进入写入会话。
    61	7. 要换客户端时，先结束当前会话并保存改动，再通过另一个 wrapper 启动新的
    62	   会话。不要在同一运行中切换软链或期待 AGENTS.md/CLAUDE.md 热重载。
    63	8. 收工时只认公共 verifier 的 RESULT PASS；将 branch、parity 和 verifier
    64	   纳入 CI。
    65	
    66	本 Demo 的 SessionStart 配置只运行启动时 parity，并不自动实现会话中漂移
    67	快照。真实项目应保留各客户端自己的 UserPromptSubmit 漂移 hook，比较公共
    68	contract_sha256；本 Demo 通过“一次只允许一个写入客户端 + 切换时重启会话”
    69	作为可执行边界。
    70	
    71	详细设计与迁移建议见：
    72	
    73	- Claude-Codex共用Harness方案.md
    74	- ../docs/superpowers/specs/2026-07-22-shared-claude-codex-harness-design.md
     1	#!/usr/bin/env bash
     2	set -euo pipefail
     3	
     4	ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
     5	cd "$ROOT"
     6	
     7	section() {
     8	  printf '\n============================================================\n'
     9	  printf '%s\n' "$1"
    10	  printf '============================================================\n'
    11	}
    12	
    13	section '1. Claude adapter'
    14	./.claude/bin/claude-feature --dry-run --contract
    15	
    16	section '2. Codex adapter'
    17	./.codex/bin/codex-feature --dry-run --contract
    18	
    19	section '3. Shared parity'
    20	./.harness/bin/check-parity.sh
    21	
    22	section '4. Strict verifier'
    23	./.harness/features/dev-sidebar/verify-sidebar.sh --demo
    24	
    25	section '5. Exploration-only skip'
    26	set +e
    27	skip_output="$(DEMO_SKIP=1 ./.harness/features/dev-sidebar/verify-sidebar.sh --demo 2>&1)"
    28	skip_rc=$?
    29	set -e
    30	if [[ "$skip_rc" -eq 0 || "$skip_output" != *'RESULT INCOMPLETE'* ]]; then
    31	  echo 'error: strict skip demo did not fail with RESULT INCOMPLETE' >&2
    32	  exit 1
    33	fi
    34	printf '%s\n' "$skip_output"
    35	DEMO_SKIP=1 ./.harness/features/dev-sidebar/verify-sidebar.sh --demo --allow-skip
    36	
    37	section '6. Regression'
    38	./tests/test-harness.sh
    39	
    40	echo 'Claude Code + Codex 共用 Harness 演示完毕'
```

stderr：空。exit code：`0`。

### 完整重放 3

```bash
nl -ba codex/README.md && nl -ba claude-code/README.md
```

stdout：

```text
     1	# AOSP 整机源码 Codex Harness 可运行 Demo
     2	
     3	这是一份 **Codex 原生重写，不是名称替换** 的 AOSP Harness 教学示例。它用 Codex 已文档化的 `AGENTS.md`、skills、project hooks 和命令行界面，演示“上下文 / 流程 / 验证闭环”三层怎样协作。Demo 不启动 Codex，不运行 AOSP 构建，也不访问 ADB 或 CVD。
     4	
     5	## 快速开始
     6	
     7	从仓库根目录运行主入口：
     8	
     9	```bash
    10	./codex/run-demo.sh
    11	```
    12	
    13	或先进入 Codex demo 目录：
    14	
    15	```bash
    16	cd codex
    17	./run-demo.sh
    18	```
    19	
    20	`run-demo.sh` 依次演示上下文选择、会话分支漂移、涉及仓分支一致性、流程 skills、严格验证和回归测试。它只调用 wrapper 的 `--dry-run` 模式和确定性 demo 入口。
    21	
    22	## Codex 与 Claude Code 版的关键差异
    23	
    24	以下 Claude Code 一栏只描述本仓库的 `claude-code/` demo，不把该 demo 的实现细节外推为 Claude Code 的通用产品契约。
    25	
    26	| 维度 | Codex 版 | 本仓库 Claude Code demo |
    27	|---|---|---|
    28	| 根 / feature 指引 | 使用根与 feature 的 `AGENTS.md`；Codex 在启动时每次运行建立一次指令链 | 使用根与 feature 的 `CLAUDE.md`，由该 demo 的 wrapper 在启动前同步根软链 |
    29	| 仓库 skills | Codex 仓库 skills 位于 `.agents/skills`；可显式 `$skill-name` 选择，也可在任务匹配 `description` 时隐式选择；没有已文档化的 `paths` 路径触发契约 | 本仓库 Claude demo 的 `.claude/skills` 示例使用 `paths` metadata；这只是对当前入库示例的描述 |
    30	| Hooks | Codex demo 用 `.codex/hooks.json`；Codex 也支持 `.codex/config.toml` 中的 inline `[hooks]` tables，两者使用同一 Codex hook schema：事件 → matcher group → command hook；项目 hook 信任必须通过 `/hooks` 审查 | 本仓库 Claude demo 用 `.claude/settings.json`，命令通过 `${CLAUDE_PROJECT_DIR}` 定位；它不与 Codex 的配置 schema 或信任流程等同 |
    31	| 启动边界 | Wrapper 必须先选定 `AGENTS.md` 再启动新运行；会话中漂移由 hook 阻断并提示重启 | 该 demo 也在启动前同步 `CLAUDE.md`，并把 SessionStart hook 定位为 fallback；这是本仓库的工程选择 |
    32	
    33	因此，Codex 版不是把 `CLAUDE.md` 改名为 `AGENTS.md`：指引发现、skill 选择、hook 配置与信任、启动时正确性边界都按 Codex 契约重新落地。
    34	
    35	## 目录与三层
    36	
    37	```text
    38	codex/
    39	├── CURRENT_FEATURE
    40	├── AGENTS.md -> features/dev-sidebar/AGENTS.md
    41	├── run-demo.sh
    42	├── .codex/
    43	│   ├── bin/codex-feature
    44	│   ├── bin/check-process-layer
    45	│   ├── hooks.json
    46	│   └── hooks/{session-start,check-branch-drift}.sh
    47	├── .agents/skills/
    48	│   ├── build-services-jar/SKILL.md
    49	│   └── build-sepolicy/SKILL.md
    50	├── features/dev-sidebar/
    51	│   ├── AGENTS.md
    52	│   ├── repos.tsv
    53	│   ├── check-branch.sh
    54	│   └── verify-sidebar.sh
    55	└── tests/test-harness.sh
    56	```
    57	
    58	| 层 | 职责 | Demo 落点 |
    59	|---|---|---|
    60	| ① 上下文层 | 在一次 Codex 运行前选定 feature，并防止会话中分支漂移 | `CURRENT_FEATURE` + 树根 `AGENTS.md` 软链 + wrapper + hooks |
    61	| ② 流程层 | 将构建、部署、安全检查和验证顺序封装为可复用流程 | `.agents/skills/*/SKILL.md` + `check-process-layer` |
    62	| ③ 验证闭环层 | 用脚本产出可审计的 PASS / FAIL / INCOMPLETE 结论 | `features/dev-sidebar/verify-sidebar.sh` |
    63	
    64	导航不单独算一层：本方案使用 **`rg` + 源码阅读**，先按仓和路径缩小范围，再搜 JNI 注册名或全限定 `Class::method`。不需要预先建立索引，也不把搜索命中误写成完整引用关系。
    65	
    66	## ① 上下文层
    67	
    68	### Wrapper
    69	
    70	```bash
    71	# 只选择 feature、校验分支并同步 AGENTS.md，不启动 Codex
    72	./.codex/bin/codex-feature --dry-run
    73	
    74	# 真实工作入口：同步完成后启动 Codex
    75	./.codex/bin/codex-feature
    76	```
    77	
    78	Wrapper 的正确性边界很重要：**AGENTS.md 每次运行只加载一次**，所以会话中改软链不等于当前运行已重载指令链。必须先由 wrapper 选定链接，再开始新运行；漂移 hook 的职责是停止继续工作并提示重启，不是在同一运行里热换上下文。
    79	
    80	Codex 默认把 Git 根当作 project root；找不到 project root 时只检查当前目录。因此对 **非 Git 的 AOSP 树根**，要从树根开始运行。本 demo 的 wrapper 会 `cd` 到树根，也为 project hook 的相对命令提供稳定起点。
    81	
    82	### Hooks 演示与信任
    83	
    84	```bash
    85	session_payload='{"session_id":"manual-demo","cwd":".","hook_event_name":"SessionStart"}'
    86	prompt_payload='{"session_id":"manual-demo","cwd":".","hook_event_name":"UserPromptSubmit"}'
    87	printf '%s\n' "$session_payload" | ./.codex/hooks/session-start.sh
    88	printf '%s\n' "$prompt_payload" | ./.codex/hooks/check-branch-drift.sh
    89	```
    90	
    91	项目级 hooks 只在 **受信任项目** 中加载。在 CLI 中使用 `/hooks` 查看来源、审查并信任精确的 hook 定义；定义改变后应重新审查。这些 hook 的相对命令依赖 wrapper 固定的工作目录。本方案不假设 hook 一定先于 `AGENTS.md` 发现执行。
    92	
    93	`repos.tsv` 是 feature 涉及仓的单一事实源：
    94	
    95	```bash
    96	./features/dev-sidebar/check-branch.sh --demo
    97	```
    98	
    99	`--demo` 故意返回一个分支漂移失败，便于检查调用方是否正确处理非零退出。
   100	
   101	## ② 流程层
   102	
   103	```bash
   104	./.codex/bin/check-process-layer
   105	```
   106	
   107	Skills 位于 `.agents/skills`。Codex 对 skills 使用 **渐进式披露**：初始上下文只放名称、`description` 和文件路径，选中后再读取完整 `SKILL.md`。
   108	
   109	- 显式选择：在提示中写 `$build-services-jar` 或通过 `/skills` 选择。
   110	- 隐式选择：任务与 skill 的 `description` 匹配时，Codex 可选择它。
   111	- 当前公开契约中 **没有已文档化的 `paths` 路径触发契约**；不要把“修改某路径”宣称为必然选中某个 skill。这个 demo 由 feature `AGENTS.md` 显式路由必须使用的 skill。
   112	
   113	## ③ 验证闭环层
   114	
   115	```bash
   116	# 离线确定性验证
   117	./features/dev-sidebar/verify-sidebar.sh --demo
   118	
   119	# 只有探索阶段才显式容忍 SKIP
   120	./features/dev-sidebar/verify-sidebar.sh --demo --allow-skip
   121	```
   122	
   123	最终状态语义是：
   124	
   125	- `RESULT PASS`：所有严格断言通过，退出 0。
   126	- `RESULT FAIL`：至少一项失败，非零退出。
   127	- `RESULT INCOMPLETE`：无 FAIL 但存在 SKIP，默认仍非零退出。
   128	- `--allow-skip` **仅用于探索**，不得作为交付或收工证据。
   129	
   130	## 适配到真实 AOSP
   131	
   132	1. 把 `features/` 建成 **manifest 之外的独立 Git 仓**，由它管理 feature 上下文、涉及仓清单和验证脚本，不污染 AOSP manifest、Gerrit 或 Soong 输入。
   133	2. 在 AOSP 树根建立树根 `AGENTS.md` 软链，并把 `.codex/` 与 `.agents/` 暴露在同一树根；日常工作始终经过 wrapper。
   134	3. 保留 `repos.tsv` 和涉及仓 checker，在开始任务前 fail closed 检查缺仓、分支漂移、detached HEAD 和非法仓库。
   135	4. 真实设备操作前必须显式固定 `ANDROID_SERIAL`，先校验 `adb -s "$ANDROID_SERIAL" get-state`；操作 Cuttlefish 前先用 `cvd fleet` 确认目标，再固定 `CVD_GROUP`，禁止对未选定组执行 stop/start。
   136	5. 把 `verify-sidebar.sh` 的 demo 数据源换成真实设备查询，保留查询失败即 FAIL、crash 时间基线、严格 SKIP 和只有 `RESULT PASS` 才能收工的语义。
   137	
   138	## 继续阅读
   139	
   140	- 长文：[AOSP 整机源码 Codex Harness 工程探索](AOSP整机源码Codex-Harness工程探索.md)
   141	- [`AGENTS.md` 自定义指令](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
   142	- [Build skills](https://learn.chatgpt.com/docs/build-skills)
   143	- [Hooks](https://learn.chatgpt.com/docs/hooks)
   144	- [Advanced configuration](https://learn.chatgpt.com/docs/config-file/config-advanced)
   145	- [Subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)
   146	- [Developer commands](https://learn.chatgpt.com/docs/developer-commands)
     1	# AOSP 整机源码 Harness —— 可运行 Demo
     2	
     3	这是《AOSP 整机源码 Harness 工程探索》一文方案的可运行最小复刻。它演示「上下文 / 流程 / 验证闭环」三层如何协作，无需真实 AOSP 树。
     4	
     5	> ⚠️ 这是**教学 Demo**，不是真实 AOSP 树。为了让目录语义也可验证，Demo 同样把公共 Harness 放在 `features/.harness/`，树根 `.claude` 只是安装器创建的软链；真实部署时再把 `features/` 本身初始化为独立 Git 仓。
     6	>
     7	> **① 上下文层使用「安装时暴露 Harness + 启动前同步 feature 单文件」**：先安装 `.claude -> features/.harness`；随后 `.claude/bin/claude-feature` 在 Claude 进程启动前把根 `CLAUDE.md` 指向当前 feature。SessionStart 只做幂等检查和告警，因为 hook 内改软链不能作为同一次启动已重载 memory 的保证。
     8	
     9	## 一眼看懂：目录 = 三层
    10	
    11	```
    12	claude-code/                              # ← 真实环境里这是 <AOSP_ROOT>（repo 工程根，非 git 仓）
    13	├── README.md                             # 你在读的这份
    14	├── run-demo.sh                           # ★ 一键演示三层如何协同（先跑这个）
    15	├── CURRENT_FEATURE                       # 模拟"锚定仓当前分支名"（真实环境读 repo 分支）
    16	│
    17	├── CLAUDE.md                             # ① 上下文：软链 → features/dev-sidebar/CLAUDE.md（feature 单文件）
    18	│
    19	├── frameworks/base/PLACEHOLDER.java      # 占位仓：feature 在此仓改代码；约定写在 feature 单文件的『### frameworks/base』节
    20	├── frameworks/native/PLACEHOLDER.cpp     # 占位仓：同上（『### frameworks/native』节）
    21	│                                         #   各仓根不物化 harness 文件
    22	├── .claude -> features/.harness          # 公共 Harness 的标准逻辑入口
    23	│   ├── bin/
    24	│   │   ├── claude-feature                # ① 推荐启动入口：先同步上下文再启动 Claude
    25	│   │   └── check-process-layer           # ② 离线自检流程 skill 工件与关键命令
    26	│   ├── settings.json                     # ① hooks 注册
    27	│   ├── hooks/
    28	│   │   ├── feature-common.sh             # ① 分支探测与软链同步公共函数
    29	│   │   ├── load-feature.sh               # ① SessionStart fallback：检查/告警
    30	│   │   └── check-branch-drift.sh         # ① UserPromptSubmit：会话中途切分支告警
    31	│   ├── skills/
    32	│   │   ├── build-services-jar/SKILL.md   # ② 流程：改 services 代码时激活
    33	│   │   └── build-sepolicy/SKILL.md       # ② 流程：改 sepolicy 时激活
    34	│   └── tests/                            # 公共 Harness 自身回归测试
    35	│
    36	└── features/                             # ① 真实环境是独立 Git 仓（不在 manifest，Gerrit/Soong 全不可见）
    37	    ├── install-harness.sh                # 安全安装根 .claude 软链；幂等且拒绝覆盖
    38	    ├── .harness/                         # 公共 wrapper/hooks/skills/settings 的物理事实源
    39	    └── dev-sidebar/                      # 目录名 = repo 分支名 = feature 名
    40	        ├── CLAUDE.md                     # ① 该 feature 的【单文件全部上下文】：树级 + 总览 + 各仓约定
    41	        ├── repos.tsv                     # ① 涉及仓单一事实源（check-branch.sh 消费）
    42	        ├── check-branch.sh               # ① 涉及仓分支一致性检查
    43	        └── verify-sidebar.sh             # ③ 确定性验证脚本（带 --demo）
    44	```
    45	
    46	## 怎么跑
    47	
    48	```bash
    49	cd aosp-harness-demo/claude-code
    50	./features/install-harness.sh
    51	./run-demo.sh
    52	```
    53	
    54	`run-demo.sh` 会依次演示：
    55	
    56	1. **① 上下文**：安装器先确认 `.claude -> features/.harness`，`.claude/bin/claude-feature --dry-run` 再于 Claude 启动前同步 feature 软链；随后 SessionStart 只确认状态。
    57	2. **① 漂移检测**：会话中切 feature 后持续告警，直到通过 wrapper 建立新会话。
    58	3. **② 流程**：`.claude/bin/check-process-layer` 离线检查两个示例 skill 的结构、编译目标、产物和验证入口。它不启动 Claude，也不冒充自动触发测试。
    59	4. **③ 验证**：默认任何 SKIP 都返回 `RESULT INCOMPLETE`；探索期必须显式 `--allow-skip`。crash 检查默认从设备启动时间（`/proc/stat` 的 `btime`）开始，也可用 `--since <epoch-seconds>` 指定部署基线；ADB 查询失败直接记为 FAIL。
    60	5. **回归测试**：`.claude/tests/test-harness.sh` 验证 installer、wrapper、流程层工件、严格 SKIP、crash 时间基线/查询失败、`repos.tsv` 分支检查，以及真实 `CLAUDE.md` 迁移失败时的备份与回滚。
    61	
    62	单独跑各层：
    63	
    64	```bash
    65	rg 'SidebarService|SidebarFlinger' .                # 导航基线：rg + 源码阅读，无索引
    66	./features/install-harness.sh                       # ① 暴露公共 Harness（幂等）
    67	./.claude/bin/claude-feature --dry-run              # ① 启动前同步 feature 上下文
    68	./.claude/bin/check-process-layer                   # ② 流程 skill 离线自检
    69	./features/dev-sidebar/verify-sidebar.sh --demo     # ③ 严格验证
    70	./features/dev-sidebar/verify-sidebar.sh --demo --allow-skip  # 探索模式
    71	./features/dev-sidebar/verify-sidebar.sh --since 1753000000    # 真实设备：显式部署基线
    72	```
    73	
    74	## 三层与文中章节对应
    75	
    76	| 层 | Demo 落地物 | 文中章节 |
    77	|---|---|---|
    78	| ① 上下文 | `features/install-harness.sh` + `.claude/bin/claude-feature` + `CLAUDE.md` 软链 + hooks | 第五节 |
    79	| ② 流程 | `features/.harness/skills/build-*/SKILL.md`（经 `.claude` 暴露，`paths` glob 激活） | 第六节 |
    80	| ③ 验证闭环 | `features/dev-sidebar/verify-sidebar.sh` | 第七节 |
    81	
    82	> **导航不单独成层**：本方案不配任何 LSP，导航一律 `rg` + 源码阅读。理由见文中第四节末「不采纳一：LSP」与第九节——clangd 单次查询确实快，但整机树规模下后台索引建不完，`findReferences` 会给出**不完整却不自知**的答案，比 `rg` 吵闹但完整的结果更危险。
    83	
    84	## 从 Demo 到真实工程要改什么
    85	
    86	- 导航直接用 `rg` 开工，不需要任何索引准备。整机树上同名符号成海，习惯是**先用路径收窄范围，再用高信息量锚点**（JNI 注册名如 `android_view_*`、C++ 的 `Class::method` 全限定名）代替泛词，避免几百条命中灌爆上下文。
    87	- Demo 已采用与真实工程相同的物理布局：公共层在 `features/.harness/`，首次克隆后从树根运行 `./features/install-harness.sh`，得到 `.claude -> features/.harness`。安装器不会覆盖已有真实目录或指向别处的软链。
    88	- 日常用 `.claude/bin/claude-feature` 启动。它会先同步根软链并在真实 repo 树运行 `check-branch.sh`，分支缺失或漂移时 fail closed。SessionStart hook 只是兜底。
    89	- `features/` 初始化成独立 Git 仓（`git init`），同时版本化 `features/.harness/` 与 `features/<分支>/`，可推私有 remote 跨机同步；它不进 manifest，故 Gerrit/Soong 全不可见。根 `.claude` 与 `CLAUDE.md` 都只是暴露入口，编辑会直达 `features/` 仓中的真实文件。
    90	- `verify-sidebar.sh` 去掉 `--demo` 后走真实 `adb` 断言。crash 窗口默认始于设备本次启动的 `btime`；若要只覆盖本次部署，用 `--since <epoch-seconds>` 传入部署前记录的设备 epoch。crash buffer 查询失败必须判 FAIL，不能当成“无崩溃”。默认 SKIP 不算成功；只有探索阶段才使用 `--allow-skip`。
    91	
    92	Demo 的 `.claude/tests/test-link-migration-safety.sh`（物理源在 `features/.harness/tests/`）专门覆盖根 `CLAUDE.md` 从真实文件迁移为软链时的失败路径：备份失败不得删除原文件，建链失败必须尝试从备份回滚，正常迁移则保留备份供人工恢复。
    93	
    94	公共物理目录刻意命名为 `.harness`：若叫 `features/.claude`，Claude Code 会把它与树根 `.claude` 当成两个 skills root，造成 skill 重复注册；前导点又保证它不可能与合法 feature 分支名撞名。
    95	
    96	## 子代理原则
    97	
    98	只读 Explore/Plan 不注入整份 feature CLAUDE.md。派发 prompt 只提供：目标、允许搜索的路径、会改变结论的关键事实、只读约束、期望输出。只有修改、构建或部署代理才携带相关硬约束。Claude Code 内建 Explore/Plan 会跳过 CLAUDE.md，因此范围和关键事实必须显式写进任务卡。
```

stderr：空。exit code：`0`。

### 完整重放 4

```bash
nl -ba common/.harness/common.md && nl -ba common/.harness/features/dev-sidebar/repos.tsv && nl -ba common/.harness/features/dev-sidebar/workflow.md && nl -ba common/.harness/bin/resolve-feature.sh
```

stdout：

```text
     1	# Shared Harness public facts
     2	
     3	This file belongs to the .harness public layer. Claude Code and Codex adapters
     4	read the same facts from here; client-specific startup, hook, and skill rules
     5	stay in their own directories.
     6	
     7	## Active feature
     8	
     9	- active feature: read CURRENT_FEATURE at startup
    10	- target branch: the active feature name for every repository in this demo
    11	- repository manifest: .harness/features/<feature>/repos.tsv
    12	- build/deploy facts: .harness/features/<feature>/workflow.md
    13	- verification entry point: the single executable verify-*.sh in the feature directory
    14	- delivery evidence: only RESULT PASS
    15	
    16	## Manifest schema
    17	
    18	repos.tsv uses four tab-separated columns:
    19	
    20	    path<TAB>convention<TAB>tags<TAB>description
    21	
    22	It is the single source of truth for both clients. Do not copy it under
    23	.claude/ or .codex/. Adapters may render a runtime summary, but they do not
    24	own another copy.
    25	
    26	## Synchronization rules
    27	
    28	1. Change public facts in .harness first.
    29	2. Keep shared build/deploy facts in the feature workflow.md. In this demo,
    30	   target_branch equals CURRENT_FEATURE for every listed repository.
    31	3. Run both .claude/bin/claude-feature --dry-run --contract and
    32	   .codex/bin/codex-feature --dry-run --contract.
    33	4. Run .harness/bin/check-parity.sh and require PARITY PASS. In a real repo
    34	   tree, wrappers also require .harness/bin/check-branches.sh to pass.
    35	5. Only one client may write the same feature at a time. End the current
    36	   session and save or commit changes before starting the other client.
    37	6. A wrapper chooses context before a new run. The demo SessionStart hook only
    38	   checks startup parity; real projects should retain client-specific prompt
    39	   hooks that compare the session snapshot with contract_sha256.
    40	7. Finish with the shared verifier. RESULT INCOMPLETE, RESULT FAIL, and
    41	   RESULT EXPLORATION are not delivery evidence.
     1	# path	convention	tags	description
     2	frameworks/base	source	java,system-server	系统服务与 SystemServer 代码
     3	frameworks/native	source	cpp,binder	Native Binder 与 JNI 代码
     4	packages/apps/SidebarApp	source	app	sidebar 应用与资源
     5	build/make	build	soong,make	构建入口与产品配置
     6	system/sepolicy	policy	selinux,service_contexts	服务上下文与 SELinux 策略
     1	# dev-sidebar shared workflow
     2	
     3	These are public build and deployment facts shared by both clients.
     4	
     5	## Build
     6	
     7	    source build/envsetup.sh
     8	    lunch <product>-userdebug
     9	    m services SidebarApp selinux_policy
    10	
    11	## Deploy
    12	
    13	1. Record a deployment time baseline.
    14	2. Set and validate an explicit ANDROID_SERIAL.
    15	3. Push only the artifacts built for the selected product.
    16	4. Restart the affected process or device only after confirming the target.
    17	
    18	## Verify
    19	
    20	Run the feature verifier. Only its strict RESULT PASS is delivery evidence.
     1	#!/usr/bin/env bash
     2	set -euo pipefail
     3	
     4	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
     5	DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
     6	ROOT="${HARNESS_ROOT:-$DEFAULT_ROOT}"
     7	CLIENT=''
     8	
     9	usage() {
    10	  printf '%s\n' 'Usage: resolve-feature.sh --client claude|codex [--contract]'
    11	}
    12	
    13	while (($# > 0)); do
    14	  case "$1" in
    15	    --client)
    16	      (($# >= 2)) || { usage >&2; exit 2; }
    17	      CLIENT="$2"
    18	      shift 2
    19	      ;;
    20	    --contract)
    21	      shift
    22	      ;;
    23	    --help)
    24	      usage
    25	      exit 0
    26	      ;;
    27	    *)
    28	      usage >&2
    29	      exit 2
    30	      ;;
    31	  esac
    32	done
    33	
    34	case "$CLIENT" in
    35	  claude|codex) ;;
    36	  *)
    37	    echo 'error: client 必须是 claude 或 codex' >&2
    38	    exit 1
    39	    ;;
    40	esac
    41	
    42	current_file="$ROOT/CURRENT_FEATURE"
    43	if [[ ! -f "$current_file" ]]; then
    44	  echo "error: 缺少 $current_file" >&2
    45	  exit 1
    46	fi
    47	
    48	if ! feature="$(python3 - "$current_file" <<'PY'
    49	import pathlib
    50	import re
    51	import sys
    52	
    53	try:
    54	    raw = pathlib.Path(sys.argv[1]).read_bytes()
    55	except OSError:
    56	    raise SystemExit(2)
    57	
    58	if b"\0" in raw:
    59	    raise SystemExit(3)
    60	try:
    61	    text = raw.decode("utf-8")
    62	except UnicodeDecodeError:
    63	    raise SystemExit(3)
    64	
    65	if text.endswith("\n"):
    66	    text = text[:-1]
    67	if text.endswith("\r"):
    68	    text = text[:-1]
    69	if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", text):
    70	    raise SystemExit(3)
    71	sys.stdout.write(text)
    72	PY
    73	)"; then
    74	  echo 'error: INVALID feature；必须是单行 ASCII 名称 [A-Za-z0-9][A-Za-z0-9._-]*' >&2
    75	  exit 1
    76	fi
    77	
    78	feature_rel=".harness/features/$feature"
    79	manifest_rel="$feature_rel/repos.tsv"
    80	workflow_rel="$feature_rel/workflow.md"
    81	manifest="$ROOT/$manifest_rel"
    82	workflow="$ROOT/$workflow_rel"
    83	common="$ROOT/.harness/common.md"
    84	
    85	[[ -f "$manifest" ]] || { echo "error: 缺少 $manifest_rel" >&2; exit 1; }
    86	[[ -f "$workflow" ]] || { echo "error: 缺少 workflow $workflow_rel" >&2; exit 1; }
    87	[[ -f "$common" ]] || { echo 'error: 缺少 .harness/common.md' >&2; exit 1; }
    88	
    89	shopt -s nullglob
    90	verifier_candidates=("$ROOT/$feature_rel"/verify-*.sh)
    91	shopt -u nullglob
    92	if [[ "${#verifier_candidates[@]}" -ne 1 || ! -x "${verifier_candidates[0]:-}" ]]; then
    93	  echo "error: $feature_rel 必须恰好有一个可执行 verifier（verify-*.sh）" >&2
    94	  exit 1
    95	fi
    96	verifier="${verifier_candidates[0]}"
    97	verifier_rel="$feature_rel/$(basename "$verifier")"
    98	
    99	if ! repo_paths="$(python3 - "$manifest" "$manifest_rel" <<'PY'
   100	import pathlib
   101	import re
   102	import sys
   103	
   104	manifest = pathlib.Path(sys.argv[1])
   105	label = sys.argv[2]
   106	try:
   107	    raw = manifest.read_bytes()
   108	except OSError:
   109	    raise SystemExit(2)
   110	if b"\0" in raw:
   111	    print(f"error: {label} contains NUL bytes", file=sys.stderr)
   112	    raise SystemExit(1)
   113	try:
   114	    lines = raw.decode("utf-8").splitlines()
   115	except UnicodeDecodeError:
   116	    print(f"error: {label} is not UTF-8", file=sys.stderr)
   117	    raise SystemExit(1)
   118	
   119	paths = []
   120	safe_path = re.compile(r"[A-Za-z0-9._+-]+(?:/[A-Za-z0-9._+-]+)*")
   121	for line_number, line in enumerate(lines, start=1):
   122	    if not line or line.startswith("#"):
   123	        continue
   124	    fields = line.split("\t")
   125	    if len(fields) != 4 or any(field == "" for field in fields):
   126	        print(
   127	            f"error: {label}:{line_number} four nonempty tab-separated fields required",
   128	            file=sys.stderr,
   129	        )
   130	        raise SystemExit(1)
   131	    path = fields[0]
   132	    if safe_path.fullmatch(path) is None or any(
   133	        part in (".", "..") for part in path.split("/")
   134	    ):
   135	        print(
   136	            f"error: {label}:{line_number} unsafe repository path '{path}'",
   137	            file=sys.stderr,
   138	        )
   139	        raise SystemExit(1)
   140	    paths.append(path)
   141	
   142	if not paths:
   143	    print(f"error: {label} has no repositories", file=sys.stderr)
   144	    raise SystemExit(1)
   145	sys.stdout.write(",".join(paths))
   146	PY
   147	)"; then
   148	  exit 1
   149	fi
   150	
   151	hash_files=("$ROOT/CURRENT_FEATURE" "$common" "$manifest" "$workflow" "$verifier")
   152	if command -v sha256sum >/dev/null 2>&1; then
   153	  contract_sha256="$(cat "${hash_files[@]}" | sha256sum | awk '{print $1}')"
   154	else
   155	  contract_sha256="$(cat "${hash_files[@]}" | shasum -a 256 | awk '{print $1}')"
   156	fi
   157	
   158	printf 'client=%s\n' "$CLIENT"
   159	printf 'feature=%s\n' "$feature"
   160	printf 'target_branch=%s\n' "$feature"
   161	printf 'manifest=%s\n' "$manifest_rel"
   162	printf 'workflow=%s\n' "$workflow_rel"
   163	printf 'verifier=%s\n' "$verifier_rel"
   164	printf 'repositories=%s\n' "$repo_paths"
   165	printf 'contract_sha256=%s\n' "$contract_sha256"
```

stderr：空。exit code：`0`。

### 完整重放 5

```bash
nl -ba common/.codex/bin/codex-feature && nl -ba common/.claude/bin/claude-feature && nl -ba common/.harness/bin/check-branches.sh
```

stdout：

```text
     1	#!/usr/bin/env bash
     2	set -euo pipefail
     3	
     4	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
     5	DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
     6	ROOT="${HARNESS_ROOT:-$DEFAULT_ROOT}"
     7	dry_run=0
     8	contract_only=0
     9	
    10	args=()
    11	while (($# > 0)); do
    12	  case "$1" in
    13	    --dry-run)
    14	      dry_run=1
    15	      shift
    16	      ;;
    17	    --contract)
    18	      contract_only=1
    19	      shift
    20	      ;;
    21	    *)
    22	      args+=("$1")
    23	      shift
    24	      ;;
    25	  esac
    26	done
    27	
    28	contract="$(HARNESS_ROOT="$ROOT" \
    29	  "$ROOT/.harness/bin/resolve-feature.sh" --client codex --contract)"
    30	if [[ -d "$ROOT/.repo" ]]; then
    31	  branch_output=''
    32	  if ! branch_output="$(HARNESS_ROOT="$ROOT" \
    33	    "$ROOT/.harness/bin/check-branches.sh")"; then
    34	    printf '%s\n' "$branch_output" >&2
    35	    exit 1
    36	  fi
    37	  if ((contract_only == 0)); then
    38	    printf '%s\n' "$branch_output"
    39	  fi
    40	fi
    41	printf '%s\n' "$contract"
    42	
    43	if ((dry_run)); then
    44	  exit 0
    45	fi
    46	
    47	cd "$ROOT"
    48	exec codex "${args[@]}"
     1	#!/usr/bin/env bash
     2	set -euo pipefail
     3	
     4	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
     5	DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
     6	ROOT="${HARNESS_ROOT:-$DEFAULT_ROOT}"
     7	dry_run=0
     8	contract_only=0
     9	
    10	args=()
    11	while (($# > 0)); do
    12	  case "$1" in
    13	    --dry-run)
    14	      dry_run=1
    15	      shift
    16	      ;;
    17	    --contract)
    18	      contract_only=1
    19	      shift
    20	      ;;
    21	    *)
    22	      args+=("$1")
    23	      shift
    24	      ;;
    25	  esac
    26	done
    27	
    28	contract="$(HARNESS_ROOT="$ROOT" \
    29	  "$ROOT/.harness/bin/resolve-feature.sh" --client claude --contract)"
    30	if [[ -d "$ROOT/.repo" ]]; then
    31	  branch_output=''
    32	  if ! branch_output="$(HARNESS_ROOT="$ROOT" \
    33	    "$ROOT/.harness/bin/check-branches.sh")"; then
    34	    printf '%s\n' "$branch_output" >&2
    35	    exit 1
    36	  fi
    37	  if ((contract_only == 0)); then
    38	    printf '%s\n' "$branch_output"
    39	  fi
    40	fi
    41	printf '%s\n' "$contract"
    42	
    43	if ((dry_run)); then
    44	  exit 0
    45	fi
    46	
    47	cd "$ROOT"
    48	exec claude "${args[@]}"
     1	#!/usr/bin/env bash
     2	set -euo pipefail
     3	
     4	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
     5	ROOT="${HARNESS_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
     6	
     7	contract="$(HARNESS_ROOT="$ROOT" \
     8	  "$ROOT/.harness/bin/resolve-feature.sh" --client claude --contract)"
     9	target_branch="$(awk -F= '$1 == "target_branch" { print substr($0, index($0, "=") + 1) }' \
    10	  <<<"$contract")"
    11	repositories="$(awk -F= '$1 == "repositories" { print substr($0, index($0, "=") + 1) }' \
    12	  <<<"$contract")"
    13	
    14	[[ -n "$target_branch" && -n "$repositories" ]] || {
    15	  echo 'error: public contract is missing target_branch or repositories' >&2
    16	  exit 1
    17	}
    18	
    19	IFS=',' read -r -a repo_list <<<"$repositories"
    20	bad=0
    21	for repo in "${repo_list[@]}"; do
    22	  repo_root="$ROOT/$repo"
    23	  if [[ ! -e "$repo_root/.git" && ! -L "$repo_root/.git" ]]; then
    24	    echo "MISSING $repo"
    25	    bad=1
    26	    continue
    27	  fi
    28	  if ! git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
    29	    echo "INVALID $repo"
    30	    bad=1
    31	    continue
    32	  fi
    33	  if branch="$(git -C "$repo_root" symbolic-ref --quiet --short HEAD 2>/dev/null)"; then
    34	    :
    35	  elif git -C "$repo_root" rev-parse --verify 'HEAD^{object}' >/dev/null 2>&1; then
    36	    branch='DETACHED'
    37	  else
    38	    echo "INVALID $repo"
    39	    bad=1
    40	    continue
    41	  fi
    42	  if [[ "$branch" == "$target_branch" ]]; then
    43	    echo "OK      $repo @ $branch"
    44	  else
    45	    echo "DRIFT   $repo @ $branch (expected $target_branch)"
    46	    bad=1
    47	  fi
    48	done
    49	
    50	exit "$bad"
```

stderr：空。exit code：`0`。

### 完整重放 6

```bash
nl -ba codex/features/dev-sidebar/AGENTS.md && nl -ba codex/features/dev-sidebar/repos.tsv && nl -ba codex/.agents/skills/build-services-jar/SKILL.md && nl -ba codex/.agents/skills/build-sepolicy/SKILL.md && nl -ba codex/.codex/bin/check-process-layer
```

stdout：

```text
     1	<!-- 本文件是 dev-sidebar 的完整 feature 上下文。树根 AGENTS.md 由
     2	     .codex/bin/codex-feature 在 Codex 启动前切换为指向本文件的相对软链。 -->
     3	
     4	# AOSP 树与 dev-sidebar feature 上下文
     5	
     6	## 树级构建约束
     7	
     8	- `envsetup.sh` 必须在 bash 中 `source`，不要依赖调用者的默认 shell；`source` 后不要直接接管道，避免函数落入子 shell。
     9	- 长时间构建必须在后台执行并把输出写入日志；轮询日志，只有出现 `build completed successfully` 成功标记才算构建完成。
    10	- 不得手工编辑 `out/` 下的生成物，所有产物都必须由构建系统生成。
    11	- 修改 public/System API 后必须运行 `m update-api`，否则 checkapi 会阻断构建。
    12	- 新增系统服务必须同时补齐 `system/sepolicy` 中的 service context、类型和 allow 规则。
    13	- push `framework.jar` 或 `services.jar` 后要评估 ART 缓存风险；校验不一致时，旧 dexpreopt/boot image 或 `/data/dalvik-cache/` 可能导致启动缓慢或失败。
    14	
    15	## 源码导航
    16	
    17	- 使用 `rg` 配合源码阅读定位模块、符号和调用链。
    18	- 先按仓库和路径缩小范围，再搜索 JNI 注册名、全限定 `Class::method` 等高信息量锚点，避免用 `onTransact` 一类泛词扫全树。
    19	- 这里没有建立完整索引，也不得把搜索结果描述成索引结论；影响面判断必须给出源码路径、关键符号和仍未确认的边界。
    20	
    21	## 子代理任务卡
    22	
    23	派发子代理时只提供完成局部任务所需的任务卡，不广播整份 feature 上下文。任务卡必须包含：
    24	
    25	- 目标：要交付或回答的具体问题；
    26	- 路径：允许读取或修改的仓库和目录；
    27	- 事实：会改变结论的版本、ABI、JNI 或生成代码信息；
    28	- 约束：禁止目录、只读要求、构建和部署限制；
    29	- 证据：期望返回的源码位置、命令结果、验证结论和未确认项。
    30	
    31	## feature: dev-sidebar
    32	
    33	目标是在 AOSP 17 中新增系统服务、native 合成侧和常驻边栏应用。
    34	
    35	允许修改的仓库只有：`frameworks/base`、`frameworks/native`、`packages/apps/SidebarApp`、`build/make`、`system/sepolicy`。机器可读清单位于 `features/dev-sidebar/repos.tsv`；开始工作前用 `./features/dev-sidebar/check-branch.sh` 检查所有涉及仓是否位于 `dev-sidebar` 分支。
    36	
    37	### 必须遵循的流程路由
    38	
    39	- 修改 `frameworks/base/services/**` 前必须使用 `$build-services-jar`。
    40	- 修改 `system/sepolicy/**` 前必须使用 `$build-sepolicy`。
    41	- 收工前必须运行 `./features/dev-sidebar/verify-sidebar.sh`；只有 `RESULT PASS` 可以作为完成证据。
    42	
    43	### frameworks/base
    44	
    45	新增 `SidebarService` 和 `ISidebar.aidl`，并在 `SystemServer` 注册 `sidebar` 服务。AIDL 进入 public/System API 时必须运行 `m update-api`；服务实现和 `SystemServer` 变更遵循 `$build-services-jar`。
    46	
    47	### frameworks/native
    48	
    49	新增 SidebarFlinger native 合成实现并接入合成服务启动链。使用唯一类名、全限定 C++ 方法和注册点导航；若触及缩放态触摸坐标映射，先明确 input 链路影响面。
    50	
    51	### packages/apps/SidebarApp
    52	
    53	常驻边栏应用通过 `ISidebar` 与系统服务通信。修改前确认平台签名、privapp 权限、产品安装位置及应用进程存活策略。
    54	
    55	### build/make
    56	
    57	仅接入 dev-sidebar 所需模块和产品配置。不要直接修改 `out/` 里的产品文件来模拟构建结果。
    58	
    59	### system/sepolicy
    60	
    61	为 `sidebar` 服务补齐 `service_contexts`、service type、域访问与必要 allow 规则。策略修改遵循 `$build-sepolicy`，验证时检查新的 AVC denial。
     1	# repository	feature	description
     2	frameworks/base	dev-sidebar	SidebarService、SystemServer 注册和 public/System API
     3	frameworks/native	dev-sidebar	SidebarFlinger native 合成实现
     4	packages/apps/SidebarApp	dev-sidebar	常驻边栏应用
     5	build/make	dev-sidebar	产品配置和模块接入
     6	system/sepolicy	dev-sidebar	新系统服务的 SELinux 策略
     1	---
     2	name: build-services-jar
     3	description: Build and deploy AOSP services.jar after changes under frameworks/base/services, including SystemServer services; use for compile targets, artifacts, push steps, ART cache risks, and feature verification.
     4	---
     5	
     6	# Build services.jar
     7	
     8	Select this repository skill explicitly as `$build-services-jar` when an `AGENTS.md` route requires it. Codex may also select it implicitly when the frontmatter description matches the task. File paths alone do not select skills.
     9	
    10	## Build in one retained session
    11	
    12	Submit this entire block as one shell invocation. Codex must keep polling the same exec session until it exits; starting the build in one session and waiting in another loses the child status.
    13	
    14	```bash
    15	bash -c '
    16	set -u
    17	build_log="$(mktemp "${TMPDIR:-/tmp}/build-services.XXXXXX.log")"
    18	artifact="out/target/product/vsoc_x86_64/system/framework/services.jar"
    19	printf "build log: %s\n" "$build_log"
    20	(
    21	  source build/envsetup.sh >/dev/null 2>&1 &&
    22	  lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 &&
    23	  m services
    24	) >"$build_log" 2>&1 &
    25	build_pid=$!
    26	while kill -0 "$build_pid" 2>/dev/null; do
    27	  tail -n 20 "$build_log"
    28	  sleep 10
    29	done
    30	wait "$build_pid"
    31	build_rc=$?
    32	if [[ "$build_rc" -ne 0 ]]; then
    33	  tail -n 200 "$build_log" >&2
    34	  exit "$build_rc"
    35	fi
    36	grep -Fq "#### build completed successfully ####" "$build_log" || exit 1
    37	[[ -f "$artifact" ]] || exit 1
    38	printf "artifact: %s\n" "$artifact"
    39	'
    40	```
    41	
    42	Build success requires the child exit status, the explicit `#### build completed successfully ####` marker, and the artifact `out/target/product/vsoc_x86_64/system/framework/services.jar`.
    43	
    44	## Pin and deploy to one device
    45	
    46	Set `ANDROID_SERIAL` only after explicitly confirming the target device. Every ADB command must retain the same serial because root, remount, push, and reboot change device state.
    47	
    48	```bash
    49	device_serial="${ANDROID_SERIAL:?Set ANDROID_SERIAL to the explicitly confirmed target serial}"
    50	adb -s "$device_serial" get-state
    51	adb -s "$device_serial" root
    52	adb -s "$device_serial" remount
    53	adb -s "$device_serial" push \
    54	  out/target/product/vsoc_x86_64/system/framework/services.jar \
    55	  /system/framework/services.jar
    56	adb -s "$device_serial" reboot
    57	```
    58	
    59	A pushed jar can disagree with ART, dexpreopt, or boot-image caches. If recovery through `/data/dalvik-cache/` is not appropriate, rebuild and deploy a full image from a fresh AOSP environment:
    60	
    61	```bash
    62	bash -c '
    63	set -u
    64	full_build_log="$(mktemp "${TMPDIR:-/tmp}/build-full-services.XXXXXX.log")"
    65	image_artifact="out/target/product/vsoc_x86_64/system.img"
    66	printf "full build log: %s\n" "$full_build_log"
    67	(
    68	  source build/envsetup.sh >/dev/null 2>&1 &&
    69	  lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 &&
    70	  m
    71	) >"$full_build_log" 2>&1 &
    72	full_build_pid=$!
    73	while kill -0 "$full_build_pid" 2>/dev/null; do
    74	  tail -n 20 "$full_build_log"
    75	  sleep 10
    76	done
    77	wait "$full_build_pid"
    78	full_build_rc=$?
    79	if [[ "$full_build_rc" -ne 0 ]]; then
    80	  tail -n 200 "$full_build_log" >&2
    81	  exit "$full_build_rc"
    82	fi
    83	grep -Fq "#### build completed successfully ####" "$full_build_log" || exit 1
    84	[[ -f "$image_artifact" ]] || exit 1
    85	'
    86	cvd fleet
    87	cvd_group="${CVD_GROUP:?Set CVD_GROUP to the explicitly confirmed group from cvd fleet}"
    88	cvd --group_name="$cvd_group" stop
    89	cvd --group_name="$cvd_group" start
    90	```
    91	
    92	The group selector placement above is the local Cuttlefish `cvd [selectors] command` form. Never infer a group when multiple devices may exist.
    93	
    94	## Check dependencies and behavior
    95	
    96	- Run `m update-api` when a change affects a public or System API.
    97	- Update and build SELinux policy when the service registration or access contract requires it; a jar-only change cannot satisfy that dependency.
    98	- Treat build success as compilation evidence, not correctness evidence. Run the applicable `features/<feature>/verify-*.sh` scripts and accept completion only when the final result is `RESULT PASS`.
     1	---
     2	name: build-sepolicy
     3	description: Build and verify AOSP SELinux policy after changes under system/sepolicy, especially new system services requiring service_contexts, service types, allow rules, denial checks, and full feature verification.
     4	---
     5	
     6	# Build SELinux policy
     7	
     8	Select this repository skill explicitly as `$build-sepolicy` when an `AGENTS.md` route requires it. Codex may also select it implicitly when the frontmatter description matches the task. File paths alone do not select skills.
     9	
    10	## Define a system service
    11	
    12	Map the service name in `system/sepolicy/private/service_contexts` or the appropriate product or vendor file:
    13	
    14	```text
    15	sidebar    u:object_r:sidebar_service:s0
    16	```
    17	
    18	Tag a service registered by SystemServer with the canonical attributes, and grant a concrete client only lookup access:
    19	
    20	```te
    21	type sidebar_service, system_server_service, service_manager_type;
    22	allow sidebar_app sidebar_service:service_manager find;
    23	```
    24	
    25	The system_server_service attribute is consumed by add_service(system_server, system_server_service). AOSP's `add_service` macro grants SystemServer `{ add find }` and adds a neverallow guarding registration from other domains, so do not add a raw per-service SystemServer allow.
    26	
    27	## Build in one retained session
    28	
    29	Submit this entire block as one shell invocation. Codex must keep polling the same exec session until it exits; starting the build in one session and waiting in another loses the child status.
    30	
    31	```bash
    32	bash -c '
    33	set -u
    34	build_log="$(mktemp "${TMPDIR:-/tmp}/build-sepolicy.XXXXXX.log")"
    35	artifact="out/target/product/vsoc_x86_64/system/etc/selinux/plat_sepolicy.cil"
    36	printf "build log: %s\n" "$build_log"
    37	(
    38	  source build/envsetup.sh >/dev/null 2>&1 &&
    39	  lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 &&
    40	  m selinux_policy
    41	) >"$build_log" 2>&1 &
    42	build_pid=$!
    43	while kill -0 "$build_pid" 2>/dev/null; do
    44	  tail -n 20 "$build_log"
    45	  sleep 10
    46	done
    47	wait "$build_pid"
    48	build_rc=$?
    49	if [[ "$build_rc" -ne 0 ]]; then
    50	  tail -n 200 "$build_log" >&2
    51	  exit "$build_rc"
    52	fi
    53	grep -Fq "#### build completed successfully ####" "$build_log" || exit 1
    54	[[ -f "$artifact" ]] || exit 1
    55	printf "artifact: %s\n" "$artifact"
    56	'
    57	```
    58	
    59	## Deploy the policy image
    60	
    61	Policy requires a full image, not a services.jar push. Build it from its own initialized shell, inspect the fleet, and explicitly confirm the group before changing its state:
    62	
    63	```bash
    64	bash -c '
    65	set -u
    66	full_build_log="$(mktemp "${TMPDIR:-/tmp}/build-full-sepolicy.XXXXXX.log")"
    67	image_artifact="out/target/product/vsoc_x86_64/system.img"
    68	printf "full build log: %s\n" "$full_build_log"
    69	(
    70	  source build/envsetup.sh >/dev/null 2>&1 &&
    71	  lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 &&
    72	  m
    73	) >"$full_build_log" 2>&1 &
    74	full_build_pid=$!
    75	while kill -0 "$full_build_pid" 2>/dev/null; do
    76	  tail -n 20 "$full_build_log"
    77	  sleep 10
    78	done
    79	wait "$full_build_pid"
    80	full_build_rc=$?
    81	if [[ "$full_build_rc" -ne 0 ]]; then
    82	  tail -n 200 "$full_build_log" >&2
    83	  exit "$full_build_rc"
    84	fi
    85	grep -Fq "#### build completed successfully ####" "$full_build_log" || exit 1
    86	[[ -f "$image_artifact" ]] || exit 1
    87	'
    88	cvd fleet
    89	cvd_group="${CVD_GROUP:?Set CVD_GROUP to the explicitly confirmed group from cvd fleet}"
    90	cvd --group_name="$cvd_group" stop
    91	cvd --group_name="$cvd_group" start
    92	```
    93	
    94	The group selector placement above is the local Cuttlefish `cvd [selectors] command` form.
    95	
    96	## Verify enforcement and behavior
    97	
    98	Set `ANDROID_SERIAL` only after explicitly confirming the target. Pin both the denial query and service registration query to it:
    99	
   100	```bash
   101	device_serial="${ANDROID_SERIAL:?Set ANDROID_SERIAL to the explicitly confirmed target serial}"
   102	adb -s "$device_serial" get-state
   103	adb -s "$device_serial" shell dmesg | grep -F 'avc: denied'
   104	adb -s "$device_serial" shell service list | grep -F sidebar
   105	```
   106	
   107	After boot, inspect denials and service registration. Investigate every new relevant denial rather than assuming an empty or filtered query proves correctness. Run the applicable `features/<feature>/verify-*.sh` scripts and accept completion only when the final result is `RESULT PASS`.
     1	#!/usr/bin/env bash
     2	set -euo pipefail
     3	
     4	SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
     5	ROOT="${HARNESS_ROOT:-$SCRIPT_ROOT}"
     6	
     7	fail() {
     8	  local label="$1"
     9	  local detail="${2:-validation failed}"
    10	
    11	  echo "FAIL  $label: $detail" >&2
    12	  exit 1
    13	}
    14	
    15	require_file() {
    16	  local file="$1"
    17	  local label="$2"
    18	
    19	  [[ -f "$file" ]] || fail "$label" "missing $file"
    20	}
    21	
    22	check_frontmatter() {
    23	  local file="$1"
    24	  local expected_name="$2"
    25	  local expected_description="$3"
    26	  local label="$4"
    27	
    28	  if ! awk -v expected_name="$expected_name" \
    29	      -v expected_description="$expected_description" '
    30	        NR == 1 { valid = ($0 == "---"); next }
    31	        NR == 2 { valid = valid && ($0 == "name: " expected_name); next }
    32	        NR == 3 { valid = valid && ($0 == "description: " expected_description); next }
    33	        NR == 4 { valid = valid && ($0 == "---"); closed = 1; exit }
    34	        END { exit !(valid && closed) }
    35	      ' "$file"; then
    36	    fail "$label frontmatter" "expected only exact name and description metadata"
    37	  fi
    38	}
    39	
    40	require_text() {
    41	  local file="$1"
    42	  local text="$2"
    43	  local label="$3"
    44	
    45	  if ! grep -Fq -- "$text" "$file"; then
    46	    fail "$label" "$file is missing '$text'"
    47	  fi
    48	}
    49	
    50	reject_regex() {
    51	  local file="$1"
    52	  local pattern="$2"
    53	  local label="$3"
    54	
    55	  if grep -Eiq -- "$pattern" "$file"; then
    56	    fail "$label" "$file contains forbidden activation metadata or wording"
    57	  fi
    58	}
    59	
    60	reject_text() {
    61	  local file="$1"
    62	  local text="$2"
    63	  local label="$3"
    64	
    65	  if grep -Fq -- "$text" "$file"; then
    66	    fail "$label" "$file contains forbidden text '$text'"
    67	  fi
    68	}
    69	
    70	check_full_build_section() {
    71	  local file="$1"
    72	  local start_marker="$2"
    73	  local label="$3"
    74	  local section
    75	
    76	  section="$(awk -v marker="$start_marker" '
    77	    index($0, marker) { capture = 1 }
    78	    capture { print }
    79	    capture && index($0, "[[ -f \"$image_artifact\" ]]") { complete = 1; exit }
    80	    END { if (!capture || !complete) exit 1 }
    81	  ' "$file")" || fail "$label full-image section" "unable to extract full-build region"
    82	
    83	  grep -Fq 'source build/envsetup.sh' <<<"$section" || \
    84	    fail "$label full-image envsetup" "full-build region lacks envsetup"
    85	  grep -Fq 'lunch aosp_cf_x86_64_phone-trunk_staging-userdebug' <<<"$section" || \
    86	    fail "$label full-image lunch target" "full-build region lacks lunch target"
    87	  grep -Eq '^[[:space:]]*m[[:space:]]*$' <<<"$section" || \
    88	    fail "$label full-image compile target" "full-build region lacks standalone m"
    89	}
    90	
    91	services="$ROOT/.agents/skills/build-services-jar/SKILL.md"
    92	sepolicy="$ROOT/.agents/skills/build-sepolicy/SKILL.md"
    93	services_description='Build and deploy AOSP services.jar after changes under frameworks/base/services, including SystemServer services; use for compile targets, artifacts, push steps, ART cache risks, and feature verification.'
    94	sepolicy_description='Build and verify AOSP SELinux policy after changes under system/sepolicy, especially new system services requiring service_contexts, service types, allow rules, denial checks, and full feature verification.'
    95	
    96	require_file "$services" 'build-services-jar skill artifact'
    97	check_frontmatter "$services" build-services-jar "$services_description" 'build-services-jar'
    98	reject_regex "$services" '^[[:space:]]*paths:|automatic(ally)?[[:space:]-]+activat|auto-activat|自动激活' 'build-services-jar activation claim'
    99	require_text "$services" '$build-services-jar' 'build-services-jar explicit selection'
   100	require_text "$services" 'AGENTS.md' 'build-services-jar AGENTS routing'
   101	require_text "$services" 'frontmatter description' 'build-services-jar implicit selection'
   102	require_text "$services" 'File paths alone do not select skills.' 'build-services-jar path selection accuracy'
   103	require_text "$services" 'bash -c' 'build-services-jar Bash invocation'
   104	require_text "$services" 'source build/envsetup.sh' 'build-services-jar envsetup command'
   105	require_text "$services" 'lunch aosp_cf_x86_64_phone-trunk_staging-userdebug' 'build-services-jar lunch target'
   106	require_text "$services" 'm services' 'build-services-jar compile target'
   107	require_text "$services" 'same exec session' 'build-services-jar retained exec session'
   108	require_text "$services" 'build_log="$(mktemp "${TMPDIR:-/tmp}/build-services.XXXXXX.log")"' 'build-services-jar unique build log'
   109	require_text "$services" 'while kill -0 "$build_pid" 2>/dev/null; do' 'build-services-jar in-session polling'
   110	require_text "$services" 'wait "$build_pid"' 'build-services-jar retained child wait'
   111	require_text "$services" 'build_rc=$?' 'build-services-jar child exit status'
   112	require_text "$services" '[[ "$build_rc" -ne 0 ]]' 'build-services-jar failed build handling'
   113	require_text "$services" '#### build completed successfully ####' 'build-services-jar success marker'
   114	require_text "$services" 'out/target/product/vsoc_x86_64/system/framework/services.jar' 'build-services-jar artifact path'
   115	require_text "$services" '[[ -f "$artifact" ]]' 'build-services-jar artifact check'
   116	require_text "$services" 'target device' 'build-services-jar ADB target warning'
   117	require_text "$services" 'change device state' 'build-services-jar ADB state warning'
   118	reject_regex "$services" '^[[:space:]]*adb[[:space:]]+(root|remount|push|reboot)' 'build-services-jar bare ADB command'
   119	require_text "$services" 'device_serial="${ANDROID_SERIAL:?Set ANDROID_SERIAL to the explicitly confirmed target serial}"' 'build-services-jar ANDROID_SERIAL pin'
   120	require_text "$services" 'adb -s "$device_serial" get-state' 'build-services-jar pinned get-state'
   121	require_text "$services" 'adb -s "$device_serial" root' 'build-services-jar pinned adb root'
   122	require_text "$services" 'adb -s "$device_serial" remount' 'build-services-jar pinned adb remount'
   123	require_text "$services" 'adb -s "$device_serial" push' 'build-services-jar pinned adb push'
   124	require_text "$services" 'adb -s "$device_serial" reboot' 'build-services-jar pinned adb reboot'
   125	require_text "$services" 'ART' 'build-services-jar ART cache guidance'
   126	require_text "$services" 'dexpreopt' 'build-services-jar dexpreopt guidance'
   127	require_text "$services" '/data/dalvik-cache/' 'build-services-jar dalvik cache recovery'
   128	require_text "$services" 'full_build_log="$(mktemp "${TMPDIR:-/tmp}/build-full-services.XXXXXX.log")"' 'build-services-jar retained full-image build'
   129	require_text "$services" 'full_build_pid=$!' 'build-services-jar full-image background child'
   130	require_text "$services" 'while kill -0 "$full_build_pid" 2>/dev/null; do' 'build-services-jar full-image polling'
   131	require_text "$services" 'wait "$full_build_pid"' 'build-services-jar full-image child wait'
   132	require_text "$services" 'full_build_rc=$?' 'build-services-jar full-image exit status'
   133	require_text "$services" '[[ "$full_build_rc" -ne 0 ]]' 'build-services-jar full-image failure handling'
   134	require_text "$services" 'grep -Fq "#### build completed successfully ####" "$full_build_log"' 'build-services-jar full-image success marker'
   135	require_text "$services" 'image_artifact="out/target/product/vsoc_x86_64/system.img"' 'build-services-jar full-image artifact'
   136	require_text "$services" '[[ -f "$image_artifact" ]]' 'build-services-jar full-image artifact check'
   137	check_full_build_section "$services" 'build-full-services.XXXXXX.log' 'build-services-jar'
   138	require_text "$services" 'cvd fleet' 'build-services-jar fleet inspection'
   139	require_text "$services" 'cvd_group="${CVD_GROUP:?Set CVD_GROUP to the explicitly confirmed group from cvd fleet}"' 'build-services-jar CVD group pin'
   140	reject_regex "$services" '^[[:space:]]*cvd[[:space:]]+(stop|start)' 'build-services-jar CVD group selector'
   141	require_text "$services" 'cvd --group_name="$cvd_group" stop' 'build-services-jar selected CVD stop'
   142	require_text "$services" 'cvd --group_name="$cvd_group" start' 'build-services-jar selected CVD start'
   143	require_text "$services" 'm update-api' 'build-services-jar update-api guidance'
   144	require_text "$services" 'SELinux' 'build-services-jar SELinux dependency'
   145	require_text "$services" 'verify-*.sh' 'build-services-jar feature verification'
   146	require_text "$services" 'RESULT PASS' 'build-services-jar pass criterion'
   147	echo "PASS  build-services-jar skill 工件完整"
   148	
   149	require_file "$sepolicy" 'build-sepolicy skill artifact'
   150	check_frontmatter "$sepolicy" build-sepolicy "$sepolicy_description" 'build-sepolicy'
   151	reject_regex "$sepolicy" '^[[:space:]]*paths:|automatic(ally)?[[:space:]-]+activat|auto-activat|自动激活' 'build-sepolicy activation claim'
   152	require_text "$sepolicy" '$build-sepolicy' 'build-sepolicy explicit selection'
   153	require_text "$sepolicy" 'AGENTS.md' 'build-sepolicy AGENTS routing'
   154	require_text "$sepolicy" 'frontmatter description' 'build-sepolicy implicit selection'
   155	require_text "$sepolicy" 'File paths alone do not select skills.' 'build-sepolicy path selection accuracy'
   156	require_text "$sepolicy" 'bash -c' 'build-sepolicy Bash invocation'
   157	require_text "$sepolicy" 'source build/envsetup.sh' 'build-sepolicy envsetup command'
   158	require_text "$sepolicy" 'lunch aosp_cf_x86_64_phone-trunk_staging-userdebug' 'build-sepolicy lunch target'
   159	require_text "$sepolicy" 'm selinux_policy' 'build-sepolicy compile target'
   160	require_text "$sepolicy" 'same exec session' 'build-sepolicy retained exec session'
   161	require_text "$sepolicy" 'build_log="$(mktemp "${TMPDIR:-/tmp}/build-sepolicy.XXXXXX.log")"' 'build-sepolicy unique build log'
   162	require_text "$sepolicy" 'while kill -0 "$build_pid" 2>/dev/null; do' 'build-sepolicy in-session polling'
   163	require_text "$sepolicy" 'wait "$build_pid"' 'build-sepolicy retained child wait'
   164	require_text "$sepolicy" 'build_rc=$?' 'build-sepolicy child exit status'
   165	require_text "$sepolicy" '[[ "$build_rc" -ne 0 ]]' 'build-sepolicy failed build handling'
   166	require_text "$sepolicy" '#### build completed successfully ####' 'build-sepolicy success marker'
   167	require_text "$sepolicy" 'out/target/product/vsoc_x86_64/system/etc/selinux/plat_sepolicy.cil' 'build-sepolicy artifact path'
   168	require_text "$sepolicy" '[[ -f "$artifact" ]]' 'build-sepolicy artifact check'
   169	require_text "$sepolicy" 'service_contexts' 'build-sepolicy service context mapping'
   170	require_text "$sepolicy" 'service_manager_type' 'build-sepolicy service type guidance'
   171	reject_text "$sepolicy" 'allow system_server sidebar_service:service_manager { add find };' 'build-sepolicy raw system_server allow'
   172	require_text "$sepolicy" 'type sidebar_service, system_server_service, service_manager_type;' 'build-sepolicy canonical SystemServer service type'
   173	require_text "$sepolicy" 'The system_server_service attribute is consumed by add_service(system_server, system_server_service).' 'build-sepolicy SystemServer registration guidance'
   174	require_text "$sepolicy" 'allow sidebar_app sidebar_service:service_manager find;' 'build-sepolicy client service-manager find permission'
   175	require_text "$sepolicy" 'avc: denied' 'build-sepolicy denial check'
   176	require_text "$sepolicy" 'service list' 'build-sepolicy service registration check'
   177	require_text "$sepolicy" 'full image' 'build-sepolicy full-image deployment'
   178	require_text "$sepolicy" 'full_build_log="$(mktemp "${TMPDIR:-/tmp}/build-full-sepolicy.XXXXXX.log")"' 'build-sepolicy retained full-image build'
   179	require_text "$sepolicy" 'full_build_pid=$!' 'build-sepolicy full-image background child'
   180	require_text "$sepolicy" 'while kill -0 "$full_build_pid" 2>/dev/null; do' 'build-sepolicy full-image polling'
   181	require_text "$sepolicy" 'wait "$full_build_pid"' 'build-sepolicy full-image child wait'
   182	require_text "$sepolicy" 'full_build_rc=$?' 'build-sepolicy full-image exit status'
   183	require_text "$sepolicy" '[[ "$full_build_rc" -ne 0 ]]' 'build-sepolicy full-image failure handling'
   184	require_text "$sepolicy" 'grep -Fq "#### build completed successfully ####" "$full_build_log"' 'build-sepolicy full-image success marker'
   185	require_text "$sepolicy" 'image_artifact="out/target/product/vsoc_x86_64/system.img"' 'build-sepolicy full-image artifact'
   186	require_text "$sepolicy" '[[ -f "$image_artifact" ]]' 'build-sepolicy full-image artifact check'
   187	check_full_build_section "$sepolicy" 'build-full-sepolicy.XXXXXX.log' 'build-sepolicy'
   188	require_text "$sepolicy" 'cvd fleet' 'build-sepolicy fleet inspection'
   189	require_text "$sepolicy" 'cvd_group="${CVD_GROUP:?Set CVD_GROUP to the explicitly confirmed group from cvd fleet}"' 'build-sepolicy CVD group pin'
   190	reject_regex "$sepolicy" '^[[:space:]]*cvd[[:space:]]+(stop|start)' 'build-sepolicy CVD group selector'
   191	require_text "$sepolicy" 'cvd --group_name="$cvd_group" stop' 'build-sepolicy selected CVD stop'
   192	require_text "$sepolicy" 'cvd --group_name="$cvd_group" start' 'build-sepolicy selected CVD start'
   193	require_text "$sepolicy" 'not a services.jar push' 'build-sepolicy jar-push warning'
   194	reject_regex "$sepolicy" '^[[:space:]]*adb[[:space:]]+shell[[:space:]]+(dmesg|service)' 'build-sepolicy bare ADB command'
   195	require_text "$sepolicy" 'device_serial="${ANDROID_SERIAL:?Set ANDROID_SERIAL to the explicitly confirmed target serial}"' 'build-sepolicy ANDROID_SERIAL pin'
   196	require_text "$sepolicy" 'adb -s "$device_serial" get-state' 'build-sepolicy pinned get-state'
   197	require_text "$sepolicy" 'adb -s "$device_serial" shell dmesg' 'build-sepolicy pinned denial query'
   198	require_text "$sepolicy" 'adb -s "$device_serial" shell service list' 'build-sepolicy pinned service query'
   199	require_text "$sepolicy" 'verify-*.sh' 'build-sepolicy feature verification'
   200	require_text "$sepolicy" 'RESULT PASS' 'build-sepolicy pass criterion'
   201	echo "PASS  build-sepolicy skill 工件完整"
   202	
   203	echo "RESULT PASS"
```

stderr：空。exit code：`0`。

### 完整重放 7

```bash
nl -ba .spec/2026-09-01-aosp-feature-minimal-checkout/PLAN.md && nl -ba .spec/2026-09-01-aosp-feature-minimal-checkout/STATE.md && nl -ba .spec/2026-09-01-aosp-feature-minimal-checkout/DECISIONS.md
```

stdout：

```text
     1	# 2026-09-01-aosp-feature-minimal-checkout 拆分计划 v1
     2	
     3	> 上游：research/report.md
     4	> v1 依据：（首版，写明基于调研的哪几条结论）
     5	
     6	## 总目标
     7	
     8	（一句话）
     9	
    10	整体验收：（命令 + 期望输出，或验收清单）
    11	整体不变量：（逐条，带阈值和验证方式）
    12	
    13	## 全局约束
    14	
    15	（所有 spec 都要遵守，数值照抄，每条一行）
    16	
    17	## spec 列表
    18	
    19	| id | 目标（一句话） | 依赖 | 独立判据 | 状态 |
    20	|---|---|---|---|---|
    21	
    22	状态取值：⬜ 未开始 / ⏳ 进行中 / ✅ 完成 / ❌ 不成立
    23	
    24	## 依赖图
    25	
    26	（文字版拓扑）
    27	
    28	## 资源冲突
    29	
    30	（同设备 / 同文件 / 同外部环境。没有就写「无」，不能缺这一节）
     1	---
     2	project: 2026-09-01-aosp-feature-minimal-checkout
     3	kind: large
     4	phase: research
     5	phase_status: in_progress
     6	basis: 分型完成：large，待确认调研范围
     7	updated: '2026-09-01T21:10:27+08:00'
     8	current_spec: null
     9	spec_stage: null
    10	---
    11	# 2026-09-01-aosp-feature-minimal-checkout 状态
    12	
    13	## 待确认项
    14	
    15	调研范围：
    16	
    17	  查：
    18	  - 当前 aosp-harness-demo 中 feature、framework、AOSP 源码与构建命令的组织方式。
    19	  - 从一个 feature 如何推导所需 AOSP Git 单仓、编译框架及其闭包依赖。
    20	  - “单仓单编”在 Soong/Make 环境下的必要条件、不可避免的公共依赖与失败边界。
    21	  - 可落地的最小化下载/编译方案，包括 manifest 或依赖描述、缓存、校验和回退机制。
    22	  - 选取仓库内一个现有 feature 做静态走查，给出可执行的验收命令草案。
    23	
    24	  不查：
    25	  - 不下载或编译完整 AOSP 整机镜像。
    26	  - 不扩展到具体业务 feature 的功能开发。
    27	  - 不覆盖厂商私有 BSP/vendor 工程的通用最小化方案；如发现依赖，只记录为边界或风险。
    28	
    29	调研范围已确认（2026-09-01，用户回复“ok”）。
    30	
    31	> 这份文件的 frontmatter 是机器读的唯一真相。正文是给人看的流水账。
    32	> 每次决定下一步动作之前重读本文件，不要靠会话记忆判断当前在第几步。
    33	
    34	## 阶段流水
    35	
    36	| 时间 | 从 | 到 | 依据 |
    37	|---|---|---|---|
    38	| 2026-09-01T21:10:27+08:00 | — | research | 分型完成：large，待确认调研范围 |
    39	
    40	## SKIPPED 记录
    41	
    42	软门禁跳过记录。收口时会逐条重报一次。
    43	
    44	| 时间 | 阶段 | 缺什么 | 批准人 |
    45	|---|---|---|---|
     1	# 2026-09-01-aosp-feature-minimal-checkout 项目口径
     2	
     3	> 前面的 spec 确认过的口径记在这里，后续 spec 起草 requirements 前先读。
     4	> 已被本文件覆盖的条目不许再标 [推断] 去问用户。
     5	
     6	| 日期 | 来自 spec | 口径 |
     7	|---|---|---|
```

stderr：空。exit code：`0`。

### 完整重放 8

```bash
nl -ba codex/CURRENT_FEATURE && nl -ba codex/.codex/bin/codex-feature && nl -ba codex/.codex/hooks/feature-common.sh && nl -ba codex/.codex/hooks/session-start.sh
```

stdout：

```text
     1	dev-sidebar
     1	#!/usr/bin/env bash
     2	set -euo pipefail
     3	
     4	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
     5	DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
     6	ROOT="${HARNESS_ROOT:-$DEFAULT_ROOT}"
     7	source "$DEFAULT_ROOT/.codex/hooks/feature-common.sh"
     8	
     9	dry_run=0
    10	if [[ "${1:-}" == '--dry-run' ]]; then
    11	  dry_run=1
    12	  shift
    13	fi
    14	
    15	feature=''
    16	if feature="$(detect_feature "$ROOT")"; then
    17	  detect_rc=0
    18	else
    19	  detect_rc=$?
    20	fi
    21	if [[ "$detect_rc" -eq 2 ]] || { [[ "$detect_rc" -eq 0 ]] && ! valid_feature_name "$feature"; }; then
    22	  echo "error: INVALID feature；名称必须是单行 ASCII 单组件 [A-Za-z0-9][A-Za-z0-9._-]*。Codex 未启动。" >&2
    23	  exit 1
    24	fi
    25	if [[ "$detect_rc" -ne 0 || -z "$feature" ]]; then
    26	  echo "error: 无法从锚点仓分支或 $ROOT/CURRENT_FEATURE 检测 feature；Codex 未启动。" >&2
    27	  exit 1
    28	fi
    29	
    30	expected_target="features/$feature/AGENTS.md"
    31	if ! target="$(feature_context_path "$ROOT" "$feature")"; then
    32	  echo "error: feature '$feature' 缺少 $expected_target；请创建该上下文或修正 CURRENT_FEATURE。Codex 未启动。" >&2
    33	  exit 1
    34	fi
    35	
    36	if [[ -d "$ROOT/.repo" ]]; then
    37	  check_branch="$ROOT/features/$feature/check-branch.sh"
    38	  if [[ ! -x "$check_branch" ]]; then
    39	    echo "error: 缺少可执行的 $check_branch，无法校验涉及仓分支；Codex 未启动。" >&2
    40	    exit 1
    41	  fi
    42	  if ! HARNESS_ROOT="$ROOT" FEATURE_NAME="$feature" "$check_branch"; then
    43	    echo "error: feature '$feature' 的涉及仓分支校验失败；AGENTS.md 未切换，Codex 未启动。" >&2
    44	    exit 1
    45	  fi
    46	fi
    47	
    48	sync_feature_link "$ROOT" "$target"
    49	echo "[codex-feature] AGENTS.md -> $target"
    50	
    51	if [[ "$dry_run" -eq 1 ]]; then
    52	  exit 0
    53	fi
    54	
    55	cd "$ROOT"
    56	exec codex "$@"
     1	#!/usr/bin/env bash
     2	
     3	valid_feature_name() {
     4	  local feature="$1"
     5	  local LC_ALL=C
     6	
     7	  [[ "$feature" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
     8	}
     9	
    10	detect_feature() {
    11	  local root="$1"
    12	  local repo candidate
    13	
    14	  for repo in frameworks/base frameworks/native frameworks/av system/core; do
    15	    if [[ ! -f "$root/$repo/.git" && ! -d "$root/$repo/.git" ]]; then
    16	      continue
    17	    fi
    18	    if ! git -C "$root/$repo" rev-parse --git-dir >/dev/null 2>&1; then
    19	      continue
    20	    fi
    21	    candidate="$(git -C "$root/$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    22	    if [[ -n "$candidate" ]]; then
    23	      printf '%s\n' "$candidate"
    24	      valid_feature_name "$candidate" || return 2
    25	      return 0
    26	    fi
    27	  done
    28	
    29	  [[ -f "$root/CURRENT_FEATURE" ]] || return 1
    30	  if ! candidate="$(python3 - "$root/CURRENT_FEATURE" <<'PY'
    31	import re
    32	import sys
    33	
    34	try:
    35	    data = open(sys.argv[1], 'rb').read()
    36	except OSError:
    37	    raise SystemExit(1)
    38	match = re.fullmatch(rb'([A-Za-z0-9][A-Za-z0-9._-]*)(?:\n)?', data)
    39	if match is None:
    40	    raise SystemExit(1)
    41	sys.stdout.buffer.write(match.group(1))
    42	PY
    43	)"; then
    44	    return 2
    45	  fi
    46	  printf '%s\n' "$candidate"
    47	  valid_feature_name "$candidate" || return 2
    48	}
    49	
    50	feature_context_path() {
    51	  local root="$1"
    52	  local feature="$2"
    53	  local target="features/$feature/AGENTS.md"
    54	
    55	  valid_feature_name "$feature" || return 1
    56	  [[ -f "$root/$target" ]] || return 1
    57	  printf '%s\n' "$target"
    58	}
    59	
    60	sync_feature_link() {
    61	  local root="$1"
    62	  local target="$2"
    63	  local link="$root/AGENTS.md"
    64	  local temporary_link replace_rc
    65	
    66	  if [[ ! -L "$link" && -e "$link" ]]; then
    67	    printf 'error: %s 是普通文件，拒绝覆盖。\n' "$link" >&2
    68	    return 1
    69	  fi
    70	  if [[ -L "$link" && "$(readlink "$link")" == "$target" ]]; then
    71	    return 0
    72	  fi
    73	
    74	  temporary_link="$root/.AGENTS.md.tmp.$$.$RANDOM"
    75	  if ! ln -s "$target" "$temporary_link"; then
    76	    printf 'error: 无法创建临时 feature 上下文软链 %s。\n' "$temporary_link" >&2
    77	    return 1
    78	  fi
    79	
    80	  if [[ ! -L "$link" && -e "$link" ]]; then
    81	    rm -f "$temporary_link"
    82	    printf 'error: %s 是普通文件，拒绝覆盖。\n' "$link" >&2
    83	    return 1
    84	  fi
    85	  if python3 - "$temporary_link" "$link" <<'PY'
    86	import os
    87	import sys
    88	
    89	source, destination = sys.argv[1:]
    90	if os.path.lexists(destination) and not os.path.islink(destination):
    91	    raise SystemExit(2)
    92	try:
    93	    os.replace(source, destination)
    94	except OSError:
    95	    raise SystemExit(1)
    96	PY
    97	  then
    98	    return 0
    99	  else
   100	    replace_rc=$?
   101	  fi
   102	
   103	  rm -f "$temporary_link"
   104	  if [[ "$replace_rc" -eq 2 ]]; then
   105	    printf 'error: %s 是普通文件，拒绝覆盖。\n' "$link" >&2
   106	  else
   107	    printf 'error: 无法安全更新 %s。\n' "$link" >&2
   108	  fi
   109	  return 1
   110	}
     1	#!/usr/bin/env bash
     2	set -euo pipefail
     3	
     4	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
     5	DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
     6	source "$SCRIPT_DIR/feature-common.sh"
     7	
     8	ROOT="${HARNESS_ROOT:-$DEFAULT_ROOT}"
     9	STATE_DIR="${CODEX_HARNESS_STATE_DIR:-${TMPDIR:-/tmp}/aosp-codex-harness-$UID}"
    10	
    11	parse_session_id() {
    12	  python3 -c '
    13	import json
    14	import re
    15	import sys
    16	
    17	try:
    18	    data = json.load(sys.stdin)
    19	    session_id = data["session_id"]
    20	except (json.JSONDecodeError, KeyError, TypeError):
    21	    raise SystemExit(1)
    22	
    23	if not isinstance(session_id, str):
    24	    raise SystemExit(1)
    25	if not 1 <= len(session_id) <= 128:
    26	    raise SystemExit(1)
    27	if session_id in (".", ".."):
    28	    raise SystemExit(1)
    29	if re.fullmatch(r"[A-Za-z0-9._-]+", session_id) is None:
    30	    raise SystemExit(1)
    31	sys.stdout.buffer.write(session_id.encode("ascii"))
    32	'
    33	}
    34	
    35	prepare_state_dir() {
    36	  python3 - "$1" <<'PY'
    37	import os
    38	import stat
    39	import sys
    40	
    41	raw_path = sys.argv[1]
    42	if not raw_path or any(ord(character) < 32 or ord(character) == 127 for character in raw_path):
    43	    raise SystemExit(1)
    44	raw_components = raw_path.split(os.sep)
    45	if any(component in (".", "..") for component in raw_components):
    46	    raise SystemExit(1)
    47	
    48	components = [component for component in raw_components if component]
    49	if not components:
    50	    raise SystemExit(1)
    51	
    52	absolute = os.path.isabs(raw_path)
    53	normalized = os.path.join(*components)
    54	if absolute:
    55	    normalized = os.sep + normalized
    56	
    57	open_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    58	if hasattr(os, "O_CLOEXEC"):
    59	    open_flags |= os.O_CLOEXEC
    60	
    61	directory_fd = os.open(os.sep if absolute else ".", open_flags)
    62	try:
    63	    for component in components:
    64	        created = False
    65	        try:
    66	            component_stat = os.lstat(component, dir_fd=directory_fd)
    67	        except FileNotFoundError:
    68	            try:
    69	                os.mkdir(component, mode=0o700, dir_fd=directory_fd)
    70	                created = True
    71	            except FileExistsError:
    72	                pass
    73	            component_stat = os.lstat(component, dir_fd=directory_fd)
    74	
    75	        if stat.S_ISLNK(component_stat.st_mode):
    76	            raise SystemExit(1)
    77	        if not stat.S_ISDIR(component_stat.st_mode):
    78	            raise SystemExit(1)
    79	
    80	        next_fd = os.open(component, open_flags, dir_fd=directory_fd)
    81	        os.close(directory_fd)
    82	        directory_fd = next_fd
    83	        if created:
    84	            os.fchmod(directory_fd, 0o700)
    85	            created_stat = os.fstat(directory_fd)
    86	            if created_stat.st_uid != os.getuid():
    87	                raise SystemExit(1)
    88	            if stat.S_IMODE(created_stat.st_mode) != 0o700:
    89	                raise SystemExit(1)
    90	
    91	    final_stat = os.fstat(directory_fd)
    92	    if final_stat.st_uid != os.getuid():
    93	        raise SystemExit(1)
    94	    os.fchmod(directory_fd, 0o700)
    95	    final_stat = os.fstat(directory_fd)
    96	    if not stat.S_ISDIR(final_stat.st_mode):
    97	        raise SystemExit(1)
    98	    if stat.S_IMODE(final_stat.st_mode) != 0o700:
    99	        raise SystemExit(1)
   100	finally:
   101	    os.close(directory_fd)
   102	
   103	sys.stdout.buffer.write(os.fsencode(normalized))
   104	PY
   105	}
   106	
   107	if ! session_id="$(parse_session_id 2>/dev/null)"; then
   108	  echo 'error: invalid hook input' >&2
   109	  exit 1
   110	fi
   111	
   112	if ! feature="$(detect_feature "$ROOT")"; then
   113	  echo 'error: unable to detect active feature' >&2
   114	  exit 1
   115	fi
   116	if ! feature_context_path "$ROOT" "$feature" >/dev/null; then
   117	  echo 'error: active feature context is unavailable' >&2
   118	  exit 1
   119	fi
   120	
   121	umask 077
   122	if ! STATE_DIR="$(prepare_state_dir "$STATE_DIR" 2>/dev/null)"; then
   123	  echo 'error: unsafe harness state directory' >&2
   124	  exit 1
   125	fi
   126	
   127	if ! python3 - "$STATE_DIR" "$session_id" "$feature" 2>/dev/null <<'PY'
   128	import os
   129	import sys
   130	import tempfile
   131	
   132	state_dir, session_id, feature = sys.argv[1:]
   133	destination = os.path.join(state_dir, session_id + ".feature")
   134	descriptor = None
   135	temporary = None
   136	
   137	try:
   138	    descriptor, temporary = tempfile.mkstemp(
   139	        dir=state_dir,
   140	        prefix="." + session_id + ".feature.tmp.",
   141	    )
   142	    os.fchmod(descriptor, 0o600)
   143	    snapshot = os.fdopen(descriptor, "w", encoding="ascii", newline="\n")
   144	    descriptor = None
   145	    with snapshot:
   146	        snapshot.write(feature + "\n")
   147	        snapshot.flush()
   148	        os.fsync(snapshot.fileno())
   149	    os.replace(temporary, destination)
   150	    temporary = None
   151	finally:
   152	    if descriptor is not None:
   153	        os.close(descriptor)
   154	    if temporary is not None:
   155	        try:
   156	            os.unlink(temporary)
   157	        except FileNotFoundError:
   158	            pass
   159	PY
   160	then
   161	  echo 'error: unable to record feature snapshot' >&2
   162	  exit 1
   163	fi
```

stderr：空。exit code：`0`。

### 完整重放 9

```bash
nl -ba common/.harness/features/dev-sidebar/verify-sidebar.sh | sed -n '1,150p' && nl -ba codex/features/dev-sidebar/check-branch.sh | sed -n '1,180p'
```

stdout：

```text
     1	#!/usr/bin/env bash
     2	set -euo pipefail
     3	
     4	demo=0
     5	allow_skip=0
     6	
     7	usage() {
     8	  printf '%s\n' 'Usage: verify-sidebar.sh [--demo] [--allow-skip]'
     9	}
    10	
    11	while (($# > 0)); do
    12	  case "$1" in
    13	    --demo)
    14	      demo=1
    15	      shift
    16	      ;;
    17	    --allow-skip)
    18	      allow_skip=1
    19	      shift
    20	      ;;
    21	    --help)
    22	      usage
    23	      exit 0
    24	      ;;
    25	    *)
    26	      usage >&2
    27	      exit 2
    28	      ;;
    29	  esac
    30	done
    31	
    32	if ((allow_skip && demo == 0)); then
    33	  echo 'error: --allow-skip requires --demo' >&2
    34	  exit 2
    35	fi
    36	
    37	if ((demo == 0)); then
    38	  serial="${ANDROID_SERIAL:-}"
    39	  [[ "$serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]] || {
    40	    echo 'error: 真实模式需要显式设置安全的 ANDROID_SERIAL' >&2
    41	    exit 2
    42	  }
    43	  ADB=(adb -s "$serial")
    44	fi
    45	
    46	pass_count=0
    47	fail_count=0
    48	skip_count=0
    49	
    50	pass_check() {
    51	  echo "PASS  $1"
    52	  pass_count=$((pass_count + 1))
    53	}
    54	
    55	fail_check() {
    56	  echo "FAIL  $1"
    57	  fail_count=$((fail_count + 1))
    58	}
    59	
    60	skip_check() {
    61	  echo "SKIP  $1"
    62	  skip_count=$((skip_count + 1))
    63	}
    64	
    65	if ((demo)) && [[ "${DEMO_SKIP:-0}" == 1 ]]; then
    66	  skip_check 'sidebar service registration（demo requested skip）'
    67	elif ((demo)); then
    68	  if [[ "${DEMO_SERVICE_REGISTERED:-1}" == 1 ]]; then
    69	    pass_check 'sidebar service registered'
    70	  else
    71	    fail_check 'sidebar service missing'
    72	  fi
    73	else
    74	  if service_output="$("${ADB[@]}" shell service list 2>/dev/null)" &&
    75	     grep -Eq 'sidebar|Sidebar' <<<"$service_output"; then
    76	    pass_check 'sidebar service registered'
    77	  elif [[ -n "${service_output:-}" ]]; then
    78	    fail_check 'sidebar service missing'
    79	  else
    80	    fail_check 'sidebar service query failed'
    81	  fi
    82	fi
    83	
    84	if ((demo)); then
    85	  boot_completed="${DEMO_BOOT_COMPLETED:-1}"
    86	else
    87	  boot_completed="$("${ADB[@]}" shell getprop sys.boot_completed 2>/dev/null || true)"
    88	  boot_completed="${boot_completed//$'\r'/}"
    89	  boot_completed="${boot_completed//$'\n'/}"
    90	fi
    91	if [[ "$boot_completed" == 1 ]]; then
    92	  pass_check 'sys.boot_completed = 1'
    93	else
    94	  fail_check 'sys.boot_completed != 1'
    95	fi
    96	
    97	if ((demo)); then
    98	  system_server="${DEMO_SYSTEM_SERVER:-1423}"
    99	else
   100	  system_server="$("${ADB[@]}" shell pidof system_server 2>/dev/null || true)"
   101	fi
   102	if [[ "$system_server" =~ ^[0-9]+([[:space:]]+[0-9]+)*$ ]]; then
   103	  pass_check "system_server pid = $system_server"
   104	else
   105	  fail_check 'system_server pid 无效或查询失败'
   106	fi
   107	
   108	if ((fail_count > 0)); then
   109	  echo 'RESULT FAIL'
   110	  exit 1
   111	fi
   112	if ((skip_count > 0 && allow_skip == 0)); then
   113	  echo 'RESULT INCOMPLETE'
   114	  exit 2
   115	fi
   116	if ((skip_count > 0)); then
   117	  echo 'RESULT EXPLORATION (SKIP allowed)'
   118	else
   119	  echo 'RESULT PASS'
   120	fi
     1	#!/usr/bin/env bash
     2	set -euo pipefail
     3	
     4	SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
     5	ROOT="${HARNESS_ROOT:-$SCRIPT_ROOT}"
     6	FEATURE="${FEATURE_NAME:-dev-sidebar}"
     7	
     8	valid_feature_name() {
     9	  local feature="$1"
    10	  local LC_ALL=C
    11	
    12	  [[ "$feature" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
    13	}
    14	
    15	if ! valid_feature_name "$FEATURE"; then
    16	  echo "INVALID feature: expected [A-Za-z0-9][A-Za-z0-9._-]*" >&2
    17	  exit 1
    18	fi
    19	
    20	LIST="$ROOT/features/$FEATURE/repos.tsv"
    21	REPOS=()
    22	LISTED_FEATURES=()
    23	DESCRIPTIONS=()
    24	
    25	if [[ ! -f "$LIST" ]]; then
    26	  echo "MISSING $LIST" >&2
    27	  exit 1
    28	fi
    29	if python3 - "$LIST" <<'PY'
    30	import pathlib
    31	import sys
    32	
    33	try:
    34	    data = pathlib.Path(sys.argv[1]).read_bytes()
    35	except OSError:
    36	    raise SystemExit(2)
    37	raise SystemExit(1 if b'\0' in data else 0)
    38	PY
    39	then
    40	  :
    41	else
    42	  manifest_bytes_rc=$?
    43	  if [[ "$manifest_bytes_rc" -eq 1 ]]; then
    44	    echo "INVALID manifest $LIST: NUL bytes are not allowed" >&2
    45	  else
    46	    echo "INVALID manifest $LIST: unable to read raw bytes" >&2
    47	  fi
    48	  exit 1
    49	fi
    50	
    51	line_number=0
    52	while IFS= read -r line || [[ -n "$line" ]]; do
    53	  line_number=$((line_number + 1))
    54	  case "$line" in
    55	    ''|'#'*) continue ;;
    56	  esac
    57	
    58	  if [[ "$line" != *$'\t'* ]]; then
    59	    echo "INVALID manifest $LIST:$line_number: expected exactly three tab-separated fields" >&2
    60	    exit 1
    61	  fi
    62	  path="${line%%$'\t'*}"
    63	  remainder="${line#*$'\t'}"
    64	  if [[ "$remainder" != *$'\t'* ]]; then
    65	    echo "INVALID manifest $LIST:$line_number: expected exactly three tab-separated fields" >&2
    66	    exit 1
    67	  fi
    68	  listed_feature="${remainder%%$'\t'*}"
    69	  description="${remainder#*$'\t'}"
    70	  if [[ -z "$path" || -z "$listed_feature" || -z "$description" || "$description" == *$'\t'* ]]; then
    71	    echo "INVALID manifest $LIST:$line_number: expected three nonempty tab-separated fields" >&2
    72	    exit 1
    73	  fi
    74	  if [[ "$listed_feature" != "$FEATURE" ]]; then
    75	    echo "INVALID manifest $LIST:$line_number: feature '$listed_feature' does not match active feature '$FEATURE'" >&2
    76	    exit 1
    77	  fi
    78	
    79	  REPOS+=("$path")
    80	  LISTED_FEATURES+=("$listed_feature")
    81	  DESCRIPTIONS+=("$description")
    82	done < "$LIST"
    83	
    84	if [[ "${#REPOS[@]}" -eq 0 ]]; then
    85	  echo "MISSING repositories in $LIST" >&2
    86	  exit 1
    87	fi
    88	
    89	if [[ "${1:-}" == '--demo' ]]; then
    90	  last_index=$((${#REPOS[@]} - 1))
    91	  for index in "${!REPOS[@]}"; do
    92	    repo="${REPOS[$index]}"
    93	    expected_feature="${LISTED_FEATURES[$index]}"
    94	    branch="$expected_feature"
    95	    if [[ "$index" -eq "$last_index" ]]; then
    96	      branch="${expected_feature}-demo-drift"
    97	    fi
    98	    if [[ "$branch" == "$expected_feature" ]]; then
    99	      echo "OK      $repo @ $branch"
   100	    else
   101	      echo "DRIFT   $repo @ $branch (应为 $expected_feature)"
   102	    fi
   103	  done
   104	  exit 1
   105	fi
   106	
   107	bad=0
   108	for index in "${!REPOS[@]}"; do
   109	  repo="${REPOS[$index]}"
   110	  expected_feature="${LISTED_FEATURES[$index]}"
   111	  repo_root="$ROOT/$repo"
   112	  if [[ ! -e "$repo_root/.git" && ! -L "$repo_root/.git" ]]; then
   113	    echo "MISSING $repo"
   114	    bad=1
   115	    continue
   116	  fi
   117	  if ! git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
   118	    echo "INVALID $repo"
   119	    bad=1
   120	    continue
   121	  fi
   122	
   123	  if branch="$(git -C "$repo_root" symbolic-ref --quiet --short HEAD 2>/dev/null)"; then
   124	    :
   125	  elif git -C "$repo_root" rev-parse --verify 'HEAD^{object}' >/dev/null 2>&1; then
   126	    branch='DETACHED'
   127	  else
   128	    echo "INVALID $repo"
   129	    bad=1
   130	    continue
   131	  fi
   132	  if [[ "$branch" == "$expected_feature" ]]; then
   133	    echo "OK      $repo @ $branch"
   134	  else
   135	    echo "DRIFT   $repo @ $branch (应为 $expected_feature)"
   136	    bad=1
   137	  fi
   138	done
   139	
   140	exit "$bad"
```

stderr：空。exit code：`0`。

### 完整重放 10

```bash
rg -n "CURRENT_FEATURE|repos.tsv|workflow.md|repositories=|MISSING|target_branch|verify-\\*|multiple|feature" common/tests/test-harness.sh | sed -n '1,220p'
```

stdout：

```text
26:  claude="$("$ROOT/.claude/bin/claude-feature" --dry-run --contract)"
27:  codex="$("$ROOT/.codex/bin/codex-feature" --dry-run --contract)"
33:  grep -Fq 'feature=dev-sidebar' <<<"$claude"
34:  grep -Fq 'target_branch=dev-sidebar' <<<"$claude"
35:  grep -Fq 'manifest=.harness/features/dev-sidebar/repos.tsv' <<<"$claude"
36:  grep -Fq 'workflow=.harness/features/dev-sidebar/workflow.md' <<<"$claude"
37:  grep -Fq 'verifier=.harness/features/dev-sidebar/verify-sidebar.sh' <<<"$claude"
49:    \( -name repos.tsv -o -name 'verify-*.sh' \) -print -quit)"
50:  test -f "$ROOT/.harness/features/dev-sidebar/repos.tsv"
51:  test -f "$ROOT/.harness/features/dev-sidebar/workflow.md"
52:  test -f "$ROOT/.harness/features/dev-sidebar/verify-sidebar.sh"
61:  ' "$ROOT/.harness/features/dev-sidebar/repos.tsv"
66:  pass_output="$("$ROOT/.harness/features/dev-sidebar/verify-sidebar.sh" --demo)"
71:    "$ROOT/.harness/features/dev-sidebar/verify-sidebar.sh" --demo 2>&1)"
78:    "$ROOT/.harness/features/dev-sidebar/verify-sidebar.sh" --demo --allow-skip)"
84:    "$ROOT/.harness/features/dev-sidebar/verify-sidebar.sh" --allow-skip 2>&1)"
105:test_invalid_feature_fails_closed() {
106:  local fixture="$FIXTURE/invalid-feature" output rc
108:  printf '%s\n' '../escape' > "$fixture/CURRENT_FEATURE"
111:    "$fixture/.claude/bin/claude-feature" --dry-run --contract 2>&1)"
115:  grep -Fq 'INVALID feature' <<<"$output"
118:test_nul_feature_fails_closed() {
119:  local fixture="$FIXTURE/nul-feature" output rc
121:  printf 'dev-sidebar\0ignored\n' > "$fixture/CURRENT_FEATURE"
124:    "$fixture/.codex/bin/codex-feature" --dry-run --contract 2>&1)"
128:  grep -Fq 'INVALID feature' <<<"$output"
135:    > "$fixture/.harness/features/dev-sidebar/repos.tsv"
138:    "$fixture/.claude/bin/claude-feature" --dry-run --contract 2>&1)"
149:    > "$fixture/.harness/features/dev-sidebar/repos.tsv"
152:    "$fixture/.codex/bin/codex-feature" --dry-run --contract 2>&1)"
159:test_feature_specific_verifier_is_discovered() {
160:  local fixture="$FIXTURE/feature-verifier" output
162:  mkdir -p "$fixture/.harness/features/dev-next"
163:  printf '%s\n' 'dev-next' > "$fixture/CURRENT_FEATURE"
164:  printf '%s\n' $'frameworks/base\tsource\ttest\tnext feature' \
165:    > "$fixture/.harness/features/dev-next/repos.tsv"
166:  printf '%s\n' '# next workflow' > "$fixture/.harness/features/dev-next/workflow.md"
168:    > "$fixture/.harness/features/dev-next/verify-next.sh"
169:  chmod +x "$fixture/.harness/features/dev-next/verify-next.sh"
171:    "$fixture/.claude/bin/claude-feature" --dry-run --contract)"
172:  grep -Fq 'feature=dev-next' <<<"$output"
173:  grep -Fq 'verifier=.harness/features/dev-next/verify-next.sh' <<<"$output"
179:  rm "$fixture/.harness/features/dev-sidebar/workflow.md"
182:    "$fixture/.codex/bin/codex-feature" --dry-run --contract 2>&1)"
192:  rm "$fixture/.harness/features/dev-sidebar/verify-sidebar.sh"
195:    "$fixture/.codex/bin/codex-feature" --dry-run --contract 2>&1)"
216:    "$fixture/.codex/bin/codex-feature" --dry-run --contract 2>&1)"
228:    'printf "%s\n" "client=codex" "feature=dev-sidebar" "manifest=.harness/features/dev-sidebar/repos.tsv" "verifier=.harness/features/dev-sidebar/other.sh" "contract_sha256=0000000000000000000000000000000000000000000000000000000000000000"' \
229:    > "$fixture/.codex/bin/codex-feature"
230:  chmod +x "$fixture/.codex/bin/codex-feature"
243:    adapter="$fixture/.$client/bin/${client}-feature"
246:      "printf '%s\\n' 'client=$client' 'feature=stale' 'target_branch=stale' 'manifest=.harness/features/stale/repos.tsv' 'workflow=.harness/features/stale/workflow.md' 'verifier=.harness/features/stale/verify-stale.sh' 'repositories=frameworks/base' 'contract_sha256=0000000000000000000000000000000000000000000000000000000000000000'" \
262:  cp "$fixture/.harness/features/dev-sidebar/repos.tsv" \
263:    "$fixture/.claude/cache/repos.tsv"
277:run_expect_success 'Invalid feature fails closed' test_invalid_feature_fails_closed
278:run_expect_success 'NUL feature fails closed' test_nul_feature_fails_closed
281:run_expect_success 'Feature-specific verifier is discovered' test_feature_specific_verifier_is_discovered
```

stderr：空。exit code：`0`。

### 完整重放 11

```bash
nl -ba common/tests/test-harness.sh | sed -n '1,70p;159,205p;255,275p'
```

stdout：

```text
     1	#!/usr/bin/env bash
     2	set -euo pipefail
     3	
     4	ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
     5	FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/shared-harness-test.XXXXXX")"
     6	trap 'rm -rf -- "$FIXTURE"' EXIT
     7	
     8	failures=0
     9	
    10	run_expect_success() {
    11	  local name="$1" rc
    12	  shift
    13	  set +e
    14	  (set -e; "$@")
    15	  rc=$?
    16	  set -e
    17	  if [[ "$rc" -eq 0 ]]; then
    18	    return 0
    19	  fi
    20	  printf 'FAIL  %s\n' "$name" >&2
    21	  failures=$((failures + 1))
    22	}
    23	
    24	test_contracts_match() {
    25	  local claude codex
    26	  claude="$("$ROOT/.claude/bin/claude-feature" --dry-run --contract)"
    27	  codex="$("$ROOT/.codex/bin/codex-feature" --dry-run --contract)"
    28	
    29	  grep -Fq 'client=claude' <<<"$claude"
    30	  grep -Fq 'client=codex' <<<"$codex"
    31	  test "$(sed 's/^client=.*/client=CLIENT/' <<<"$claude")" = \
    32	    "$(sed 's/^client=.*/client=CLIENT/' <<<"$codex")"
    33	  grep -Fq 'feature=dev-sidebar' <<<"$claude"
    34	  grep -Fq 'target_branch=dev-sidebar' <<<"$claude"
    35	  grep -Fq 'manifest=.harness/features/dev-sidebar/repos.tsv' <<<"$claude"
    36	  grep -Fq 'workflow=.harness/features/dev-sidebar/workflow.md' <<<"$claude"
    37	  grep -Fq 'verifier=.harness/features/dev-sidebar/verify-sidebar.sh' <<<"$claude"
    38	  grep -Eq '^contract_sha256=[0-9a-f]{64}$' <<<"$claude"
    39	}
    40	
    41	test_parity_passes() {
    42	  local output
    43	  output="$("$ROOT/.harness/bin/check-parity.sh")"
    44	  grep -Fq 'PARITY PASS' <<<"$output"
    45	}
    46	
    47	test_shared_source_is_not_duplicated() {
    48	  test -z "$(find "$ROOT/.claude" "$ROOT/.codex" -type f \
    49	    \( -name repos.tsv -o -name 'verify-*.sh' \) -print -quit)"
    50	  test -f "$ROOT/.harness/features/dev-sidebar/repos.tsv"
    51	  test -f "$ROOT/.harness/features/dev-sidebar/workflow.md"
    52	  test -f "$ROOT/.harness/features/dev-sidebar/verify-sidebar.sh"
    53	}
    54	
    55	test_manifest_has_canonical_schema() {
    56	  awk -F '\t' '
    57	    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    58	    NF != 4 { exit 1 }
    59	    $1 == "" || $2 == "" || $3 == "" || $4 == "" { exit 1 }
    60	    END { if (NR == 0) exit 1 }
    61	  ' "$ROOT/.harness/features/dev-sidebar/repos.tsv"
    62	}
    63	
    64	test_verifier_strict_states() {
    65	  local pass_output incomplete_output incomplete_rc allowed_output
    66	  pass_output="$("$ROOT/.harness/features/dev-sidebar/verify-sidebar.sh" --demo)"
    67	  grep -Fxq 'RESULT PASS' <<<"$pass_output"
    68	
    69	  set +e
    70	  incomplete_output="$(DEMO_SKIP=1 \
   159	test_feature_specific_verifier_is_discovered() {
   160	  local fixture="$FIXTURE/feature-verifier" output
   161	  copy_fixture "$fixture"
   162	  mkdir -p "$fixture/.harness/features/dev-next"
   163	  printf '%s\n' 'dev-next' > "$fixture/CURRENT_FEATURE"
   164	  printf '%s\n' $'frameworks/base\tsource\ttest\tnext feature' \
   165	    > "$fixture/.harness/features/dev-next/repos.tsv"
   166	  printf '%s\n' '# next workflow' > "$fixture/.harness/features/dev-next/workflow.md"
   167	  printf '%s\n' '#!/usr/bin/env bash' 'echo RESULT PASS' \
   168	    > "$fixture/.harness/features/dev-next/verify-next.sh"
   169	  chmod +x "$fixture/.harness/features/dev-next/verify-next.sh"
   170	  output="$(HARNESS_ROOT="$fixture" \
   171	    "$fixture/.claude/bin/claude-feature" --dry-run --contract)"
   172	  grep -Fq 'feature=dev-next' <<<"$output"
   173	  grep -Fq 'verifier=.harness/features/dev-next/verify-next.sh' <<<"$output"
   174	}
   175	
   176	test_missing_workflow_fails_closed() {
   177	  local fixture="$FIXTURE/missing-workflow" output rc
   178	  copy_fixture "$fixture"
   179	  rm "$fixture/.harness/features/dev-sidebar/workflow.md"
   180	  set +e
   181	  output="$(HARNESS_ROOT="$fixture" \
   182	    "$fixture/.codex/bin/codex-feature" --dry-run --contract 2>&1)"
   183	  rc=$?
   184	  set -e
   185	  test "$rc" -ne 0
   186	  grep -Fq 'workflow' <<<"$output"
   187	}
   188	
   189	test_missing_public_file_fails_closed() {
   190	  local fixture="$FIXTURE/missing-public" output rc
   191	  copy_fixture "$fixture"
   192	  rm "$fixture/.harness/features/dev-sidebar/verify-sidebar.sh"
   193	  set +e
   194	  output="$(HARNESS_ROOT="$fixture" \
   195	    "$fixture/.codex/bin/codex-feature" --dry-run --contract 2>&1)"
   196	  rc=$?
   197	  set -e
   198	  test "$rc" -ne 0
   199	  grep -Fq 'verifier' <<<"$output"
   200	}
   201	
   202	test_shared_branch_checker() {
   203	  local fixture="$FIXTURE/branch-check" repo output rc
   204	  copy_fixture "$fixture"
   205	  mkdir -p "$fixture/.repo"
   255	  grep -Fq 'PARITY FAIL' <<<"$output"
   256	}
   257	
   258	test_parity_detects_nested_fact_copy() {
   259	  local fixture="$FIXTURE/parity-duplicate" output rc
   260	  copy_fixture "$fixture"
   261	  mkdir -p "$fixture/.claude/cache"
   262	  cp "$fixture/.harness/features/dev-sidebar/repos.tsv" \
   263	    "$fixture/.claude/cache/repos.tsv"
   264	  set +e
   265	  output="$(HARNESS_ROOT="$fixture" "$fixture/.harness/bin/check-parity.sh" 2>&1)"
   266	  rc=$?
   267	  set -e
   268	  test "$rc" -ne 0
   269	  grep -Fq 'duplicated public facts' <<<"$output"
   270	}
   271	
   272	run_expect_success 'Claude/Codex public contracts match' test_contracts_match
   273	run_expect_success 'Parity checker passes' test_parity_passes
   274	run_expect_success 'Public facts are not duplicated' test_shared_source_is_not_duplicated
   275	run_expect_success 'Manifest follows canonical four-column schema' test_manifest_has_canonical_schema
```

stderr：空。exit code：`0`。
