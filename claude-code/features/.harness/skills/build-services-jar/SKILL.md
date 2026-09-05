---
name: build-services-jar
description: 编译 / 部署 services.jar —— 改 frameworks/base/services 下代码（含 SystemServer 注册系统服务）时用
paths:
  - "frameworks/base/services/**"
---

<!-- DEMO —— ② 流程层示例 skill。物理源位于 features/.harness/skills/，
     经树根 .claude 软链暴露，避免 features/.claude 造成重复 skill 注册。 -->

# build-services-jar（② 流程：改 services 代码时激活）

承载**不随 feature 变**的通用流程；feature 特有内容写在 `features/<分支>/CLAUDE.md` 的对应仓小节，那里一句话指回本 skill（单一事实源，避免两处漂移）。

## 单编目标与产物

```bash
command_adapter="${HARNESS_COMMAND_ADAPTER:-common/.harness/bin/run-command.sh}"
HARNESS_SESSION_ID="${HARNESS_SESSION_ID:-manual-$$}"
export HARNESS_SESSION_ID
bash "$command_adapter" build workspace-build -- bash -c 'source build/envsetup.sh >/dev/null 2>&1 \
  && lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 \
  && m services'
```

- 产物：`out/target/product/vsoc_x86_64/system/framework/services.jar`

## push 清单（快环）

```bash
device_serial="${ANDROID_SERIAL-}"
instance_id="${ANDROID_INSTANCE_ID-}"
command_adapter="${HARNESS_COMMAND_ADAPTER:-common/.harness/bin/run-command.sh}"
if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ || ! "$instance_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]]; then
  echo 'error: set ANDROID_SERIAL to a safe, explicit target serial' >&2
  exit 2
fi
HARNESS_SESSION_ID="${HARNESS_SESSION_ID:-manual-$$}"
export HARNESS_SESSION_ID ANDROID_INSTANCE_ID="$instance_id"
bash "$command_adapter" mutate android-device -- adb -s "$device_serial" root
bash "$command_adapter" mutate android-device -- adb -s "$device_serial" remount
bash "$command_adapter" mutate android-device -- adb -s "$device_serial" push out/target/product/vsoc_x86_64/system/framework/services.jar /system/framework/services.jar
bash "$command_adapter" reconnect android-device -- adb -s "$device_serial" reboot
```

## 已知坑

- **ART 缓存**：push services.jar 后 dexpreopt/boot image 与新 jar 校验不一致会拖慢启动甚至起不来。诡异时清 `/data/dalvik-cache/`，或走稳环（`m` 整机 → `cvd stop` → `cvd start` 换新镜像）。
- **新增系统服务**：必须同步 `system/sepolicy`（service_contexts + .te），否则 avc denied 起不来——见 `build-sepolicy` skill。
- **改 public/System API**：必须 `m update-api`，否则 checkapi 挂构建。

## 编过 ≠ 改对

build 成功只是第一步。收工前必须跑 `features/<分支>/verify-*.sh` 且全部 PASS 才允许宣布完成。
