import base64, hashlib, json, os, re; from urllib.parse import parse_qsl,urlsplit; RUNTIME_ABI, _SAFE = "seed-contract-runtime/v1", 2**53-1
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
    if isinstance(value, list):
        for item in value: _guard(item)
        return
    if isinstance(value, dict):
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
_DOMAINS={"seed_request":"aosp-harness/seed-request/v1\0","project_source_state":"aosp-harness/project-source-state/v1\0","source_state":"aosp-harness/source-state/v1\0","trace":"aosp-harness/trace/v1\0","command_journal":"aosp-harness/command-journal/v1\0","seed_content":"aosp-harness/seed-content/v1\0","seed_identity":"aosp-harness/seed-identity/v1\0","seed":"aosp-harness/seed-artifact/v1\0","terminal_report":"aosp-harness/terminal-report/v1\0"}
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
    return base64.b64decode(v)
def _rel(v): _text(v); _bad() if "\0" in v or v.startswith("/") or any(x in ("", ".", "..") for x in v.split("/")) else None
def _credential_key(v):
    compact=re.sub("[^a-z0-9]","",v.lower())
    return any(x in compact for x in ("token","secret","credential","signature","password","passwd","apikey")) or compact in ("auth","authorization","authentication","oauth")
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
def _project(v):
    _exact(v,("path","head","status_sha256","entries")); _rel(v["path"]); _hex(v["head"],(40,64)); _hex(v["status_sha256"])
    type(v["entries"]) is list or _bad(); [_entry(x) for x in v["entries"]]
    if [_b64(x["path_b64"]) for x in v["entries"]] != sorted({_b64(x["path_b64"]) for x in v["entries"]}): _bad()
    return _DOMAINS["project_source_state"]
def _request(v):
    _exact(v,("schema_version","kind","source_root","envsetup_relpath","lunch","source_scope","resource_minimums","estimated_disk_upper_bound_bytes")); _text(v["source_root"]); _rel(v["envsetup_relpath"]); _scope(v["source_scope"]); _u(v["estimated_disk_upper_bound_bytes"])
    "\0" not in v["source_root"] and v["source_root"].startswith("/") and v["source_root"] == os.path.realpath(v["source_root"]) and v["envsetup_relpath"] == "build/envsetup.sh" or _bad(); _exact(v["lunch"],("target","product","release","variant")); [_text(x) for x in v["lunch"].values()]; _exact(v["resource_minimums"],("available_bytes","available_inodes","effective_memory_bytes","effective_cpus")); [_u(x) for x in v["resource_minimums"].values()]
def _state(v):
    _exact(v,("schema_version","kind","manifest_sha256","projects")); _hex(v["manifest_sha256"])
    type(v["projects"]) is list or _bad(); [_project(x) for x in v["projects"]]
    if [x["path"].encode() for x in v["projects"]] != sorted({x["path"].encode() for x in v["projects"]}): _bad()
def _trace(v):
    kinds=("other","external_network","source_mutation","sync_download","config_query","module_build","package"); _exact(v,("schema_version","kind","records","counts")); _exact(v["counts"],kinds)
    if type(v["records"]) is not list: _bad()
    for r in v["records"]:
        _exact(r,("sequence","process_ordinal","syscall","result","errno","exec_argv_b64","paths","address_family","classification")); _u(r["sequence"]); _u(r["process_ordinal"]); _text(r["syscall"],True); _i(r["result"])
        if (r["result"] >= 0) != (r["errno"] is None): _bad()
        if r["errno"] is not None: _text(r["errno"],True)
        {"execve":lambda:type(r["exec_argv_b64"]) is list or _bad(),"execveat":lambda:type(r["exec_argv_b64"]) is list or _bad()}.get(r["syscall"],lambda:r["exec_argv_b64"] is None or _bad())(); r["syscall"] not in ("execve","execveat") or [_b64(x) for x in r["exec_argv_b64"]]
        if type(r["paths"]) is not list or r["address_family"] not in (None,"AF_INET","AF_INET6","AF_UNIX","AF_OTHER") or r["classification"] not in kinds: _bad()
        for p in r["paths"]: _exact(p,("role","dirfd","raw_b64","resolved_b64")); _b64(p["raw_b64"]); _b64(p["resolved_b64"]); p["dirfd"] is None or _i(p["dirfd"]); p["role"] in ("path","oldpath","newpath","target","linkpath","source_fd","destination_fd") or _bad()
    if [r["sequence"] for r in v["records"]] != sorted({r["sequence"] for r in v["records"]}): _bad()
    for k in kinds: _u(v["counts"][k]); v["counts"][k] == sum(r["classification"] == k and r["result"] >= 0 for r in v["records"]) or _bad()
def _journal(v):
    stages=("manifest_before","source_state_before","namespace_probe","envsetup_lunch","manifest_after","source_state_after"); _exact(v,("schema_version","kind","records"))
    type(v["records"]) is list or _bad(); [_exact(r,("stage","argv_b64","cwd_b64","exit_code","trace_first_sequence","trace_last_sequence")) for r in v["records"]]
    if [r["stage"] for r in v["records"]] != list(stages): _bad()
    for r in v["records"]: [_b64(x) for x in r["argv_b64"]] if type(r["argv_b64"]) is list else _bad(); _b64(r["cwd_b64"]); [_u(r[x]) for x in ("exit_code","trace_first_sequence","trace_last_sequence")]; r["trace_first_sequence"] <= r["trace_last_sequence"] or _bad()
def _manifest(v):
    _exact(v,("repository_commit","locked_xml_sha256","project_count","remotes","projects")); _hex(v["repository_commit"],(40,64)); _hex(v["locked_xml_sha256"]); _u(v["project_count"]); type(v["remotes"]) is list and type(v["projects"]) is list or _bad(); v["project_count"]==len(v["projects"]) or _bad()
    for r in v["remotes"]: _exact(r,("name","fetch_url","review_url","mirror_url")); _text(r["name"]); [_url(x) for x in (r["fetch_url"],r["review_url"],r["mirror_url"])]
    for p in v["projects"]: _exact(p,("path","name","remote","revision","head","source_state_digest")); _rel(p["path"]); [_text(p[x]) for x in ("name","remote","revision")]; _hex(p["head"],(40,64)); _hex(p["source_state_digest"])
    [r["name"] for r in v["remotes"]]==sorted({r["name"] for r in v["remotes"]}) and [p["path"].encode() for p in v["projects"]]==sorted({p["path"].encode() for p in v["projects"]}) or _bad()
def _tools(v):
    _exact(v,("repo_checkout_commit","repo_launcher_path","repo_launcher_sha256","repo_version","git_version","python_version")); v["repo_checkout_commit"] is None or _hex(v["repo_checkout_commit"],(40,64)); _text(v["repo_launcher_path"]); "\0" not in v["repo_launcher_path"] and v["repo_launcher_path"].startswith("/") and not v["repo_launcher_path"].startswith("//") and v["repo_launcher_path"]==os.path.normpath(v["repo_launcher_path"]) or _bad(); _hex(v["repo_launcher_sha256"]); [_text(v[x]) for x in ("repo_version","git_version","python_version")]
def _execution(v,identity=False):
    _exact(v,("host_arch","kind","container_digest") if identity else ("host_arch","kernel_release","kind","container_digest")); _text(v["host_arch"]); v["kind"] in ("host","container") or _bad(); (v["container_digest"] is None if v["kind"]=="host" else type(v["container_digest"]) is str and _hex(v["container_digest"]) is None) or _bad(); identity or _text(v["kernel_release"])
def _minimum(v): _exact(v,("available_bytes","available_inodes","effective_memory_bytes","effective_cpus")); [_u(v[x]) for x in v]
def _resources(v):
    _exact(v,("estimated_disk_upper_bound_bytes","minimums","measured","passed")); _u(v["estimated_disk_upper_bound_bytes"]); _minimum(v["minimums"]); _exact(v["measured"],("available_bytes","available_inodes","host_mem_available_bytes","cgroup_mem_remaining_bytes","effective_memory_bytes","online_cpu_count","cpuset_cpu_count","effective_cpu_numerator","effective_cpu_denominator")); [_u(v["measured"][x]) for x in v["measured"] if x not in ("cgroup_mem_remaining_bytes","cpuset_cpu_count")]; [v["measured"][x] is None or _u(v["measured"][x]) for x in ("cgroup_mem_remaining_bytes","cpuset_cpu_count")]; _exact(v["passed"],("disk","inodes","memory","cpu")); all(type(x) is bool for x in v["passed"].values()) or _bad(); m=v["measured"]; c=m["cgroup_mem_remaining_bytes"]; m["online_cpu_count"]>0 and m["effective_cpu_numerator"]>0 and m["effective_cpu_denominator"]>0 and (m["cpuset_cpu_count"] is None or m["cpuset_cpu_count"]>0) and __import__("math").gcd(m["effective_cpu_numerator"],m["effective_cpu_denominator"])==1 and m["effective_memory_bytes"]==(min(m["host_mem_available_bytes"],c) if c is not None else m["host_mem_available_bytes"]) or _bad(); p=v["passed"]; p=={"disk":m["available_bytes"]>=max(v["minimums"]["available_bytes"],v["estimated_disk_upper_bound_bytes"]),"inodes":m["available_inodes"]>=v["minimums"]["available_inodes"],"memory":m["effective_memory_bytes"]>=v["minimums"]["effective_memory_bytes"],"cpu":m["effective_cpu_numerator"]>=v["minimums"]["effective_cpus"]*m["effective_cpu_denominator"]} or _bad()
def _lunch(v,identity=False):
    keys=("target","product","release","variant","variables") if identity else ("target","product","release","variant","variables","out_dir_relative","envsetup_exit","lunch_exit"); _exact(v,keys); [_text(v[x]) for x in ("target","product","release","variant")]; _exact(v["variables"],("TARGET_PRODUCT","TARGET_RELEASE","TARGET_BUILD_VARIANT","TARGET_ARCH","TARGET_2ND_ARCH","HOST_OS","HOST_ARCH")); [x is None or type(x) is str or _bad() for x in v["variables"].values()]; identity or (_rel(v["out_dir_relative"]),v["out_dir_relative"].startswith("tmp/preflight/") or _bad(),_u(v["envsetup_exit"]),_u(v["lunch_exit"]))
def _seed_state(v,project_count=None):
    _exact(v,("state","clean_source_proof","affected_project_count","before_digest","after_digest","observed_ignored_inputs")); v["state"] in ("clean","dirty") and type(v["clean_source_proof"]) is bool or _bad(); _u(v["affected_project_count"]); _hex(v["before_digest"]); _hex(v["after_digest"]); (((v["state"]=="clean" and v["clean_source_proof"] is True and v["affected_project_count"]==0) or (v["state"]=="dirty" and v["clean_source_proof"] is False and 0<v["affected_project_count"]<=project_count)) if project_count is not None else True) or _bad(); type(v["observed_ignored_inputs"]) is list or _bad()
    for x in v["observed_ignored_inputs"]:
        _exact(x,("path_b64","resolved_path_b64","entry_kind","mode","content_sha256","symlink_target_sha256","target_content_sha256")); _b64(x["path_b64"]); _b64(x["resolved_path_b64"]); _u(x["mode"]); x["entry_kind"] in ("regular","symlink") or _bad()
        if x["entry_kind"]=="regular": _hex(x["content_sha256"]); x["symlink_target_sha256"] is None and x["target_content_sha256"] is None or _bad()
        else: x["content_sha256"] is None or _bad(); _hex(x["symlink_target_sha256"]); _hex(x["target_content_sha256"])
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
def _terminal(v):
    reasons=("SOURCE_ROOT_UNAVAILABLE","REPO_METADATA_UNAVAILABLE","ENVSETUP_UNAVAILABLE","REPO_CLIENT_UNAVAILABLE","WORKTREE_ENUM_UNAVAILABLE","RESOURCE_DISK","RESOURCE_INODE","RESOURCE_MEMORY","RESOURCE_CPU","NETWORK_NAMESPACE_UNAVAILABLE","TRACE_UNAVAILABLE","LUNCH_FAILED","FORBIDDEN_EXECUTION","SOURCE_MUTATION","SOURCE_CHANGED"); _exact(v,("schema_version","kind","request_digest","primary_reason","failed_checks","completed_observation_digests","summary_lines")); _hex(v["request_digest"]); type(v["failed_checks"]) is list and v["failed_checks"] and all(x in reasons for x in v["failed_checks"]) and v["failed_checks"]==sorted(set(v["failed_checks"]),key=reasons.index) and v["primary_reason"]==v["failed_checks"][0] or _bad(); _exact(v["completed_observation_digests"],("source_state","trace","command_journal")); [x is None or _hex(x) for x in v["completed_observation_digests"].values()]; type(v["summary_lines"]) is list and len(v["summary_lines"])<=120 and all(type(x) is str and x in v["failed_checks"] for x in v["summary_lines"]) or _bad()
def _object_bytes(v): return canonical_bytes(value=v)+b"\n"
def _validate_artifact(v):
    _guard(v); handlers={"seed_request":_request,"source_state":_state,"trace":_trace,"command_journal":_journal,"seed":_seed,"terminal_report":_terminal}; _bad() if type(v) is not dict or type(v.get("schema_version")) is not int or v["schema_version"] != 1 or type(v.get("kind")) is not str or v["kind"] not in handlers else None; return (handlers[v["kind"]](v),_DOMAINS[v["kind"]])[1]
def load_artifact(*, path: str, expected_kind: str) -> dict:
    if type(path) is not str or type(expected_kind) is not str or not path or expected_kind not in ("seed_request","source_state","trace","command_journal","seed","terminal_report"): raise ContractError("ARGUMENT_ERROR")
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
    return value
