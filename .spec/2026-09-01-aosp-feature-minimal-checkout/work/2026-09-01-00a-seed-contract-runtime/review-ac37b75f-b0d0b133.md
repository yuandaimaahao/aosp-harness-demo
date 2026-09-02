# review 包 ac37b75f..b0d0b133

## commit 列表

```
b0d0b13 fix(harness): close terminal summary grammar
aaa5c4a feat(harness): validate terminal report artifact
```

## diff --stat

```
 common/.harness/closure/v1/lib/seed_contract_runtime.py |  9 ++++++---
 common/tests/fixtures/aosp17-services/seed.golden.json  |  1 +
 common/tests/test_seed_contract_runtime.py              | 11 ++++++++++-
 3 files changed, 17 insertions(+), 4 deletions(-)
```

## diff

```diff
diff --git a/common/.harness/closure/v1/lib/seed_contract_runtime.py b/common/.harness/closure/v1/lib/seed_contract_runtime.py
index d5d2228..b1dda98 100644
--- a/common/.harness/closure/v1/lib/seed_contract_runtime.py
+++ b/common/.harness/closure/v1/lib/seed_contract_runtime.py
@@ -16,21 +16,21 @@ def _guard(value):
         for key, item in value.items():
             if not isinstance(key, str) or not key.isascii(): raise ContractError("DESCRIPTOR_SCHEMA_INVALID")
             _guard(item)
         return
     raise ContractError("DESCRIPTOR_SCHEMA_INVALID")
 def canonical_bytes(*, value: object) -> bytes:
     _guard(value); return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
 def domain_digest(*, domain_ascii: str, value: object) -> str:
     if type(domain_ascii) is not str or not domain_ascii.isascii(): raise ContractError("ARGUMENT_ERROR")
     return hashlib.sha256(domain_ascii.encode() + canonical_bytes(value=value)).hexdigest()
-_DOMAINS={"seed_request":"aosp-harness/seed-request/v1\0","project_source_state":"aosp-harness/project-source-state/v1\0","source_state":"aosp-harness/source-state/v1\0","trace":"aosp-harness/trace/v1\0","command_journal":"aosp-harness/command-journal/v1\0","seed_content":"aosp-harness/seed-content/v1\0","seed_identity":"aosp-harness/seed-identity/v1\0","seed":"aosp-harness/seed-artifact/v1\0"}
+_DOMAINS={"seed_request":"aosp-harness/seed-request/v1\0","project_source_state":"aosp-harness/project-source-state/v1\0","source_state":"aosp-harness/source-state/v1\0","trace":"aosp-harness/trace/v1\0","command_journal":"aosp-harness/command-journal/v1\0","seed_content":"aosp-harness/seed-content/v1\0","seed_identity":"aosp-harness/seed-identity/v1\0","seed":"aosp-harness/seed-artifact/v1\0","terminal_report":"aosp-harness/terminal-report/v1\0"}
 def _bad(): raise ContractError("DESCRIPTOR_SCHEMA_INVALID")
 def _exact(v, keys): _bad() if type(v) is not dict or set(v) != set(keys) else None
 def _u(v): _bad() if type(v) is not int or not 0 <= v <= _SAFE else None
 def _i(v): _bad() if type(v) is not int or not -_SAFE <= v <= _SAFE else None
 def _text(v, ascii=False): _bad() if type(v) is not str or not v or ascii and not v.isascii() else None
 def _hex(v, lengths=(64,)): _bad() if type(v) is not str or len(v) not in lengths or any(c not in "0123456789abcdef" for c in v) else None
 def _b64(v):
     try:
         if type(v) is not str or base64.b64encode(base64.b64decode(v, validate=True)).decode() != v: _bad()
     except (ValueError,base64.binascii.Error): _bad()
@@ -101,24 +101,27 @@ def _seed_state(v,project_count=None):
     [_b64(x["path_b64"]) for x in v["observed_ignored_inputs"]]==sorted({_b64(x["path_b64"]) for x in v["observed_ignored_inputs"]}) or _bad()
 def _seed_guard(v): _exact(v,("parent_netns_inode","probe_netns_inode","trace_digest","command_journal_digest","external_network_count","source_mutation_count","sync_download_count","module_build_count","package_count")); [_u(v[x]) for x in v if x.endswith("count") or x.endswith("inode")]; [_hex(v[x]) for x in ("trace_digest","command_journal_digest")]
 def _seed_parts(v):
     request={"schema_version":1,"kind":"seed_request","source_root":v["source"]["root"],"envsetup_relpath":v["source"]["envsetup_relpath"],"lunch":{x:v["lunch"][x] for x in ("target","product","release","variant")},"source_scope":v["source_scope"],"resource_minimums":v["resources"]["minimums"],"estimated_disk_upper_bound_bytes":v["resources"]["estimated_disk_upper_bound_bytes"]}; content={"locked_xml_sha256":v["manifest"]["locked_xml_sha256"],"projects":v["manifest"]["projects"],"observed_ignored_inputs":v["source_state"]["observed_ignored_inputs"]}; identity={"source_scope":v["source_scope"],"manifest":v["manifest"],"tools":v["tools"],"execution_identity":{x:v["execution"][x] for x in ("host_arch","kind","container_digest")},"lunch_identity":{x:v["lunch"][x] for x in ("target","product","release","variant","variables")},"source_state_identity":v["source_state"],"seed_content_digest":domain_digest(domain_ascii=_DOMAINS["seed_content"],value=content)}; return request,content,identity
 def _seed(v):
     _exact(v,("schema_version","kind","evidence_class","request_digest","source_scope","source","manifest","tools","execution","resources","lunch","source_state","guard","seed_content_digest","seed_identity_digest")); v["evidence_class"] in ("real_source","fixture_only") or _bad(); _hex(v["request_digest"]); _scope(v["source_scope"]); _exact(v["source"],("root","envsetup_relpath")); _manifest(v["manifest"]); _tools(v["tools"]); _execution(v["execution"]); _resources(v["resources"]); _lunch(v["lunch"]); _seed_state(v["source_state"],len(v["manifest"]["projects"])); _seed_guard(v["guard"]); request,content,identity=_seed_parts(v); _request(request); v["request_digest"]==domain_digest(domain_ascii=_DOMAINS["seed_request"],value=request) and v["seed_content_digest"]==identity["seed_content_digest"] and v["seed_identity_digest"]==domain_digest(domain_ascii=_DOMAINS["seed_identity"],value=identity) or _bad(); all(v["resources"]["passed"].values()) and v["lunch"]["envsetup_exit"]==v["lunch"]["lunch_exit"]==0 and v["guard"]["parent_netns_inode"]!=v["guard"]["probe_netns_inode"] and not any(v["guard"][x] for x in ("external_network_count","source_mutation_count","sync_download_count","module_build_count","package_count")) and v["source_state"]["before_digest"]==v["source_state"]["after_digest"] or _bad()
 def _validate_public_real(payload,evidence):
     try: _validate_artifact(payload)
     except ContractError: return False
     return payload["evidence_class"]=="real_source" and payload["source_scope"]=={"role":"public_aosp17_cuttlefish","public_aosp_baseline":True,"vendor_context":False,"platform_family":"aosp-17"} and type(evidence) is dict and set(evidence)=={"source_state_before","source_state_after","trace","command_journal"} and all(type(x) is bool and x for x in evidence.values())
+def _terminal(v):
+    reasons=("SOURCE_ROOT_UNAVAILABLE","REPO_METADATA_UNAVAILABLE","ENVSETUP_UNAVAILABLE","REPO_CLIENT_UNAVAILABLE","WORKTREE_ENUM_UNAVAILABLE","RESOURCE_DISK","RESOURCE_INODE","RESOURCE_MEMORY","RESOURCE_CPU","NETWORK_NAMESPACE_UNAVAILABLE","TRACE_UNAVAILABLE","LUNCH_FAILED","FORBIDDEN_EXECUTION","SOURCE_MUTATION","SOURCE_CHANGED"); _exact(v,("schema_version","kind","request_digest","primary_reason","failed_checks","completed_observation_digests","summary_lines")); _hex(v["request_digest"]); type(v["failed_checks"]) is list and v["failed_checks"] and all(x in reasons for x in v["failed_checks"]) and v["failed_checks"]==sorted(set(v["failed_checks"]),key=reasons.index) and v["primary_reason"]==v["failed_checks"][0] or _bad(); _exact(v["completed_observation_digests"],("source_state","trace","command_journal")); [x is None or _hex(x) for x in v["completed_observation_digests"].values()]; type(v["summary_lines"]) is list and len(v["summary_lines"])<=120 and all(type(x) is str and x in v["failed_checks"] for x in v["summary_lines"]) or _bad()
+def _object_bytes(v): return canonical_bytes(value=v)+b"\n"
 def _validate_artifact(v):
-    _guard(v); handlers={"seed_request":_request,"source_state":_state,"trace":_trace,"command_journal":_journal,"seed":_seed}; _bad() if type(v) is not dict or type(v.get("schema_version")) is not int or v["schema_version"] != 1 or type(v.get("kind")) is not str or v["kind"] not in handlers else None; return (handlers[v["kind"]](v),_DOMAINS[v["kind"]])[1]
+    _guard(v); handlers={"seed_request":_request,"source_state":_state,"trace":_trace,"command_journal":_journal,"seed":_seed,"terminal_report":_terminal}; _bad() if type(v) is not dict or type(v.get("schema_version")) is not int or v["schema_version"] != 1 or type(v.get("kind")) is not str or v["kind"] not in handlers else None; return (handlers[v["kind"]](v),_DOMAINS[v["kind"]])[1]
 def load_artifact(*, path: str, expected_kind: str) -> dict:
-    if type(path) is not str or type(expected_kind) is not str or not path or expected_kind not in ("seed_request","source_state","trace","command_journal","seed"): raise ContractError("ARGUMENT_ERROR")
+    if type(path) is not str or type(expected_kind) is not str or not path or expected_kind not in ("seed_request","source_state","trace","command_journal","seed","terminal_report"): raise ContractError("ARGUMENT_ERROR")
     try: raw = open(path, "rb").read()
     except (OSError, TypeError): raise ContractError("DESCRIPTOR_NOT_FOUND") from None
     try: value = json.loads(raw.decode(), object_pairs_hook=_pairs)
     except UnicodeDecodeError: raise ContractError("DESCRIPTOR_INVALID_UTF8") from None
     except json.JSONDecodeError: raise ContractError("DESCRIPTOR_SCHEMA_INVALID") from None
     if type(value) is not dict or type(value.get("schema_version")) is not int: _bad()
     if value["schema_version"] != 1: raise ContractError("UNSUPPORTED_SCHEMA_VERSION")
     _guard(value)
     if not isinstance(value, dict) or value.get("kind") != expected_kind: raise ContractError("DESCRIPTOR_SCHEMA_INVALID")
     _validate_artifact(value)
diff --git a/common/tests/fixtures/aosp17-services/seed.golden.json b/common/tests/fixtures/aosp17-services/seed.golden.json
new file mode 100644
index 0000000..dc912ae
--- /dev/null
+++ b/common/tests/fixtures/aosp17-services/seed.golden.json
@@ -0,0 +1 @@
+{"evidence_class":"fixture_only","execution":{"container_digest":null,"host_arch":"x","kernel_release":"k","kind":"host"},"guard":{"command_journal_digest":"0000000000000000000000000000000000000000000000000000000000000000","external_network_count":0,"module_build_count":0,"package_count":0,"parent_netns_inode":1,"probe_netns_inode":2,"source_mutation_count":0,"sync_download_count":0,"trace_digest":"0000000000000000000000000000000000000000000000000000000000000000"},"kind":"seed","lunch":{"envsetup_exit":0,"lunch_exit":0,"out_dir_relative":"tmp/preflight/o","product":"p","release":"r","target":"t","variables":{"HOST_ARCH":null,"HOST_OS":null,"TARGET_2ND_ARCH":null,"TARGET_ARCH":null,"TARGET_BUILD_VARIANT":null,"TARGET_PRODUCT":null,"TARGET_RELEASE":null},"variant":"v"},"manifest":{"locked_xml_sha256":"0000000000000000000000000000000000000000000000000000000000000000","project_count":1,"projects":[{"head":"0000000000000000000000000000000000000000","name":"a","path":"a","remote":"r","revision":"r","source_state_digest":"0000000000000000000000000000000000000000000000000000000000000000"}],"remotes":[],"repository_commit":"0000000000000000000000000000000000000000"},"request_digest":"5fd6cac93686910c29b559035de83be42b298a37d2a7cafc4a424d7b334fd2f8","resources":{"estimated_disk_upper_bound_bytes":1,"measured":{"available_bytes":1,"available_inodes":1,"cgroup_mem_remaining_bytes":null,"cpuset_cpu_count":null,"effective_cpu_denominator":1,"effective_cpu_numerator":1,"effective_memory_bytes":1,"host_mem_available_bytes":1,"online_cpu_count":1},"minimums":{"available_bytes":1,"available_inodes":1,"effective_cpus":1,"effective_memory_bytes":1},"passed":{"cpu":true,"disk":true,"inodes":true,"memory":true}},"schema_version":1,"seed_content_digest":"e2aa90f5a480bee62511c5cd43c1ff849c9fdd1c340a2516512e246fee173443","seed_identity_digest":"bffeddfc7e780ef132ba29b19507f18f40c65cc8f9e8a808767b24931f03f5c4","source":{"envsetup_relpath":"build/envsetup.sh","root":"/"},"source_scope":{"platform_family":"aosp-17","public_aosp_baseline":true,"role":"public_aosp17_cuttlefish","vendor_context":false},"source_state":{"affected_project_count":0,"after_digest":"0000000000000000000000000000000000000000000000000000000000000000","before_digest":"0000000000000000000000000000000000000000000000000000000000000000","clean_source_proof":true,"observed_ignored_inputs":[{"content_sha256":"0000000000000000000000000000000000000000000000000000000000000000","entry_kind":"regular","mode":1,"path_b64":"YQ==","resolved_path_b64":"Yg==","symlink_target_sha256":null,"target_content_sha256":null}],"state":"clean"},"tools":{"git_version":"g","python_version":"p","repo_checkout_commit":null,"repo_launcher_path":"/","repo_launcher_sha256":"0000000000000000000000000000000000000000000000000000000000000000","repo_version":"r"}}
diff --git a/common/tests/test_seed_contract_runtime.py b/common/tests/test_seed_contract_runtime.py
index 2aa3691..afee81e 100644
--- a/common/tests/test_seed_contract_runtime.py
+++ b/common/tests/test_seed_contract_runtime.py
@@ -77,14 +77,23 @@ def seed():
         changed=copy.deepcopy(seed); changed["manifest"]["remotes"]=[{"name":"r","fetch_url":remote,"review_url":None,"mirror_url":None}]; finish(changed); assert runtime._validate_artifact(changed)=="aosp-harness/seed-artifact/v1\0"
     for provider in ("fetch_url","review_url","mirror_url"):
         for key in ("private_token","PRIVATETOKEN","PrivateToken","oauth_token","OAUTHTOKEN","oAuThToKeN","client_secret","CLIENTSECRET","ClientSecret","X-Amz-Credential","XAMZCREDENTIAL","xAmZcReDeNtIaL","X-Amz-Signature","XAMZSIGNATURE","xAmZsIgNaTuRe","password","auth","api_key"):
             remote={"name":"r","fetch_url":None,"review_url":None,"mirror_url":None}; remote[provider]=f"https://example/repo?{key}=secret"; changed=copy.deepcopy(seed); changed["manifest"]["remotes"]=[remote]; finish(changed); bad(lambda changed=changed:runtime._validate_artifact(changed),"DESCRIPTOR_SCHEMA_INVALID")
         remote={"name":"r","fetch_url":None,"review_url":None,"mirror_url":None}; remote[provider]="https://example/repo/@scope/project?ref=main&author=alice"; changed=copy.deepcopy(seed); changed["manifest"]["remotes"]=[remote]; finish(changed); assert runtime._validate_artifact(changed)=="aosp-harness/seed-artifact/v1\0"
     evidence={"source_state_before":True,"source_state_after":True,"trace":True,"command_journal":True}; vendor=finish(copy.deepcopy(seed)); vendor["evidence_class"]="real_source"; vendor=finish(vendor); assert runtime._validate_artifact(vendor)=="aosp-harness/seed-artifact/v1\0" and not runtime._validate_public_real(seed,evidence) and not runtime._validate_public_real(vendor,evidence)
     public=finish(copy.deepcopy(seed)); public.update(evidence_class="real_source",source_scope={"role":"public_aosp17_cuttlefish","public_aosp_baseline":True,"vendor_context":False,"platform_family":"aosp-17"}); public=finish(public); assert expected(public)[2]!=identity and runtime._validate_public_real(public,evidence) and not runtime._validate_public_real(public,{**evidence,"trace":False})
     for key,value in (("schema_version",2),("kind","not-seed")): changed=copy.deepcopy(public); changed[key]=value; assert not runtime._validate_public_real(changed,evidence)
     with tempfile.TemporaryDirectory() as d:
         p=Path(d)/"seed.json"; p.write_text(__import__("json").dumps(seed)); link=Path(d)/"repo"; link.symlink_to(p); launcher=copy.deepcopy(seed); launcher["tools"]["repo_launcher_path"]=str(link); finish(launcher); assert load_artifact(path=str(p),expected_kind="seed")==seed and runtime._validate_artifact(launcher)=="aosp-harness/seed-artifact/v1\0"
+def terminal():
+    runtime=__import__("seed_contract_runtime"); copy=__import__("copy"); fixture=Path(__file__).parent/"fixtures/aosp17-services/seed.golden.json"; golden=load_artifact(path=str(fixture),expected_kind="seed"); assert fixture.read_bytes()==runtime._object_bytes(golden) and golden["evidence_class"]=="fixture_only" and golden["source_scope"]["role"]=="public_aosp17_cuttlefish" and domain_digest(domain_ascii="aosp-harness/seed-artifact/v1\0",value=golden)=="07ed847af333505342d14f49d28982f6bcc307984dbf928cd762b49c7872587f"
+    reasons=("SOURCE_ROOT_UNAVAILABLE","REPO_METADATA_UNAVAILABLE","ENVSETUP_UNAVAILABLE","REPO_CLIENT_UNAVAILABLE","WORKTREE_ENUM_UNAVAILABLE","RESOURCE_DISK","RESOURCE_INODE","RESOURCE_MEMORY","RESOURCE_CPU","NETWORK_NAMESPACE_UNAVAILABLE","TRACE_UNAVAILABLE","LUNCH_FAILED","FORBIDDEN_EXECUTION","SOURCE_MUTATION","SOURCE_CHANGED"); report={"schema_version":1,"kind":"terminal_report","request_digest":"0"*64,"primary_reason":reasons[0],"failed_checks":[reasons[0],reasons[10]],"completed_observation_digests":{"source_state":None,"trace":"0"*64,"command_journal":None},"summary_lines":[reasons[0],reasons[10],reasons[0]]}; assert runtime._validate_artifact(report)=="aosp-harness/terminal-report/v1\0" and runtime._object_bytes(report)==canonical_bytes(value=report)+b"\n" and domain_digest(domain_ascii="aosp-harness/terminal-report/v1\0",value=report)=="83ffe86b71affe2165201193c163c9e531ed08b6a3ff76a56db8e1b625bd4268"; evidence(); seed()
+    for key in report: changed=copy.deepcopy(report); changed.pop(key); bad(lambda changed=changed:runtime._validate_artifact(changed),"DESCRIPTOR_SCHEMA_INVALID"); changed=copy.deepcopy(report); changed[key]={}; bad(lambda changed=changed:runtime._validate_artifact(changed),"DESCRIPTOR_SCHEMA_INVALID"); changed=copy.deepcopy(report); changed[key]=None; bad(lambda changed=changed:runtime._validate_artifact(changed),"DESCRIPTOR_SCHEMA_INVALID")
+    for key in report["completed_observation_digests"]: changed=copy.deepcopy(report); changed["completed_observation_digests"].pop(key); bad(lambda changed=changed:runtime._validate_artifact(changed),"DESCRIPTOR_SCHEMA_INVALID"); changed=copy.deepcopy(report); changed["completed_observation_digests"][key]=[]; bad(lambda changed=changed:runtime._validate_artifact(changed),"DESCRIPTOR_SCHEMA_INVALID"); changed=copy.deepcopy(report); changed["completed_observation_digests"][key]=None; runtime._validate_artifact(changed)
+    for reason in reasons: changed=copy.deepcopy(report); changed.update(primary_reason=reason,failed_checks=[reason],summary_lines=[reason]); runtime._validate_artifact(changed)
+    for lines in ([reasons[10],reasons[0],reasons[10]],[reasons[0]]*120): changed=copy.deepcopy(report); changed["summary_lines"]=lines; runtime._validate_artifact(changed)
+    for fn in (lambda x:x.update(failed_checks=[]),lambda x:x.update(failed_checks=["UNKNOWN"]),lambda x:x.update(failed_checks=[None]),lambda x:x.update(failed_checks=[reasons[10],reasons[0]]),lambda x:x.update(failed_checks=[reasons[0],reasons[0]]),lambda x:x.update(primary_reason=reasons[10]),lambda x:x["completed_observation_digests"].update(extra=None),lambda x:x["completed_observation_digests"].update(trace="A"*64),lambda x:x.update(summary_lines=[None]),lambda x:x.update(summary_lines=[reasons[0]]*121),lambda x:x.update(summary_lines=["alice"]),lambda x:x.update(summary_lines=["12:00:00Z"]),lambda x:x.update(summary_lines=["1788283200"]),lambda x:x.update(summary_lines=["ghp_abcdefgh"]),lambda x:x.update(summary_lines=["AKIA123"]),lambda x:x.update(summary_lines=["int main(void) { return 0; }"])): changed=copy.deepcopy(report); fn(changed); bad(lambda changed=changed:runtime._validate_artifact(changed),"DESCRIPTOR_SCHEMA_INVALID")
+    changed=copy.deepcopy(golden); changed["guard"]["trace_digest"]="1"*64; assert runtime._validate_artifact(changed)==runtime._DOMAINS["seed"] and changed["seed_identity_digest"]==golden["seed_identity_digest"] and domain_digest(domain_ascii=runtime._DOMAINS["seed"],value=changed)!=domain_digest(domain_ascii=runtime._DOMAINS["seed"],value=golden)
 if __name__ == "__main__":
-    cases = {"canonical-core": core, "concurrent-core": concurrent, "evidence-schema": evidence,"seed-schema":seed}
+    cases = {"canonical-core": core, "concurrent-core": concurrent, "evidence-schema": evidence,"seed-schema":seed,"terminal-golden":terminal}
     try: [(cases[case](), print("PASS " + case)) for case in sys.argv[1:]]
     except (IndexError, KeyError): raise SystemExit("usage: canonical-core|concurrent-core") from None
```
