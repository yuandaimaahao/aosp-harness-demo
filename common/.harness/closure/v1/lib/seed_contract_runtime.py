import base64, hashlib, json; RUNTIME_ABI, _SAFE = "seed-contract-runtime/v1", 2**53-1
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
_DOMAINS={"seed_request":"aosp-harness/seed-request/v1\0","source_state":"aosp-harness/source-state/v1\0","trace":"aosp-harness/trace/v1\0","command_journal":"aosp-harness/command-journal/v1\0"}
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
def _rel(v): _text(v); _bad() if v.startswith("/") or any(x in ("", ".", "..") for x in v.split("/")) else None
def _scope(v): _exact(v,("role","public_aosp_baseline","vendor_context","platform_family")); _bad() if v not in ({"role":"public_aosp17_cuttlefish","public_aosp_baseline":True,"vendor_context":False,"platform_family":"aosp-17"},{"role":"local_lk7k_product","public_aosp_baseline":False,"vendor_context":True,"platform_family":"aosp-17"}) else None
def _entry(v):
    _exact(v,("path_b64","status_record_b64","entry_kind","mode","content_sha256","symlink_target_sha256")); _b64(v["path_b64"]); _b64(v["status_record_b64"]); _u(v["mode"])
    if v["entry_kind"] == "regular": _hex(v["content_sha256"]); ok=v["symlink_target_sha256"] is None
    elif v["entry_kind"] == "symlink": _hex(v["symlink_target_sha256"]); ok=v["content_sha256"] is None
    elif v["entry_kind"] == "missing": ok=v["mode"] == 0 and v["content_sha256"] is None and v["symlink_target_sha256"] is None
    else: ok=False
    if not ok: _bad()
def _project(v):
    _exact(v,("path","head","status_sha256","entries")); _rel(v["path"]); _hex(v["head"],(40,64)); _hex(v["status_sha256"])
    if type(v["entries"]) is not list: _bad()
    for x in v["entries"]: _entry(x)
    if [ _b64(x["path_b64"]) for x in v["entries"]] != sorted({_b64(x["path_b64"]) for x in v["entries"]}): _bad()
def _request(v):
    _exact(v,("schema_version","kind","source_root","envsetup_relpath","lunch","source_scope","resource_minimums","estimated_disk_upper_bound_bytes")); _text(v["source_root"]); _rel(v["envsetup_relpath"]); _scope(v["source_scope"]); _u(v["estimated_disk_upper_bound_bytes"])
    if not v["source_root"].startswith("/") or any(x in (".","..") for x in v["source_root"].split("/")) or v["envsetup_relpath"] != "build/envsetup.sh": _bad()
    _exact(v["lunch"],("target","product","release","variant")); [_text(x) for x in v["lunch"].values()]; _exact(v["resource_minimums"],("available_bytes","available_inodes","effective_memory_bytes","effective_cpus")); [_u(x) for x in v["resource_minimums"].values()]
def _state(v):
    _exact(v,("schema_version","kind","manifest_sha256","projects")); _hex(v["manifest_sha256"])
    if type(v["projects"]) is not list: _bad()
    for x in v["projects"]: _project(x)
    if [x["path"].encode() for x in v["projects"]] != sorted({x["path"].encode() for x in v["projects"]}): _bad()
def _trace(v):
    kinds=("other","external_network","source_mutation","sync_download","config_query","module_build","package"); _exact(v,("schema_version","kind","records","counts")); _exact(v["counts"],kinds)
    if type(v["records"]) is not list: _bad()
    for r in v["records"]:
        _exact(r,("sequence","process_ordinal","syscall","result","errno","exec_argv_b64","paths","address_family","classification")); _u(r["sequence"]); _u(r["process_ordinal"]); _text(r["syscall"],True); _i(r["result"])
        if (r["result"] >= 0) != (r["errno"] is None): _bad()
        if r["errno"] is not None: _text(r["errno"],True)
        if r["syscall"] in ("execve","execveat"):
            if type(r["exec_argv_b64"]) is not list: _bad()
            [_b64(x) for x in r["exec_argv_b64"]]
        elif r["exec_argv_b64"] is not None: _bad()
        if type(r["paths"]) is not list or r["address_family"] not in (None,"AF_INET","AF_INET6","AF_UNIX","AF_OTHER") or r["classification"] not in kinds: _bad()
        for p in r["paths"]: _exact(p,("role","dirfd","raw_b64","resolved_b64")); _b64(p["raw_b64"]); _b64(p["resolved_b64"]); p["dirfd"] is None or _i(p["dirfd"]); p["role"] in ("path","oldpath","newpath","target","linkpath","source_fd","destination_fd") or _bad()
    if [r["sequence"] for r in v["records"]] != sorted({r["sequence"] for r in v["records"]}): _bad()
    for k in kinds: _u(v["counts"][k]); v["counts"][k] == sum(r["classification"] == k and r["result"] >= 0 for r in v["records"]) or _bad()
def _journal(v):
    stages=("manifest_before","source_state_before","namespace_probe","envsetup_lunch","manifest_after","source_state_after"); _exact(v,("schema_version","kind","records"))
    if type(v["records"]) is not list or [r.get("stage") for r in v["records"]] != list(stages): _bad()
    for r in v["records"]: _exact(r,("stage","argv_b64","cwd_b64","exit_code","trace_first_sequence","trace_last_sequence")); [_b64(x) for x in r["argv_b64"]] if type(r["argv_b64"]) is list else _bad(); _b64(r["cwd_b64"]); [_u(r[x]) for x in ("exit_code","trace_first_sequence","trace_last_sequence")]; r["trace_first_sequence"] <= r["trace_last_sequence"] or _bad()
def _validate_artifact(v):
    if type(v) is not dict or v.get("schema_version") != 1: raise ContractError("UNSUPPORTED_SCHEMA_VERSION")
    {"seed_request":_request,"source_state":_state,"trace":_trace,"command_journal":_journal}.get(v.get("kind"),_bad)(v)
    return _DOMAINS[v["kind"]]
def load_artifact(*, path: str, expected_kind: str) -> dict:
    if type(path) is not str or type(expected_kind) is not str or not path or not expected_kind: raise ContractError("ARGUMENT_ERROR")
    try: raw = open(path, "rb").read()
    except (OSError, TypeError): raise ContractError("DESCRIPTOR_NOT_FOUND") from None
    try: value = json.loads(raw.decode(), object_pairs_hook=_pairs)
    except UnicodeDecodeError: raise ContractError("DESCRIPTOR_INVALID_UTF8") from None
    except json.JSONDecodeError: raise ContractError("DESCRIPTOR_SCHEMA_INVALID") from None
    _guard(value)
    if not isinstance(value, dict) or value.get("kind") != expected_kind: raise ContractError("DESCRIPTOR_SCHEMA_INVALID")
    _validate_artifact(value)
    return value
