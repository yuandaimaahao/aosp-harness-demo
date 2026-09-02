# review 包 7f2d97fe..bf1b8fac

## commit 列表

```
bf1b8fa fix(harness): reject sensitive remote query keys
```

## diff --stat

```
 common/.harness/closure/v1/lib/seed_contract_runtime.py | 7 +++++--
 common/tests/test_seed_contract_runtime.py              | 4 ++++
 2 files changed, 9 insertions(+), 2 deletions(-)
```

## diff

```diff
diff --git a/common/.harness/closure/v1/lib/seed_contract_runtime.py b/common/.harness/closure/v1/lib/seed_contract_runtime.py
index a16e9e9..95230af 100644
--- a/common/.harness/closure/v1/lib/seed_contract_runtime.py
+++ b/common/.harness/closure/v1/lib/seed_contract_runtime.py
@@ -1,11 +1,11 @@
-import base64, hashlib, json, os; from urllib.parse import parse_qsl,urlsplit; RUNTIME_ABI, _SAFE = "seed-contract-runtime/v1", 2**53-1
+import base64, hashlib, json, os, re; from urllib.parse import parse_qsl,urlsplit; RUNTIME_ABI, _SAFE = "seed-contract-runtime/v1", 2**53-1
 class ContractError(Exception):
     def __init__(self, code: str) -> None: self._code = code if isinstance(code, str) else "ARGUMENT_ERROR"; super().__init__(self._code)
     code = property(lambda self: self._code)
 def _pairs(pairs):
     if len(result := dict(pairs)) != len(pairs): raise ContractError("DUPLICATE_JSON_KEY")
     return result
 def _guard(value):
     if value is None or isinstance(value, bool): return
     if isinstance(value, int) and -_SAFE <= value <= _SAFE: return
     if isinstance(value, str) and not any(0xd800 <= ord(c) <= 0xdfff for c in value): return
@@ -29,26 +29,29 @@ def _exact(v, keys): _bad() if type(v) is not dict or set(v) != set(keys) else N
 def _u(v): _bad() if type(v) is not int or not 0 <= v <= _SAFE else None
 def _i(v): _bad() if type(v) is not int or not -_SAFE <= v <= _SAFE else None
 def _text(v, ascii=False): _bad() if type(v) is not str or not v or ascii and not v.isascii() else None
 def _hex(v, lengths=(64,)): _bad() if type(v) is not str or len(v) not in lengths or any(c not in "0123456789abcdef" for c in v) else None
 def _b64(v):
     try:
         if type(v) is not str or base64.b64encode(base64.b64decode(v, validate=True)).decode() != v: _bad()
     except (ValueError,base64.binascii.Error): _bad()
     return base64.b64decode(v)
 def _rel(v): _text(v); _bad() if "\0" in v or v.startswith("/") or any(x in ("", ".", "..") for x in v.split("/")) else None
+def _credential_key(v):
+    parts=tuple(x for x in re.split("[^a-z0-9]+",re.sub(r"(?<=[a-z0-9])(?=[A-Z])","_",v).lower()) if x)
+    return any(x in {"token","secret","credential","signature","password","passwd","auth","authorization","apikey"} for x in parts) or any(parts[x:x+2]==("api","key") for x in range(len(parts)-1))
 def _url(v):
     if v is None: return
     type(v) is str or _bad()
     try: u=urlsplit(v)
     except ValueError: _bad()
-    u.username is None and not {k.lower() for k,_ in parse_qsl(u.query,keep_blank_values=True)} & {"access_token","token","password","passwd","secret","api_key","apikey","authorization"} or _bad()
+    u.username is None and not any(_credential_key(k) for k,_ in parse_qsl(u.query,keep_blank_values=True)) or _bad()
 def _scope(v): _exact(v,("role","public_aosp_baseline","vendor_context","platform_family")); type(v["public_aosp_baseline"]) is type(v["vendor_context"]) is bool or _bad(); _bad() if v not in ({"role":"public_aosp17_cuttlefish","public_aosp_baseline":True,"vendor_context":False,"platform_family":"aosp-17"},{"role":"local_lk7k_product","public_aosp_baseline":False,"vendor_context":True,"platform_family":"aosp-17"}) else None
 def _entry(v):
     _exact(v,("path_b64","status_record_b64","entry_kind","mode","content_sha256","symlink_target_sha256")); _b64(v["path_b64"]); _b64(v["status_record_b64"]); _u(v["mode"])
     _text(v["entry_kind"]); {"regular":lambda:(_hex(v["content_sha256"]),v["symlink_target_sha256"] is None or _bad()),"symlink":lambda:(_hex(v["symlink_target_sha256"]),v["content_sha256"] is None or _bad()),"missing":lambda:v["mode"] == 0 and v["content_sha256"] is None and v["symlink_target_sha256"] is None or _bad()}.get(v["entry_kind"],_bad)()
 def _project(v):
     _exact(v,("path","head","status_sha256","entries")); _rel(v["path"]); _hex(v["head"],(40,64)); _hex(v["status_sha256"])
     type(v["entries"]) is list or _bad(); [_entry(x) for x in v["entries"]]
     if [_b64(x["path_b64"]) for x in v["entries"]] != sorted({_b64(x["path_b64"]) for x in v["entries"]}): _bad()
     return _DOMAINS["project_source_state"]
 def _request(v):
diff --git a/common/tests/test_seed_contract_runtime.py b/common/tests/test_seed_contract_runtime.py
index 0057a5a..3239aef 100644
--- a/common/tests/test_seed_contract_runtime.py
+++ b/common/tests/test_seed_contract_runtime.py
@@ -68,19 +68,23 @@ def seed():
     for q,z in ((('manifest','repository_commit'),"1"*40),(('tools','repo_version'),"x"),(('execution','host_arch'),"y"),(('lunch','target'),"x"),(('lunch','variables','TARGET_2ND_ARCH'),""),(('source_state','observed_ignored_inputs',0,'content_sha256'),"1"*64)):
         changed=copy.deepcopy(seed); get(changed,q[:-1])[q[-1]]=z; finish(changed); assert expected(changed)[2]!=identity and runtime._validate_artifact(changed)=="aosp-harness/seed-artifact/v1\0"
     changed=copy.deepcopy(seed); changed["source_state"].update(before_digest="1"*64,after_digest="1"*64); finish(changed); assert expected(changed)[2]!=identity and runtime._validate_artifact(changed)=="aosp-harness/seed-artifact/v1\0"
     for state,proof,count,good in (("clean",True,0,True),("clean",False,0,False),("clean",True,1,False),("dirty",False,1,True),("dirty",False,0,False),("dirty",True,1,False),("dirty",False,2,False)):
         changed=copy.deepcopy(seed); changed["source_state"].update(state=state,clean_source_proof=proof,affected_project_count=count); finish(changed); (runtime._validate_artifact(changed) if good else bad(lambda changed=changed:runtime._validate_artifact(changed),"DESCRIPTOR_SCHEMA_INVALID"))
     for path,value in ((('execution','container_digest'),"1"*64),(('manifest','remotes'),[{"name":"r","fetch_url":"https://alice:secret@example/repo","review_url":None,"mirror_url":None}]),(('manifest','remotes'),[{"name":"r","fetch_url":"https://example/repo?access_token=secret","review_url":None,"mirror_url":None}]),(('manifest','projects',0,'path'),"a\0b"),(('lunch','out_dir_relative'),"tmp/preflight/a\0b")):
         changed=copy.deepcopy(seed); get(changed,path[:-1])[path[-1]]=value; finish(changed); bad(lambda changed=changed:runtime._validate_artifact(changed),"DESCRIPTOR_SCHEMA_INVALID")
     container=copy.deepcopy(seed); container["execution"].update(kind="container",container_digest="1"*64); finish(container); assert runtime._validate_artifact(container)=="aosp-harness/seed-artifact/v1\0"
     for remote in ("https://example/repo/@scope/project",""):
         changed=copy.deepcopy(seed); changed["manifest"]["remotes"]=[{"name":"r","fetch_url":remote,"review_url":None,"mirror_url":None}]; finish(changed); assert runtime._validate_artifact(changed)=="aosp-harness/seed-artifact/v1\0"
+    for provider in ("fetch_url","review_url","mirror_url"):
+        for key in ("private_token","oauth_token","client_secret","X-Amz-Credential","X-Amz-Signature","password","auth","api_key"):
+            remote={"name":"r","fetch_url":None,"review_url":None,"mirror_url":None}; remote[provider]=f"https://example/repo?{key}=secret"; changed=copy.deepcopy(seed); changed["manifest"]["remotes"]=[remote]; finish(changed); bad(lambda changed=changed:runtime._validate_artifact(changed),"DESCRIPTOR_SCHEMA_INVALID")
+        remote={"name":"r","fetch_url":None,"review_url":None,"mirror_url":None}; remote[provider]="https://example/repo/@scope/project?ref=main&author=alice"; changed=copy.deepcopy(seed); changed["manifest"]["remotes"]=[remote]; finish(changed); assert runtime._validate_artifact(changed)=="aosp-harness/seed-artifact/v1\0"
     evidence={"source_state_before":True,"source_state_after":True,"trace":True,"command_journal":True}; vendor=finish(copy.deepcopy(seed)); vendor["evidence_class"]="real_source"; vendor=finish(vendor); assert runtime._validate_artifact(vendor)=="aosp-harness/seed-artifact/v1\0" and not runtime._validate_public_real(seed,evidence) and not runtime._validate_public_real(vendor,evidence)
     public=finish(copy.deepcopy(seed)); public.update(evidence_class="real_source",source_scope={"role":"public_aosp17_cuttlefish","public_aosp_baseline":True,"vendor_context":False,"platform_family":"aosp-17"}); public=finish(public); assert expected(public)[2]!=identity and runtime._validate_public_real(public,evidence) and not runtime._validate_public_real(public,{**evidence,"trace":False})
     for key,value in (("schema_version",2),("kind","not-seed")): changed=copy.deepcopy(public); changed[key]=value; assert not runtime._validate_public_real(changed,evidence)
     with tempfile.TemporaryDirectory() as d:
         p=Path(d)/"seed.json"; p.write_text(__import__("json").dumps(seed)); link=Path(d)/"repo"; link.symlink_to(p); launcher=copy.deepcopy(seed); launcher["tools"]["repo_launcher_path"]=str(link); finish(launcher); assert load_artifact(path=str(p),expected_kind="seed")==seed and runtime._validate_artifact(launcher)=="aosp-harness/seed-artifact/v1\0"
 if __name__ == "__main__":
     cases = {"canonical-core": core, "concurrent-core": concurrent, "evidence-schema": evidence,"seed-schema":seed}
     try: [(cases[case](), print("PASS " + case)) for case in sys.argv[1:]]
     except (IndexError, KeyError): raise SystemExit("usage: canonical-core|concurrent-core") from None
```
