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

Tag a service registered by SystemServer with the canonical attributes, and grant a concrete client only lookup access:

```te
type sidebar_service, system_server_service, service_manager_type;
allow sidebar_app sidebar_service:service_manager find;
```

The system_server_service attribute is consumed by add_service(system_server, system_server_service). AOSP's `add_service` macro grants SystemServer `{ add find }` and adds a neverallow guarding registration from other domains, so do not add a raw per-service SystemServer allow.

## Build in one retained session

Submit this entire block as one shell invocation. Codex must keep polling the same exec session until it exits; starting the build in one session and waiting in another loses the child status.

```bash
bash -c '
set -u
build_log="$(mktemp "${TMPDIR:-/tmp}/build-sepolicy.XXXXXX.log")"
artifact="out/target/product/vsoc_x86_64/system/etc/selinux/plat_sepolicy.cil"
printf "build log: %s\n" "$build_log"
(
  source build/envsetup.sh >/dev/null 2>&1 &&
  lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 &&
  m selinux_policy
) >"$build_log" 2>&1 &
build_pid=$!
while kill -0 "$build_pid" 2>/dev/null; do
  tail -n 20 "$build_log"
  sleep 10
done
wait "$build_pid"
build_rc=$?
if [[ "$build_rc" -ne 0 ]]; then
  tail -n 200 "$build_log" >&2
  exit "$build_rc"
fi
grep -Fq "#### build completed successfully ####" "$build_log" || exit 1
[[ -f "$artifact" ]] || exit 1
printf "artifact: %s\n" "$artifact"
'
```

## Deploy the policy image

Policy requires a full image, not a services.jar push. Build it from its own initialized shell, inspect the fleet, and explicitly confirm the group before changing its state:

```bash
bash -c 'source build/envsetup.sh >/dev/null 2>&1 && lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 && m'
cvd fleet
cvd_group="${CVD_GROUP:?Set CVD_GROUP to the explicitly confirmed group from cvd fleet}"
cvd --group_name="$cvd_group" stop
cvd --group_name="$cvd_group" start
```

The group selector placement above is the local Cuttlefish `cvd [selectors] command` form.

## Verify enforcement and behavior

Set `ANDROID_SERIAL` only after explicitly confirming the target. Pin both the denial query and service registration query to it:

```bash
device_serial="${ANDROID_SERIAL:?Set ANDROID_SERIAL to the explicitly confirmed target serial}"
adb -s "$device_serial" get-state
adb -s "$device_serial" shell dmesg | grep -F 'avc: denied'
adb -s "$device_serial" shell service list | grep -F sidebar
```

After boot, inspect denials and service registration. Investigate every new relevant denial rather than assuming an empty or filtered query proves correctness. Run the applicable `features/<feature>/verify-*.sh` scripts and accept completion only when the final result is `RESULT PASS`.
