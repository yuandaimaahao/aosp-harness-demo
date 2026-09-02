import sys

if sys.argv[1:] == ["protocol"]:
    print("session-path-race-driver-v0")
else:
    raise SystemExit(1)
