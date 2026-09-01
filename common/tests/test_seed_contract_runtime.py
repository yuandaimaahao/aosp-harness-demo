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
    assert canonical_bytes(value={"b":"雪","a":1}) == b'{"a":1,"b":"\xe9\x9b\xaa"}'
    assert canonical_bytes(value={"a":1,"b":"雪"}) == canonical_bytes(value={"b":"雪","a":1})
    for n in (-(2**53-1), 2**53-1): canonical_bytes(value=n)
    for n in (-2**53, 2**53): bad(lambda n=n: canonical_bytes(value=n), "DESCRIPTOR_SCHEMA_INVALID")
    for s in ("\ud800", "\udc00"): bad(lambda s=s: canonical_bytes(value=s), "DESCRIPTOR_SCHEMA_INVALID")
    for value in ((1,2), {1:"v"}, {1:"a","1":"b"}): bad(lambda value=value: canonical_bytes(value=value), "DESCRIPTOR_SCHEMA_INVALID")
    with tempfile.TemporaryDirectory() as directory:
        p = Path(directory) / "seed.json"
        for raw, code in ((b'{"kind":"seed","kind":"seed"}', "DUPLICATE_JSON_KEY"), (b'{"kind":"seed","x":"\\ud800"}', "DESCRIPTOR_SCHEMA_INVALID")):
            p.write_bytes(raw); bad(lambda: load_artifact(path=str(p), expected_kind="seed"), code)
    assert domain_digest(domain_ascii="test/v1\0", value={"a":1}) == hashlib.sha256(b'test/v1\0{"a":1}').hexdigest()
def concurrent():
    with ThreadPoolExecutor(max_workers=8) as pool: outcomes = list(pool.map(lambda _: subprocess.run([sys.executable, __file__, "canonical-core"], capture_output=True, text=True, env={**os.environ,"PYTHONDONTWRITEBYTECODE":"1"}), range(20)))
    assert all((r.returncode, r.stdout, r.stderr) == (0, "PASS canonical-core\n", "") for r in outcomes)
if __name__ == "__main__":
    cases = {"canonical-core": core, "concurrent-core": concurrent}
    try: cases[sys.argv[1]](); print("PASS " + sys.argv[1])
    except (IndexError, KeyError): raise SystemExit("usage: canonical-core|concurrent-core") from None
