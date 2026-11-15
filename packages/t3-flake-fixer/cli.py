import argparse
import json
import logging
import os
from pathlib import Path

from notify import notify
from receiver import serve


def main():
    parser = argparse.ArgumentParser(prog="t3-flake-fixer")
    commands = parser.add_subparsers(dest="mode", required=True)
    server = commands.add_parser("serve", help="Receive failures and launch repairs")
    server.add_argument("--config", required=True)
    sender = commands.add_parser("notify", help="Report a matching failed build")
    sender.add_argument(
        "--context",
        default=os.environ.get("NIXBOT_CONTEXT_FILE"),
        required=not os.environ.get("NIXBOT_CONTEXT_FILE"),
    )
    sender.add_argument("--url", required=True)
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO)
    if args.mode == "serve":
        serve(json.loads(Path(args.config).read_text()))
    else:
        notify(args.context, args.url)


if __name__ == "__main__":
    main()
