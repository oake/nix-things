#!/usr/bin/env python3

import fcntl
import hmac
import json
import logging
import os
import re
import socket
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import quote
from urllib.request import urlopen


def validate(p, repos):
    if not isinstance(p, dict) or set(p) != {
        "repository",
        "revision",
        "build_id",
        "build_number",
        "failed_attributes",
    }:
        raise ValueError("invalid payload fields")
    repo = p["repository"]
    if (
        not isinstance(repo, str)
        or not re.fullmatch(r"[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+", repo)
        or repo not in repos
    ):
        raise ValueError("unknown repository")
    if not isinstance(p["revision"], str) or not re.fullmatch(
        r"[0-9a-f]{40}", p["revision"]
    ):
        raise ValueError("invalid revision")
    positive = lambda x: type(x) is int and 0 < x < 2**63
    if not positive(p["build_id"]) or not positive(p["build_number"]):
        raise ValueError("invalid parent ID")
    steps = p["failed_attributes"]
    if not isinstance(steps, list) or len(steps) > 1000:
        raise ValueError("invalid failed_steps")
    destinations = set()
    for s in steps:
        if not isinstance(s, dict) or set(s) != {"type", "attribute"}:
            raise ValueError("invalid failure fields")
        if s["type"] not in ("build", "evaluation", "parent_evaluation"):
            raise ValueError("invalid failure type or log ID")
        a = s["attribute"]
        if s["type"] == "parent_evaluation":
            if a is not None:
                raise ValueError("parent evaluation attribute must be null")
        elif (
            not isinstance(a, str)
            or len(a) > 200
            or not re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_.+-]*", a)
            or ".." in a
        ):
            raise ValueError("unsafe attribute")
        dest = (s["type"], a)
        if dest in destinations:
            raise ValueError("duplicate log destination")
        destinations.add(dest)
    return p


class Receiver:
    def __init__(self, config):
        self.c = config
        self.root = Path(config["storageRoot"]).expanduser().resolve()
        self.root.mkdir(parents=True, exist_ok=True, mode=0o700)

    def process(self, p):
        bundle = self.root / p["repository"] / str(p["build_id"])
        bundle.mkdir(parents=True, exist_ok=True)
        with (bundle / ".lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            if (bundle / ".launched").exists():
                return
            self._process(p)

    def _process(self, p):
        if not p["failed_attributes"]:
            return
        bundle = self.root / p["repository"] / str(p["build_id"])
        bundle.mkdir(parents=True, exist_ok=True)
        try:
            for step in p["failed_attributes"]:
                dest = bundle / (step["attribute"] or "") / (step["type"] + ".log")
                dest.parent.mkdir(exist_ok=True)
                tmp = dest.with_suffix(".part")
                base = (
                    self.c["nixbotUrl"].rstrip("/")
                    + "/api/repos/"
                    + self.c.get("nixbotForge", "github")
                    + "/"
                    + p["repository"]
                    + "/builds/"
                    + str(p["build_number"])
                )
                url = base + (
                    ""
                    if step["type"] == "parent_evaluation"
                    else "/logs/" + quote(step["attribute"], safe="") + "/text"
                )
                try:
                    with (
                        urlopen(url, timeout=60) as response,
                        tmp.open("wb") as f,
                    ):
                        if step["type"] == "parent_evaluation":
                            f.write(json.load(response)["build"]["error"].encode())
                        else:
                            while chunk := response.read(1024 * 1024):
                                f.write(chunk)
                        f.flush()
                        os.fsync(f.fileno())
                    if not tmp.stat().st_size:
                        raise ValueError("empty log: " + url)
                    os.replace(tmp, dest)
                finally:
                    tmp.unlink(missing_ok=True)
        except Exception as e:
            logging.error("log download failed for %s: %s", bundle, e)
            raise
        values = dict(
            repository=p["repository"],
            revision=p["revision"],
            build_id=str(p["build_id"]),
            build_number=str(p["build_number"]),
            bundle_path=str(bundle),
            failed_steps="\n".join(
                "- The entire flake failed to evaluate"
                if step["type"] == "parent_evaluation"
                else "- Attribute "
                + step["attribute"]
                + " failed to "
                + ("build" if step["type"] == "build" else "evaluate")
                for step in p["failed_attributes"]
            ),
        )
        prompt = re.sub(r"\{\{([a-z_]+)\}\}", lambda m: values[m[1]], self.c["prompt"])
        branch = "flake-update-fix/" + str(p["build_id"])
        argv = [
            self.c["t3Executable"],
            "thread",
            "start",
            "--worktree",
            "origin/flake-update",
            "--branch",
            branch,
            "--title",
            "Fix flake update " + str(p["build_id"]),
            "--json",
        ]
        if self.c.get("t3BaseDir"):
            argv += ["--base-dir", self.c["t3BaseDir"]]
        argv += [self.c["repositories"][p["repository"]], "-"]
        if self.c.get("recordOnly"):
            (bundle / "recorded.json").write_text(json.dumps(p, indent=2))
        else:
            try:
                result = subprocess.run(
                    argv,
                    input=prompt,
                    text=True,
                    capture_output=True,
                    timeout=120,
                    check=True,
                )
                details = json.loads(result.stdout)
                logging.info("launched repair for %s: %s", bundle, details)
            except Exception:
                logging.exception("T3 launch failed for %s", bundle)
                raise
        with (bundle / ".launched").open("x") as marker:
            marker.write(json.dumps(p))
            marker.flush()
            os.fsync(marker.fileno())


def serve(c):
    os.umask(0o077)
    receiver = Receiver(c)
    token = (
        Path(c["secretFile"].replace("%d", os.environ.get("CREDENTIALS_DIRECTORY", "")))
        .read_text()
        .strip()
        if c.get("secretFile")
        else None
    )
    if token == "":
        raise ValueError("empty authentication secret")

    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            if self.path != "/nixbot-failure":
                self.send_error(404)
                return
            if token is not None and not hmac.compare_digest(
                self.headers.get("Authorization", ""), "Bearer " + token
            ):
                self.send_error(401)
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if self.headers.get("Transfer-Encoding") or not 0 < length <= 262144:
                    raise ValueError("invalid body size")
                self.connection.settimeout(10)
                body = self.rfile.read(length)
                if len(body) != length:
                    raise ValueError("incomplete request")
                payload = validate(json.loads(body), c["repositories"])
            except (ValueError, OSError) as e:
                self.send_error(400, str(e))
                return
            try:
                receiver.process(payload)
            except Exception:
                logging.exception("processing notification failed")
                self.send_error(503)
                return
            self.send_response(202)
            self.send_header("Content-Length", "0")
            self.end_headers()

    host, separator, port = c["listenAddress"].rpartition(":")
    if not separator or not host or not port.isdecimal() or not 1 <= int(port) <= 65535:
        raise ValueError(
            "listenAddress must be host:port with port between 1 and 65535"
        )
    if host.startswith("[") and host.endswith("]"):
        host = host[1:-1]

    class Server(ThreadingHTTPServer):
        address_family = socket.AF_INET6 if ":" in host else socket.AF_INET

    server = Server((host, int(port)), Handler)
    server.serve_forever()
