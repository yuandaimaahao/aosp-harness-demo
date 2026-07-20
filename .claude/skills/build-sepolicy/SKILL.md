---
name: build-sepolicy
description: 新增/修改系统服务的 SELinux 策略 —— 改 system/sepolicy 时用（service_contexts + .te 三件套）
paths:
  - "system/sepolicy/**"
---

<!-- DEMO —— ② 流程层示例 skill。paths glob 命中 system/sepolicy/** 时自动激活。 -->

# build-sepolicy（② 流程：改 sepolicy 时激活）

新增系统服务后**必须**同步 SELinux 策略，否则服务注册/被访问时 `avc: denied`，服务起不来。这是 CLAUDE.md 六条硬约束之一。

## 三件套

1. **声明服务类型**（`system/sepolicy/private/service_contexts` 或 vendor 对应文件）：

   ```
   sidebar    u:object_r:sidebar_service:s0
   ```

2. **定义 type + 允许规则**（`.te`，如 `private/sidebar.te`）：

   ```
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
- 验证：起机后 `adb shell dmesg | grep 'avc: denied'` 应无本服务相关 denial；
  `adb shell service list | grep sidebar` 能看到服务 —— 收口到 `features/<分支>/verify-*.sh`。
