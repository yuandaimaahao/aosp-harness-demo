<!-- DEMO —— ② 单仓约定：只写本 feature 在 frameworks/native 里的【特有】内容。
     通用编译/push 流程不在这里写（会与编译 skill 漂移）——一句话指回 skill。
     本文件由 SessionStart hook 物化成 frameworks/native/CLAUDE.md，编辑该仓文件时按需加载。 -->

# dev-sidebar × frameworks/native

## 本 feature 在这个仓改了什么

- 新增 `services/sidebarflinger/SidebarFlinger.cpp` —— native 合成侧，把边栏窗口的缩放态合成到屏幕。
- 注册进 SurfaceFlinger 的服务启动链。

## feature 特有注意点

- 纯 native（C++）：改 `.cpp/.h` 或新增源文件进模块后 → 后台重跑 `./gen-compdb-clangd.sh`（compdb 结构变了，clangd 才不失准）。
- 窗口缩放态下的 touch 事件映射若要动，属 input 链路，谨慎评估再改。

## 编译 / push / 验证

通用流程见对应 native 编译 skill（Read `services/sidebarflinger/**` 时自动激活）：单编目标、产物、push 清单。本文件不重复。
