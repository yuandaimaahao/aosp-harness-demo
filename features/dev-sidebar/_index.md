<!-- DEMO —— ② 上下文层：SessionStart 注入的索引（真实工程里几百 token）。
     纯指针：目标 + 指向 repos.tsv + 验证入口；涉及仓清单由 hook 现读 repos.tsv 渲染注入，本文件不复列。
     单仓详情不在此，靠各仓 CLAUDE.md 按需加载（用"feature 涉及仓有限"换上下文经济性）。 -->

# feature: dev-sidebar

**目标**：在 AOSP 17 上新增一个系统服务 + 一个常驻边栏应用。

## 涉及仓（本 feature 只动这些，清单外默认不动）

涉及仓 + 各仓约定文件 + compdb 标记的**单一事实源**是本目录 `repos.tsv`：`load-feature.sh` 据它物化各仓 CLAUDE.md，
并把涉及仓清单渲染进 SessionStart 注入（本文件不复列具体仓，避免两处漂移）；`gen-compdb-clangd.sh` 据它取 compdb 仓集。
增删仓只改 `repos.tsv` 一处，无需动脚本或本文件。

## 一致性检查

```bash
./features/dev-sidebar/check-branch.sh        # 涉及仓是否都在 dev-sidebar 分支
```

## 验证入口（收工前必须全 PASS）

```bash
./features/dev-sidebar/verify-sidebar.sh      # 真实环境
./features/dev-sidebar/verify-sidebar.sh --demo   # 无设备演示
```

> 编译成功 ≠ 改动正确。verify 脚本就是本 feature 的测试。
