# AOSP feature 最小仓与单仓单编调研报告

## 结论

**可以做，但不能把目标定义为“物理上只有一个 Git 仓就能编译”。** Repo 支持只同步指定 project/path、manifest groups 和 reduced manifest；但 `m <module>` 只裁剪最终执行目标，Soong/Make 仍会做 product/release 配置、扫描构建文件并生成全局图。可验收的定义应为：一个 feature 只下载它的可写业务仓，加上版本锁定、只读的构建底座和经 clean build 证明的依赖闭包。出处：https://android.googlesource.com/tools/repo/+/refs/heads/stable/man/repo-sync.1（获取于 2026-09-01）；https://source.android.com/docs/setup/build/building（获取于 2026-09-01）；research/raw/agent-aosp-soong.md。

**当前 harness 还做不到这一点。** 它已能用 feature 选择 `repos.tsv`、`workflow.md` 和唯一 verifier，并对已存在 Git 目录的分支漂移 fail closed；但 `repos.tsv` 没有 remote/project/revision、product、module goal 或依赖边，resolver 不下载源码、不求闭包、不机器选择构建器。`dev-sidebar` 的 5 仓是人工声明的可修改边界，不是可编译闭包。出处：`common/.harness/bin/resolve-feature.sh:99`；`common/.harness/bin/check-branches.sh:19`；`common/.harness/features/dev-sidebar/repos.tsv:2`；research/raw/agent-harness-mapping.md。

**推荐“完整种子树预计算 + SHA 锁 + 缩减工作区 clean-build 证明 + 有界审计补仓”。** 在一个 canonical full AOSP tree 中固定 manifest、Repo/host、product、release config、variant 和 goals，从 Soong module graph、module-info、action inputs 及 Make/product include 计算候选 Git project 闭包；生成 SHA-pinned reduced manifest，再在全新工作区、全新 `OUT_DIR` 且编译阶段断网的条件下跑 `m nothing` 和目标构建。只有能唯一映射到已锁定 project 的 missing path/module/tool 才允许补仓，超额、多义、vendor/private 依赖一律 fail closed。出处：https://android.googlesource.com/platform/build/soong/+/refs/heads/android17-release/ui/build/soong.go（获取于 2026-09-01）；https://android.googlesource.com/platform/build/+/HEAD/core/tasks/module-info.mk（获取于 2026-09-01）；research/raw/agent-minimal-closure-design.md。

**构建底座不能硬编码成永久不变的几个仓。** Android 17 标准 combined `m` 路径的起始集至少涉及 `build/make`、`build/soong`、`build/blueprint`、`build/release`、host Go/JDK/build-tools、部分 bootstrap Go 依赖和 `system/core`；但精确集合还会随 Android revision、host、product、语言/模块类型改变。所以应拆为可共享的 B0 bootstrap baseline、B1 product baseline、feature 可写 overlay 和 target dependency closure，并把所有维度纳入 cache key。出处：https://android.googlesource.com/platform/build/soong/+/refs/heads/android17-release/scripts/microfactory.bash（获取于 2026-09-01）；https://android.googlesource.com/platform/build/+/refs/heads/android17-release/core/main.mk（获取于 2026-09-01）；research/raw/agent-aosp-soong.md。

**“单仓单编”应实现为 repo-unit job，不应取代 feature integration job。** repo-unit job 只允许一个 project overlay 可写，依赖和底座全部只读，只构建该仓对应 goals，并校验其他 project 未变。它只证明该仓修改在固定依赖世界中可编译；像 `dev-sidebar` 这样同时跨 framework service、native、app、product 和 SELinux 的 feature，交付前仍必须跑所有 feature commits 同时可见的 integration build 和设备 verifier。出处：`codex/features/dev-sidebar/AGENTS.md:31`；`common/.harness/features/dev-sidebar/verify-sidebar.sh:108`；research/raw/agent-minimal-closure-design.md。

**`dev-sidebar` 适合做首个闭包原型，但不能把当前 5 仓当成正例答案。** 它已给出 `services SidebarApp selinux_policy` 三个 seed goals，但 `frameworks/native` 没有明确 native goal，`<product>` 仍是占位符，`build/make` 同时是 feature 可写仓和 bootstrap baseline，`selinux_policy` 又强依赖 product/device/vendor 上下文。第一个原型应先锁定一个 AOSP 17 tag 和 Cuttlefish product，只对 `services` 生成与证明 reduced closure，再逐步加 app、native、policy 和 build baseline 变更。出处：`common/.harness/features/dev-sidebar/workflow.md:7`；`common/.harness/features/dev-sidebar/repos.tsv:2`；research/raw/agent-minimal-closure-design.md。

## 未解决冲突

- 当前 workflow 使用 `lunch <product>-userdebug`，而 Android 17 官方形式是 `product-release_config-variant`；尚未知道 harness 实际要锁定哪个 product/release config。出处：`common/.harness/features/dev-sidebar/workflow.md:8`；https://source.android.com/docs/setup/build/building（获取于 2026-09-01）。
- `repos.tsv` 声明 `frameworks/native` 是 feature 影响仓，但 workflow 没有 SidebarFlinger 或其他 native module goal；尚无真实业务源码可确认它是被传递构建还是构建目标漏配。出处：`common/.harness/features/dev-sidebar/repos.tsv:3`；`common/.harness/features/dev-sidebar/workflow.md:9`。

## 我没能确认的

- 没有目标 Android tag/manifest commit、真实 product、release config、host/container 和 vendor manifest，因此还不能给出 `dev-sidebar` 的精确 Git project 数量、磁盘体积和 clean-build 时间。
- demo 没有真实 SidebarApp、SidebarFlinger 和 SidebarService 源码，无法确认真实 module 名、manifest project 映射、generated/API 依赖和 native goal。
- 尚未在 AOSP 17 真实树上验证 `json-module-graph`/`module-info` 对该 product 的 Soong、Make 与 mixed Bazel 覆盖率，也未验证补仓能否在拟定预算内收敛。
- 尚未确认企业环境是否已有 Repo/Git mirror、RBE/action cache、断网构建和只读 overlay 能力；这些会影响原型的实现顺序，不改变上述可行性结论。

## 原始证据

- `research/raw/agent-harness-mapping.md`
- `research/raw/agent-aosp-soong.md`
- `research/raw/agent-minimal-closure-design.md`
