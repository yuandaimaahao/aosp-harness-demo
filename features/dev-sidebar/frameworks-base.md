<!-- DEMO —— ② 单仓约定：只写本 feature 在 frameworks/base 里的【特有】内容。
     通用编译/push 流程不在这里写（会与 build-services-jar skill 漂移）——一句话指回 skill。 -->

# dev-sidebar × frameworks/base

## 本 feature 在这个仓改了什么

- 新增 `services/core/java/com/android/server/sidebar/SidebarService.java`
  —— 系统服务实现，暴露 `ISidebar` AIDL 接口。
- `SystemServer.java` 里注册 `SidebarService`（`ServiceManager.addService("sidebar", ...)`）。
- 新增 `core/java/android/sidebar/ISidebar.aidl`（public/System API 面）。

## feature 特有注意点

- **改了 public/System API**（新增 `android.sidebar` 包 + AIDL）→ 必须 `m update-api`，否则 checkapi 挂构建。
- **新增系统服务** → 必须同步 `system/sepolicy`（见 `build-sepolicy` skill）。
- 新增 `.aidl` / 新源文件进模块后，compdb 结构变了 → 后台重跑 `./gen-compdb-clangd.sh`。

## 编译 / push / 验证

通用流程见 skill **`build-services-jar`**（Read `services/**` 时自动激活）：单编 `m services`、
产物 `services.jar`、push 清单、ART 缓存坑。本文件不重复。
