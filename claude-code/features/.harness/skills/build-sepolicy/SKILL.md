---
name: build-sepolicy
description: 新增/修改系统服务的 SELinux 策略 —— 改 system/sepolicy 时用（service_contexts + .te 三件套）
paths:
  - "system/sepolicy/**"
---

<!-- DEMO —— ② 流程层示例 skill。物理源位于 features/.harness/skills/，
     经树根 .claude 软链暴露，paths 命中 system/sepolicy/** 时才可见。 -->

# build-sepolicy（② 流程：改 sepolicy 时激活）

新增系统服务后**必须**同步 SELinux 策略，否则服务注册/被访问时 `avc: denied`，服务起不来。这是 CLAUDE.md 六条硬约束之一。

## 三件套

1. **声明服务类型**（`system/sepolicy/private/service_contexts` 或 vendor 对应文件）：

   ```text
   sidebar    u:object_r:sidebar_service:s0
   ```

2. **定义 type + 允许规则**（`.te`，如 `private/sidebar.te`）：

   ```text
   type sidebar_service, service_manager_type;
   allow system_server sidebar_service:service_manager { add find };
   ```

3. **允许客户端 find**（谁要用这个服务就给谁 `find` 权限）。

## 编译与验证

```bash
bash -c 'source build/envsetup.sh >/dev/null 2>&1 \
  && lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 \
  && m selinux_policy' > /tmp/build-sepolicy.log 2>&1 &
```

- 策略随整机镜像生效，改动一般走稳环（`m` 整机 → `cvd stop/start` 换新镜像）更稳。
- 起机后执行以下验证：`dmesg` 不应出现本服务相关的 denial，服务列表应包含 `sidebar`；收口到 `features/<分支>/verify-*.sh`。

```bash
device_serial="${ANDROID_SERIAL-}"
if [[ -z "$device_serial" || ! "$device_serial" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then
  echo 'error: set ANDROID_SERIAL to a safe, explicit target serial' >&2
  exit 2
fi
adb -s "$device_serial" shell dmesg | grep 'avc: denied'
adb -s "$device_serial" shell service list | grep sidebar
```
