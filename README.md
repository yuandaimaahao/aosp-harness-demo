# AOSP 整机源码 Harness —— 可运行 Demo

这是[《AOSP 整机源码 Harness 工程探索》](https://transsioner.feishu.cn/docx/SkmjdUAKuonHDax9kUIctYOWnPp)一文四层方案的**可运行最小复刻**。它用文中的示例 feature `dev-sidebar`（在 AOSP 17 上新增一个系统服务 + 一个常驻边栏应用）把「代码智能 / 上下文 / 流程 / 护栏与验证」四层的落地物都摆了出来，并给关键脚本加了 `--demo` 模式，让你**不需要一棵真实 AOSP 树也能跑起来看效果**。

> ⚠️ 这是**教学 Demo**，不是真实约束。真实工程里 `CLAUDE.md`、`.claude/`、`features/` 都是放在 AOSP 树根（一个非 git 仓的 repo 工程根）的游离文件。
>
> **② 上下文层已升级到 v2「软链单文件」**：一个 feature 的**全部**上下文（树级 bootstrap/硬约束 + feature 总览 + 各仓约定）都在**一个** `features/<分支>/CLAUDE.md` 里；树根 `CLAUDE.md` 是**指向它的软链**，SessionStart hook 按分支重指。不再往各仓根物化子目录 CLAUDE.md（v1 做法，已废）。这样启动即整份进 Memory files 持久桶、长会话不掉、子代理也吃到；且**全程不往任何仓写一个字节**。

## 一眼看懂：目录 = 四层

```
aosp-harness-demo/                        # ← 真实环境里这是 <AOSP_ROOT>（repo 工程根，非 git 仓）
├── README.md                             # 你在读的这份
├── run-demo.sh                           # ★ 一键演示四层如何协同（先跑这个）
├── CURRENT_FEATURE                       # 模拟"锚定仓当前分支名"（真实环境读 repo 分支）
│
├── CLAUDE.md                             # ② 上下文：软链 → features/dev-sidebar/CLAUDE.md（feature 单文件）
├── .clangd                               # ① 代码智能：指向 feature 精简 compdb
├── gen-compdb-clangd.sh                  # ① 代码智能：两段式 compdb 刷新（带 --demo）
│
├── frameworks/base/PLACEHOLDER.java      # 占位仓：feature 在此仓改代码；约定写在 feature 单文件的『### frameworks/base』节
├── frameworks/native/PLACEHOLDER.cpp     # 占位仓：同上（『### frameworks/native』节）
│                                         #   v2：各仓根不再有 CLAUDE.md
├── .claude/
│   ├── settings.json                     # ② hooks 注册 + ④ permissions 硬门禁
│   ├── hooks/
│   │   ├── load-feature.sh               # ② SessionStart：把树根 CLAUDE.md 软链重指到 feature 单文件
│   │   └── check-branch-drift.sh         # ② UserPromptSubmit：会话中途切分支告警
│   ├── rules/
│   │   └── compdb-freshness.md           # ① compdb 时效提醒（path-scoped rule）
│   └── skills/
│       ├── build-services-jar/SKILL.md   # ③ 流程：改 services 代码时激活
│       └── build-sepolicy/SKILL.md       # ③ 流程：改 sepolicy 时激活
│
└── features/                             # ② 真实环境是独立 git 仓（不在 manifest，gerrit/soong 全不可见）
    └── dev-sidebar/                      # 目录名 = repo 分支名 = feature 名
        ├── CLAUDE.md                     # ② 该 feature 的【单文件全部上下文】：树级 + 总览 + 各仓约定
        ├── repos.tsv                     # ① compdb 仓集单一事实源（gen-compdb 据它取标 compdb 的仓）
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
2. **② 上下文（v2 软链单文件）**：模拟 Claude Code 启动，触发 `load-feature.sh`——把树根 `CLAUDE.md` **软链重指**到 `features/dev-sidebar/CLAUDE.md`；启动时 Claude Code 穿软链把该 feature 的全部上下文（树级 bootstrap/硬约束 + 总览 + 各仓约定）载入 Memory files 持久桶。编辑树根 `CLAUDE.md` = 直接编辑 feature 单文件（软链）→ 落 `features/` 仓。
3. **② 上下文（漂移检测）**：模拟会话中途 `repo checkout` 切了分支，`check-branch-drift.sh` 打印一次告警；不切则零输出。
4. **④ 护栏与验证**：`verify-sidebar.sh --demo` 跑四步确定性断言，输出只有 `PASS/FAIL/SKIP`。

单独跑各层：

```bash
./gen-compdb-clangd.sh --demo                       # ① 两段式 compdb
echo '{"cwd":"'$PWD'"}' | .claude/hooks/load-feature.sh   # ② 软链重指
./features/dev-sidebar/verify-sidebar.sh --demo     # ④ 验证
```

## 四层与文中章节对应

| 层 | Demo 落地物 | 文中章节 |
|---|---|---|
| ① 代码智能 | `.clangd` + `gen-compdb-clangd.sh` + `rules/compdb-freshness.md` | 第五节 |
| ② 上下文 | `CLAUDE.md`(软链) + `hooks/*` + `features/dev-sidebar/CLAUDE.md`(单文件) | 第六节 |
| ③ 流程 | `.claude/skills/build-*/SKILL.md`（`paths` glob 激活） | 第七节 |
| ④ 护栏与验证 | `settings.json` 的 `permissions.ask` + `verify-sidebar.sh` | 第八节 |

## 从 Demo 到真实工程要改什么

- `.clangd` 的 `CompilationDatabase` 改成**绝对路径**（指向 `out/soong/development/ide/compdb-feature/`）。
- `gen-compdb-clangd.sh` 去掉 `--demo` 分支，走真实 `SOONG_GEN_COMPDB=1 m nothing`（需 bash、source 后不接 pipe）；无参时它已按当前 git 分支自动读 `features/<分支>/repos.tsv` 里标 `compdb` 的仓（`detect_feature` 内置"有独立 `.git` 的仓优先、`CURRENT_FEATURE` 回退"）。
- `load-feature.sh` 的分支探测在真实树会命中"有独立 `.git` 的锚定仓"（frameworks/base → frameworks/native → …）的当前 git 分支；demo 里这些是占位目录、无独立 `.git`，自动回退 `CURRENT_FEATURE`。它做的事只有一件：**把树根 `CLAUDE.md` 软链重指到 `features/<分支>/CLAUDE.md`**——不往任何仓写文件（v2 相对 v1 去掉了各仓 CLAUDE.md 物化 + `.git/info/exclude` 隔离那整套）。
- `features/` 初始化成独立 git 仓（`git init`），可推私有 remote 跨机同步；它不进 manifest，故 gerrit/soong 全不可见。编辑经树根软链**直达** `features/<分支>/CLAUDE.md`，改动就在 `features/` 仓里，提交手动。
- `verify-sidebar.sh` 去掉 `--demo`，走真实 `adb` 断言（此时 `adb push/reboot` 会命中 `permissions.ask` 弹窗）。
```

