---
name: build-services-jar
description: 编译 / 部署 services.jar —— 改 frameworks/base/services 下代码（含 SystemServer 注册系统服务）时用
paths:
  - "frameworks/base/services/**"
---

<!-- DEMO —— ② 流程层示例 skill。paths glob 命中时（agent Read 到 frameworks/base/services/** 下的文件）自动激活；
     平时零上下文占用。真实工程里放 AOSP 树根 .claude/skills/，不嵌进 gerrit project（否则被跟踪 → 污染上游）。 -->

# build-services-jar（② 流程：改 services 代码时激活）

承载**不随 feature 变**的通用流程；feature 特有内容写在 `features/<分支>/frameworks-base.md`，那里一句话指回本 skill（单一事实源，避免两处漂移）。

## 单编目标与产物

```bash
# envsetup 必须 bash，source 后不接 pipe；一切编译后台跑 + 轮询日志
bash -c 'source build/envsetup.sh >/dev/null 2>&1 \
  && lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 \
  && m services' > /tmp/build-services.log 2>&1 &
# 轮询 /tmp/build-services.log，看到 #### build completed successfully #### 才算完
```

- 产物：`out/target/product/vsoc_x86_64/system/framework/services.jar`

## push 清单（快环）

```bash
adb root && adb remount            # ← 会改动真机状态，执行前先确认目标设备
adb push out/target/product/vsoc_x86_64/system/framework/services.jar \
         /system/framework/services.jar
adb reboot                         # ← 同样会改动真机状态
```

## 已知坑

- **ART 缓存**：push services.jar 后 dexpreopt/boot image 与新 jar 校验不一致会拖慢启动甚至起不来。
  诡异时清 `/data/dalvik-cache/`，或走稳环（`m` 整机 → `cvd stop` → `cvd start` 换新镜像）。
- **新增系统服务**：必须同步 `system/sepolicy`（service_contexts + .te），否则 avc denied 起不来 —— 见 `build-sepolicy` skill。
- **改 public/System API**：必须 `m update-api`，否则 checkapi 挂构建。

## 编过 ≠ 改对

build 成功只是第一步。收工前必须跑 `features/<分支>/verify-*.sh` 且全部 PASS 才允许宣布完成。
