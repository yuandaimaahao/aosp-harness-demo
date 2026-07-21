# AOSP 整机源码 Harness —— 可运行 Demo

这是[《AOSP 整机源码 Harness 工程探索》](https://transsioner.feishu.cn/docx/SkmjdUAKuonHDax9kUIctYOWnPp)一文方案的可运行最小复刻。它演示「上下文 / 流程 / 验证闭环」三层如何协作，无需真实 AOSP 树。

> ⚠️ 这是**教学 Demo**，不是真实约束。真实工程里 `CLAUDE.md`、`.claude/`、`features/` 都是放在 AOSP 树根（一个非 git 仓的 repo 工程根）的游离文件。
>
> **① 上下文层使用「启动前同步 + 单文件」**：`.claude/bin/claude-feature` 在 Claude 进程启动前把根 `CLAUDE.md` 指向当前 feature。SessionStart 只做幂等检查和告警，因为 hook 内改软链不能作为同一次启动已重载 memory 的保证。

## 一眼看懂：目录 = 三层

```
claude-code/                              # ← 真实环境里这是 <AOSP_ROOT>（repo 工程根，非 git 仓）
├── README.md                             # 你在读的这份
├── run-demo.sh                           # ★ 一键演示三层如何协同（先跑这个）
├── CURRENT_FEATURE                       # 模拟"锚定仓当前分支名"（真实环境读 repo 分支）
│
├── CLAUDE.md                             # ① 上下文：软链 → features/dev-sidebar/CLAUDE.md（feature 单文件）
│
├── frameworks/base/PLACEHOLDER.java      # 占位仓：feature 在此仓改代码；约定写在 feature 单文件的『### frameworks/base』节
├── frameworks/native/PLACEHOLDER.cpp     # 占位仓：同上（『### frameworks/native』节）
│                                         #   各仓根不物化 harness 文件
├── .claude/
│   ├── bin/
│   │   ├── claude-feature                # ① 推荐启动入口：先同步上下文再启动 Claude
│   │   └── check-process-layer           # ② 离线自检流程 skill 工件与关键命令
│   ├── settings.json                     # ① hooks 注册
│   ├── hooks/
│   │   ├── feature-common.sh             # ① 分支探测与软链同步公共函数
│   │   ├── load-feature.sh               # ① SessionStart fallback：检查/告警
│   │   └── check-branch-drift.sh         # ① UserPromptSubmit：会话中途切分支告警
│   └── skills/
│       ├── build-services-jar/SKILL.md   # ② 流程：改 services 代码时激活
│       └── build-sepolicy/SKILL.md       # ② 流程：改 sepolicy 时激活
│
└── features/                             # ① 真实环境是独立 git 仓（不在 manifest，gerrit/soong 全不可见）
    └── dev-sidebar/                      # 目录名 = repo 分支名 = feature 名
        ├── CLAUDE.md                     # ① 该 feature 的【单文件全部上下文】：树级 + 总览 + 各仓约定
        ├── repos.tsv                     # ① 涉及仓单一事实源（check-branch.sh 消费）
        ├── check-branch.sh               # ① 涉及仓分支一致性检查
        └── verify-sidebar.sh             # ③ 确定性验证脚本（带 --demo）
```

## 怎么跑

```bash
cd aosp-harness-demo/claude-code
./run-demo.sh
```

`run-demo.sh` 会依次演示：

1. **① 上下文**：`.claude/bin/claude-feature --dry-run` 在 Claude 启动前同步软链，随后 SessionStart 只确认状态。
2. **① 漂移检测**：会话中切 feature 后持续告警，直到通过 wrapper 建立新会话。
3. **② 流程**：`.claude/bin/check-process-layer` 离线检查两个示例 skill 的结构、编译目标、产物和验证入口。它不启动 Claude，也不冒充自动触发测试。
4. **③ 验证**：默认任何 SKIP 都返回 `RESULT INCOMPLETE`；探索期必须显式 `--allow-skip`。crash 检查默认从设备启动时间（`/proc/stat` 的 `btime`）开始，也可用 `--since <epoch-seconds>` 指定部署基线；ADB 查询失败直接记为 FAIL。
5. **回归测试**：验证 wrapper、流程层工件、严格 SKIP、crash 时间基线/查询失败和 `repos.tsv` 分支检查。

单独跑各层：

```bash
rg 'SidebarService|SidebarFlinger' .                # 导航基线：rg + 源码阅读，无索引
./.claude/bin/claude-feature --dry-run                      # ① 启动前同步
./.claude/bin/check-process-layer                    # ② 流程 skill 离线自检
./features/dev-sidebar/verify-sidebar.sh --demo     # ③ 严格验证
./features/dev-sidebar/verify-sidebar.sh --demo --allow-skip  # 探索模式
./features/dev-sidebar/verify-sidebar.sh --since 1753000000    # 真实设备：显式部署基线
```

## 三层与文中章节对应

| 层 | Demo 落地物 | 文中章节 |
|---|---|---|
| ① 上下文 | `.claude/bin/claude-feature` + `CLAUDE.md` 软链 + hooks | 第五节 |
| ② 流程 | `.claude/skills/build-*/SKILL.md`（`paths` glob 激活） | 第六节 |
| ③ 验证闭环 | `features/dev-sidebar/verify-sidebar.sh` | 第七节 |

> **导航不单独成层**：本方案不配任何 LSP，导航一律 `rg` + 源码阅读。理由见文中第四节末「不采纳一：LSP」与第九节——clangd 单次查询确实快，但整机树规模下后台索引建不完，`findReferences` 会给出**不完整却不自知**的答案，比 `rg` 吵闹但完整的结果更危险。

## 从 Demo 到真实工程要改什么

- 导航直接用 `rg` 开工，不需要任何索引准备。整机树上同名符号成海，习惯是**先用路径收窄范围，再用高信息量锚点**（JNI 注册名如 `android_view_*`、C++ 的 `Class::method` 全限定名）代替泛词，避免几百条命中灌爆上下文。
- 日常用 `.claude/bin/claude-feature` 启动。它会先同步根软链并在真实 repo 树运行 `check-branch.sh`，分支缺失或漂移时 fail closed。SessionStart hook 只是兜底。
- `features/` 初始化成独立 git 仓（`git init`），可推私有 remote 跨机同步；它不进 manifest，故 gerrit/soong 全不可见。编辑经树根软链**直达** `features/<分支>/CLAUDE.md`，改动就在 `features/` 仓里，提交手动。
- `verify-sidebar.sh` 去掉 `--demo` 后走真实 `adb` 断言。crash 窗口默认始于设备本次启动的 `btime`；若要只覆盖本次部署，用 `--since <epoch-seconds>` 传入部署前记录的设备 epoch。crash buffer 查询失败必须判 FAIL，不能当成“无崩溃”。默认 SKIP 不算成功；只有探索阶段才使用 `--allow-skip`。

## 子代理原则

只读 Explore/Plan 不注入整份 feature CLAUDE.md。派发 prompt 只提供：目标、允许搜索的路径、会改变结论的关键事实、只读约束、期望输出。只有修改、构建或部署代理才携带相关硬约束。Claude Code 内建 Explore/Plan 会跳过 CLAUDE.md，因此范围和关键事实必须显式写进任务卡。
