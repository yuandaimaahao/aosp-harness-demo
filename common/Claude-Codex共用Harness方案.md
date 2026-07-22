# Claude Code 与 Codex 共用 Harness 工程方案

## 摘要

在 AOSP 这种由 repo 管理、包含大量独立 Git 仓的源码树中，真正需要同步
的不是两个客户端的配置文件，而是 feature 的公共事实：当前工作目标、涉及
哪些仓、每个仓遵循什么约定、怎样编译部署、怎样验证结果。

因此本方案把 Harness 拆成两层：

- 公共层：.harness/，拥有唯一事实源、唯一 verifier 和 parity checker。
- 客户端适配层：.claude/ 与 .codex/，只拥有各自能理解的上下文、启动
  wrapper、hooks/settings 和 skills。

这能让 Claude Code 与 Codex 共享同一棵源码树，同时避免把一个客户端的机制
误写成另一个客户端的产品契约。

## 1. 为什么要有公共层

AOSP 工作通常跨越 Java framework、Native Binder、应用、构建系统和
SELinux policy。单靠聊天记录无法稳定传递这些边界；单靠一份 README 也无法
保证另一个客户端会按同一顺序构建和验证。

公共层应该保存可被脚本消费的事实，而不是保存某个模型的提示词。这里的
repos.tsv 采用四列 tab schema：

    path<TAB>convention<TAB>tags<TAB>description

例如 frameworks/base 的约定可以是 source，标签可以是
java,system-server。Claude 和 Codex 都从这份文件生成契约摘要，不再各自维护
一份三列或四列变体。

## 2. 推荐目录

真实 AOSP 树根可以采用下面的布局：

    AOSP_ROOT/
    ├── .harness/
    │   ├── common.md
    │   ├── features/dev-sidebar/repos.tsv
    │   ├── features/dev-sidebar/verify-sidebar.sh
    │   └── bin/
    │       ├── resolve-feature.sh
    │       └── check-parity.sh
    ├── .claude/
    │   ├── bin/claude-feature
    │   └── settings.json
    ├── .codex/
    │   ├── bin/codex-feature
    │   └── hooks.json
    ├── CLAUDE.md
    ├── AGENTS.md
    └── CURRENT_FEATURE

本仓库的 common/ 就是上述 AOSP_ROOT 的离线教学模拟。已有
claude-code/ 和 codex/ 仍保留为独立对照 Demo，避免为了共用方案破坏原有
教学内容。

## 3. 公共层应该管什么

公共层只放跨客户端都成立的内容：

1. 当前 feature 名和 feature 目录。
2. 涉及仓的 manifest、分支要求、路径约定和风险标签。
3. 构建、部署、验证循环的事实性命令。
4. verifier 的输入、输出和退出码语义。
5. parity 检查和 CI 入口。

公共层不放：

1. Claude 的 settings.json schema。
2. Codex 的 hooks.json schema。
3. 依赖某个客户端自动激活的 skill/path 约定。
4. 只对单一客户端成立的提示词或会话行为。

## 4. 两个客户端适配层

### Claude Code

.claude/bin/claude-feature 先调用公共 resolver，输出 contract，再执行
claude。真实项目中可以在 Claude settings 中注册 SessionStart 或
UserPromptSubmit 检查，但这些 hooks 只负责检查和阻断，不负责把 Codex
上下文注入当前 Claude 运行。

根部 CLAUDE.md 说明 Claude 的工作方式，并引用 .harness/common.md。
如果 feature 变化，启动 wrapper 要在新会话前重新读取公共事实。

### Codex

.codex/bin/codex-feature 先调用同一个 resolver，固定工作目录到 AOSP 树根，
再执行 codex。根部 AGENTS.md 说明 Codex 的指令链边界；hooks.json 只
使用 Codex 自己的 hook schema。

Codex 的 AGENTS.md 指令链在一次 run 开始时建立。因此会话中修改链接或
CURRENT_FEATURE 不能视为已经加载新上下文；正确动作是停止当前会话，再通过
wrapper 启动新 run。

## 5. 怎样证明两个 Harness 同步

同步不能靠“看起来内容差不多”。本 Demo 的 resolver 输出：

    client
    feature
    manifest
    verifier
    repositories
    contract_sha256

其中 client 是适配器自身字段，其他字段必须完全相同。parity checker 会：

1. 分别运行 Claude 和 Codex dry-run。
2. 将 client 字段归一化为 CLIENT。
3. 比较剩余字段。
4. 检查两个上下文都引用 .harness/common.md。
5. 拒绝 .claude/repos.tsv 或 .codex/repos.tsv 这样的复制事实源。

如果任意一边出现漂移，parity 返回非零，CI 不能继续。

## 6. verifier 的严格语义

构建和部署不等于功能完成。公共 verifier 必须把“没有证据”和“证据失败”
分开：

- PASS：断言成功。
- FAIL：查询失败、结果错误或服务缺失。
- SKIP：该断言没有执行。
- RESULT INCOMPLETE：没有 FAIL，但默认仍有 SKIP，返回非零。
- RESULT PASS (SKIP allowed)：只有探索阶段显式允许 SKIP 时才返回 0。

真实设备模式应额外固定 ANDROID_SERIAL，检查 adb 状态，记录部署前时间基线，
查询 crash buffer，并把查询错误判为 FAIL。Demo 使用确定性环境变量和
--demo，所以不依赖设备。

## 7. 推荐工作流

### 开始任务

1. 从 AOSP 树根进入，不在单个仓目录内启动客户端。
2. 修改 .harness/features/<feature>/repos.tsv 或 common.md 后，运行两个
   dry-run 和 parity。
3. 先选 Claude 或 Codex 一个客户端开始写入，不并行修改同一 feature。

### 切换客户端

1. 停止当前客户端会话。
2. 检查 git/repo 工作区，确保改动已保存、提交或明确留在工作区。
3. 运行目标 wrapper 的 dry-run，确认 feature 和 contract hash。
4. 再启动目标客户端的新会话。

两个客户端共用源码目录，但不共用会话状态。不要让一个客户端在工作时修改
另一个客户端的 CLAUDE.md、AGENTS.md、settings 或 hooks。

### 收工

运行：

    ./.harness/bin/check-parity.sh
    ./.harness/features/dev-sidebar/verify-sidebar.sh

只有 parity 成功且 verifier 输出 RESULT PASS 才把任务标为完成。

## 8. 从 Demo 迁移到真实 AOSP

1. 把 common/.harness 的内容移到 AOSP_ROOT/.harness，并在项目级 Git
   仓中管理；不要把它写进 repo manifest。
2. 将涉及仓的真实分支检查接入 resolver，缺仓、detached HEAD 或分支漂移时
   fail closed。
3. 在 verifier 中固定目标设备或 Cuttlefish group，禁止对未选择的目标做
   stop/start。
4. 将构建产物、部署命令和 API 更新规则写入公共 facts 或独立 skills；不要
   依赖聊天记忆。
5. 在 CI 中先跑 parity，再按 feature 调用 verifier；保存 contract hash、
   设备序列号和验证输出作为审计证据。

## 9. 常见错误

### 错误：为两个客户端各复制一份 repos.tsv

复制后最容易出现一边新增仓、另一边忘记同步。正确做法是公共 manifest + 两个
运行时 adapter。

### 错误：把 Claude 的 paths 触发写成 Codex 保证

不同客户端的 skill 发现和 hooks 契约不同。公共层只记录“需要什么流程”，具体
激活规则写在对应客户端的适配层。

### 错误：在会话中途切换 CURRENT_FEATURE

上下文可能已经在 run 开始时读取。正确做法是让 hook 阻断当前 turn，并通过
wrapper 启动新会话。

### 错误：把 SKIP 当成成功

设备查询失败或断言未执行时，绿色日志不代表功能完成。默认的 INCOMPLETE 非零
语义可以避免把探索结果误当交付证据。

## 10. 本 Demo 的验证命令

    ./common/.claude/bin/claude-feature --dry-run --contract
    ./common/.codex/bin/codex-feature --dry-run --contract
    ./common/.harness/bin/check-parity.sh
    ./common/.harness/features/dev-sidebar/verify-sidebar.sh --demo
    ./common/tests/test-harness.sh

这五个入口足以验证公共事实源、两个客户端适配器、parity 和严格验证闭环。
