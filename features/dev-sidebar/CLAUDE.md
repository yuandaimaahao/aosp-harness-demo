<!-- DEMO · v2 软链单文件 —— 这是《AOSP 整机源码 Harness 工程探索》的 feature 上下文示例。
     真实环境里 <AOSP_ROOT>/CLAUDE.md 是指向本文件的软链；每次会话(含子代理)启动即把整份载入持久上下文。
     整个 feature 的上下文都在这一个文件里：树级 bootstrap/硬约束 + feature 总览 + 各仓约定。
     无子目录 CLAUDE.md、无 @import；SessionStart hook 按分支重指软链。 -->

# 树根 CLAUDE.md（② 上下文层 · v2 软链单文件）

本文件 = 树级固定内容（bootstrap + 硬约束，只写 agent 默认会犯的错、不写文档）+ 当前 feature 的全部上下文（总览 + 各仓约定）。换 feature 时 SessionStart hook 把树根软链重指到另一个 `features/<分支>/CLAUDE.md`。

## 编译（agent 默认会做错的地方）

- envsetup 必须用 **bash**（工具默认 shell 可能是 zsh），且 **source 后不能接 pipe**（函数会进子 shell）：

```bash
bash -c 'source build/envsetup.sh >/dev/null 2>&1 \
  && lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 \
  && m services' > /tmp/build.log 2>&1 &   # 后台 + 日志轮询，看到 build completed successfully 才算完
```

- **一切编译必须后台跑 + 轮询日志**：前台命令有超时上限，单编模块十几分钟起步。
- lunch 目标是三段式 `product-release-variant`，release 段如 `trunk_staging`（可从 `out/soong.log` 的 `TARGET_RELEASE=` 反查）。

## 硬约束（子代理也必须遵守）

| 硬约束 | 防的是什么 |
|---|---|
| 不向任何 gerrit project 提交 harness/上下文文件（CLAUDE.md/.claude/features/.clangd 等） | 知识污染上游 |
| 禁配 Java LSP / 禁生成 Eclipse 工程文件 | 吃内存 + 写坏树（Eclipse 残留的 .aconfig 被 soong glob 到会构建失败） |
| 改 public/System API 后必须 `m update-api` | 否则 checkapi 挂构建 |
| 新增系统服务必须同步 `system/sepolicy`（service_contexts + .te） | 否则服务起不来（avc denied） |
| push framework.jar/services.jar 后注意 ART 缓存 | dexpreopt/boot image 校验不一致拖慢甚至起不来，诡异时清 `/data/dalvik-cache/` |
| 不手改 `out/` 下任何生成物 | 破坏增量构建 |

## 代码导航

- C++：clangd 已配（树根 `.clangd` → feature 精简 compdb）；改了 `Android.bp/.mk`、`repo sync`、新增源文件后跑 `./gen-compdb-clangd.sh` 刷新。
- Java/Kotlin：**无 LSP**（论证过的取舍），用 Grep 搜符号 + Read；跨 Java↔JNI↔native 用 JNI 注册名（如 `android_view_*`）作 Grep 锚点。

---

# feature: dev-sidebar

**目标**：在 AOSP 17 上新增一个系统服务 + 一个常驻边栏应用。

**涉及仓**（本 feature 只动这些，清单外默认不动）：`frameworks/base`、`frameworks/native`、`packages/apps/SidebarApp`、`build/make`、`system/sepolicy`。compdb 仓集的单一事实源是本目录 `repos.tsv`（`gen-compdb-clangd.sh` 据它取标 `compdb` 的仓）。各仓 feature 约定见下方 `## 涉及仓约定`。

**一致性检查**：`./features/dev-sidebar/check-branch.sh`（涉及仓是否都在 dev-sidebar 分支）。
**验证入口**（收工前必须全 PASS）：`./features/dev-sidebar/verify-sidebar.sh`（`--demo` 为无设备演示）——编译成功 ≠ 改动正确，verify 脚本就是本 feature 的测试。

## 涉及仓约定

### frameworks/base

本 feature 在此仓：新增 `services/core/java/com/android/server/sidebar/SidebarService.java`（系统服务，暴露 `ISidebar` AIDL 接口）；`SystemServer.java` 里注册（`ServiceManager.addService("sidebar", ...)`）；新增 `core/java/android/sidebar/ISidebar.aidl`（public/System API 面）。

- **改了 public/System API**（新增 `android.sidebar` 包 + AIDL）→ 必须 `m update-api`，否则 checkapi 挂构建。
- **新增系统服务** → 必须同步 `system/sepolicy`（见 `build-sepolicy` skill）。
- 新增 `.aidl`/新源文件进模块后，compdb 结构变了 → 后台重跑 `./gen-compdb-clangd.sh`。
- 编译/push/验证通用流程见 skill **`build-services-jar`**（Read `services/**` 时自动激活）：单编 `m services`、产物 `services.jar`、push 清单、ART 缓存坑。

### frameworks/native

本 feature 在此仓：新增 `services/sidebarflinger/SidebarFlinger.cpp`（native 合成侧，把边栏窗口的缩放态合成到屏幕）；注册进 SurfaceFlinger 的服务启动链。

- 纯 native（C++）：改 `.cpp/.h` 或新增源文件进模块后 → 后台重跑 `./gen-compdb-clangd.sh`（compdb 结构变了，clangd 才不失准）。
- 窗口缩放态下的 touch 事件映射若要动，属 input 链路，谨慎评估再改。
- 编译/push/验证通用流程见对应 native 编译 skill（Read `services/sidebarflinger/**` 时激活）。
