---
name: build-services-jar
description: Build and deploy AOSP services.jar after changes under frameworks/base/services, including SystemServer services; use for compile targets, artifacts, push steps, ART cache risks, and feature verification.
---

# Build services.jar

Select this repository skill explicitly as `$build-services-jar` when an `AGENTS.md` route requires it. Codex may also select it implicitly when the frontmatter description matches the task. File paths alone do not select skills.

## Build in the background

Run AOSP environment setup under Bash, start the targeted build in the background, and keep its output in a log:

```bash
bash -c 'source build/envsetup.sh >/dev/null 2>&1 \
  && lunch aosp_cf_x86_64_phone-trunk_staging-userdebug >/dev/null 2>&1 \
  && m services' > /tmp/build-services.log 2>&1 &
build_pid=$!
```

Poll `/tmp/build-services.log` while the job runs. After `wait "$build_pid"`, inspect the log and accept build success only when it contains the explicit marker `#### build completed successfully ####`.

The expected artifact is:

```text
out/target/product/vsoc_x86_64/system/framework/services.jar
```

## Deploy deliberately

Before `adb root`, `adb remount`, `adb push`, or `adb reboot`, confirm the target device with `adb devices` and select the intended serial. These commands change device state and must not run against an unconfirmed target.

```bash
adb root
adb remount
adb push out/target/product/vsoc_x86_64/system/framework/services.jar \
  /system/framework/services.jar
adb reboot
```

A pushed jar can disagree with ART, dexpreopt, or boot-image caches. If the device fails to boot or behaves inconsistently, use a confirmed recovery procedure for `/data/dalvik-cache/`, or use the stable full-image loop: run `m`, then `cvd stop`, then `cvd start` with the new image.

## Check dependencies and behavior

- Run `m update-api` when a change affects a public or System API.
- Update and build SELinux policy when the service registration or access contract requires it; a jar-only change cannot satisfy that dependency.
- Treat build success as compilation evidence, not correctness evidence. Run the applicable `features/<feature>/verify-*.sh` scripts and accept completion only when the final result is `RESULT PASS`.
