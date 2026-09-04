# review 包 ffb05899..3ab44a54

## commit 列表

```
3ab44a5 fix(resource-lease): retry once at deadline
```

## diff --stat

```
 common/.harness/lib/resource-leases.sh | 4 ++--
 1 file changed, 2 insertions(+), 2 deletions(-)
```

## diff

```diff
diff --git a/common/.harness/lib/resource-leases.sh b/common/.harness/lib/resource-leases.sh
index 99aa664..f5e7945 100644
--- a/common/.harness/lib/resource-leases.sh
+++ b/common/.harness/lib/resource-leases.sh
@@ -239,22 +239,22 @@ def acquire(pid, pwd, session, wait, request_path):
                         if os.path.exists(temporary):
                             os.unlink(temporary)
                     try:
                         os.write(1, (token + "\n").encode())
                     except OSError:
                         remove_record(root, os.path.join(root, "active-" + token), token)
                         raise
                     return
             finally:
                 fcntl.flock(lock_fd, fcntl.LOCK_UN)
-            if not occupied or wait_value == 0 or test_seam("monotonic", time.monotonic()) >= deadline:
-                die(BUSY, 3)
+            if not occupied or wait_value == 0: die(BUSY, 3)
+            if test_seam("monotonic", time.monotonic()) >= deadline: continue
             time.sleep(min(0.05, max(0.0, deadline - time.monotonic())))
     finally:
         os.close(lock_fd)
 def release(pid, token):
     if not re.fullmatch(r"[0-9a-f]{32}", token): raise LeaseError()
     current = owner(pid)
     root, lock_fd = root_and_lock()
     try:
         test_seam("flock"); fcntl.flock(lock_fd, fcntl.LOCK_EX)
         recover_trash(root)
```
