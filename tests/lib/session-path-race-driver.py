#!/usr/bin/env python3
import sys

PROTOCOL = "session-path-race-driver-v1"

if sys.argv[1:] == ["protocol"]:
    print(PROTOCOL)
    raise SystemExit
if len(sys.argv) == 4 and sys.argv[1] == "self-test":
    mode = "self-test"
elif len(sys.argv) == 7 and sys.argv[1] == "run-matrix":
    mode = "run-matrix"
else:
    raise SystemExit(2)

raise AssertionError("matrix executor incomplete")
