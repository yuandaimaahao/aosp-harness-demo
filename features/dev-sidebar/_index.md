<!-- DEMO —— ② 上下文层：SessionStart 注入的索引（真实工程里几百 token）。
     只放"索引粒度"：目标 + 涉及仓清单 + 各约定文件路径 + 验证脚本入口；
     单仓详情按需 Read（用"feature 涉及仓有限"换上下文经济性）。 -->

# feature: dev-sidebar

**目标**：在 AOSP 17 上新增一个系统服务 + 一个常驻边栏应用。

## 涉及仓（本 feature 只动这些，清单外默认不动）

| 仓 | 干什么 | 单仓约定 / skill |
|---|---|---|
| `frameworks/base` | SidebarService + SystemServer 注册 | 按需 Read `features/dev-sidebar/frameworks-base.md`；编译走 `build-services-jar` skill |
| `frameworks/native` | SidebarFlinger（native 合成侧） | 编译走 `build-services-jar` / native 对应 skill |
| `packages/apps/SidebarApp` | 常驻边栏 app | 边栏 app 编译/push skill |
| `build/make` | 产品配置接入新模块 | 无 C++，不进 compdb |
| `system/sepolicy` | 新服务的 SELinux 策略 | Read 时激活 `build-sepolicy` skill |

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
