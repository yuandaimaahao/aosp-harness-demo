import base64, fcntl, hashlib, json, os, re; from types import MappingProxyType; from urllib.parse import parse_qsl,urlsplit; RUNTIME_ABI, _SAFE = "seed-contract-runtime/v1", 2**53-1
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
_P=os.O_PATH|os.O_DIRECTORY|os.O_NOFOLLOW
def _same(fd,path):
    other=os.open(path,_P)
    try: return os.fstat(fd).st_dev==os.fstat(other).st_dev and os.fstat(fd).st_ino==os.fstat(other).st_ino
    finally: os.close(other)
def _close(fd):
    try: os.close(fd)
    except OSError: pass
def _drop(nodes): [_close(fd) for fd,_ in nodes]
def _clean(made):
    for fd,name in reversed(made):
        try: os.rmdir(name,dir_fd=fd)
        except OSError: pass
def _walk(path,make=False):
    nodes=[]; made=[]
    try:
        nodes=[(os.open("/",_P),"/")]
        for name in path.split("/")[1:]:
            parent,base=nodes[-1]; _same(parent,base) or (_ for _ in ()).throw(OSError()) ; child_path=base.rstrip("/")+"/"+name
            try: child=os.open(name,_P,dir_fd=parent)
            except FileNotFoundError:
                if not make: raise
                try: os.mkdir(name,0o700,dir_fd=parent)
                except FileExistsError: pass
                else: made.append((parent,name))
                child=os.open(name,_P,dir_fd=parent)
            nodes.append((child,child_path)); (_same(parent,base) and _same(child,child_path)) or (_ for _ in ()).throw(OSError())
        return nodes,made
    except BaseException: _clean(made); _drop(nodes); raise
def validate_state_paths(*, state_dir: str, out_ref: str | None, artifact_store: str, forbidden_roots: tuple[str, ...]):
    if type(state_dir) is not str or type(artifact_store) is not str or type(forbidden_roots) is not tuple or out_ref is not None and type(out_ref) is not str or any(type(x)is not str or "\0" in x or not os.path.isabs(x) or x!=os.path.normpath(x) or x!=os.path.realpath(x) for x in forbidden_roots): raise ContractError("ARGUMENT_ERROR")
    state=state_dir; store=os.path.join(state,"artifacts/v1"); sd=od=rd=made=[]
    try:
        if not os.path.isabs(state) or state.startswith("~") or state!=os.path.normpath(state) or state!=os.path.realpath(state) or artifact_store!=store or not os.access(state,os.W_OK|os.X_OK): raise OSError
        if any(x=="/" or state==x or state.startswith(x+"/") or store==x or store.startswith(x+"/") for x in forbidden_roots): raise OSError
        sd,_=_walk(state); od,made=_walk(store+"/sha256",True)
        if not all(_same(fd,path) for fd,path in sd+od): raise OSError
    except (OSError,TypeError,ValueError): _clean(made); _drop(od); _drop(sd); raise ContractError("STATE_DIR_CONTRACT") from None
    if out_ref is None: _drop(od); _drop(sd); return MappingProxyType({"state_dir":state,"artifact_store":store,"object_dir":store+"/sha256","out_ref":None,"ref_parent":None,"lock_path":None})
    try:
        if not os.path.isabs(out_ref) or out_ref!=os.path.normpath(out_ref) or not(state!=out_ref and out_ref.startswith(state+"/")) or any(x=="/" or out_ref==x or out_ref.startswith(x+"/") for x in forbidden_roots): raise OSError
        parent,leaf=os.path.dirname(out_ref),os.path.basename(out_ref)
        if not leaf or leaf in (".",".."): raise OSError
        rd,rmade=_walk(parent,True); made+=rmade
        try: mode=os.stat(leaf,dir_fd=rd[-1][0],follow_symlinks=False).st_mode
        except FileNotFoundError: mode=0
        if mode and not __import__("stat").S_ISREG(mode) or not all(_same(fd,path) for fd,path in sd+od+rd): raise OSError
    except ContractError: _clean(made); _drop(rd); _drop(od); _drop(sd); raise
    except (OSError,TypeError,ValueError):
        try: changed=not all(_same(fd,path) for fd,path in sd+od)
        except OSError: changed=True
        _clean(made); _drop(rd); _drop(od); _drop(sd); raise ContractError("STATE_DIR_CONTRACT" if changed else "OUT_REF_CONTRACT") from None
    _drop(rd); _drop(od); _drop(sd)
    return MappingProxyType({"state_dir":state,"artifact_store":store,"object_dir":store+"/sha256","out_ref":out_ref,"ref_parent":parent,"lock_path":out_ref+".lock"})
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
def _readat(fd,name,mode=None):
    try: probe=os.open(name,os.O_PATH|os.O_NOFOLLOW,dir_fd=fd)
    except OSError as error: return None if error.errno==2 else False
    try:
        stat=os.fstat(probe)
        if not __import__("stat").S_ISREG(stat.st_mode) or mode is not None and __import__("stat").S_IMODE(stat.st_mode)!=mode: return False
        file=os.open(name,os.O_RDONLY|os.O_NONBLOCK|os.O_NOFOLLOW,dir_fd=fd)
        try: fresh=os.fstat(file); return b"".join(iter(lambda:os.read(file,65536),b"")) if (fresh.st_dev,fresh.st_ino)==(stat.st_dev,stat.st_ino) else False
        finally: os.close(file)
    except OSError: return False
    finally: os.close(probe)
def _decode(raw):
    try:
        value=json.loads(raw.decode(),object_pairs_hook=_pairs); return value if raw==_object_bytes(value) else False
    except (AttributeError,ContractError,RecursionError,UnicodeError,json.JSONDecodeError,TypeError): return False
def _artifact(raw,digest,kind):
    try:
        value=_decode(raw); return value if value is not False and _validate_artifact(value)==_DOMAINS[kind] and hashlib.sha256(_DOMAINS[kind].encode()+_object_bytes(value)[:-1]).hexdigest()==digest else False
    except ContractError: return False
def _closure(seed,values):
    try:
        states=(values["before"],values["after"]); manifest=seed["manifest"]
        for state in states:
            state["manifest_sha256"]==manifest["locked_xml_sha256"] and {x["path"] for x in state["projects"]}=={x["path"] for x in manifest["projects"]} and all(domain_digest(domain_ascii=_DOMAINS["project_source_state"],value=x)==next(y["source_state_digest"] for y in manifest["projects"] if y["path"]==x["path"]) for x in state["projects"]) or (_ for _ in ()).throw(ValueError())
        trace,journal=values["trace"],values["journal"]; all(trace["counts"][x]==seed["guard"][x+"_count"] for x in ("external_network","source_mutation","sync_download","module_build","package")) or (_ for _ in ()).throw(ValueError()); sequences={x["sequence"] for x in trace["records"]}; all(x["exit_code"]==0 and x["trace_first_sequence"] in sequences and x["trace_last_sequence"] in sequences for x in journal["records"]) and next(x["exit_code"] for x in journal["records"] if x["stage"]=="envsetup_lunch")==seed["lunch"]["lunch_exit"] or (_ for _ in ()).throw(ValueError())
        return {"source_state_before":True,"source_state_after":True,"trace":True,"command_journal":True}
    except (KeyError,StopIteration,ValueError,ContractError): raise ContractError("REF_CORRUPT") from None
def resolve_ref(*, state_dir: str, ref: str, artifact_store: str, forbidden_roots: tuple[str, ...], require_public_real: bool = False) -> dict:
    if type(state_dir) is not str or type(ref) is not str or type(artifact_store) is not str or type(forbidden_roots) is not tuple or type(require_public_real) is not bool or any(type(x)is not str or "\0" in x or not os.path.isabs(x) or x!=os.path.normpath(x) or x!=os.path.realpath(x) for x in forbidden_roots): raise ContractError("ARGUMENT_ERROR")
    paths=validate_state_paths(state_dir=state_dir,out_ref=None,artifact_store=artifact_store,forbidden_roots=forbidden_roots); nodes=[]; object_nodes=[]; lock=probe=None; locked=False
    if not os.path.isabs(ref) or ref!=os.path.normpath(ref) or not (paths["state_dir"]=="/" or ref.startswith(paths["state_dir"]+"/")) or os.path.basename(ref) in ("",".","..") or any(ref==x or ref.startswith(x+"/") for x in forbidden_roots): raise ContractError("OUT_REF_CONTRACT")
    try:
        nodes,_=_walk(os.path.dirname(ref),True); parent=nodes[-1][0]; name=os.path.basename(ref)+".lock"; made=False
        try:
            probe=os.open(name,os.O_PATH|os.O_NOFOLLOW,dir_fd=parent)
        except FileNotFoundError:
            try: lock=os.open(name,os.O_RDWR|os.O_NONBLOCK|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600,dir_fd=parent); made=True
            except FileExistsError: probe=os.open(name,os.O_PATH|os.O_NOFOLLOW,dir_fd=parent)
        try:
            if probe is not None: stat=os.fstat(probe); __import__("stat").S_ISREG(stat.st_mode) and stat.st_uid==os.geteuid() and __import__("stat").S_IMODE(stat.st_mode)==0o600 or (_ for _ in ()).throw(OSError()); lock=os.open(name,os.O_RDWR|os.O_NONBLOCK|os.O_NOFOLLOW,dir_fd=parent); fresh=os.fstat(lock); (fresh.st_dev,fresh.st_ino)==(stat.st_dev,stat.st_ino) or (_ for _ in ()).throw(OSError())
            made and os.fchmod(lock,0o600); stat=os.fstat(lock)
            __import__("stat").S_ISREG(stat.st_mode) and stat.st_uid==os.geteuid() and __import__("stat").S_IMODE(stat.st_mode)==0o600 or (_ for _ in ()).throw(OSError())
        finally: probe is None or os.close(probe)
        try: fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError: raise ContractError("REF_BUSY") from None
        locked=True
        raw=_readat(parent,os.path.basename(ref)); raw is not None or (_ for _ in ()).throw(ContractError("ARTIFACT_MISSING")); raw is not False or (_ for _ in ()).throw(ContractError("REF_CORRUPT")); descriptor=_decode(raw); type(descriptor) is dict and set(descriptor)=={"schema_version","kind","digest"} and type(descriptor.get("schema_version")) is int and descriptor["schema_version"]==1 and descriptor.get("kind") in ("env_pass","terminal_report") and type(descriptor.get("digest")) is str and re.fullmatch("[0-9a-f]{64}",descriptor["digest"]) or (_ for _ in ()).throw(ContractError("REF_CORRUPT"))
        expected={"env_pass":"seed","terminal_report":"terminal_report"}[descriptor["kind"]]; object_nodes,_=_walk(paths["object_dir"]); objectfd=object_nodes[-1][0]
        raw=_readat(objectfd,descriptor["digest"],0o444); raw is not None or (_ for _ in ()).throw(ContractError("ARTIFACT_MISSING")); primary=_artifact(raw,descriptor["digest"],expected); primary is not False or (_ for _ in ()).throw(ContractError("REF_CORRUPT"))
        needs=[("before",primary["source_state"]["before_digest"],"source_state"),("after",primary["source_state"]["after_digest"],"source_state"),("trace",primary["guard"]["trace_digest"],"trace"),("journal",primary["guard"]["command_journal_digest"],"command_journal")] if expected=="seed" else [(key,digest,key) for key,digest in primary["completed_observation_digests"].items() if digest is not None]
        all(type(digest)is str and re.fullmatch("[0-9a-f]{64}",digest) and kind in _DOMAINS for _,digest,kind in needs) or (_ for _ in ()).throw(ContractError("REF_CORRUPT")); raw={label:_readat(objectfd,digest,0o444) for label,digest,kind in needs}; any(value is None for value in raw.values()) and (_ for _ in ()).throw(ContractError("ARTIFACT_MISSING")); values={label:_artifact(raw[label],digest,kind) for label,digest,kind in needs}; all(value is not False for value in values.values()) or (_ for _ in ()).throw(ContractError("REF_CORRUPT"))
        evidence=_closure(primary,values) if expected=="seed" else None; require_public_real and not _validate_public_real(primary,evidence) and (_ for _ in ()).throw(ContractError("PUBLIC_SCOPE_REQUIRED")); return primary
    except ContractError: raise
    except (OSError,TypeError,ValueError,KeyError): raise ContractError("REF_CORRUPT" if locked else "OUT_REF_CONTRACT") from None
    finally:
        if lock is not None:
            try: fcntl.flock(lock,fcntl.LOCK_UN)
            except OSError: pass
        for fd in ([lock] if lock is not None else [])+[fd for fd,_ in object_nodes+nodes]:
            try: os.close(fd)
            except OSError: pass
def _publish_object(*, state_dir: str, artifact_store: str, object_kind: str, payload: dict, forbidden_roots: tuple[str, ...], fault_point: str | None = None, _output: bool = False) -> dict:
    if type(state_dir) is not str or type(artifact_store) is not str or type(object_kind) is not str or object_kind not in (("source_state","trace","command_journal","seed","terminal_report") if _output else ("source_state","trace","command_journal")) or type(payload) is not dict or type(forbidden_roots) is not tuple or fault_point not in (None,"OBJECT_LINK","OBJECT_DIR_FSYNC") or any(type(x)is not str or "\0" in x or not os.path.isabs(x) or x!=os.path.normpath(x) or x!=os.path.realpath(x) for x in forbidden_roots): raise ContractError("ARGUMENT_ERROR")
    domain=_validate_artifact(payload); payload["kind"]==object_kind or (_ for _ in ()).throw(ContractError("ARGUMENT_ERROR")); data=_object_bytes(payload); digest=hashlib.sha256(domain.encode()+data[:-1]).hexdigest(); paths=validate_state_paths(state_dir=state_dir,out_ref=None,artifact_store=artifact_store,forbidden_roots=forbidden_roots); nodes=[]; linked=False; fd=None
    try:
        nodes,_=_walk(paths["object_dir"]); fd=os.open(".",os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=nodes[-1][0])
        def read(name):
            try: probe=os.open(name,os.O_PATH|os.O_NOFOLLOW,dir_fd=fd)
            except FileNotFoundError: return None
            try: stat=os.fstat(probe)
            finally: os.close(probe)
            if not __import__("stat").S_ISREG(stat.st_mode) or __import__("stat").S_IMODE(stat.st_mode)!=0o444: raise ContractError("DIGEST_COLLISION")
            file=os.open(name,os.O_RDONLY|os.O_NOFOLLOW,dir_fd=fd)
            try:
                if not __import__("stat").S_ISREG(os.fstat(file).st_mode) or __import__("stat").S_IMODE(os.fstat(file).st_mode)!=0o444 or b"".join(iter(lambda:os.read(file,65536),b"")) != data: raise ContractError("DIGEST_COLLISION")
                os.fsync(file); return True
            finally: os.close(file)
        old=read(digest)
        if old is not None:
            os.fsync(fd); return {"digest":digest,"object_path":paths["object_dir"]+"/"+digest}
        file=os.open(".",os.O_RDWR|os.O_TMPFILE,0o600,dir_fd=fd)
        try:
            os.fchmod(file,0o600); view=memoryview(data)
            while view: view=view[os.write(file,view):]
            os.fsync(file); os.fchmod(file,0o444); os.fsync(file)
            if fault_point == "OBJECT_LINK": raise ContractError("PUBLISH_PRECOMMIT_FAILED")
            c=__import__("ctypes"); link=c.CDLL(None,use_errno=True).linkat; result=link(file,b"",fd,digest.encode(),0x1000); result and c.get_errno()==2 and (result:=link(-100,f"/proc/self/fd/{file}".encode(),fd,digest.encode(),0x400)); result==0 or (_ for _ in ()).throw(OSError(c.get_errno(),"linkat")); linked=True
            if fault_point == "OBJECT_DIR_FSYNC": raise ContractError("PUBLISH_OBJECT_ORPHANED")
            os.fsync(fd); return {"digest":digest,"object_path":paths["object_dir"]+"/"+digest}
        finally: os.close(file)
    except ContractError: raise
    except OSError as error:
        try:
            if error.errno==17 and read(digest): os.fsync(fd); return {"digest":digest,"object_path":paths["object_dir"]+"/"+digest}
        except OSError: pass
        raise ContractError("PUBLISH_OBJECT_ORPHANED" if linked else "PUBLISH_PRECOMMIT_FAILED") from None
    finally:
        if fd is not None: _close(fd)
        _drop(nodes)
def publish_object(*, state_dir: str, artifact_store: str, object_kind: str, payload: dict, forbidden_roots: tuple[str, ...], fault_point: str | None = None) -> dict: return _publish_object(state_dir=state_dir,artifact_store=artifact_store,object_kind=object_kind,payload=payload,forbidden_roots=forbidden_roots,fault_point=fault_point)
def _lock_ref(parent_path,name):
    nodes=[]; lock=probe=None
    try:
        nodes,_=_walk(parent_path,True); parent=nodes[-1][0]; leaf=name+".lock"
        try: probe=os.open(leaf,os.O_PATH|os.O_NOFOLLOW,dir_fd=parent)
        except FileNotFoundError:
            try: lock=os.open(leaf,os.O_RDWR|os.O_NONBLOCK|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600,dir_fd=parent)
            except FileExistsError: probe=os.open(leaf,os.O_PATH|os.O_NOFOLLOW,dir_fd=parent)
        try:
            if probe is not None: stat=os.fstat(probe); __import__("stat").S_ISREG(stat.st_mode) and stat.st_uid==os.geteuid() and __import__("stat").S_IMODE(stat.st_mode)==0o600 or (_ for _ in ()).throw(OSError()); lock=os.open(leaf,os.O_RDWR|os.O_NONBLOCK|os.O_NOFOLLOW,dir_fd=parent); fresh=os.fstat(lock); (fresh.st_dev,fresh.st_ino)==(stat.st_dev,stat.st_ino) or (_ for _ in ()).throw(OSError())
            os.fchmod(lock,0o600); stat=os.fstat(lock); __import__("stat").S_ISREG(stat.st_mode) and stat.st_uid==os.geteuid() and __import__("stat").S_IMODE(stat.st_mode)==0o600 or (_ for _ in ()).throw(OSError()); fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        finally: probe is None or os.close(probe)
        return nodes,lock
    except (OSError,TypeError,ValueError) as error: _drop(nodes+([(lock,"")] if lock is not None else [])); raise ContractError("REF_BUSY" if isinstance(error,BlockingIOError) else "OUT_REF_CONTRACT") from None
def _stored(fd,digest,kind): raw=_readat(fd,digest,0o444); raw is not None or (_ for _ in ()).throw(ContractError("ARTIFACT_MISSING")); value=_artifact(raw,digest,kind) if raw is not False else False; value is not False or (_ for _ in ()).throw(ContractError("REF_CORRUPT")); return value
def _evidence(fd,payload): needs=[("before",payload["source_state"]["before_digest"],"source_state"),("after",payload["source_state"]["after_digest"],"source_state"),("trace",payload["guard"]["trace_digest"],"trace"),("journal",payload["guard"]["command_journal_digest"],"command_journal")] if payload["kind"]=="seed" else [(k,d,k) for k,d in payload["completed_observation_digests"].items() if d is not None]; values={label:_stored(fd,digest,kind) for label,digest,kind in needs}; payload["kind"]!="seed" or _closure(payload,values); return values
def _existing_ref(parent,name,objectfd):
    raw=_readat(parent,name)
    if raw is None: return None
    raw is not False or (_ for _ in ()).throw(ContractError("REF_CORRUPT")); value=_decode(raw); type(value)is dict and set(value)=={"schema_version","kind","digest"} and type(value.get("schema_version"))is int and value["schema_version"]==1 and value.get("kind") in ("env_pass","terminal_report") and type(value.get("digest"))is str and re.fullmatch("[0-9a-f]{64}",value["digest"]) or (_ for _ in ()).throw(ContractError("REF_CORRUPT")); primary=_stored(objectfd,value["digest"],{"env_pass":"seed","terminal_report":"terminal_report"}[value["kind"]]); _evidence(objectfd,primary); return value
def publish(*, state_dir: str, out_ref: str, artifact_store: str, object_kind: str, payload: dict, ref_kind: str, semantic_exit: int, forbidden_roots: tuple[str, ...], fault_point: str | None = None) -> dict:
    if type(state_dir)is not str or type(out_ref)is not str or type(artifact_store)is not str or type(object_kind)is not str or type(payload)is not dict or type(ref_kind)is not str or type(semantic_exit)is not int or semantic_exit not in (0,20) or type(forbidden_roots)is not tuple or fault_point not in (None,"OBJECT_LINK","OBJECT_DIR_FSYNC","REF_RENAME","REF_DIR_FSYNC") or any(type(x)is not str or "\0" in x or not os.path.isabs(x) or x!=os.path.normpath(x) or x!=os.path.realpath(x) for x in forbidden_roots): raise ContractError("ARGUMENT_ERROR")
    (object_kind,ref_kind) in (("seed","env_pass"),("terminal_report","terminal_report")) or (_ for _ in ()).throw(ContractError("ARGUMENT_ERROR")); (type(payload.get("kind"))is not str or payload["kind"]==object_kind) or (_ for _ in ()).throw(ContractError("ARGUMENT_ERROR")); domain=_validate_artifact(payload); payload["kind"]==object_kind or (_ for _ in ()).throw(ContractError("ARGUMENT_ERROR")); paths=validate_state_paths(state_dir=state_dir,out_ref=None,artifact_store=artifact_store,forbidden_roots=forbidden_roots); (os.path.isabs(out_ref) and out_ref==os.path.normpath(out_ref) and out_ref!=paths["state_dir"] and out_ref.startswith(paths["state_dir"]+"/") and os.path.basename(out_ref) not in ("",".","..") and not any(out_ref==x or out_ref.startswith(x+"/") for x in forbidden_roots)) or (_ for _ in ()).throw(ContractError("OUT_REF_CONTRACT")); nodes=[]; objects=[]; lock=refdir=None; temp=None; renamed=False
    try:
        nodes,lock=_lock_ref(os.path.dirname(out_ref),os.path.basename(out_ref)); parent=nodes[-1][0]; refdir=os.open(".",os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=parent); objects,_=_walk(paths["object_dir"]); objectfd=objects[-1][0]; _existing_ref(parent,os.path.basename(out_ref),objectfd); _evidence(objectfd,payload); result=_publish_object(state_dir=state_dir,artifact_store=artifact_store,object_kind=object_kind,payload=payload,forbidden_roots=forbidden_roots,fault_point=fault_point if fault_point in ("OBJECT_LINK","OBJECT_DIR_FSYNC") else None,_output=True)
        try:
            for n in os.listdir(refdir):
                if re.fullmatch(r"\."+re.escape(os.path.basename(out_ref))+r"\.tmp\.[0-9]+\.[0-9a-f]{16}",n): p=os.open(n,os.O_PATH|os.O_NOFOLLOW,dir_fd=refdir); objects.append((p,"")); stat=os.fstat(p); _close(objects.pop()[0]); __import__("stat").S_ISREG(stat.st_mode) and __import__("stat").S_IMODE(stat.st_mode)==0o600 and os.unlink(n,dir_fd=refdir)
        except OSError: pass
        data=_object_bytes({"schema_version":1,"kind":ref_kind,"digest":result["digest"]}); temp="."+os.path.basename(out_ref)+".tmp."+str(os.getpid())+"."+__import__("secrets").token_hex(8); fd=os.open(temp,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600,dir_fd=refdir)
        try:
            os.fchmod(fd,0o600); view=memoryview(data)
            while view: view=view[os.write(fd,view):]
            os.fsync(fd)
        finally: os.close(fd)
        os.replace(temp,os.path.basename(out_ref),src_dir_fd=refdir,dst_dir_fd=refdir); renamed=True
        if fault_point in ("REF_RENAME","REF_DIR_FSYNC"): raise ContractError("REF_DURABILITY_UNCERTAIN")
        os.fsync(refdir); return {"digest":result["digest"],"object_path":result["object_path"],"ref_path":out_ref,"semantic_exit":semantic_exit}
    except ContractError: raise
    except OSError: raise ContractError("REF_DURABILITY_UNCERTAIN" if renamed else "PUBLISH_OBJECT_ORPHANED") from None
    finally:
        if temp is not None and not renamed:
            try: os.unlink(temp,dir_fd=refdir)
            except OSError: pass
        if lock is not None:
            try: fcntl.flock(lock,fcntl.LOCK_UN)
            except OSError: pass
        _drop(objects+nodes+[(fd,"") for fd in (refdir,lock) if fd is not None])
