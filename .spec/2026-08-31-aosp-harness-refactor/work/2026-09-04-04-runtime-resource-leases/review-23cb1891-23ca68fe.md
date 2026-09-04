# review 包 23cb1891..23ca68fe

## commit 列表

```
23ca68f fix(harness): bound resource lease lock wait
```

## diff --stat

```
 common/.harness/lib/resource-leases.sh | 14 +++++++-------
 1 file changed, 7 insertions(+), 7 deletions(-)
```

## diff

```diff
diff --git a/common/.harness/lib/resource-leases.sh b/common/.harness/lib/resource-leases.sh
index d1ea494..7f6c0e3 100644
--- a/common/.harness/lib/resource-leases.sh
+++ b/common/.harness/lib/resource-leases.sh
@@ -23,22 +23,21 @@ _harness_resource_lease_run() {
     _harness_resource_lease_error
     return
   }
   if python3 - "$$" "$PWD" "$action" "$@" >"$capture/out" 2>"$capture/err" <<'PY'
 import base64, fcntl, hashlib, json, os, pathlib, re, secrets, stat, sys, tempfile, time
 # HARNESS_RESOURCE_LEASE_TEST_SEAM
 def test_seam(_point, value=None): return value
 FAIL = b"error: resource lease operation failed\n"
 BUSY = b"error: resource lease unavailable\n"
 SAFE = re.compile(rb"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
-class LeaseError(Exception):
-    pass
+class LeaseError(Exception): pass
 def die(message=FAIL, rc=2):
     os.write(2, message)
     raise SystemExit(rc)
 def owner(pid):
     if not pid.isdecimal() or int(pid) <= 0: raise LeaseError()
     raw = open(f"/proc/{pid}/stat", encoding="ascii").read()
     return [os.geteuid(), int(pid), raw.rsplit(")", 1)[1].split()[19]]
 def owner_live(value):
     if (not isinstance(value, list) or len(value) != 3
             or any(isinstance(item, bool) for item in value[:2])
@@ -101,24 +100,22 @@ def normalize(path, pwd):
         raise LeaseError() from exc
     return normalize_bytes(raw, pwd)
 def root_and_lock():
     root = os.environ.get("HARNESS_RESOURCE_LEASE_ROOT")
     if not root:
         root = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp",
                             f"aosp-harness-resource-leases-{os.geteuid()}")
     encoded = os.fsencode(root)
     if not os.path.isabs(root) or any(ch < 32 or ch == 127 for ch in encoded):
         raise LeaseError()
-    try:
-        os.mkdir(root, 0o700)
-    except FileExistsError:
-        pass
+    try: os.mkdir(root, 0o700)
+    except FileExistsError: pass
     info = test_seam("root-owner", os.lstat(root))
     if (not stat.S_ISDIR(info.st_mode) or stat.S_ISLNK(info.st_mode)
             or info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode) != 0o700):
         raise LeaseError()
     flags = os.O_RDWR | os.O_CREAT | getattr(os, "O_NOFOLLOW", 0)
     fd = os.open(os.path.join(root, ".lock"), flags, 0o600)
     lock_info = test_seam("lock-owner", os.fstat(fd))
     if (not stat.S_ISREG(lock_info.st_mode) or lock_info.st_uid != os.geteuid()
             or stat.S_IMODE(lock_info.st_mode) != 0o600):
         os.close(fd)
@@ -194,21 +191,24 @@ def acquire(pid, pwd, session, wait, request_path):
     wait_value = int(wait)
     if wait_value > 300:
         raise LeaseError()
     canonical, digest, wanted = normalize(request_path, pwd)
     current = owner(pid)
     root, lock_fd = root_and_lock()
     deadline = test_seam("monotonic", time.monotonic()) + wait_value
     try:
         while True:
             occupied = False
-            test_seam("flock"); fcntl.flock(lock_fd, fcntl.LOCK_EX)
+            try: test_seam("flock"); fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
+            except BlockingIOError:
+                if wait_value == 0 or test_seam("monotonic", time.monotonic()) >= deadline: die(BUSY, 3)
+                time.sleep(min(0.05, max(0.0, deadline - time.monotonic()))); continue
             try:
                 recover_trash(root)
                 records = []
                 for path, record, request, keys in active_records(root):
                     if not owner_live(record["owner"]):
                         remove_record(root, path, record["token"])
                     else:
                         records.append((path, record, request, keys))
                 for _path, record, request, keys in records:
                     overlap = bool(wanted & keys)
```
