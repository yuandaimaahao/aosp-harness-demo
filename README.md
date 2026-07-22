# AOSP 整机源码 Harness Demo

本仓库包含两套彼此独立的客户端 Demo，以及一套共用 Harness 方案 Demo：

- [`claude-code/`](claude-code/)：Claude Code 版本。
- [`codex/`](codex/)：Codex 版本，包含可运行示例和完整探索文档。
- [`common/`](common/)：Claude Code + Codex 共用公共层、两个适配器、parity 检查和同步方案。

三个 Demo 都不依赖真实 AOSP 源码树或 Android 设备。
