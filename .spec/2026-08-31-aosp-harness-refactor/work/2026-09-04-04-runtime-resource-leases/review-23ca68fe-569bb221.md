# review 包 23ca68fe..569bb221

## commit 列表

```
569bb22 fix(harness): stop lease publish after deadline
```

## diff --stat

```
 common/.harness/lib/resource-leases.sh | 4 ++--
 1 file changed, 2 insertions(+), 2 deletions(-)
```

## diff

```diff
diff --git a/common/.harness/lib/resource-leases.sh b/common/.harness/lib/resource-leases.sh
index 7f6c0e3..99aa664 100644
--- a/common/.harness/lib/resource-leases.sh
+++ b/common/.harness/lib/resource-leases.sh
@@ -182,33 +182,33 @@ def recover_trash(root):
             test_seam("unlink"); os.unlink(os.path.join(root, name))
 def remove_record(root, path, token):
     trash = os.path.join(root, ".trash-" + token)
     test_seam("unpublish"); os.replace(path, trash)
     test_seam("unlink"); os.unlink(trash)
 def acquire(pid, pwd, session, wait, request_path):
     session_bytes = os.fsencode(session)
     if not safe_component(session_bytes) or not re.fullmatch(r"(?:0|[1-9][0-9]{0,2})", wait):
         raise LeaseError()
     wait_value = int(wait)
-    if wait_value > 300:
-        raise LeaseError()
+    if wait_value > 300: raise LeaseError()
     canonical, digest, wanted = normalize(request_path, pwd)
     current = owner(pid)
     root, lock_fd = root_and_lock()
     deadline = test_seam("monotonic", time.monotonic()) + wait_value
     try:
         while True:
             occupied = False
             try: test_seam("flock"); fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
             except BlockingIOError:
                 if wait_value == 0 or test_seam("monotonic", time.monotonic()) >= deadline: die(BUSY, 3)
                 time.sleep(min(0.05, max(0.0, deadline - time.monotonic()))); continue
+            if wait_value and test_seam("monotonic", time.monotonic()) >= deadline: die(BUSY, 3)
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
