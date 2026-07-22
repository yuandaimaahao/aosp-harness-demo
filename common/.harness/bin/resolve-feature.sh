#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROOT="${HARNESS_ROOT:-$DEFAULT_ROOT}"
CLIENT=''

usage() {
  printf '%s\n' 'Usage: resolve-feature.sh --client claude|codex [--contract]'
}

while (($# > 0)); do
  case "$1" in
    --client)
      (($# >= 2)) || { usage >&2; exit 2; }
      CLIENT="$2"
      shift 2
      ;;
    --contract)
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

case "$CLIENT" in
  claude|codex) ;;
  *)
    echo 'error: client 必须是 claude 或 codex' >&2
    exit 1
    ;;
esac

current_file="$ROOT/CURRENT_FEATURE"
if [[ ! -f "$current_file" ]]; then
  echo "error: 缺少 $current_file" >&2
  exit 1
fi

if ! feature="$(python3 - "$current_file" <<'PY'
import pathlib
import re
import sys

try:
    raw = pathlib.Path(sys.argv[1]).read_bytes()
except OSError:
    raise SystemExit(2)

if b"\0" in raw:
    raise SystemExit(3)
try:
    text = raw.decode("utf-8")
except UnicodeDecodeError:
    raise SystemExit(3)

if text.endswith("\n"):
    text = text[:-1]
if text.endswith("\r"):
    text = text[:-1]
if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", text):
    raise SystemExit(3)
sys.stdout.write(text)
PY
)"; then
  echo 'error: INVALID feature；必须是单行 ASCII 名称 [A-Za-z0-9][A-Za-z0-9._-]*' >&2
  exit 1
fi

feature_rel=".harness/features/$feature"
manifest_rel="$feature_rel/repos.tsv"
workflow_rel="$feature_rel/workflow.md"
manifest="$ROOT/$manifest_rel"
workflow="$ROOT/$workflow_rel"
common="$ROOT/.harness/common.md"

[[ -f "$manifest" ]] || { echo "error: 缺少 $manifest_rel" >&2; exit 1; }
[[ -f "$workflow" ]] || { echo "error: 缺少 workflow $workflow_rel" >&2; exit 1; }
[[ -f "$common" ]] || { echo 'error: 缺少 .harness/common.md' >&2; exit 1; }

shopt -s nullglob
verifier_candidates=("$ROOT/$feature_rel"/verify-*.sh)
shopt -u nullglob
if [[ "${#verifier_candidates[@]}" -ne 1 || ! -x "${verifier_candidates[0]:-}" ]]; then
  echo "error: $feature_rel 必须恰好有一个可执行 verifier（verify-*.sh）" >&2
  exit 1
fi
verifier="${verifier_candidates[0]}"
verifier_rel="$feature_rel/$(basename "$verifier")"

if ! repo_paths="$(python3 - "$manifest" "$manifest_rel" <<'PY'
import pathlib
import re
import sys

manifest = pathlib.Path(sys.argv[1])
label = sys.argv[2]
try:
    raw = manifest.read_bytes()
except OSError:
    raise SystemExit(2)
if b"\0" in raw:
    print(f"error: {label} contains NUL bytes", file=sys.stderr)
    raise SystemExit(1)
try:
    lines = raw.decode("utf-8").splitlines()
except UnicodeDecodeError:
    print(f"error: {label} is not UTF-8", file=sys.stderr)
    raise SystemExit(1)

paths = []
safe_path = re.compile(r"[A-Za-z0-9._+-]+(?:/[A-Za-z0-9._+-]+)*")
for line_number, line in enumerate(lines, start=1):
    if not line or line.startswith("#"):
        continue
    fields = line.split("\t")
    if len(fields) != 4 or any(field == "" for field in fields):
        print(
            f"error: {label}:{line_number} four nonempty tab-separated fields required",
            file=sys.stderr,
        )
        raise SystemExit(1)
    path = fields[0]
    if safe_path.fullmatch(path) is None or any(
        part in (".", "..") for part in path.split("/")
    ):
        print(
            f"error: {label}:{line_number} unsafe repository path '{path}'",
            file=sys.stderr,
        )
        raise SystemExit(1)
    paths.append(path)

if not paths:
    print(f"error: {label} has no repositories", file=sys.stderr)
    raise SystemExit(1)
sys.stdout.write(",".join(paths))
PY
)"; then
  exit 1
fi

hash_files=("$ROOT/CURRENT_FEATURE" "$common" "$manifest" "$workflow" "$verifier")
if command -v sha256sum >/dev/null 2>&1; then
  contract_sha256="$(cat "${hash_files[@]}" | sha256sum | awk '{print $1}')"
else
  contract_sha256="$(cat "${hash_files[@]}" | shasum -a 256 | awk '{print $1}')"
fi

printf 'client=%s\n' "$CLIENT"
printf 'feature=%s\n' "$feature"
printf 'target_branch=%s\n' "$feature"
printf 'manifest=%s\n' "$manifest_rel"
printf 'workflow=%s\n' "$workflow_rel"
printf 'verifier=%s\n' "$verifier_rel"
printf 'repositories=%s\n' "$repo_paths"
printf 'contract_sha256=%s\n' "$contract_sha256"
