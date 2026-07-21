# AOSP 整机源码 Codex Harness 可运行 Demo

这是一份 **Codex 原生重写，不是名称替换** 的 AOSP Harness 教学示例。它用 Codex 已文档化的 `AGENTS.md`、skills、project hooks 和命令行界面，演示“上下文 / 流程 / 验证闭环”三层怎样协作。Demo 不启动 Codex，不运行 AOSP 构建，也不访问 ADB 或 CVD。

## 快速开始

从仓库根目录运行主入口：

```bash
./codex/run-demo.sh
```

或先进入 Codex demo 目录：

```bash
cd codex
./run-demo.sh
```

`run-demo.sh` 依次演示上下文选择、会话分支漂移、涉及仓分支一致性、流程 skills、严格验证和回归测试。它只调用 wrapper 的 `--dry-run` 模式和确定性 demo 入口。

## 目录与三层

```text
codex/
├── CURRENT_FEATURE
├── AGENTS.md -> features/dev-sidebar/AGENTS.md
├── run-demo.sh
├── .codex/
│   ├── bin/codex-feature
│   ├── bin/check-process-layer
│   ├── hooks.json
│   └── hooks/{session-start,check-branch-drift}.sh
├── .agents/skills/
│   ├── build-services-jar/SKILL.md
│   └── build-sepolicy/SKILL.md
├── features/dev-sidebar/
│   ├── AGENTS.md
│   ├── repos.tsv
│   ├── check-branch.sh
│   └── verify-sidebar.sh
└── tests/test-harness.sh
```

| 层 | 职责 | Demo 落点 |
|---|---|---|
| ① 上下文层 | 在一次 Codex 运行前选定 feature，并防止会话中分支漂移 | `CURRENT_FEATURE` + 树根 `AGENTS.md` 软链 + wrapper + hooks |
| ② 流程层 | 将构建、部署、安全检查和验证顺序封装为可复用流程 | `.agents/skills/*/SKILL.md` + `check-process-layer` |
| ③ 验证闭环层 | 用脚本产出可审计的 PASS / FAIL / INCOMPLETE 结论 | `features/dev-sidebar/verify-sidebar.sh` |

导航不单独算一层：本方案使用 **`rg` + 源码阅读**，先按仓和路径缩小范围，再搜 JNI 注册名或全限定 `Class::method`。不需要预先建立索引，也不把搜索命中误写成完整引用关系。

## ① 上下文层

### Wrapper

```bash
# 只选择 feature、校验分支并同步 AGENTS.md，不启动 Codex
./.codex/bin/codex-feature --dry-run

# 真实工作入口：同步完成后启动 Codex
./.codex/bin/codex-feature
```

Wrapper 的正确性边界很重要：**AGENTS.md 每次运行只加载一次**，所以会话中改软链不等于当前运行已重载指令链。必须先由 wrapper 选定链接，再开始新运行；漂移 hook 的职责是停止继续工作并提示重启，不是在同一运行里热换上下文。

Codex 默认把 Git 根当作 project root；找不到 project root 时只检查当前目录。因此对 **非 Git 的 AOSP 树根**，要从树根开始运行。本 demo 的 wrapper 会 `cd` 到树根，也为 project hook 的相对命令提供稳定起点。

### Hooks 演示与信任

```bash
session_payload='{"session_id":"manual-demo","cwd":".","hook_event_name":"SessionStart"}'
prompt_payload='{"session_id":"manual-demo","cwd":".","hook_event_name":"UserPromptSubmit"}'
printf '%s\n' "$session_payload" | ./.codex/hooks/session-start.sh
printf '%s\n' "$prompt_payload" | ./.codex/hooks/check-branch-drift.sh
```

项目级 hooks 只在 **受信任项目** 中加载。在 CLI 中使用 `/hooks` 查看来源、审查并信任精确的 hook 定义；定义改变后应重新审查。这些 hook 的相对命令依赖 wrapper 固定的工作目录。本方案不假设 hook 一定先于 `AGENTS.md` 发现执行。

`repos.tsv` 是 feature 涉及仓的单一事实源：

```bash
./features/dev-sidebar/check-branch.sh --demo
```

`--demo` 故意返回一个分支漂移失败，便于检查调用方是否正确处理非零退出。

## ② 流程层

```bash
./.codex/bin/check-process-layer
```

Skills 位于 `.agents/skills`。Codex 对 skills 使用 **渐进式披露**：初始上下文只放名称、`description` 和文件路径，选中后再读取完整 `SKILL.md`。

- 显式选择：在提示中写 `$build-services-jar` 或通过 `/skills` 选择。
- 隐式选择：任务与 skill 的 `description` 匹配时，Codex 可选择它。
- 当前公开契约中 **没有已文档化的 `paths` 路径触发契约**；不要把“修改某路径”宣称为必然选中某个 skill。这个 demo 由 feature `AGENTS.md` 显式路由必须使用的 skill。

## ③ 验证闭环层

```bash
# 离线确定性验证
./features/dev-sidebar/verify-sidebar.sh --demo

# 只有探索阶段才显式容忍 SKIP
./features/dev-sidebar/verify-sidebar.sh --demo --allow-skip
```

最终状态语义是：

- `RESULT PASS`：所有严格断言通过，退出 0。
- `RESULT FAIL`：至少一项失败，非零退出。
- `RESULT INCOMPLETE`：无 FAIL 但存在 SKIP，默认仍非零退出。
- `--allow-skip` **仅用于探索**，不得作为交付或收工证据。

## 适配到真实 AOSP

1. 把 `features/` 建成 **manifest 之外的独立 Git 仓**，由它管理 feature 上下文、涉及仓清单和验证脚本，不污染 AOSP manifest、Gerrit 或 Soong 输入。
2. 在 AOSP 树根建立树根 `AGENTS.md` 软链，并把 `.codex/` 与 `.agents/` 暴露在同一树根；日常工作始终经过 wrapper。
3. 保留 `repos.tsv` 和涉及仓 checker，在开始任务前 fail closed 检查缺仓、分支漂移、detached HEAD 和非法仓库。
4. 真实设备操作前必须显式固定 `ANDROID_SERIAL`，先校验 `adb -s "$ANDROID_SERIAL" get-state`；操作 Cuttlefish 前先用 `cvd fleet` 确认目标，再固定 `CVD_GROUP`，禁止对未选定组执行 stop/start。
5. 把 `verify-sidebar.sh` 的 demo 数据源换成真实设备查询，保留查询失败即 FAIL、crash 时间基线、严格 SKIP 和只有 `RESULT PASS` 才能收工的语义。

## 继续阅读

- 长文：[AOSP 整机源码 Codex Harness 工程探索](AOSP整机源码Codex-Harness工程探索.md)
- [`AGENTS.md` 自定义指令](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [Build skills](https://learn.chatgpt.com/docs/build-skills)
- [Hooks](https://learn.chatgpt.com/docs/hooks)
- [Advanced configuration](https://learn.chatgpt.com/docs/config-file/config-advanced)
- [Subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)
- [Developer commands](https://learn.chatgpt.com/docs/developer-commands)
