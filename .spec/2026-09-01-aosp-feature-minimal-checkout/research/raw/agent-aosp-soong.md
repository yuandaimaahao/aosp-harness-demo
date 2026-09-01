# AOSP feature 最小源码 checkout：Repo / Manifest 与 Soong / Make 依赖闭包调研

- 调研日期：2026-09-01（Asia/Shanghai）
- 调研范围：AOSP `android-latest-release` 在本日解析到的 `android17-release`；Repo stable/HEAD；Soong/Make 官方源码与 `source.android.com`
- 资料约束：只采用 AOSP/Repo 官方一手资料（`source.android.com`、`android.googlesource.com`）；未采用博客、论坛或搜索结果二次解读
- 核心问题：能否只下载某 feature 所需 Git 单仓与编译框架；哪些公共仓不可避免；为何无法在下载前纯静态、普适地求出完备依赖闭包

## 结论摘要

1. **技术上可以做 reduced manifest，但不存在“任意 feature 一键求最小 Git 仓集合”的官方通用能力。** Repo 支持按 project/path 同步、按 manifest group 过滤，也允许自建/分层 manifest；Soong 源码还明确承认 `aosp_kernel-build-tools` 一类 reduced manifest 分支。可是这些机制只负责“下载哪些 Git project”，不会从一个 Soong/Make module 自动反推出跨仓闭包。
2. **`m <module>` 是构建目标裁剪，不是源码发现/配置裁剪。** 当前构建驱动先做 product/release config，递归发现源码树中的 `Android.bp`，生成 Soong 图；Linux 的标准 Make/Kati 路径还会加载发现到的 `Android.mk`，再把 Kati 与 Soong Ninja 图合并。即使 `m nothing` 不执行模块编译，也会解析、校验构建结构。
3. **可落地方案是“固定分支 + 固定 product/release/host + 从完整参考树生成候选闭包 + 在全新 reduced checkout 中验证”，而不是只看 feature 仓的 `Android.bp`。** 公共底座至少包含构建入口/Soong/Blueprint/release 配置、对应主机的 Go/JDK/Build Tools，以及当前 bootstrap 直接引用的少量外部 Go 仓；标准 `m`/Kati 路径在 Android 17 还直接依赖 `system/core`。其余仓由 feature 语言、模块类型、product、分区、接口及生成工具决定。

## 一、Repo / manifest 能裁剪什么

### 1. Repo 确实支持只同步列出的 project

Repo stable 的 `repo sync` 手册说明：命令行列出的项目可用 project name、相对路径或绝对路径指定；不列项目时才同步 manifest 中全部项目。因此以下两类动作是合法的：

```sh
repo sync build/make build/soong path/to/feature
# 或维护一份只含候选 project 的独立 manifest 后执行普通 repo sync
```

manifest 的 `<project>` 是 Git 仓级别的下载单元，`path` 决定它在工作树中的位置；`groups` 和 `repo init -g`/`repo sync -g` 可过滤项目。每个项目还隐式属于 `all`、`name:<name>`、`path:<path>` 等组。`remove-project` 允许在分层/本地 manifest 中移除上游项目。

**边界：** group 只有在 manifest 作者已按目标维度标注时才有价值。AOSP 默认 manifest 常见的是 `pdk`、`tradefed`、host 平台或设备组，并没有“每个 feature 一个 group”的保证。

### 2. `--partial-clone` 不是 Git project 裁剪

官方 AOSP 下载文档推荐：

```sh
repo init --partial-clone --no-use-superproject \
  -b android-latest-release \
  -u https://android.googlesource.com/platform/manifest
repo sync -c -j8
```

同步排错文档把 partial clone 解释为 Git objects 按需下载。因此它降低 blob/object 传输量，但并不自动把 1,000 多个 manifest project 变成一个 feature 的仓级闭包。若目标是少 checkout Git 仓，必须使用 project list、groups，或维护 reduced manifest；不能只加 `--partial-clone`。

### 3. 本日默认 manifest 的量级与分支解析

抓取 `platform/manifest` 的 `android-latest-release/default.xml` 得到：

- `<default revision="android17-release">`；
- 共有 1,087 个 `<project>` 元素（这是 XML 快照计数，不等于考虑 host/group 后一定 checkout 的精确数量）；
- 顶部直接列出 `build/make`、`build/blueprint`、`build/release`、`build/soong`；
- `build/make` 通过 `linkfile` 提供顶层 `build/envsetup.sh`、`build/core` 等；`build/soong` 通过 `linkfile` 提供顶层 `Android.bp` 与 `bootstrap.bash`。

这说明 AOSP 的“标准支持路径”仍是默认 manifest 全量同步。Repo 提供裁剪能力，不等于 AOSP 官方为任意 feature 发布或承诺一份最小 manifest。

## 二、标准 `m` 构建的 bootstrap 与 module 单编

### 1. 入口不是直接运行某仓里的编译器

官方 Build Android 文档要求先：

```sh
source build/envsetup.sh
lunch <product>-<release>-<variant>
m <module-name>
```

文档明确说 module name 可作为 `m` 参数单独构建；同时给出 `m nothing` 的语义：不构建产物，但会解析并校验 build structure。这已经表明 module 单编仍依赖全局构建初始化。

`build/make/envsetup.sh` 的当前源码进一步显示：在 AOSP 顶层存在 `build/soong/soong_ui.bash` 时，Make 命令实际转交给 `soong_ui.bash --make-mode`。

### 2. Soong bootstrap 的实际链路

`build/soong/ui/build/soong.go` 的官方注释给出三步 bootstrap：

1. `microfactory` 先编译自己和 `soong_ui`；
2. 简化版 `soong_build` 读取描述自身的 Blueprint 文件，生成 `.bootstrap/build.ninja`；
3. `soong_ui` 执行该 bootstrap Ninja，产生完整 Soong builder 与最终 Ninja 图；之后 Kati 再解析 Makefile。

`soong_ui.bash` 与 `scripts/microfactory.bash` 把这条链落实为源码路径：

- `GOROOT` 固定到树内对应 host 的 `prebuilts/go/...`；
- `BLUEPRINTDIR=${TOP}/build/blueprint`；
- package 路径直接引用 `build/soong`、`build/make/tools/rbcrun`、`prebuilts/bazel/common/proto`、`external/golang-protobuf`、`external/starlark-go`、`external/pogreb`；
- 启动脚本编译 `soong_ui`、`mk2rbc`、`rbcrun`、`release-config`。

所以“feature Git 仓 + `build/soong` 一个仓”并不足以启动当前 Android 17 的标准构建。

### 3. Product config、Soong、Kati、Ninja 的先后关系

`ui/build/build.go` 显示构建驱动先执行 product config，随后重新计算运行阶段；源码注释直接指出其后的工作都依赖 product config。正常路径再依次：

1. `runSoong` 生成 Soong Ninja；
2. `runKatiCleanSpec` / `runKatiBuild` / `runKatiPackage` 生成 Make/Kati Ninja；
3. 创建 combined Ninja；
4. Ninja 执行选中的目标及依赖。

`platform/build` README 也说明迁移期全部 Makefile 由 Kati 读取并生成 Ninja，再与 Soong 的 Ninja 合成一个图。

### 4. `m <module>` 为什么仍看全树

Android 17 的 `ui/build/finder.go`：

- 从 `.` 递归查找全部 `Android.bp`，写入 `out/.module_paths/Android.bp.list`；
- 查找顶层 `Android.mk` 集合，写入 `Android.mk.list`；
- 还扫描 `device/`、`vendor/`、`product/` 下的 `AndroidProducts.mk`，以及 release config maps 等配置文件。

顶层 `build/soong/root.bp` 甚至专门写明：Soong 会找到源码树里的全部 `Android.bp`，旧式 `subdirs` 列表已不再需要。

Linux 标准 Make 路径中，`build/make/core/main.mk` 默认把 `Android.mk.list` 加入 `subdir_makefiles` 并逐个 `include`。只有 product 显式设置 `PRODUCT_IGNORE_ALL_ANDROIDMK=true` 并提供 allowlist 时才收窄；这不是任意 feature 自动获得的行为。

因此，`m Foo` 的“单编”发生在图已配置/加载之后：Ninja 最终只执行 `Foo` 及其目标依赖，但前端不只读取 `Foo` 所在 Git 仓。

## 三、公共仓：哪些不可避免

下表区分“当前 Android 17 标准 combined `m` 路径的底座”和“随 feature/product 变化的仓”。不存在脱离 host、product、release、模块类型的唯一精确清单。

| 层级 | 当前 Android 17 候选必需仓/类别 | 一手依据与限定 |
|---|---|---|
| Repo 元数据 | `platform/manifest` 与 Repo client | 决定 Git project 到工作树 path/revision 的映射；不是模块编译产物的一部分，但 checkout 必需。使用 `--no-use-superproject` 时 superproject 不是必需。 |
| 构建入口/Make | `platform/build` → `build/make` | 提供 `envsetup.sh`、`build/core`、product config、`rbcrun` 路径及 Kati 主 Makefile。标准 `m` 必需。 |
| Soong/图引擎 | `platform/build/soong`、`platform/build/blueprint` | `soong_ui`、`soong_build`、module/mutator 逻辑与 Blueprint bootstrap。 |
| Release 配置 | `platform/build/release` | 当前 Make release config 默认直接指向 `build/release/release_config_map.textproto`；Android 17 默认 manifest 单列此仓。vendor/device 还可贡献额外 map。 |
| Bootstrap Go 依赖 | host 对应的 `prebuilts/go/...`，以及 `external/golang-protobuf`、`external/starlark-go`、`external/pogreb`、`prebuilts/bazel/common` | `microfactory.bash` 的 `GOROOT` 与 package-path 显式引用。不同 host 选择不同 Go prebuilt。 |
| Kati/Ninja 工具 | `prebuilts/build-tools` | `ui/build/config.go` 的 `KatiBin()` / `NinjaBin()` 最终从 `prebuilts/build-tools/<host>/bin` 取 `ckati`/`ninja`。 |
| Java 运行环境 | 默认 `prebuilts/jdk/jdk21`，某些配置用 `jdk25` | `ConfigJavaEnvironment` 把 OpenJDK 21 设为全局默认，`useJdk25` 时切到 25；确切选择受 release/build config 影响。JDK 8 是额外兼容路径，不应无条件算入每个最小闭包。 |
| 标准 Make/Kati 的跨仓硬引用 | `system/core` | Android 17 `build/make/core/main.mk` 非 optional 地 `include system/core/rootdir/create_root_structure.mk`。若使用正常 `m --make-mode`，即便目标 feature 不在 `system/core`，候选 checkout 也要含它；真正的 `--soong-only` 专用构建可改变这一结论。 |
| 语言/模块类型工具链 | 例如 C/C++ 的 `prebuilts/clang/host/...`、Java/Kotlin、Rust、AIDL、资源打包、APEX/SELinux 工具仓 | 由 feature 的 module type 与 action 决定，不能统一删除。当前驱动还无条件设置树内 clang symbolizer 路径，但是否实际执行 clang 取决于动作。 |
| Product/board/device | 对应 `device/...`、`product/...`、`vendor/...` 及其继承/配置引用 | `lunch` 必须先确定目标；finder 与 product config 会扫描/加载这些树。用 unbundled/host-only/reduced product 可显著减少，但必须为具体目标验证。 |
| Feature 的模块闭包 | feature 仓 + 被引用模块、defaults、filegroup、生成器、接口、headers、runtime/required 模块所在仓 | Soong 名称依赖与 Git project 没有一对一索引；需要在固定配置的完整图中求闭包，再映射回 manifest path。 |

一个很有价值的官方参照是 `platform/prebuilts/build-tools` 在 `android-17.0.0_r1` 自带的 `manifest.xml`：它记录了 133 个 project，不仅有四个 build 仓和 toolchain prebuilts，还包括大量 `external/`、`system/`、`bionic`、`art` 等。它**不是“任意 feature 的推荐最小 manifest”**，但直接说明即使目标只是产出 Android build tools，真实源码闭包也远大于“`build/soong` 单仓”。

## 四、为什么下载前难以纯静态、完备地求闭包

### 1. Repo 的图是 Git 仓布局图，不是 module 依赖图

manifest 只描述 project 的 `name/path/revision/groups`。一个 Git project 可含许多 module，一个 module 可按名称依赖其他任意路径下的 module。Repo 不理解 `shared_libs`、`static_libs`、`defaults`、`required`、生成工具或 product packages，因此不能从 `repo sync feature/path` 自动补齐模块依赖仓。

### 2. 在看到所有定义前，名称解析本身可能不完备

Soong README 规定 module name 在相应 namespace 中解析；全局名、namespace imports、`//scope:name` 都可能把依赖指向另一仓。finder 又是先递归收集工作树中的 `Android.bp`。若定义所在仓从未 checkout，它不会出现在待解析列表中；通常只能在图生成时表现为 missing dependency，而不是在 Repo 下载阶段被自动发现。

### 3. 依赖由 Go mutator 动态增加、替换、分裂

`android/mutator.go` 暴露并实际使用：

- `AddDependency` / `AddVariationDependencies` / reverse dependencies；
- `ReplaceDependencies`；
- `CreateModule`；
- 按 arch、OS、image、APEX 等创建 variants。

Soong README 的关键语义是：`Android.bp` 自身没有普通控制流，复杂性在 Go build logic 中处理。也就是说，只做 Blueprint 文本扫描会漏掉 module type 的隐式依赖、自动生成模块、variant 选择和 prebuilt/source 替换。

### 4. Product / release / vendor 配置改变属性与模块集合

当前 Soong 支持按 `arch`、product variable、release flag 和 `soong_config_variable` 选择属性；vendor 的值可由 `BoardConfig.mk` 设置。被选择的 `srcs`、defaults、libraries、tools 因 `TARGET_PRODUCT`、`TARGET_RELEASE`、架构、分区或 vendor config 不同而变化。

Make 一侧还有 `ifeq/ifneq`、变量展开、`wildcard`、`include/-include`、`$(shell ...)` 和 product inheritance。Android 17 的 release config 本身就会按 device/vendor 下存在的 map 文件与 `PRODUCT_RELEASE_CONFIG_MAPS` 改变输入。未固定产品和配置时，不存在单一闭包。

### 5. required/runtime/打包依赖不等于显式编译链接依赖

Soong 的 `required`、`target_required`、`host_required` 会在 mutator 中加入依赖；Make 还在读完全部 module makefiles 后解析 required modules。只抓 `shared_libs`/`static_libs` 会漏掉打包、安装、证书、VINTF、APEX、生成器和 host tool 依赖。

### 6. 官方 reduced-manifest 源码案例正好证明边界

Android 17 `android/module.go` 的注释描述 `aosp_kernel-build-tools`：该 reduced manifest 没有 `external/bouncycastle`；顶层 `build_image` 的 `required` 链经 `boot_signer` 到 `bouncycastle-unbundled`，从而构建失败。源码随后直言 Soong 无法正确判断自己是否运行在 reduced manifest，只能用缺少 DeviceArch/DeviceName 作强信号，并在这种情况下跳过一部分 required/VINTF 依赖。

这既证明 reduced manifest 可存在，也证明它需要专用构建模式/代码豁免；不能据此推导“所有 feature 都能安全只取静态显式依赖”。`ALLOW_MISSING_DEPENDENCIES` 也只是允许图继续生成/用错误规则占位，不代表得到可执行、可发布的完整构建。

## 五、建议的可验证实现流程

1. **固定维度：** pin manifest revision（最好 `repo manifest -r`）、host OS/arch、`TARGET_PRODUCT`、`TARGET_RELEASE`、variant，以及精确 module goal。不同维度分别有闭包，不能混为一个“最小集”。
2. **准备完整参考 checkout：** 按官方默认 manifest 同步一次，运行 `m nothing` 和 `m <feature-module>`，确认基线可构建。
3. **取得配置后的 Soong 图：** 当前 Soong bootstrap 有 `json-module-graph` factory，会输出 `out/soong/module-graph.json` 与 `module-actions.json`。从目标 module 做正向依赖闭包，并收集 action inputs/tools/source paths。
4. **补 Make/product/硬编码输入：** Soong JSON 图不覆盖全部 Kati/product 语义；审计 `Android.mk.list`、product inheritance、release config maps、`PRODUCT_PACKAGES`/`required`、主 Makefile 的跨仓 include，以及目标镜像/打包动作。
5. **映射到 Git project：** 用 pinned manifest 的 `<project path>` 最长前缀把已收集源码路径映射回 project。加入本报告“公共底座”以及对应 product/toolchain 仓。
6. **生成独立 reduced manifest：** 推荐把它版本化并 pin SHA；若只是临时实验，也可用 `repo sync <project-list>`。不要把 `--partial-clone` 当作仓裁剪。
7. **从空目录验收：** 只用 reduced manifest 重新 `repo init/sync`，依次跑 `source build/envsetup.sh`、固定 `lunch`、`m nothing`、`m <feature-module>`；如果交付物涉及安装/镜像/APEX，再验证对应打包目标和测试。必须从 clean out 验证，避免完整树/旧产物掩盖缺仓。
8. **把 missing dep 当反馈，不当求解器：** 每次补仓都记录触发链；最终把 manifest 与分支一起维护。AOSP 构建逻辑或产品配置变化后需要重新求闭包。

可接受的目标通常不是数学意义“最小”，而是：**在固定配置和验收目标下，clean checkout 可重复通过、且留有少量稳定公共仓余量的最小维护集。**

## 六、资料冲突与解释

| 表面冲突 | 解释 |
|---|---|
| 官方下载页让用户同步默认完整 source tree；Repo 手册却允许只同步 project list。 | 前者是 AOSP 支持的通用上手/整机路径，后者是 Repo 的底层 SCM 能力。Repo 能少下仓，不保证 AOSP 任意 product/module 在少仓下成立。 |
| `Android.bp` “没有 conditionals/control flow”；本报告却说闭包动态。 | Blueprint 文件语法保持声明式，但 Go module logic、mutators、select/product/soong config、variant 选择会在配置后改变依赖与动作；Make 仍有完整条件语义。 |
| reduced manifest 在官方源码中真实存在；Soong 又说不能正确识别 reduced manifest。 | reduced manifest 是为特定目标人工设计的产品/分支，并可能带专门的 `--soong-only` 路径或豁免；不是通用自动推导能力。 |
| `m <module>` 被称作单模块构建；finder 却扫描全部 `Android.bp`。 | “单模块”指最终 build goal，不代表只解析该目录/仓。官方 `m nothing` 的说明也把图解析与实际编译分开。 |

## 七、未确认项 / 需要具体 feature 后才能回答

1. 未给出 feature module 名称、所在分支/tag、目标 product/release/host，因此本报告不能列出 feature-specific Git project 精确闭包。
2. `jdk21` 与 `jdk25` 的最终选择依赖 Android 17 的 release/build flag；本报告只确认源码中的默认与切换分支，没有替某个未指定 target 运行 product config。
3. `--soong-only`、unbundled app/APEX、host-only、kernel/build-tools 等专用目标可进一步减少 Make/product/system 仓，但是否符合该 feature 的交付物尚未确认。
4. Soong JSON module graph 能覆盖配置后的 Soong module/action 图，但不能单独证明 Make/product/打包闭包完备；需要 clean reduced checkout 验收。
5. 未发现 AOSP 官方提供“输入任意 module，输出可直接同步的最小 repo manifest”的命令或稳定接口；此结论是对所列官方文档/源码的检索结果，不是官方对所有未来版本的否定声明。

## 八、一手资料索引（均获取于 2026-09-01）

1. **AOSP：Download the Android source**  
   URL: https://source.android.com/docs/setup/download  
   要点：官方默认 `repo init --partial-clone ... android-latest-release` 后执行无 project list 的 `repo sync -c -j8`；manifest 决定各 Git project 的工作树位置。

2. **AOSP：Troubleshoot and fix sync issues / partial clone**  
   URL: https://source.android.com/docs/setup/download/troubleshoot-sync  
   要点：partial clone 是 Git objects 按需下载，不能直接等同于 project 级最小 checkout。

3. **AOSP：Build Android**  
   URL: https://source.android.com/docs/setup/build/building  
   短摘：`m nothing` 会“parses and validates the build structure”；`m <module>` 可指定 module，但仍从树顶构建。

4. **Repo stable：repo sync manual**  
   URL: https://android.googlesource.com/tools/repo/+/refs/heads/stable/man/repo-sync.1  
   要点：命令行可列 project name/path；未列出时同步 manifest 中所有项目；`-g` 可临时按 groups 过滤。

5. **Repo HEAD：Manifest Format**  
   URL: https://android.googlesource.com/tools/repo/+/HEAD/docs/manifest-format.md  
   短摘：manifest 描述“directories that are visible and where they should be obtained”；记录 project/groups/linkfile/remove-project/local manifest 语义。

6. **AOSP manifest：android-latest-release/default.xml**  
   URL: https://android.googlesource.com/platform/manifest/+/refs/heads/android-latest-release/default.xml  
   要点：本日解析到 `android17-release`；快照含 1,087 个 project 元素；确认本文列出的 build/prebuilt/external 公共仓路径。

7. **Soong Android 17 README**  
   URL: https://android.googlesource.com/platform/build/soong/+/android17-release/README.md  
   短摘：`Android.bp` 无普通控制流，复杂性由 Go build logic 处理；说明 namespace、Soong config variables、build logic 生成 Ninja rules。

8. **Soong Android 17 bootstrap driver**  
   URL: https://android.googlesource.com/platform/build/soong/+/refs/heads/android17-release/ui/build/soong.go  
   要点：microfactory → 简化 soong_build → `.bootstrap/build.ninja` → 完整 Soong/Ninja；源码还定义 JSON module graph/action 输出。

9. **Soong Android 17 startup scripts**  
   URLs:  
   - https://android.googlesource.com/platform/build/soong/+/refs/heads/android17-release/soong_ui.bash  
   - https://android.googlesource.com/platform/build/soong/+/refs/heads/android17-release/scripts/microfactory.bash  
   要点：确认树内 Go、Blueprint、protobuf/Starlark/pogreb/Bazel proto 与 `rbcrun` 的直接 bootstrap 路径。

10. **Soong Android 17 build orchestration / source finder**  
    URLs:  
    - https://android.googlesource.com/platform/build/soong/+/refs/heads/android17-release/ui/build/build.go  
    - https://android.googlesource.com/platform/build/soong/+/refs/heads/android17-release/ui/build/finder.go  
    - https://android.googlesource.com/platform/build/soong/+/refs/heads/android17-release/root.bp  
    要点：product config 先行；递归收集 `Android.bp`/`Android.mk`/product/release config；Soong 根文件确认全树发现。

11. **Soong Android 17 mutator 与 reduced manifest 特例**  
    URLs:  
    - https://android.googlesource.com/platform/build/soong/+/refs/heads/android17-release/android/mutator.go  
    - https://android.googlesource.com/platform/build/soong/+/refs/heads/android17-release/android/module.go  
    要点：mutator 可动态新增/替换/变体化依赖与创建 module；`aosp_kernel-build-tools` 注释给出缺仓导致 required 链失败，并写明无法正确判断 reduced manifest。

12. **Make Android 17 build core / README / release config**  
    URLs:  
    - https://android.googlesource.com/platform/build/+/refs/heads/android17-release/core/main.mk  
    - https://android.googlesource.com/platform/build/+/refs/heads/android17-release/README.md  
    - https://android.googlesource.com/platform/build/+/refs/heads/android17-release/core/release_config.mk  
    要点：Kati 加载 Make module rules 并与 Soong Ninja 合并；当前主 Makefile直接 include `system/core/rootdir/create_root_structure.mk`；release map 受 product/device/vendor 文件影响。

13. **Soong Android 17 tool paths / Java config**  
    URL: https://android.googlesource.com/platform/build/soong/+/refs/heads/android17-release/ui/build/config.go  
    要点：`ckati`/`ninja` 来自 `prebuilts/build-tools/<host>/bin`；JDK 21 为全局默认，配置可切换 JDK 25；设置 clang symbolizer 路径。

14. **Android 17 build-tools recorded manifest**  
    URL: https://android.googlesource.com/platform/prebuilts/build-tools/+/refs/tags/android-17.0.0_r1/manifest.xml  
    要点：官方 build-tools 产物记录的源码 manifest 含 133 个 project，用作“构建框架自身也有宽依赖面”的一手参照；不是任意 feature 的推荐 manifest。

15. **Build release Android 17 tree**  
    URL: https://android.googlesource.com/platform/build/release/+/refs/heads/android17-release  
    要点：确认 `release_config_map.textproto`、release configs、flag declarations/values 等由独立 Git project 提供。

## 九、搜索 / 抓取命令与结果摘要

所有命令工作目录均为仓库根；只读网络抓取，未 checkout AOSP 巨型源码树。

```sh
# 1. 解析本日 android-latest-release 与 project 数量
curl -fsSL 'https://android.googlesource.com/platform/manifest/+/refs/heads/android-latest-release/default.xml?format=TEXT' \
  | base64 -d | awk '/<project /{n++} END{print n}'
# 结果：1087；pipeline exit 0。default revision 为 android17-release。

# 2. 核对 bootstrap 直接引用的公共 project 都存在于默认 manifest
curl -fsSL '<同上 URL>' | base64 -d \
  | rg '<project path="(build/(make|blueprint|release|soong)|prebuilts/(go/linux-x86|build-tools|bazel/common|jdk/jdk21|jdk/jdk25|clang/host/linux-x86)|external/(golang-protobuf|starlark-go|pogreb))"'
# 结果：列出的 13 个 project 均命中；exit 0。

# 3. 抓 bootstrap 路径
curl -fsSL 'https://android.googlesource.com/platform/build/soong/+/refs/heads/android17-release/scripts/microfactory.bash?format=TEXT' \
  | base64 -d | sed -n '20,95p'
# 结果：得到 GOROOT、BLUEPRINTDIR、六个 EXTRA_ARGS pkg-path 和 source build_go；exit 0。

# 4. 抓全树发现与 Make include 行为
curl -fsSL 'https://android.googlesource.com/platform/build/soong/+/refs/heads/android17-release/ui/build/finder.go?format=TEXT' \
  | base64 -d | sed -n '145,255p'
curl -fsSL 'https://android.googlesource.com/platform/build/+/refs/heads/android17-release/core/main.mk?format=TEXT' \
  | base64 -d | sed -n '245,310p'
# 结果：确认 Android.bp/Android.mk/product/release map 收集、Kati include 列表与 system/core 直接 include；exit 0。

# 5. 抓 reduced manifest 特例
curl -fsSL 'https://android.googlesource.com/platform/build/soong/+/refs/heads/android17-release/android/module.go?format=TEXT' \
  | base64 -d | rg -n -C 8 'reduced manifest|fullManifest|AllowMissingDependencies'
# 结果：命中 aosp_kernel-build-tools / bouncycastle 缺仓链和 Soong 无法正确识别 reduced manifest 的注释；exit 0。

# 6. 统计官方 Android 17 build-tools recorded manifest
curl -fsSL 'https://android.googlesource.com/platform/prebuilts/build-tools/+/refs/tags/android-17.0.0_r1/manifest.xml?format=TEXT' \
  | base64 -d | awk '/<project /{n++} END{print n}'
# 结果：133；exit 0。
```

联网搜索工具还执行了仅限官方域名的检索，主题包括：Repo sync project list/groups、manifest format/local manifests、AOSP download/build、Soong finder/mutator/module graph、Android 17 release config 与 build-tools manifest。结果均回到本节资料索引中的官方页面或源码。

### 保留的抓取错误

- 请求 `https://android.googlesource.com/platform/build/soong/+/refs/heads/android17-release/docs/perf.md?format=TEXT` 返回 HTTP 400，`curl` exit 22、pipeline exit 1；因此没有把旧分支搜索结果中“always loads the entire module graph”的 perf 文档句子当作 Android 17 证据。全树发现结论改由 Android 17 `ui/build/finder.go`、`root.bp` 和官方 `m nothing` 文档直接支持。
- 一次循环抓取 `ui/build/release_config.go` 返回 HTTP 404；该文件名在 Android 17 不存在。release config 结论改由实际存在的 `build/make/core/release_config.mk`、`build/release` 仓与 Soong `config.go/build.go` 支持。
- 个别 `curl | rg -m` 探索命令出现 `curl: (23) Failure writing output to destination`，原因是下游 `rg -m` 提前关闭管道；相同文件随后用 `sed`/不提前关闭的管道重新抓取并得到 exit 0，不视为来源不可达。
