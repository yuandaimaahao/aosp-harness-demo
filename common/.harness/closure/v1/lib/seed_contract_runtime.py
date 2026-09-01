import hashlib, json; RUNTIME_ABI, _SAFE = "seed-contract-runtime/v1", 2**53-1
class ContractError(Exception):
    __slots__ = ("_code",)
    def __init__(self, code): self._code = code; super().__init__(code)
    code = property(lambda self: self._code)
def _pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result: raise ContractError("DUPLICATE_JSON_KEY")
        result[key] = value
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
            if not isinstance(key, str): raise ContractError("DESCRIPTOR_SCHEMA_INVALID")
            _guard(key); _guard(item)
        return
    raise ContractError("DESCRIPTOR_SCHEMA_INVALID")
def canonical_bytes(*, value):
    _guard(value); return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
def domain_digest(*, domain_ascii, value):
    try: prefix = domain_ascii.encode("ascii")
    except (AttributeError, UnicodeEncodeError): raise ContractError("ARGUMENT_ERROR") from None
    return hashlib.sha256(prefix + canonical_bytes(value=value)).hexdigest()
def load_artifact(*, path, expected_kind):
    try: raw = open(path, "rb").read()
    except (OSError, TypeError): raise ContractError("DESCRIPTOR_NOT_FOUND") from None
    try: value = json.loads(raw.decode(), object_pairs_hook=_pairs)
    except UnicodeDecodeError: raise ContractError("DESCRIPTOR_INVALID_UTF8") from None
    except json.JSONDecodeError: raise ContractError("DESCRIPTOR_SCHEMA_INVALID") from None
    _guard(value)
    if not isinstance(value, dict) or value.get("kind") != expected_kind: raise ContractError("DESCRIPTOR_SCHEMA_INVALID")
    return value
