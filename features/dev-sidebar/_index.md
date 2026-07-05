<!-- DEMO —— ② 上下文层：SessionStart 注入的索引（真实工程里几百 token）。
     只放"索引粒度"：目标 + 涉及仓清单 + 各约定文件路径 + 验证脚本入口；
     单仓详情按需 Read（用"feature 涉及仓有限"换上下文经济性）。 -->

# feature: dev-sidebar

**目标**：在 AOSP 17 上新增一个系统服务 + 一个常驻边栏应用。

## 涉及仓（本 feature 只动这些，清单外默认不动）

仓清单 + 各仓约定文件 + compdb 标记的**单一事实源**是本目录 `repos.tsv`
（`load-feature.sh` 据它物化各仓 CLAUDE.md；`gen-compdb-clangd.sh` 据它取 compdb 仓集）。
当前涉及：`frameworks/base`、`frameworks/native`、`packages/apps/SidebarApp`、`build/make`、`system/sepolicy`
（前三者标 `compdb`＝有 C++、进 clangd；base/native 有单仓约定文件、会物化成 `<仓>/CLAUDE.md`，
编辑该仓文件时按需加载）。增删仓改 `repos.tsv` 即可，无需动脚本。

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
