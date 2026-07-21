<!-- 本文件是 dev-sidebar 的完整 feature 上下文。树根 AGENTS.md 由
     .codex/bin/codex-feature 在 Codex 启动前切换为指向本文件的相对软链。 -->

# AOSP 树与 dev-sidebar feature 上下文

## 树级构建约束

- `envsetup.sh` 必须在 bash 中 `source`，不要依赖调用者的默认 shell；`source` 后不要直接接管道，避免函数落入子 shell。
- 长时间构建必须在后台执行并把输出写入日志；轮询日志，只有出现 `build completed successfully` 成功标记才算构建完成。
- 不得手工编辑 `out/` 下的生成物，所有产物都必须由构建系统生成。
- 修改 public/System API 后必须运行 `m update-api`，否则 checkapi 会阻断构建。
- 新增系统服务必须同时补齐 `system/sepolicy` 中的 service context、类型和 allow 规则。
- push `framework.jar` 或 `services.jar` 后要评估 ART 缓存风险；校验不一致时，旧 dexpreopt/boot image 或 `/data/dalvik-cache/` 可能导致启动缓慢或失败。

## 源码导航

- 使用 `rg` 配合源码阅读定位模块、符号和调用链。
- 先按仓库和路径缩小范围，再搜索 JNI 注册名、全限定 `Class::method` 等高信息量锚点，避免用 `onTransact` 一类泛词扫全树。
- 这里没有建立完整索引，也不得把搜索结果描述成索引结论；影响面判断必须给出源码路径、关键符号和仍未确认的边界。

## 子代理任务卡

派发子代理时只提供完成局部任务所需的任务卡，不广播整份 feature 上下文。任务卡必须包含：

- 目标：要交付或回答的具体问题；
- 路径：允许读取或修改的仓库和目录；
- 事实：会改变结论的版本、ABI、JNI 或生成代码信息；
- 约束：禁止目录、只读要求、构建和部署限制；
- 证据：期望返回的源码位置、命令结果、验证结论和未确认项。

## feature: dev-sidebar

目标是在 AOSP 17 中新增系统服务、native 合成侧和常驻边栏应用。

允许修改的仓库只有：`frameworks/base`、`frameworks/native`、`packages/apps/SidebarApp`、`build/make`、`system/sepolicy`。机器可读清单位于 `features/dev-sidebar/repos.tsv`；开始工作前用 `./features/dev-sidebar/check-branch.sh` 检查所有涉及仓是否位于 `dev-sidebar` 分支。

### 必须遵循的流程路由

- 修改 `frameworks/base/services/**` 前必须使用 `$build-services-jar`。
- 修改 `system/sepolicy/**` 前必须使用 `$build-sepolicy`。
- 收工前必须运行 `./features/dev-sidebar/verify-sidebar.sh`；只有 `RESULT PASS` 可以作为完成证据。

### frameworks/base

新增 `SidebarService` 和 `ISidebar.aidl`，并在 `SystemServer` 注册 `sidebar` 服务。AIDL 进入 public/System API 时必须运行 `m update-api`；服务实现和 `SystemServer` 变更遵循 `$build-services-jar`。

### frameworks/native

新增 SidebarFlinger native 合成实现并接入合成服务启动链。使用唯一类名、全限定 C++ 方法和注册点导航；若触及缩放态触摸坐标映射，先明确 input 链路影响面。

### packages/apps/SidebarApp

常驻边栏应用通过 `ISidebar` 与系统服务通信。修改前确认平台签名、privapp 权限、产品安装位置及应用进程存活策略。

### build/make

仅接入 dev-sidebar 所需模块和产品配置。不要直接修改 `out/` 里的产品文件来模拟构建结果。

### system/sepolicy

为 `sidebar` 服务补齐 `service_contexts`、service type、域访问与必要 allow 规则。策略修改遵循 `$build-sepolicy`，验证时检查新的 AVC denial。
