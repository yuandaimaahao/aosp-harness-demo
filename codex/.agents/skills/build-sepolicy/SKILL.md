---
name: build-sepolicy
description: Build and verify AOSP SELinux policy after changes under system/sepolicy, especially new system services requiring service_contexts, service types, allow rules, denial checks, and full feature verification.
---

# Build SELinux policy

Select this repository skill explicitly as `$build-sepolicy` when an `AGENTS.md` route requires it. Codex may also select it implicitly when the frontmatter description matches the task. File paths alone do not select skills.

## Define a system service

Map the service name in `system/sepolicy/private/service_contexts` or the appropriate product or vendor file:

```text
sidebar    u:object_r:sidebar_service:s0
```

Declare a service-manager type and grant only the required registration and lookup permissions:

```te
type sidebar_service, service_manager_type;
allow system_server sidebar_service:service_manager { add find };
allow sidebar_app sidebar_service:service_manager find;
```

The `system_server` domain needs `add` to register the service and `find` if it looks the service up. Each client domain needs its own `find` rule; do not broaden access to unrelated domains.

## Build in the background

Run AOSP environment setup under Bash and keep the targeted policy build in a log:

```bash
bash -c 'source build/envsetup.sh >/dev/null 2>&1 \
  && lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 \
  && m selinux_policy' > /tmp/build-sepolicy.log 2>&1 &
policy_build_pid=$!
```

Poll `/tmp/build-sepolicy.log`, wait for the background job, and require the explicit `#### build completed successfully ####` marker before treating the build as successful.

Policy normally requires a full image deployment: run `m`, then `cvd stop`, then `cvd start`. This is not a services.jar push; the new policy must be present in the booted image.

## Verify enforcement and behavior

After boot, inspect denials and service registration:

```bash
adb shell dmesg | grep -F 'avc: denied'
adb shell service list | grep -F sidebar
```

Investigate every new relevant denial rather than assuming an empty or filtered query proves correctness. Run the applicable `features/<feature>/verify-*.sh` scripts and accept completion only when the final result is `RESULT PASS`.
