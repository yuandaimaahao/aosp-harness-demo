# dev-sidebar shared workflow

These are public build and deployment facts shared by both clients.

## Build

    source build/envsetup.sh
    lunch <product>-userdebug
    m services SidebarApp selinux_policy

## Deploy

1. Record a deployment time baseline.
2. Set and validate an explicit ANDROID_SERIAL.
3. Push only the artifacts built for the selected product.
4. Restart the affected process or device only after confirming the target.

## Verify

Run the feature verifier. Only its strict RESULT PASS is delivery evidence.
