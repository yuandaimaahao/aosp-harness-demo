# feature → 最小 Git 项目闭包 → 最小构建底座 → 单仓单编：独立架构调研

- 调研日期：2026-09-01（Asia/Shanghai）
- 工作区：`/home/zzh0838/CareerDevelop/AI2D/aosp-harness-demo`
- 范围：只读检查 harness demo；不下载/编译完整 AOSP，不覆盖 vendor/BSP 通用解法，不读取其他代理输出；本文件是唯一写入。
- 样本 feature：`common/.harness/features/dev-sidebar`

## 1. 结论先行

推荐候选 C：**版本锁定的完整种子树预计算 + 分层项目锁 + 缩减工作区 clean-build 证明 + 有界、可审计失败补仓**。

“最小”必须定义为某个确定构建上下文下的**已证明闭包**，而不是永远正确的全局最小集：

```text
ClosureKey = H(
  manifest lock + repo tool/version + host/container +
  product + release_config + variant + build goals +
  declared environment + closure extractor version
)

MaterializedProjects =
  bootstrap_baseline
  ∪ product_baseline
  ∪ feature_mutable_projects
  ∪ transitive_dependency_projects
  ∪ audited_failure_additions
```

“单仓单编”也必须收窄定义：**每个 job 只允许一个 Git 项目可写、只请求声明的 module goal；依赖项目和公共底座仍然必须存在且只读**。它不等于“磁盘里只有一个 Git 仓”或“模块没有跨仓依赖”。跨仓 feature 仍需最后一次所有 feature commits 同时可见的 integration build。

推荐方案能落地，但需要一个按 Android 版本/产品维护的 canonical full-tree closure builder；普通开发机只消费其 lock、Git CAS 和已证明的缩减 checkout。当前 demo 只能完成静态适配性判断，因为工作区没有 `.repo` 和真实 AOSP 源码树。

## 2. 本地一手证据

### 2.1 当前公共契约是什么

- `common/.harness/features/dev-sidebar/repos.tsv:2-6` 声明 5 个项目：`frameworks/base`、`frameworks/native`、`packages/apps/SidebarApp`、`build/make`、`system/sepolicy`。
- `common/.harness/features/dev-sidebar/workflow.md:7-9` 声明树根构建环境和目标：`source build/envsetup.sh`、`lunch <product>-userdebug`、`m services SidebarApp selinux_policy`。
- `common/.harness/bin/resolve-feature.sh:99-149` 只验证四列 TSV 和安全路径；`:151-165` 对 feature 公共文件做一个整体 SHA-256 并输出项目路径，但没有 manifest URL、项目 Git SHA、产品、host、module→project 边或 toolchain 版本。
- `common/.harness/bin/check-branches.sh:19-50` 只要求清单项目都在 feature 同名 symbolic branch；同名分支可以指向不同基线，因此它是漂移门禁，不是可复现版本锁。
- `common/tests/test-harness.sh:55-61` 只验证四个非空字段；`:105-156` 已有 fail-closed 的 feature/path/schema 负例，这是后续 lock validator 可沿用的安全基线。
- `codex/features/dev-sidebar/AGENTS.md:33-60` 说明该 feature 同时改系统服务、native 合成、应用、产品接入和 SELinux；`:11-13` 还明确 API 更新、策略和 ART/boot image 风险，说明单 module 编译不能替代集成验证。

### 2.2 实际命令记录

以下均在仓库根目录执行。每条命令的 stderr 均为空（除非明确列出）。

#### 命令 A：解析当前 feature 契约

```console
$ ./common/.codex/bin/codex-feature --dry-run --contract
client=codex
feature=dev-sidebar
target_branch=dev-sidebar
manifest=.harness/features/dev-sidebar/repos.tsv
workflow=.harness/features/dev-sidebar/workflow.md
verifier=.harness/features/dev-sidebar/verify-sidebar.sh
repositories=frameworks/base,frameworks/native,packages/apps/SidebarApp,build/make,system/sepolicy
contract_sha256=42c3e86e2bdfc69468b4319894ca75192caf97b2b86b32249769dad51cadf02d
[stdout 如上；stderr 空；exit code 0]
```

#### 命令 B：现有公共层 parity 与回归

```console
$ ./common/.harness/bin/check-parity.sh
PARITY PASS  Claude/Codex 共享同一公共契约
[stdout 如上；stderr 空；exit code 0]

$ ./common/tests/test-harness.sh
RESULT PASS  shared Harness regression suite
[stdout 如上；stderr 空；exit code 0]
```

这只能证明两个 client 消费同一份 harness 契约及既有 fail-closed 规则，不能证明 AOSP Git/构建依赖闭合。

#### 命令 C：列出项目角色/标签和目标

```console
$ awk -F '\t' '!/^#/ && NF {printf "%s\t%s\t%s\n",$1,$2,$3}' common/.harness/features/dev-sidebar/repos.tsv
frameworks/base source  java,system-server
frameworks/native       source  cpp,binder
packages/apps/SidebarApp        source  app
build/make      build   soong,make
system/sepolicy policy  selinux,service_contexts
[stdout 如上（显示时以空白对齐）；stderr 空；exit code 0]

$ sed -n '5,10p' common/.harness/features/dev-sidebar/workflow.md
## Build

    source build/envsetup.sh
    lunch <product>-userdebug
    m services SidebarApp selinux_policy
[stdout 如上；stderr 空；exit code 0]
```

#### 命令 D：确认本仓库不是 AOSP checkout

```console
$ if [[ -d .repo ]]; then echo 'AOSP repo client detected'; else echo 'NO .repo: this is a harness-only demo'; fi
NO .repo: this is a harness-only demo
[stdout 如上；stderr 空；exit code 0]

$ find common/.harness/features -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
dev-sidebar
[stdout 如上；stderr 空；exit code 0]
```

因此本调研没有伪造真实 `m`/`repo sync` 成功证据；AOSP 动态闭包仍是未确认项。

#### 命令 E：调研前工作树边界

```console
$ git status --short -- . ':!.spec/2026-09-01-aosp-feature-minimal-checkout/research/raw'
 M .spec/2026-08-31-aosp-harness-refactor/specs/2026-09-01-03a-session-path-safety/ledger.md
 M .spec/2026-08-31-aosp-harness-refactor/specs/2026-09-01-03a-session-path-safety/tasks.md
?? .spec/2026-08-31-aosp-harness-refactor/work/2026-09-01-03a-session-path-safety/
?? .spec/2026-09-01-aosp-feature-minimal-checkout/
[stdout 如上；stderr 空；exit code 0]
```

这些既有改动未被触碰。

## 3. AOSP/Repo 官方一手依据（访问于 2026-09-01）

1. [AOSP Build Android](https://source.android.com/docs/setup/build/building)：官方要求先 `source build/envsetup.sh` 再 `lunch`；当前 lunch 形式是 `product_name-release_config-build_variant`；`m <modules>` 可构建指定模块，而 `m nothing` 只解析并验证构建结构。该页还说明 Android 17+ 构建期间源码树默认只读。这同时支持“module goal 单编”和“依赖树仍需可解析/只读挂载”两点。
2. [AOSP Download the Android source](https://source.android.com/docs/setup/download)：官方示例使用 `repo init --partial-clone --no-use-superproject ...` 和 `repo sync -c -j8`；同页明确真实硬件需要设备专有库，支持把私有 vendor/BSP 设为本方案硬边界。
3. [AOSP Repo command reference](https://source.android.com/docs/setup/reference/repo)：`repo sync [project-list]` 可只同步指定项目；`repo status [project-list]` 可检查工作树；项目对应树内一个独立目录。它提供了按生成项目清单 materialize 的官方机制。
4. [Repo manifest format](https://gerrit.googlesource.com/git-repo/+/HEAD/docs/manifest-format.md)：manifest 的 `project` 有 `name/path/remote/revision/groups/upstream` 等字段，且 `revision` 可为显式 SHA。生成 lock 时不能只存 path。
5. [Repo `manifest.py`](https://gerrit.googlesource.com/git-repo/+/HEAD/subcmds/manifest.py#34)：`repo manifest -r` 会把每个 project revision 写为当前 commit hash，官方称为 revision-locked manifest；这是 platform lock 的基准生成方式。
6. [Soong README](https://android.googlesource.com/platform/build/soong/+/HEAD/README.md)：Android.bp module 是 Soong 的基本构建单元，依赖可以通过 `:module` 输出展开；说明闭包主键应为 module variant，再映射到 Git project，而不是直接从 feature 文本猜仓。
7. [Soong JSON module graph 查询说明](https://android.googlesource.com/platform/build/bazel/+/410fd24a1ba250a7357a71ff204f284483375854/json_module_graph/README.md)：`m json-module-graph` 生成图，官方脚本支持 `directDeps`、`transitiveDeps`、`fullTransitiveDeps` 和 variant 查询，可作为 Soong 预计算闭包的第一数据源。
8. [Soong UI graph 生成源码](https://android.googlesource.com/platform/build/soong/+/319eaaa9f51cc501d2c97d610bf7c129736d8e45/ui/build/soong.go#285)：生成 `module-graph.json` 的调用显式传入 `--module_graph_file`；同文件 `:331-342` 显示 bootstrap 仍需要 Android.bp 文件列表和 Soong host tool 目录。
9. [Soong build config 源码](https://android.googlesource.com/platform/build/soong/+/aee299e9f3bb1d17d931b179e099719f857f15c3/ui/build/config.go#1031)：Soong 记录按 target product 区分的 used-environment 文件，并定义 `module-graph.json`、`module-actions.json` 输出位置；支持把 product 与实际使用环境纳入 cache/lock key。
10. [Make `module-info.mk`](https://android.googlesource.com/platform/build/+/HEAD/core/tasks/module-info.mk#20)：`module-info.json` 合并 Soong/Make 信息，包含 module path、`dependencies`、required、shared/static/system libs、host/target dependencies；它应补充 Soong 图处理 Make/安装依赖，但源码注释也说 runtime dependencies 当前只覆盖部分 C/C++ binary，不能把它当完整证明。
11. [Soong Build Performance](https://android.googlesource.com/platform/build/soong/+/HEAD/docs/perf.md#137)：官方明确 Soong 会加载整个 module graph，且 `mm` 趋近 `mma`；同页也展示 Kati 读取很多 Makefile 以及 `m nothing` 的图再生成。这否定“只取目标模块源码仓就一定能启动 Soong/Make”的假设。

## 4. 候选比较

| 候选 | 做法 | 优点 | 致命问题 | 结论 |
|---|---|---|---|---|
| A. 手写 reduced manifest | feature 作者直接列业务仓 + 固定几个 `build/*`/`prebuilts/*` | 最简单 | product/variant、generated source、Make include、host tool 和全图解析依赖不可见；漂移靠失败才发现 | 不作为交付架构 |
| B. 完整 manifest + partial clone | 仍同步所有 project 元数据/工作树，只依赖 partial clone 降网络量 | 兼容性最好，失败少 | 不是最小 Git 项目集合；工作树和 inode 成本仍大 | 作为 canonical seed/紧急诊断，不是开发 workspace |
| **C. 测量闭包 + 缩减证明 + 审计补仓** | full seed 生成图/lock，按项目闭包 materialize，clean build 固定点验证 | 可复现、可解释、能逐步逼近真实闭包；普通 workspace 最小 | 需要按平台/产品预计算；首次 seed 成本不能消失 | **推荐** |

候选 C 的核心取舍是：把一次完整树成本集中到 closure builder，而不是承诺从零靠静态语法就能推导全部 AOSP 依赖。

## 5. 推荐架构

### 5.1 两份声明、一个证明产物

不要继续扩展单个四列 `repos.tsv` 让它同时承担意图和物化状态。建议拆为：

1. `feature.yaml`（人维护的意图）
   - `schema_version`
   - `feature_id`
   - `platform_lock` 引用
   - `target.product/release_config/variant`
   - `goals`：module 名、可选 variant/architecture
   - `mutable_projects`：`name/path/base_revision/feature_revision/write_policy`
   - `verification`：build、host/device verifier
   - `boundaries`：允许/禁止的 project 前缀、最大补仓次数和数量
2. `platform.lock.xml` + digest（机器生成）
   - 来自 `repo manifest -r`，包含完整 manifest 中所有 project 的 `name/path/remote/revision/upstream`；另锁 manifest repository commit、Repo 版本。
   - 它是“可解析缺仓属于哪个 SHA”的权威字典，不代表普通 workspace 要同步所有项目。
3. `closure.lock.json`（机器生成的证明）
   - 完整 `ClosureKey`；精确项目集合及每项角色：`bootstrap`、`product`、`mutable`、`module-dependency`、`failure-addition`。
   - 每个非固定底座项目至少一个 witness：`target module variant -> dependency edge -> module path -> manifest project`，或 `build/product include -> path -> project`。
   - 记录 graph/module-info/module-actions/used-env 的 SHA-256、每轮失败摘要、补仓 project 和理由、最终 clean build log digest。
   - 生成 `checkout.xml`（只含 closure 项目且 revision 为 SHA），供普通 workspace init/sync。

示意（字段名为设计草案）：

```yaml
schema_version: 1
feature_id: dev-sidebar
platform_lock: locks/aosp17-<digest>.xml
target:
  product: <required>
  release_config: <required>
  variant: userdebug
goals: [services, SidebarApp, selinux_policy]
mutable_projects:
  - {path: frameworks/base, name: platform/frameworks/base}
  - {path: frameworks/native, name: platform/frameworks/native}
  - {path: packages/apps/SidebarApp, name: platform/packages/apps/SidebarApp}
  - {path: build/make, name: platform/build}
  - {path: system/sepolicy, name: platform/system/sepolicy}
closure_policy:
  max_iterations: 8
  max_added_projects: 64
  forbid_prefixes: [vendor/]
```

`<product>` 和 `<release_config>` 不允许占位符进入 lock；当前 workflow 的 `<product>-userdebug` 只能做人读模板，不能做 closure/cache key。

### 5.2 分层构建底座

底座不能笼统写成 `prebuilts/* + build/make + build/soong`：`prebuilts/*` 是多个独立 Git project，且 bootstrap 所需集合随 Android revision、host OS、构建模式变化。建议分两层：

- **B0 bootstrap baseline（跨 feature、但不跨 platform lock/host）**：至少从 `build/make`、`build/soong`、`build/blueprint` 起步；再由 canonical seed 的 bootstrap action inputs/depfiles 精确收集该 revision 实际使用的 `prebuilts/build-tools`、Go/JDK/clang/Bazel 等 project。不得在设计中硬编码“所有版本固定这几个仓”。
- **B1 product baseline（同 product/release/variant 共享）**：lunch/product config 所读取的 device/product/system/vendor 配置项目、Soong namespaces、Make includes。它不是目标 module 的普通链接依赖，但缺失时构建图不能生成。
- **F feature overlay**：feature 声明可写 projects。
- **D target dependency closure**：module graph + module-info + build action inputs 映射出的只读 projects。

角色可重叠。例如 `dev-sidebar` 的 `build/make` 同时属于 B0 与 F。物化时它必须是 feature revision 的唯一 overlay；更重要的是，只要 `build/make`、`build/soong`、`build/blueprint` 或 bootstrap prebuilt 发生变化，就创建新的 baseline/ClosureKey，禁止复用旧图和旧 `out`。

### 5.3 预计算算法

在 canonical、完整、revision-locked AOSP seed 中：

1. 校验 full tree 每个 project HEAD 等于 `platform.lock.xml`；固定容器/host、Repo 版本、product/release/variant、环境 allowlist。
2. `source build/envsetup.sh && lunch ...`。
3. 运行 `m nothing`，再运行 `m json-module-graph module-info`（具体 release 若 goal 名不同，由 version adapter 声明，不能静默猜测）。保存 module graph、module actions、module-info、used-env 和 Soong/Kati depfiles摘要。
4. 对每个目标 module 的实际 variants 求传递依赖；用 module `path` 和 full manifest 的最长路径前缀映射为 Git project。合并 Make/required/runtime/host-target dependencies、目标源文件项目、B0/B1。
5. 为每个项目写 witness；没有 witness 的非底座项目不进入初始 closure。
6. 生成 SHA-pinned `checkout.xml`，在**全新、无旧 out**的缩减 workspace materialize。
7. 编译阶段断网，运行 `m nothing` 和目标 `m ...`。成功后再跑一次 no-op build 并保存 log/digest，状态为 `PROVEN`。
8. 若失败，仅进入下面的有界补仓状态机；达到固定点后重写 lock。任何 inputs/manifest/product/env/goals 变化都使 lock 过期。

Soong graph 是必要但非充分输入；最终 clean build 才是证明，因为 Make 的动态 include/`$(shell)`、generated sources、工具执行和不完整 runtime dependency 元数据不能全部由单一 JSON 图覆盖。

### 5.4 失败补仓状态机

```text
PRECOMPUTED -> MATERIALIZED -> PARSE_PROBE -> TARGET_BUILD -> PROVEN
                                  |               |
                                  +---- MISSING --+
                                           |
                         resolve path/module/tool against full lock
                                           |
                       unique + allowed + exact locked SHA ?
                          yes: append audit event, sync one project,
                               discard partial out, retry
                          no : UNRESOLVED (fail closed)
```

可自动补仓的证据类型：

- 缺文件/目录/Make include/Android.bp namespace，能由 full manifest 唯一最长路径匹配；
- `depends on undefined module`，能由 canonical seed 的 module index 唯一映射到 project；
- 缺 host executable/prebuilt，能由 canonical seed 的 action input 映射；
- product config 或 generated source 路径能唯一映射。

每次事件必须记录 `iteration`、原始 stderr 摘要和完整 log digest、resolver 类型、project name/path、locked SHA、witness、前后 closure digest。

以下一律不自动“扩大到全树”：

- 映射到多个项目、无映射、需换 revision、需要 vendor/private 权限；
- 超过 `max_iterations` / `max_added_projects`；
- compiler/link/test 功能错误而非缺仓；
- build 脚本要求联网或写只读源码；
- 目标 module 不存在或 feature 声明与真实模块名不一致。

补仓后应丢弃该轮 partial `out` 并 clean retry，避免“上轮残留产物让闭包看似成功”。

### 5.5 缓存

按风险从低到高分层：

1. **Git CAS/mirror cache**：按 remote+object id 共享 Git objects；普通 workspace 仍检出独立工作树。结合官方 partial clone 降初次网络量。不得共享一个可写 Git worktree。
2. **closure cache**：以完整 `ClosureKey` 缓存 graph、module index、lock 和证明 log；任一 key 字段变化即 miss。
3. **源码基线**：B0/B1 以只读 lower layer/reflink snapshot 共享，feature project 用独立 overlay；Android 17+ 源码只读模型与此相容。较老分支或违规生成器需要显式 version exception，不能默认开启可写全树。
4. **构建输出**：每 job 独立 `OUT_DIR`。安全默认不跨 ClosureKey 复用可写 Soong/Kati/Ninja `out`；如采用官方/企业 RBE action cache，必须把 toolchain、command、env 和所有 input digests 纳入 action key。最终 artifacts 作为 CAS 对象只读发布。

禁止仅按 `feature_id`、branch 名、module 名或当前 demo 的 `contract_sha256` 命中构建缓存。

### 5.6 版本一致性门禁

物化后、构建前必须同时验证：

- manifest repo commit、Repo tool version、closure/check-out lock digest；
- 每个 materialized project 的 `name/path/remote/HEAD` 精确等于 lock；
- mutable project 的 `base_revision` 关系和 feature commit/diff digest；若允许 dirty tree，必须连同 untracked 内容哈希进入 key，否则拒绝缓存；
- product/release_config/variant、host/container image、实际 used-env；
- 非唯一可写 project 全部只读，编译前后 `repo status`/content digest 不变；
- 无 `repo sync` 的裸调用，无 revision 浮动，无 build-stage 网络。

当前 `target_branch=dev-sidebar` 只能保留为人类工作流属性；不能替代上述 SHA 门禁。

## 6. “单仓单编”执行模型

对一个 feature 生成两类 job：

### Repo-unit job

- 请求参数：`feature lock + write_project + goals subset`。
- 只有 `write_project` overlay 可写；B0/B1/D 只读。
- 只运行该仓映射的 module goals。例如 `frameworks/base -> services`。
- 校验构建前后所有其他项目无变更。
- 这证明“该仓修改在固定依赖世界中可编译”，不证明跨仓 feature 集成。

### Feature-integration job（交付必需）

- 所有 feature project revisions 同时可见，但源码仍应在构建期间只读；运行 feature 完整 goals 和 verifier。
- 对跨仓 API/JNI/AIDL/SELinux/product package 关系做最终门禁。

如果 feature 的仓 A 修改依赖仓 B 同一 feature 中尚未合入的新 API，repo-unit job 有两种合法结果：使用一份显式 stack lock 同时看到 B 的 commit（此时“单仓”只表示写权限），或 fail 并标记 `REQUIRES_STACKED_INTEGRATION`。不得偷偷切换依赖分支。

## 7. dev-sidebar 适配性走查

### 7.1 能直接迁移的内容

- 现有 5 个 path 可直接成为 `mutable_projects` 初稿。
- 现有 `m services SidebarApp selinux_policy` 可成为目标 seeds。
- `verify-sidebar.sh` 的严格 `RESULT PASS/INCOMPLETE/FAIL` 语义可继续作为 build 之后的运行态证据；`common/.harness/features/dev-sidebar/verify-sidebar.sh:108-120` 已 fail closed。
- 当前 path/schema/唯一 verifier/parity 负例适合提升为 feature schema validator 的回归基线。

### 7.2 暴露出的缺口

1. **没有真实版本锁**：5 行都没有 project name/remote/SHA；同名 branch 检查不足。
2. **构建上下文不完整**：`<product>` 未实例化，当前 AOSP 官方 lunch 还要求 release config；SELinux closure 对 product/device/vendor 特别敏感。
3. **目标覆盖不完整**：声明修改 `frameworks/native`，但 build goals 没有明确 SidebarFlinger/native module；要么补真实 module goal，要么 closure lock 必须解释它只由 `services`/product goal 间接覆盖。当前 demo 无真实源码，无法确认。
4. **`build/make` 角色冲突**：它既是 feature mutable project 又是 B0。任何真实修改都会使共享 baseline、预计算 graph 和 out cache 失效，必须单独 baseline lane。
5. **`selinux_policy` 不是仓内局部目标**：它会聚合 product/device/vendor 策略；若目标产品依赖私有 vendor policy，本研究范围内只能 `UNRESOLVED_VENDOR_BOUNDARY`。
6. **`services` 是大粒度目标**：它会拉入大量 `frameworks/base` Java/生成/API 依赖；项目闭包可能远大于 5 个仓，但仍可能显著小于全 AOSP。
7. **应用仓是假定存在**：本 demo 不含真实 AOSP manifest，`packages/apps/SidebarApp` 的 project name、remote 和 SHA 必须在实际 platform/vendor manifest 中确认；不能只按 path 合成 remote。
8. **运行 verifier 不等于 build 证明**：现有 `--demo` 成功是 deterministic fixture，不验证 AOSP artifact。

### 7.3 建议的 job 拆分

| write project | seed goal | 特殊门禁 |
|---|---|---|
| `frameworks/base` | `services`，若改 public/System API 再加 `update-api` 流程 | API txt、AIDL、SystemServer；最终 integration |
| `frameworks/native` | **待真实源码确认的 SidebarFlinger module** | JNI/Binder/ABI；不能拿 `services` 代替 |
| `packages/apps/SidebarApp` | `SidebarApp` | platform signing/privapp/product install 由 integration 验证 |
| `system/sepolicy` | `selinux_policy` | 固定 product；vendor policy 是边界 |
| `build/make` | 由实际变更影响的 product/goal | 强制新 B0/B1/closure；禁止旧 build cache |

静态结论：该 feature **适合验证推荐架构的分层和失败边界，但不适合作为“5 仓即完整闭包”的正例**。它恰好覆盖 Soong/Make、Java/native、app、policy 和 build baseline 冲突，适合做首个端到端 closure fixture。

## 8. 验收命令草案

以下是后续实现应提供的接口草案，不声称当前仓库已存在 `feature-closure`。

### 8.1 当前 demo 的回归基线（现在可执行）

```bash
./common/.codex/bin/codex-feature --dry-run --contract
./common/.harness/bin/check-parity.sh
./common/tests/test-harness.sh
```

期望：依次 exit 0；包含 `feature=dev-sidebar`、`PARITY PASS`、`RESULT PASS`。

### 8.2 platform/closure lock

```bash
repo manifest -r -o platform.lock.xml
feature-closure lock \
  --feature .harness/features/dev-sidebar/feature.yaml \
  --platform-lock platform.lock.xml \
  --out closure.lock.json
feature-closure verify-lock closure.lock.json
```

期望：全部 exit 0；`verify-lock` 输出 `LOCK PASS <closure-digest>`；lock 中没有占位 product/release config，每个 project 为 SHA revision，每个非底座项目有 witness。

### 8.3 只同步闭包并校验版本

```bash
feature-closure emit-manifest closure.lock.json > checkout.xml
repo init --partial-clone --no-use-superproject \
  -u <locked-manifest-repository> -b <locked-manifest-revision> -m checkout.xml
repo sync -c -d -j8 $(feature-closure projects closure.lock.json)
feature-closure verify-worktree closure.lock.json
```

期望：全部 exit 0；实际 project 集合等于 lock，所有 HEAD 精确匹配；禁止没有 project-list 的 `repo sync`。生产实现可改为独立生成的 manifest repo，关键是不让 `<locked-...>` 成为运行时占位符。

### 8.4 clean parse/build 固定点

```bash
export OUT_DIR="out/closure-$(feature-closure digest closure.lock.json)"
source build/envsetup.sh
lunch "$(feature-closure lunch-target closure.lock.json)"
feature-closure network-guard -- m nothing
feature-closure network-guard -- m services SidebarApp selinux_policy
feature-closure verify-proof closure.lock.json "$OUT_DIR"
```

期望：全部 exit 0；分别输出 AOSP 成功标记和 `CLOSURE PROVEN`；构建期间无网络、无缺仓补取、无只读项目变更。第一次成功必须使用全新 `OUT_DIR`。

### 8.5 单仓写隔离

```bash
feature-closure build-repo closure.lock.json \
  --write-project frameworks/base --goal services
feature-closure assert-readonly-unchanged closure.lock.json \
  --except frameworks/base
```

期望：exit 0；输出 `REPO BUILD PASS frameworks/base services`，其他项目 content/HEAD/status 不变。

### 8.6 必测负例

```bash
feature-closure test omit-witness-project closure.lock.json
feature-closure test mutate-locked-revision closure.lock.json
feature-closure test unresolved-vendor-dependency closure.lock.json
feature-closure test exceed-expansion-budget closure.lock.json
feature-closure test build-framework-change-invalidates-cache closure.lock.json
```

期望：这些测试命令自身 exit 0，但分别确认受测构建以 `MISSING_PROJECT`、`LOCK_MISMATCH`、`UNRESOLVED_VENDOR_BOUNDARY`、`EXPANSION_LIMIT`、`CACHE_MISS_FRAMEWORK_CHANGED` fail closed；任何一个都不得自动 full sync。

### 8.7 feature 最终集成

```bash
feature-closure build-feature closure.lock.json
ANDROID_SERIAL=<explicit-safe-serial> \
  ./.harness/features/dev-sidebar/verify-sidebar.sh
```

期望：build exit 0；verifier 最后一行严格为 `RESULT PASS`。`--demo` 不可作为交付证据。

## 9. 硬边界与不变量

1. 最小集合只对完整 ClosureKey 有效；换 manifest/project SHA、product、release config、variant、host/toolchain、goal、声明环境或 extractor 即失效。
2. 构建阶段不联网、不调用裸 `repo sync`；补仓只能发生在独立 materialize/retry 阶段，且只能取 full lock 中的 exact SHA。
3. 不存在“解析错误就同步全树”回退；未知、多义、私有 vendor、预算超限均 fail closed。
4. B0 变更（尤其 `build/make`/`build/soong`/`build/blueprint`/bootstrap prebuilts）强制重算图和新 out/cache namespace。
5. 单仓是写权限/任务边界，不是物理依赖边界；跨仓 feature 必须有 integration build。
6. 第一次 closure proof 必须 fresh workspace + fresh out；旧产物、远程下载或手工 out 文件不能参与成功判定。
7. 每个非底座项目有机器可读 witness；每个失败补仓有原 stderr log digest 和 closure 变更事件。
8. 非目标项目只读；Android 17+ 不开启 `BUILD_BROKEN_SRC_DIR_IS_WRITABLE=true` 作为常态绕过。
9. vendor/BSP/专有 binary 不在通用自动求解范围；缺失时输出具体边界，不把 AOSP generic 成功外推到真机产品。
10. module build 成功只证明构建；设备交付仍需严格 verifier，且 `SKIP`/demo 不等于 PASS。

## 10. 风险与未确认项

### 高风险

- 不同 Android/vendor branch 的 graph goal、module-info 完整性和 mixed Bazel 行为不同，需要 version adapter；本报告只从官方当前/HEAD 机制证明可行性，未在 AOSP 17 实树运行。
- Soong 会加载全 module graph；缩减项目树可能因与目标无传递链接关系、但仍处于扫描/namespace/product 可见范围的 Android.bp 而失败。clean proof + audited additions 是必要保险。
- Make `$(shell)`、条件 include、生成工具和外部脚本可产生图外输入；单靠 JSON 图会漏仓。
- `build/make` feature 修改会改变 closure extractor 自身看到的世界，需先在隔离的新 baseline seed 重算，存在 bootstrap 的“鸡生蛋”运维成本。

### 中风险

- `module path -> repo project` 要用 full manifest 的规范化最长前缀并处理 copyfile/linkfile；不能简单字符串首段映射。
- partial clone 只降低 Git object 网络量，不保证模块构建时不会触发 lazy fetch；build 网络隔离前必须 prefetch closure 所需 blobs，或 materialize 阶段执行 blob completeness 验证。
- 共享 read-only lower layer/overlayfs 在不同 CI/kernel 环境的 inode、symlink、文件时间语义需原型验证；保守 fallback 是独立 checkout + Git object cache。
- 同目标的 feature commits 若未提交，dirty/untracked 内容 hashing 和复现语义需产品口径确认。

### 尚未确认（必须在真实 AOSP/目标产品上回答）

1. 目标 Android 版本/tag、manifest URL/commit、Repo 版本、host/container。
2. `dev-sidebar` 的真实 product、release config、variant 和 vendor manifest。
3. `packages/apps/SidebarApp` 是否真是独立 manifest project，及其 remote/project name。
4. SidebarFlinger 对应的真实 build module goal；当前 workflow 没列出。
5. AOSP 17 该 branch 的 `m json-module-graph`/`module-info` 输出 schema 及 Make/Bazel coverage。
6. B0 实际精确项目集；尤其所需 prebuilts、`build/blueprint`/`build/bazel` 与 external Go 库，必须由 canonical seed action inputs 得出。
7. `services`、`SidebarApp`、`selinux_policy` 在选定产品上的 project 数量/磁盘量/clean build 时间，补仓能否在建议的 8 轮/64 项目预算内收敛。
8. 企业环境是否已有 repo mirror、RBE/action cache、容器网络隔离和只读 overlay 能力。

## 11. 建议下一步最小原型

先只做 `dev-sidebar + 一个明确 AOSP 17 tag + 一个 AOSP/Cuttlefish product`：

1. 生成 full `platform.lock.xml`；
2. canonical full tree 跑 `m nothing json-module-graph module-info`；
3. 只选 `services`，实现 module/path→project witness 和 SHA-pinned `checkout.xml`；
4. 在断网 fresh workspace 做 clean `m nothing && m services`，记录每轮补仓；
5. 收敛后再加 `SidebarApp`、native 真实 goal、`selinux_policy`；最后验证 `build/make` 变更必定触发 baseline cache miss。

这个顺序先验证最难且通用的“全图解析 + 缩减证明”机制，再扩展到 app/policy/vendor 边界；不会把 demo 的五仓清单误当成已证实闭包。
