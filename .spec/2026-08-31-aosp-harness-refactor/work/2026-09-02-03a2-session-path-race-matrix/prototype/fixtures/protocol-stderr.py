import sys

if sys.argv[1:] == ["protocol"]:
    print("session-path-race-driver-v1")
    print("unexpected stderr", file=sys.stderr)
else:
    raise SystemExit(1)
