# review 包 bf1b8fac..ac37b75f

## commit 列表

```
ac37b75 fix(harness): normalize credential query keys
```

## diff --stat

```
 common/.harness/closure/v1/lib/seed_contract_runtime.py | 4 ++--
 common/tests/test_seed_contract_runtime.py              | 2 +-
 2 files changed, 3 insertions(+), 3 deletions(-)
```

## diff

```diff
diff --git a/common/.harness/closure/v1/lib/seed_contract_runtime.py b/common/.harness/closure/v1/lib/seed_contract_runtime.py
index 95230af..d5d2228 100644
--- a/common/.harness/closure/v1/lib/seed_contract_runtime.py
+++ b/common/.harness/closure/v1/lib/seed_contract_runtime.py
@@ -30,22 +30,22 @@ def _u(v): _bad() if type(v) is not int or not 0 <= v <= _SAFE else None
 def _i(v): _bad() if type(v) is not int or not -_SAFE <= v <= _SAFE else None
 def _text(v, ascii=False): _bad() if type(v) is not str or not v or ascii and not v.isascii() else None
 def _hex(v, lengths=(64,)): _bad() if type(v) is not str or len(v) not in lengths or any(c not in "0123456789abcdef" for c in v) else None
 def _b64(v):
     try:
         if type(v) is not str or base64.b64encode(base64.b64decode(v, validate=True)).decode() != v: _bad()
     except (ValueError,base64.binascii.Error): _bad()
     return base64.b64decode(v)
 def _rel(v): _text(v); _bad() if "\0" in v or v.startswith("/") or any(x in ("", ".", "..") for x in v.split("/")) else None
 def _credential_key(v):
-    parts=tuple(x for x in re.split("[^a-z0-9]+",re.sub(r"(?<=[a-z0-9])(?=[A-Z])","_",v).lower()) if x)
-    return any(x in {"token","secret","credential","signature","password","passwd","auth","authorization","apikey"} for x in parts) or any(parts[x:x+2]==("api","key") for x in range(len(parts)-1))
+    compact=re.sub("[^a-z0-9]","",v.lower())
+    return any(x in compact for x in ("token","secret","credential","signature","password","passwd","apikey")) or compact in ("auth","authorization","authentication","oauth")
 def _url(v):
     if v is None: return
     type(v) is str or _bad()
     try: u=urlsplit(v)
     except ValueError: _bad()
     u.username is None and not any(_credential_key(k) for k,_ in parse_qsl(u.query,keep_blank_values=True)) or _bad()
 def _scope(v): _exact(v,("role","public_aosp_baseline","vendor_context","platform_family")); type(v["public_aosp_baseline"]) is type(v["vendor_context"]) is bool or _bad(); _bad() if v not in ({"role":"public_aosp17_cuttlefish","public_aosp_baseline":True,"vendor_context":False,"platform_family":"aosp-17"},{"role":"local_lk7k_product","public_aosp_baseline":False,"vendor_context":True,"platform_family":"aosp-17"}) else None
 def _entry(v):
     _exact(v,("path_b64","status_record_b64","entry_kind","mode","content_sha256","symlink_target_sha256")); _b64(v["path_b64"]); _b64(v["status_record_b64"]); _u(v["mode"])
     _text(v["entry_kind"]); {"regular":lambda:(_hex(v["content_sha256"]),v["symlink_target_sha256"] is None or _bad()),"symlink":lambda:(_hex(v["symlink_target_sha256"]),v["content_sha256"] is None or _bad()),"missing":lambda:v["mode"] == 0 and v["content_sha256"] is None and v["symlink_target_sha256"] is None or _bad()}.get(v["entry_kind"],_bad)()
diff --git a/common/tests/test_seed_contract_runtime.py b/common/tests/test_seed_contract_runtime.py
index 3239aef..2aa3691 100644
--- a/common/tests/test_seed_contract_runtime.py
+++ b/common/tests/test_seed_contract_runtime.py
@@ -69,21 +69,21 @@ def seed():
         changed=copy.deepcopy(seed); get(changed,q[:-1])[q[-1]]=z; finish(changed); assert expected(changed)[2]!=identity and runtime._validate_artifact(changed)=="aosp-harness/seed-artifact/v1\0"
     changed=copy.deepcopy(seed); changed["source_state"].update(before_digest="1"*64,after_digest="1"*64); finish(changed); assert expected(changed)[2]!=identity and runtime._validate_artifact(changed)=="aosp-harness/seed-artifact/v1\0"
     for state,proof,count,good in (("clean",True,0,True),("clean",False,0,False),("clean",True,1,False),("dirty",False,1,True),("dirty",False,0,False),("dirty",True,1,False),("dirty",False,2,False)):
         changed=copy.deepcopy(seed); changed["source_state"].update(state=state,clean_source_proof=proof,affected_project_count=count); finish(changed); (runtime._validate_artifact(changed) if good else bad(lambda changed=changed:runtime._validate_artifact(changed),"DESCRIPTOR_SCHEMA_INVALID"))
     for path,value in ((('execution','container_digest'),"1"*64),(('manifest','remotes'),[{"name":"r","fetch_url":"https://alice:secret@example/repo","review_url":None,"mirror_url":None}]),(('manifest','remotes'),[{"name":"r","fetch_url":"https://example/repo?access_token=secret","review_url":None,"mirror_url":None}]),(('manifest','projects',0,'path'),"a\0b"),(('lunch','out_dir_relative'),"tmp/preflight/a\0b")):
         changed=copy.deepcopy(seed); get(changed,path[:-1])[path[-1]]=value; finish(changed); bad(lambda changed=changed:runtime._validate_artifact(changed),"DESCRIPTOR_SCHEMA_INVALID")
     container=copy.deepcopy(seed); container["execution"].update(kind="container",container_digest="1"*64); finish(container); assert runtime._validate_artifact(container)=="aosp-harness/seed-artifact/v1\0"
     for remote in ("https://example/repo/@scope/project",""):
         changed=copy.deepcopy(seed); changed["manifest"]["remotes"]=[{"name":"r","fetch_url":remote,"review_url":None,"mirror_url":None}]; finish(changed); assert runtime._validate_artifact(changed)=="aosp-harness/seed-artifact/v1\0"
     for provider in ("fetch_url","review_url","mirror_url"):
-        for key in ("private_token","oauth_token","client_secret","X-Amz-Credential","X-Amz-Signature","password","auth","api_key"):
+        for key in ("private_token","PRIVATETOKEN","PrivateToken","oauth_token","OAUTHTOKEN","oAuThToKeN","client_secret","CLIENTSECRET","ClientSecret","X-Amz-Credential","XAMZCREDENTIAL","xAmZcReDeNtIaL","X-Amz-Signature","XAMZSIGNATURE","xAmZsIgNaTuRe","password","auth","api_key"):
             remote={"name":"r","fetch_url":None,"review_url":None,"mirror_url":None}; remote[provider]=f"https://example/repo?{key}=secret"; changed=copy.deepcopy(seed); changed["manifest"]["remotes"]=[remote]; finish(changed); bad(lambda changed=changed:runtime._validate_artifact(changed),"DESCRIPTOR_SCHEMA_INVALID")
         remote={"name":"r","fetch_url":None,"review_url":None,"mirror_url":None}; remote[provider]="https://example/repo/@scope/project?ref=main&author=alice"; changed=copy.deepcopy(seed); changed["manifest"]["remotes"]=[remote]; finish(changed); assert runtime._validate_artifact(changed)=="aosp-harness/seed-artifact/v1\0"
     evidence={"source_state_before":True,"source_state_after":True,"trace":True,"command_journal":True}; vendor=finish(copy.deepcopy(seed)); vendor["evidence_class"]="real_source"; vendor=finish(vendor); assert runtime._validate_artifact(vendor)=="aosp-harness/seed-artifact/v1\0" and not runtime._validate_public_real(seed,evidence) and not runtime._validate_public_real(vendor,evidence)
     public=finish(copy.deepcopy(seed)); public.update(evidence_class="real_source",source_scope={"role":"public_aosp17_cuttlefish","public_aosp_baseline":True,"vendor_context":False,"platform_family":"aosp-17"}); public=finish(public); assert expected(public)[2]!=identity and runtime._validate_public_real(public,evidence) and not runtime._validate_public_real(public,{**evidence,"trace":False})
     for key,value in (("schema_version",2),("kind","not-seed")): changed=copy.deepcopy(public); changed[key]=value; assert not runtime._validate_public_real(changed,evidence)
     with tempfile.TemporaryDirectory() as d:
         p=Path(d)/"seed.json"; p.write_text(__import__("json").dumps(seed)); link=Path(d)/"repo"; link.symlink_to(p); launcher=copy.deepcopy(seed); launcher["tools"]["repo_launcher_path"]=str(link); finish(launcher); assert load_artifact(path=str(p),expected_kind="seed")==seed and runtime._validate_artifact(launcher)=="aosp-harness/seed-artifact/v1\0"
 if __name__ == "__main__":
     cases = {"canonical-core": core, "concurrent-core": concurrent, "evidence-schema": evidence,"seed-schema":seed}
     try: [(cases[case](), print("PASS " + case)) for case in sys.argv[1:]]
```
