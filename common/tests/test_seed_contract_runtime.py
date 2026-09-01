#!/usr/bin/env python3
import hashlib, sys
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
    p = Path(__file__).with_suffix(".json")
    for raw, code in ((b'{"kind":"seed","kind":"seed"}', "DUPLICATE_JSON_KEY"), (b'{"kind":"seed","x":"\\ud800"}', "DESCRIPTOR_SCHEMA_INVALID")):
        p.write_bytes(raw); bad(lambda: load_artifact(path=str(p), expected_kind="seed"), code)
    p.unlink(); assert domain_digest(domain_ascii="test/v1\0", value={"a":1}) == hashlib.sha256(b'test/v1\0{"a":1}').hexdigest()
if __name__ == "__main__":
    if sys.argv[1:] != ["canonical-core"]: raise SystemExit("usage: canonical-core")
    core(); print("PASS canonical-core")
