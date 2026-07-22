# Claude Code + Codex 共用 Harness 设计

## 目标

在保留现有 `claude-code/` 与 `codex/` 独立教学 Demo 的同时，新增一个
`common/` Demo，演示真实 AOSP 树中如何让 Claude Code 与 Codex 共用同一套
Harness 事实源，并分别保留客户端特有的适配层。

成功标准：

- 公共层只维护一份 feature、涉及仓、目标分支、验证入口和验证语义。
- Claude/Codex wrapper 都能从同一棵 demo 树选择相同 feature，并输出相同的
  公共契约摘要。
- 公共 verifier 只有 `RESULT PASS` 才返回 0；`FAIL` 和默认 `INCOMPLETE`
  都返回非零。
- `common/run-demo.sh` 离线运行，不依赖真实 AOSP、ADB、Claude 或 Codex
  会话。
- 文档解释同一项目中如何同步两个 Harness，以及何时必须停止一个客户端再
  切换到另一个客户端。

## 方案选择

### 方案 A：公共层 + 两个适配器（采用）

在 AOSP 树根放置 `.harness/`，由它保存公共事实源和唯一 verifier；`.claude/`
与 `.codex/` 只提供各自的 wrapper、hooks/config 和上下文文件。两个 wrapper
通过同一个解析脚本读取 `.harness`，再输出规范化契约摘要。

优点是事实不重复、客户端边界清晰，并且可以单独验证公共层；代价是需要显式
维护两个客户端入口和各自的文档。

### 方案 B：把 Claude Demo 直接改造成双客户端配置

将现有 `claude-code/` 目录改造成同时包含 `.claude/` 与 `.codex/` 的工程。

优点是目录少；缺点是破坏现有对照 Demo，且容易让 Claude 专属契约与 Codex
契约混在一起，不适合教学和迁移。

### 方案 C：公共 manifest 生成两份客户端目录

用生成器从一份 YAML/TSV 生成 Claude 和 Codex 配置。

优点是可以生成更多客户端；缺点是引入生成产物、漂移和额外工具链。当前需求只
需要两个客户端，YAGNI 不采用。

## 目录与边界

```text
common/
├── .harness/
│   ├── common.md                         # 公共事实、流程边界和状态语义
│   ├── features/dev-sidebar/repos.tsv    # 唯一涉及仓事实源（4 列）
│   ├── features/dev-sidebar/workflow.md  # 共享编译、部署与验证事实
│   ├── features/dev-sidebar/verify-sidebar.sh
│   ├── bin/resolve-feature.sh            # 两个 adapter 共用
│   ├── bin/check-branches.sh             # 真实 repo 树共享分支门禁
│   └── bin/check-parity.sh                # 双客户端一致性检查
├── .claude/
│   ├── bin/claude-feature                 # Claude 启动适配器
│   └── settings.json                      # Claude 侧配置示例
├── .codex/
│   ├── bin/codex-feature                  # Codex 启动适配器
│   └── hooks.json                         # Codex 侧配置示例
├── CLAUDE.md                              # Claude 专属上下文 + 公共层引用
├── AGENTS.md                              # Codex 专属上下文 + 公共层引用
├── CURRENT_FEATURE
├── run-demo.sh
└── tests/test-harness.sh
```

`CLAUDE.md` 与 `AGENTS.md` 不做字节级同步：前者说明 Claude 的启动和
SessionStart 边界，后者说明 Codex 的启动时指令链和 hooks 信任边界。两者都
引用 `.harness/common.md`，并通过 parity checker 校验 feature、manifest、
verifier 和公共事实摘要一致。

统一 `repos.tsv` schema 为：

```text
path<TAB>convention<TAB>tags<TAB>description
```

适配器禁止复制该文件。需要给具体客户端展示时，读取公共 manifest 并在运行时
生成摘要。

## 数据流与运行方式

1. 用户在树根运行 `.claude/bin/claude-feature --dry-run` 或
   `.codex/bin/codex-feature --dry-run`。
2. 两个 wrapper 调用 `.harness/bin/resolve-feature.sh`，读取
   `CURRENT_FEATURE`，校验 feature 名、manifest、workflow 和唯一可执行的
   `verify-*.sh`。真实 repo 树还先通过共享 `check-branches.sh`。
3. wrapper 输出 `client / feature / target_branch / manifest / workflow /
   verifier / repositories / contract_sha256`。
   真正启动客户端时，wrapper 先固定工作目录到树根，再执行 `claude` 或
   `codex`；本 demo 默认只演示 dry-run。
4. 任一客户端完成工作后调用同一份
   `.harness/features/dev-sidebar/verify-sidebar.sh --demo`。
5. `check-parity.sh` 先直接生成 canonical contract，再逐个比较两个 adapter；
   同时确认两个上下文文件引用公共事实源，客户端目录没有复制 manifest、
   workflow 或 verifier。

同一棵源码树不允许 Claude 与 Codex 同时在同一 feature 分支写入。切换客户端
前先结束当前会话，确认工作区干净或已保存，再用目标 wrapper 启动新会话；hooks
只能阻止漂移，不能在现有会话中热重载另一套上下文。

教学 Demo 的 SessionStart 只校验启动时 parity，不实现跨客户端通用漂移 hook。
真实项目保留各客户端自己的 UserPromptSubmit schema，并比较会话启动时保存的
`contract_sha256`；漂移时阻断并要求重启。

## 错误处理与验证

- 缺少 `CURRENT_FEATURE`、非法 feature 名、manifest 或 verifier 时，wrapper
  fail closed，不启动客户端。
- verifier 的查询失败记为 `FAIL`；存在 `SKIP` 且未显式 `--allow-skip` 时记为
  `RESULT INCOMPLETE` 并返回非零。`--allow-skip` 只允许与 `--demo` 同用，
  输出 `RESULT EXPLORATION`，不能作为交付 PASS。
- parity 发现两个 adapter 的公共字段不一致时返回非零，并打印差异字段。
- 所有测试只使用临时 fixture；不触碰仓库中已有的 `demo-out/`。

## 不在本次范围

- 不实现真实 Claude/Codex API 调用。
- 不把客户端 hooks 伪装成跨客户端共用配置；配置 schema 仍由各自客户端
  单独维护。
- 不引入 YAML 解析器、构建系统或真实 AOSP 编译。
