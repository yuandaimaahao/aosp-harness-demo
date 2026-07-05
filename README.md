# AOSP 整机源码 Harness —— 可运行 Demo

这是[《AOSP 整机源码 Harness 工程探索》](http://ahaoframework.tech/agentic-coding/AOSP%E6%95%B4%E6%9C%BA%E6%BA%90%E7%A0%81Harness%E5%B7%A5%E7%A8%8B%E6%8E%A2%E7%B4%A2.html)一文四层方案的**可运行最小复刻**。它用文中的示例 feature `dev-sidebar`（在 AOSP 17 上新增一个系统服务 + 一个常驻边栏应用）把「代码智能 / 上下文 / 流程 / 护栏与验证」四层的落地物都摆了出来，并给关键脚本加了 `--demo` 模式，让你**不需要一棵真实 AOSP 树也能跑起来看效果**。

> ⚠️ 这是**教学 Demo**，不是真实约束。目录里的 `CLAUDE.md`、`.claude/`、`features/` 都带了 `DEMO` 横幅；真实工程里它们是放在 AOSP 树根（一个非 git 仓的 repo 工程根）的游离文件。

## 一眼看懂：目录 = 四层

```
aosp-harness-demo/                        # ← 真实环境里这是 <AOSP_ROOT>（repo 工程根，非 git 仓）
├── README.md                             # 你在读的这份
├── run-demo.sh                           # ★ 一键演示四层如何协同（先跑这个）
├── CURRENT_FEATURE                       # 模拟"锚定仓当前分支名"（真实环境读 repo 分支）
│
├── CLAUDE.md                             # ② 上下文：固定 bootstrap + 6 条硬约束（不随 feature 变）
├── .clangd                               # ① 代码智能：指向 feature 精简 compdb
├── gen-compdb-clangd.sh                  # ① 代码智能：两段式 compdb 刷新（带 --demo）
│
├── frameworks/base/PLACEHOLDER.java      # 占位仓：演示"编辑该仓文件 → 按需加载 frameworks/base/CLAUDE.md"
├── frameworks/native/PLACEHOLDER.cpp     # 占位仓：同上（frameworks/native/CLAUDE.md）
│                                         #   运行后各仓根出现 load-feature 物化的 CLAUDE.md（被 .gitignore 忽略）
├── .claude/
│   ├── settings.json                     # ② hooks 注册 + ④ permissions 硬门禁
│   ├── hooks/
│   │   ├── load-feature.sh               # ② SessionStart：注入索引 + 按 repos.tsv 物化各仓 CLAUDE.md
│   │   └── check-branch-drift.sh         # ② UserPromptSubmit：会话中途切分支告警
│   ├── rules/
│   │   └── compdb-freshness.md           # ① compdb 时效提醒（path-scoped rule）
│   └── skills/
│       ├── build-services-jar/SKILL.md   # ③ 流程：改 services 代码时激活
│       └── build-sepolicy/SKILL.md       # ③ 流程：改 sepolicy 时激活
│
└── features/                             # ② 真实环境是独立 git 仓（不在 manifest，gerrit/soong 全不可见）
    └── dev-sidebar/                      # 目录名 = repo 分支名 = feature 名
        ├── _index.md                     # ② 启动注入的索引（几百 token）
        ├── repos.tsv                     # ①② 涉及仓单一事实源（路径/约定/compdb 标签/说明，两脚本共读）
        ├── frameworks-base.md            # ② 单仓约定 → 物化成 frameworks/base/CLAUDE.md
        ├── frameworks-native.md          # ② 单仓约定 → 物化成 frameworks/native/CLAUDE.md
        ├── check-branch.sh               # ② 涉及仓分支一致性检查
        └── verify-sidebar.sh             # ④ 确定性验证脚本（带 --demo）
```

## 怎么跑

```bash
cd aosp-harness-demo
./run-demo.sh
```

`run-demo.sh` 会依次演示：

1. **① 代码智能**：`gen-compdb-clangd.sh --demo` 造一份"全树 compdb"再按 feature 涉及仓过滤成精简库，打印 `全树 N 条 → feature M 条`——复刻"两段式精简"。
2. **② 上下文（SessionStart 注入 + 物化各仓 CLAUDE.md）**：模拟 Claude Code 启动，触发 `load-feature.sh`——把 `features/dev-sidebar/_index.md` 注入为会话上下文（agent"睁眼看到"的第一屏），并按 `repos.tsv` 为 `frameworks/base`、`frameworks/native` 物化 `<仓>/CLAUDE.md`（内容=各仓约定，编辑该仓文件时 Claude Code 按需加载）。真实环境这些 CLAUDE.md 写各仓 `.git/info/exclude` 隔离、不进 gerrit；demo 各仓非 git 仓，用顶层 `.gitignore` 模拟同一隔离。
3. **② 上下文（漂移检测）**：模拟会话中途 `repo checkout` 切了分支，`check-branch-drift.sh` 打印一次告警；不切则零输出。
4. **④ 护栏与验证**：`verify-sidebar.sh --demo` 跑四步确定性断言，输出只有 `PASS/FAIL/SKIP`。

单独跑各层：

```bash
./gen-compdb-clangd.sh --demo                       # ① 两段式 compdb
echo '{"cwd":"'$PWD'"}' | .claude/hooks/load-feature.sh   # ② 注入
./features/dev-sidebar/verify-sidebar.sh --demo     # ④ 验证
```

## 四层与文中章节对应

| 层 | Demo 落地物 | 文中章节 |
|---|---|---|
| ① 代码智能 | `.clangd` + `gen-compdb-clangd.sh` + `rules/compdb-freshness.md` | 第五节 |
| ② 上下文 | `CLAUDE.md` + `hooks/*` + `features/dev-sidebar/*` | 第六节 |
| ③ 流程 | `.claude/skills/build-*/SKILL.md`（`paths` glob 激活） | 第七节 |
| ④ 护栏与验证 | `settings.json` 的 `permissions.ask` + `verify-sidebar.sh` | 第八节 |

## 从 Demo 到真实工程要改什么

- `.clangd` 的 `CompilationDatabase` 改成**绝对路径**（指向 `out/soong/development/ide/compdb-feature/`）。
- `gen-compdb-clangd.sh` 去掉 `--demo` 分支，走真实 `SOONG_GEN_COMPDB=1 m nothing`（需 bash、source 后不接 pipe）；无参时它已按当前 git 分支自动读 `features/<分支>/repos.tsv` 里标 `compdb` 的仓（`detect_feature` 内置"有独立 `.git` 的仓优先、`CURRENT_FEATURE` 回退"），真实树无需额外改动。
- `load-feature.sh` / `check-branch-drift.sh` 的分支探测在真实树会命中"有独立 `.git` 的锚定仓"（frameworks/base → frameworks/native → …）的当前 git 分支；demo 里这些是占位目录、无独立 `.git`，自动回退 `CURRENT_FEATURE`。`load-feature.sh` 物化的各仓 `CLAUDE.md` 在真实环境写入各仓 `.git/info/exclude`（对 git 隐身、不进 gerrit），demo 用顶层 `.gitignore` 模拟这一隔离——不再需要把占位目录忽略之外的额外处理。
- `features/` 初始化成独立 git 仓（`git init`），可推私有 remote 跨机同步；它不进 manifest，故 gerrit/soong 全不可见。
- `verify-sidebar.sh` 去掉 `--demo`，走真实 `adb` 断言（此时 `adb push/reboot` 会命中 `permissions.ask` 弹窗）。
