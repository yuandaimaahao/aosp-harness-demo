# Shared Harness Codex adapter

本文件是 Codex 的客户端适配层，不是公共事实源。

- 公共 feature、涉及仓、验证入口和同步规则：阅读 .harness/common.md。
- 公共 manifest：只读 wrapper 输出的 .harness/features/<feature>/repos.tsv。
- Codex 每次运行前必须通过 .codex/bin/codex-feature 固定工作目录并输出公共
  契约；AGENTS.md 指令链不会在会话中途热重载。
- .codex/hooks.json 只维护 Codex 能理解的配置；不要把 Claude settings schema
  当成 Codex 的契约。
- 本 Demo 的 SessionStart 只校验启动时 parity；真实项目继续使用 Codex 专属
  UserPromptSubmit hook 比较会话快照与公共 contract_sha256。
- 完成前运行 .harness/bin/check-parity.sh 和公共 verifier。
