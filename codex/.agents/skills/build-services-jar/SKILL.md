---
name: build-services-jar
description: Build and deploy AOSP services.jar after changes under frameworks/base/services, including SystemServer services; use for compile targets, artifacts, push steps, ART cache risks, and feature verification.
---

# Build services.jar

Select this repository skill explicitly as `$build-services-jar` when an `AGENTS.md` route requires it. Codex may also select it implicitly when the frontmatter description matches the task. File paths alone do not select skills.

## Build in one retained session

Submit this entire block as one shell invocation. Codex must keep polling the same exec session until it exits; starting the build in one session and waiting in another loses the child status.

```bash
bash -c '
set -u
build_log="$(mktemp "${TMPDIR:-/tmp}/build-services.XXXXXX.log")"
artifact="out/target/product/vsoc_x86_64/system/framework/services.jar"
printf "build log: %s\n" "$build_log"
(
  source build/envsetup.sh >/dev/null 2>&1 &&
  lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 &&
  m services
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

Build success requires the child exit status, the explicit `#### build completed successfully ####` marker, and the artifact `out/target/product/vsoc_x86_64/system/framework/services.jar`.

## Pin and deploy to one device

Set `ANDROID_SERIAL` only after explicitly confirming the target device. Every ADB command must retain the same serial because root, remount, push, and reboot change device state.

```bash
device_serial="${ANDROID_SERIAL:?Set ANDROID_SERIAL to the explicitly confirmed target serial}"
adb -s "$device_serial" get-state
adb -s "$device_serial" root
adb -s "$device_serial" remount
adb -s "$device_serial" push \
  out/target/product/vsoc_x86_64/system/framework/services.jar \
  /system/framework/services.jar
adb -s "$device_serial" reboot
```

A pushed jar can disagree with ART, dexpreopt, or boot-image caches. If recovery through `/data/dalvik-cache/` is not appropriate, rebuild and deploy a full image from a fresh AOSP environment:

```bash
bash -c 'source build/envsetup.sh >/dev/null 2>&1 && lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 && m'
cvd fleet
cvd_group="${CVD_GROUP:?Set CVD_GROUP to the explicitly confirmed group from cvd fleet}"
cvd --group_name="$cvd_group" stop
cvd --group_name="$cvd_group" start
```

The group selector placement above is the local Cuttlefish `cvd [selectors] command` form. Never infer a group when multiple devices may exist.

## Check dependencies and behavior

- Run `m update-api` when a change affects a public or System API.
- Update and build SELinux policy when the service registration or access contract requires it; a jar-only change cannot satisfy that dependency.
- Treat build success as compilation evidence, not correctness evidence. Run the applicable `features/<feature>/verify-*.sh` scripts and accept completion only when the final result is `RESULT PASS`.
