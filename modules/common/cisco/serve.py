import argparse
import re
import shutil
import signal
import sys
import tempfile
from pathlib import Path
from xml.sax.saxutils import escape as xml_escape

PLACEHOLDER = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}|\$([A-Za-z_][A-Za-z0-9_]*)")


def load_secrets(path):
    secrets = {}
    with open(path, encoding="utf-8") as fh:
        for lineno, raw in enumerate(fh, 1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                raise SystemExit(f"{path}:{lineno}: expected KEY=value")
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                value = value[1:-1]
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
                raise SystemExit(f"{path}:{lineno}: invalid secret name {key!r}")
            secrets[key] = value
    return secrets


def substitute(text, secrets, *, escape=True):
    missing = []

    def repl(match):
        name = match.group(1) or match.group(2)
        if name not in secrets:
            missing.append(name)
            return match.group(0)
        value = secrets[name]
        return xml_escape(value) if escape else value

    out = PLACEHOLDER.sub(repl, text)
    if missing:
        names = ", ".join(sorted(set(missing)))
        raise SystemExit(f"unresolved secret placeholder(s): {names}")
    return out


def make_tree_writable(root):
    # copytree preserves the Nix store's 555 directories, so unlink/rename
    # in the temp copy would fail with EACCES.
    root = Path(root)
    for path in [root, *root.rglob("*")]:
        if path.is_symlink() or not path.is_dir():
            continue
        path.chmod(0o700)


def prepare_root(store_root, secrets_path):
    if secrets_path is None:
        return store_root, None
    dest = tempfile.mkdtemp(prefix="cisco-config-")
    shutil.copytree(store_root, dest, dirs_exist_ok=True, symlinks=True)
    make_tree_writable(dest)
    secrets = load_secrets(secrets_path)
    for path in Path(dest).rglob("*.xml"):
        text = path.read_text(encoding="utf-8")
        updated = substitute(text, secrets)
        if updated != text:
            path.unlink()
            path.write_text(updated, encoding="utf-8")
    for path in sorted(Path(dest).rglob("*"), key=lambda p: len(str(p)), reverse=True):
        if path.is_dir():
            continue
        new_name = substitute(path.name, secrets, escape=False)
        if new_name == path.name:
            continue
        target = path.with_name(new_name)
        if target.exists():
            raise SystemExit(f"secret substitution would overwrite {target}")
        path.rename(target)
    return dest, dest


def serve_http(root, bind, port):
    from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

    class Handler(SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=root, **kwargs)

    ThreadingHTTPServer((bind, port), Handler).serve_forever()


def serve_tftp(root, bind, port):
    import logging

    import tftpy

    logging.basicConfig(
        stream=sys.stderr, level=logging.INFO, format="%(asctime)s %(message)s"
    )
    tftpy.TftpServer(root).listen(bind, port)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("http", "tftp"))
    parser.add_argument("--root", required=True)
    parser.add_argument("--bind", required=True)
    parser.add_argument("--port", required=True, type=int)
    parser.add_argument("--secrets")
    args = parser.parse_args()

    root, tmp = prepare_root(args.root, args.secrets)

    def cleanup(*_):
        if tmp is not None:
            shutil.rmtree(tmp, ignore_errors=True)
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)
    try:
        if args.mode == "http":
            serve_http(root, args.bind, args.port)
        else:
            serve_tftp(root, args.bind, args.port)
    finally:
        if tmp is not None:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
