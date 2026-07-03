<!-- DEMO —— 这是《AOSP 整机源码 Harness 工程探索》的示例文件，非真实约束。
     真实环境里这份 CLAUDE.md 放在 AOSP 树根，每次会话（含子代理）自动加载。 -->

# 树根 CLAUDE.md（② 上下文层：固定 bootstrap + 硬约束）

本文件只写 **agent 默认会犯的错**，不写文档。feature 级、随分支变的内容由 SessionStart hook 注入（见 `features/<分支>/_index.md`），不写在这里。

## 编译（agent 默认会做错的地方）

- envsetup 必须用 **bash**（工具默认 shell 可能是 zsh），且 **source 后不能接 pipe**（函数会进子 shell）：

```bash
bash -c 'source build/envsetup.sh >/dev/null 2>&1 \
  && lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 \
  && m services' > /tmp/build.log 2>&1 &   # 后台 + 日志轮询，看到 build completed successfully 才算完
```

- **一切编译必须后台跑 + 轮询日志**：前台命令有超时上限，单编模块十几分钟起步。
- lunch 目标是三段式 `product-release-variant`，release 段如 `trunk_staging`（可从 `out/soong.log` 的 `TARGET_RELEASE=` 反查）。

## 硬约束（子代理也必须遵守）

| 硬约束 | 防的是什么 |
|---|---|
| 不向任何 gerrit project 提交 harness/上下文文件（CLAUDE.md/.claude/features/.clangd 等） | 知识污染上游 |
| 禁配 Java LSP / 禁生成 Eclipse 工程文件 | 吃内存 + 写坏树（Eclipse 残留的 .aconfig 被 soong glob 到会构建失败） |
| 改 public/System API 后必须 `m update-api` | 否则 checkapi 挂构建 |
| 新增系统服务必须同步 `system/sepolicy`（service_contexts + .te） | 否则服务起不来（avc denied） |
| push framework.jar/services.jar 后注意 ART 缓存 | dexpreopt/boot image 校验不一致拖慢甚至起不来，诡异时清 `/data/dalvik-cache/` |
| 不手改 `out/` 下任何生成物 | 破坏增量构建 |

## 代码导航

- C++：clangd 已配（树根 `.clangd` → feature 精简 compdb）；改了 `Android.bp/.mk`、`repo sync`、新增源文件后跑 `./gen-compdb-clangd.sh` 刷新。
- Java/Kotlin：**无 LSP**（论证过的取舍），用 Grep 搜符号 + Read；跨 Java↔JNI↔native 用 JNI 注册名（如 `android_view_*`）作 Grep 锚点。
