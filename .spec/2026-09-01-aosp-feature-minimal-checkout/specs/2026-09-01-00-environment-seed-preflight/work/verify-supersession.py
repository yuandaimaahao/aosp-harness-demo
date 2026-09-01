#!/usr/bin/env python3
"""Fail-closed dispatcher for supersession-validator/v1."""

import argparse
import importlib.util
import pathlib
import sys

from supersession_lib import ContractError


PASS_LINES = {
    "self-test": "RESULT PASS environment-seed-preflight-supersession-self-test",
    "pre-commit": "RESULT PASS environment-seed-preflight-supersession-pre-commit",
    "accept": "RESULT PASS environment-seed-preflight-supersession-acceptance",
}


class ClosedParser(argparse.ArgumentParser):
    def error(self, message):
        raise ContractError("ARGUMENT_ERROR")


def _parse(argv):
    parser = ClosedParser(add_help=False)
    commands = parser.add_subparsers(dest="mode", required=True)
    commands.add_parser("self-test", add_help=False)
    pre_commit = commands.add_parser("pre-commit", add_help=False)
    accept = commands.add_parser("accept", add_help=False)
    for target in (pre_commit, accept):
        target.add_argument("--project-root", required=True)
        target.add_argument("--base-commit", required=True)
        target.add_argument("--manifest", required=True)
    pre_commit.add_argument("--require-complete", action="store_true")
    accept.add_argument("--merge-commit", required=True)
    accept.add_argument("--ledger", required=True)
    return parser.parse_args(argv)


def _load(path, mode):
    module_path = path / "modes" / f"{mode.replace('-', '_')}.py"
    if not module_path.is_file():
        raise ContractError("CAPABILITY_UNAVAILABLE")
    spec = importlib.util.spec_from_file_location(f"supersession_mode_{mode}", module_path)
    if spec is None or spec.loader is None:
        raise ContractError("CAPABILITY_UNAVAILABLE")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    if not callable(getattr(module, "run", None)):
        raise ContractError("CAPABILITY_UNAVAILABLE")
    return module


def main(argv):
    try:
        args = _parse(argv)
        dispatcher = pathlib.Path(__file__).resolve()
        expected = PASS_LINES[args.mode]
        context = {"dispatcher_path": dispatcher, "work_dir": dispatcher.parent, "pass_line": expected}
        if _load(dispatcher.parent, args.mode).run(args, context) != expected:
            raise ContractError("INTERNAL_ERROR")
    except ContractError as exc:
        print(f"RESULT FAIL supersession {exc.code}", file=sys.stderr)
        return 1
    except Exception:
        print("RESULT FAIL supersession INTERNAL_ERROR", file=sys.stderr)
        return 1
    print(expected)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
