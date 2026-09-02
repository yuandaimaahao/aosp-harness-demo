import os
import pathlib
import sys


log = os.environ.get("FAKE_DRIVER_ARGV_LOG")
matrix_evidence = os.environ.get("FAKE_DRIVER_MATRIX_EVIDENCE")
case_log_evidence = os.environ.get("FAKE_DRIVER_CASE_LOG_EVIDENCE")
mode = os.environ.get("FAKE_DRIVER_MODE", "pass")
if log:
    with open(log, "a", encoding="utf-8") as stream:
        stream.write("\t".join(sys.argv[1:]) + "\n")
if sys.argv[1:] == ["protocol"]:
    print("session-path-race-driver-v1")
elif len(sys.argv) == 7 and sys.argv[1] == "run-matrix":
    if mode == "run-rc":
        raise SystemExit(1)
    case_tsv = pathlib.Path(sys.argv[5])
    case_log = pathlib.Path(sys.argv[6])
    if matrix_evidence:
        pathlib.Path(matrix_evidence).write_bytes(case_tsv.read_bytes())
    case_log.parent.mkdir(mode=0o700)
    ids = [line.split("\t", 1)[0] for line in case_tsv.read_text().splitlines()]
    if mode == "log-duplicate":
        ids[-1] = ids[0]
    case_log.write_text("".join(case_id + "\n" for case_id in ids))
    if case_log_evidence:
        pathlib.Path(case_log_evidence).write_bytes(case_log.read_bytes())
    if mode == "run-stderr":
        print("unexpected stderr", file=sys.stderr)
    if mode == "run-summary":
        print("RESULT PASS  wrong summary")
    else:
        print("RESULT PASS  session path race driver")
else:
    raise SystemExit(2)
