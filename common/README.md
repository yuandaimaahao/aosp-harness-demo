# Claude Code + Codex 共用 Harness Demo

这个目录模拟一个真实 AOSP 树根：公共层放在 .harness/，Claude Code 和
Codex 各自只保留适配层。它解决的是“一个项目中如何同步两个 Harness 工程”，
而不是把两个客户端配置文件强行做成同一份。

## 一键运行

从仓库根目录执行：

    ./common/run-demo.sh

或者：

    cd common
    ./run-demo.sh

Demo 不启动 Claude/Codex，不运行 AOSP 编译，也不访问 ADB；它会演示两个
wrapper 输出同一份公共契约、parity 检查、严格 verifier、SKIP 语义和回归测试。

## 目录职责

    .harness/
      common.md                         公共事实和同步规则
      features/dev-sidebar/repos.tsv    唯一涉及仓 manifest
      features/dev-sidebar/verify-sidebar.sh
      bin/resolve-feature.sh            两个 adapter 共用的解析器
      bin/check-parity.sh               公共契约一致性检查
    .claude/                            Claude 专属 wrapper/settings
    .codex/                             Codex 专属 wrapper/hooks
    CLAUDE.md / AGENTS.md                各自客户端上下文，不做字节同步

## 日常使用顺序

    ./.claude/bin/claude-feature --dry-run --contract
    ./.codex/bin/codex-feature --dry-run --contract
    ./.harness/bin/check-parity.sh
    ./.harness/features/dev-sidebar/verify-sidebar.sh --demo

真实 AOSP 树中，最后一个命令去掉 --demo 并要求显式安全的 ANDROID_SERIAL。
公共 verifier 的结果语义是：

- RESULT PASS：所有断言通过，可以作为交付证据。
- RESULT FAIL：至少一项失败，必须修复。
- RESULT INCOMPLETE：默认存在 SKIP 也失败；只有探索阶段才可显式使用
  --allow-skip。

## 一个项目中同步两个 Harness

1. 将 .harness/ 纳入项目级版本控制，Claude 与 Codex 都从同一树根启动。
2. 只在 .harness/features/<feature>/repos.tsv 维护涉及仓、约定、标签和说明。
3. 两个客户端的 wrapper 都先读取 CURRENT_FEATURE，再输出公共契约；不要各自
   复制 manifest 或 verifier。
4. 修改公共层后先跑 parity，再选择一个客户端进入写入会话。
5. 要换客户端时，先结束当前会话并保存改动，再通过另一个 wrapper 启动新的
   会话。不要在同一运行中切换软链或期待 AGENTS.md/CLAUDE.md 热重载。
6. 收工时只认公共 verifier 的 RESULT PASS；将 parity 和 verifier 纳入 CI。

详细设计与迁移建议见：

- Claude-Codex共用Harness方案.md
- ../docs/superpowers/specs/2026-07-22-shared-claude-codex-harness-design.md
