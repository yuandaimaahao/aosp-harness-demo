# Shared Harness Claude adapter

本文件是 Claude Code 的客户端适配层，不是公共事实源。

- 公共 feature、涉及仓、验证入口和同步规则：阅读 .harness/common.md。
- 公共 manifest：只读 .harness/features/dev-sidebar/repos.tsv。
- Claude 会话必须通过 .claude/bin/claude-feature 启动；wrapper 先输出公共契约，
  再启动 Claude。
- Claude 的 hooks/settings 只维护 Claude 能理解的配置；不要把 Codex hook schema
  当成 Claude 的契约。
- 完成前运行 .harness/bin/check-parity.sh 和公共 verifier。
