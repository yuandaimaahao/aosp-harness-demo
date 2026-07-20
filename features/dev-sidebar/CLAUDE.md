<!-- DEMO · 启动前同步 + 单文件 —— 这是《AOSP 整机源码 Harness 工程探索》的 feature 上下文示例。
     真实环境里 <AOSP_ROOT>/CLAUDE.md 是指向本文件的软链；.claude/bin/claude-feature 在 Claude 启动前选定它。
     整个 feature 的上下文都在这一个文件里：树级 bootstrap/硬约束 + feature 总览 + 各仓约定。
     SessionStart 只做幂等检查和恢复告警，不承担首次加载顺序保证。 -->

# 树根 CLAUDE.md（① 上下文层 · 启动前同步）

本文件 = 树级固定内容 + 当前 feature 上下文。换 feature 后使用 `.claude/bin/claude-feature` 启动，让 wrapper 在 Claude 读取项目 memory 前把根软链切到 `features/<分支>/CLAUDE.md`。

## 编译（agent 默认会做错的地方）

- envsetup 必须用 **bash**（工具默认 shell 可能是 zsh），且 **source 后不能接 pipe**（函数会进子 shell）：

```bash
bash -c 'source build/envsetup.sh >/dev/null 2>&1 \
  && lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 \
  && m services' > /tmp/build.log 2>&1 &   # 后台 + 日志轮询，看到 build completed successfully 才算完
```

- **一切编译必须后台跑 + 轮询日志**：前台命令有超时上限，单编模块十几分钟起步。
- lunch 目标是三段式 `product-release-variant`，release 段如 `trunk_staging`（可从 `out/soong.log` 的 `TARGET_RELEASE=` 反查）。

## 硬约束（主代理和会修改代码的代理必须遵守）

| 硬约束 | 防的是什么 |
|---|---|
| 不向任何 gerrit project 提交 harness/上下文文件（CLAUDE.md/.claude/features/ 等） | 知识污染上游 |
| 不配任何 LSP（clangd/jdtls/Eclipse/aidegen）、禁生成 Eclipse 工程文件、禁建 compdb | 吃内存 + 写坏树（Eclipse 残留的 .aconfig 被 soong glob 到会构建失败）；索引在整机树规模下建不完，会给出不完整却不自知的引用结果 |
| 改 public/System API 后必须 `m update-api` | 否则 checkapi 挂构建 |
| 新增系统服务必须同步 `system/sepolicy`（service_contexts + .te） | 否则服务起不来（avc denied） |
| push framework.jar/services.jar 后注意 ART 缓存 | dexpreopt/boot image 校验不一致拖慢甚至起不来，诡异时清 `/data/dalvik-cache/` |
| 不手改 `out/` 下任何生成物 | 破坏增量构建 |

## 代码导航

- 全语言统一：`rg` + 源码阅读定位模块、符号和调用链，不准备任何索引（见硬约束：本树不配 LSP）。
- 整机树同名符号成海（`onTransact` 之流全树数百命中）。习惯：**先用路径收窄范围，再用高信息量锚点代替泛词**——跨 Java↔JNI↔native 用 JNI 注册名（如 `android_view_*`），C++ 用 `Class::method` 全限定名，二者在全树近乎唯一。
- 判断"改这个会影响谁"时，宁可要 `rg` 吵闹但完整的结果，也不要一个看起来干净、实则漏掉大半的答案。

## 子代理派发

只读 Explore/Plan 不注入整份 feature 上下文。派发时只给一张局部任务卡：

- 目标：要回答的具体问题；
- 范围：允许搜索的仓和目录；
- 关键事实：会改变结论的版本、ABI/JNI 或生成代码事实；
- 约束：只读、禁止目录或禁止动作；
- 输出：源码路径、关键函数、证据和未确认项。

只有承担代码修改、构建或部署的代理才需要相关硬约束。内建 Explore/Plan 会跳过 CLAUDE.md，因此关键范围必须写进派发 prompt。

---

# feature: dev-sidebar

**目标**：在 AOSP 17 上新增一个系统服务 + 一个常驻边栏应用。

**涉及仓**（本 feature 只动这些，清单外默认不动）：`frameworks/base`、`frameworks/native`、`packages/apps/SidebarApp`、`build/make`、`system/sepolicy`。机器可读单一事实源是本目录 `repos.tsv`（分支一致性检查读取它）。各仓 feature 约定见下方 `## 涉及仓约定`。

**一致性检查**：`./features/dev-sidebar/check-branch.sh`（涉及仓是否都在 dev-sidebar 分支）。
**验证入口**：`./features/dev-sidebar/verify-sidebar.sh`。默认只要有 SKIP 就返回 `RESULT INCOMPLETE`；探索期必须显式加 `--allow-skip`。`--demo` 为无设备演示。

## 涉及仓约定

### frameworks/base

本 feature 在此仓：新增 `services/core/java/com/android/server/sidebar/SidebarService.java`（系统服务，暴露 `ISidebar` AIDL 接口）；`SystemServer.java` 里注册（`ServiceManager.addService("sidebar", ...)`）；新增 `core/java/android/sidebar/ISidebar.aidl`（public/System API 面）。

- **改了 public/System API**（新增 `android.sidebar` 包 + AIDL）→ 必须 `m update-api`，否则 checkapi 挂构建。
- **新增系统服务** → 必须同步 `system/sepolicy`（见 `build-sepolicy` skill）。
- 编译/push/验证通用流程见 skill **`build-services-jar`**（Read `services/**` 时自动激活）：单编 `m services`、产物 `services.jar`、push 清单、ART 缓存坑。

### frameworks/native

本 feature 在此仓：新增 `services/sidebarflinger/SidebarFlinger.cpp`（native 合成侧，把边栏窗口的缩放态合成到屏幕）；注册进 SurfaceFlinger 的服务启动链。

- 纯 native（C++）：导航用 `rg`；`SidebarFlinger` 这类新符号是独特锚点，直接搜即可。
- 窗口缩放态下的 touch 事件映射若要动，属 input 链路，谨慎评估再改。
- 编译/push/验证通用流程见对应 native 编译 skill（Read `services/sidebarflinger/**` 时激活）。
