#!/usr/bin/env python3
import hashlib, os, subprocess, sys, tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parents[1] / ".harness/closure/v1/lib"))
try: from seed_contract_runtime import ContractError, RUNTIME_ABI, canonical_bytes, domain_digest, load_artifact
except ModuleNotFoundError: print("FAIL canonical-core runtime/API missing", file=sys.stderr); raise SystemExit(1)
def bad(fn, code):
    try: fn()
    except ContractError as error: assert error.code == code
    else: raise AssertionError(code)
def core():
    assert RUNTIME_ABI == "seed-contract-runtime/v1"
    assert ContractError(7).code == "ARGUMENT_ERROR"
    assert canonical_bytes(value={"b":"雪","a":1}) == b'{"a":1,"b":"\xe9\x9b\xaa"}' == canonical_bytes(value={"a":1,"b":"雪"})
    for n in (-(2**53-1), 2**53-1): canonical_bytes(value=n)
    for n in (-2**53, 2**53): bad(lambda n=n: canonical_bytes(value=n), "DESCRIPTOR_SCHEMA_INVALID")
    for s in ("\ud800", "\udc00"): bad(lambda s=s: canonical_bytes(value=s), "DESCRIPTOR_SCHEMA_INVALID")
    for value in ((1,2), {1:"v"}, {1:"a","1":"b"}): bad(lambda value=value: canonical_bytes(value=value), "DESCRIPTOR_SCHEMA_INVALID")
    for fn in (canonical_bytes, lambda **kw: domain_digest(domain_ascii="test/v1\0", **kw)): bad(lambda fn=fn: fn(value={"\ue000":1,"\U00010000":2}), "DESCRIPTOR_SCHEMA_INVALID")
    with tempfile.TemporaryDirectory() as directory:
        p = Path(directory) / "seed.json"
        for raw, code in ((b'{"kind":"seed","kind":"seed"}', "DUPLICATE_JSON_KEY"), (b'{"kind":"seed","x":"\\ud800"}', "DESCRIPTOR_SCHEMA_INVALID")):
            p.write_bytes(raw); bad(lambda: load_artifact(path=str(p), expected_kind="seed"), code)
    for kwargs in ({"path":None,"expected_kind":"seed"}, {"path":"missing","expected_kind":1}): bad(lambda kwargs=kwargs: load_artifact(**kwargs), "ARGUMENT_ERROR")
    assert domain_digest(domain_ascii="test/v1\0", value={"a":1}) == hashlib.sha256(b'test/v1\0{"a":1}').hexdigest()
    for domain in (type("FauxDomain",(),{"encode":lambda *_:b"x"})(), type("ExplodingDomain",(),{"encode":lambda *_:(_ for _ in ()).throw(RuntimeError("unexpected"))})()): bad(lambda domain=domain: domain_digest(domain_ascii=domain,value={}), "ARGUMENT_ERROR")
    assert ContractError.__init__.__annotations__ == {"code":str,"return":None} and canonical_bytes.__annotations__ == {"value":object,"return":bytes} and domain_digest.__annotations__ == {"domain_ascii":str,"value":object,"return":str} and load_artifact.__annotations__ == {"path":str,"expected_kind":str,"return":dict}
def concurrent():
    with ThreadPoolExecutor(max_workers=8) as pool: outcomes = list(pool.map(lambda _: subprocess.run([sys.executable, __file__, "canonical-core"], capture_output=True, text=True, env={**os.environ,"PYTHONDONTWRITEBYTECODE":"1"}), range(20)))
    assert all((r.returncode, r.stdout, r.stderr) == (0, "PASS canonical-core\n", "") for r in outcomes)
def evidence():
    runtime=__import__("seed_contract_runtime"); assert hasattr(runtime, "_validate_artifact"), "evidence validators missing"
    b = lambda x: __import__("base64").b64encode(x).decode()
    req={"schema_version":1,"kind":"seed_request","source_root":"/src","envsetup_relpath":"build/envsetup.sh","lunch":{"target":"a","product":"b","release":"c","variant":"d"},"source_scope":{"role":"local_lk7k_product","public_aosp_baseline":False,"vendor_context":True,"platform_family":"aosp-17"},"resource_minimums":{"available_bytes":0,"available_inodes":0,"effective_memory_bytes":0,"effective_cpus":0},"estimated_disk_upper_bound_bytes":0}
    entry={"path_b64":b(b"a"),"status_record_b64":b(b"x"),"entry_kind":"regular","mode":1,"content_sha256":"0"*64,"symlink_target_sha256":None}; state={"schema_version":1,"kind":"source_state","manifest_sha256":"0"*64,"projects":[{"path":"a","head":"0"*40,"status_sha256":"0"*64,"entries":[entry]}]}
    record={"sequence":0,"process_ordinal":0,"syscall":"execve","result":0,"errno":None,"exec_argv_b64":[b(b"x"),b(b"x")],"paths":[{"role":"path","dirfd":None,"raw_b64":b(b"a"),"resolved_b64":b(b"a")}],"address_family":None,"classification":"other"}; trace={"schema_version":1,"kind":"trace","records":[record],"counts":{"other":1,"external_network":0,"source_mutation":0,"sync_download":0,"config_query":0,"module_build":0,"package":0}}
    stages=("manifest_before","source_state_before","namespace_probe","envsetup_lunch","manifest_after","source_state_after"); journal={"schema_version":1,"kind":"command_journal","records":[{"stage":s,"argv_b64":[b(b"x"),b(b"x")],"cwd_b64":b(b"/"),"exit_code":0,"trace_first_sequence":0,"trace_last_sequence":0} for s in stages]}
    with tempfile.TemporaryDirectory() as d:
        for value in (req,state,trace,journal):
            p=Path(d)/value["kind"]; p.write_text(__import__("json").dumps(value)); assert load_artifact(path=str(p),expected_kind=value["kind"]) == value
            assert domain_digest(domain_ascii=runtime._DOMAINS[value["kind"]],value=value) == hashlib.sha256(runtime._DOMAINS[value["kind"]].encode()+canonical_bytes(value=value)).hexdigest()
        for value, mutate in ((state,lambda x:x["projects"].append(x["projects"][0])),(trace,lambda x:x["records"][0].update(errno="E",result=0)),(journal,lambda x:x["records"].reverse()),(req,lambda x:x["resource_minimums"].update(available_bytes=True))):
            x=__import__("copy").deepcopy(value); mutate(x); p=Path(d)/"bad"; p.write_text(__import__("json").dumps(x)); bad(lambda:load_artifact(path=str(p),expected_kind=x["kind"]),"DESCRIPTOR_SCHEMA_INVALID")
if __name__ == "__main__":
    cases = {"canonical-core": core, "concurrent-core": concurrent, "evidence-schema": evidence}
    try: [(cases[case](), print("PASS " + case)) for case in sys.argv[1:]]
    except (IndexError, KeyError): raise SystemExit("usage: canonical-core|concurrent-core") from None
