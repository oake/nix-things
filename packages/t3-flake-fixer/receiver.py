#!/usr/bin/env python3
"""Buildbot failure receiver. Only configured API roots and projects are used."""
import argparse
import hmac
import json
import logging
import os
from pathlib import Path
import re
import subprocess
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.request import urlopen


def validate(p, repos):
    if not isinstance(p, dict) or set(p) != {'repository', 'revision', 'parent_build_id', 'failed_steps'}:
        raise ValueError('invalid payload fields')
    repo = p['repository']
    if not isinstance(repo, str) or not re.fullmatch(r'[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+', repo) or repo not in repos:
        raise ValueError('unknown repository')
    if not isinstance(p['revision'], str) or not re.fullmatch(r'[0-9a-f]{40}', p['revision']):
        raise ValueError('invalid revision')
    positive = lambda x: type(x) is int and 0 < x < 2**63
    if not positive(p['parent_build_id']):
        raise ValueError('invalid parent ID')
    steps = p['failed_steps']
    if not isinstance(steps, list) or len(steps) > 1000:
        raise ValueError('invalid failed_steps')
    destinations = set()
    for s in steps:
        if not isinstance(s, dict) or set(s) != {'type', 'attribute', 'log_id'}:
            raise ValueError('invalid failure fields')
        if s['type'] not in ('build', 'evaluation', 'parent_evaluation') or not positive(s['log_id']):
            raise ValueError('invalid failure type or log ID')
        a = s['attribute']
        if s['type'] == 'parent_evaluation':
            if a is not None:
                raise ValueError('parent evaluation attribute must be null')
        elif not isinstance(a, str) or len(a) > 200 or not re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.+-]*', a) or '..' in a:
            raise ValueError('unsafe attribute')
        dest = (s['type'], a)
        if dest in destinations:
            raise ValueError('duplicate log destination')
        destinations.add(dest)
    return p


class Receiver:
    def __init__(self, config):
        self.c = config
        self.root = Path(config['storageRoot']).expanduser().resolve()
        self.root.mkdir(parents=True, exist_ok=True, mode=0o700)

    def process(self, p):
        if not p['failed_steps']:
            return
        bundle = self.root / p['repository'] / str(p['parent_build_id'])
        bundle.mkdir(parents=True, exist_ok=True)
        try:
            for step in p['failed_steps']:
                dest = bundle / (step['attribute'] or '') / (step['type'] + '.log')
                dest.parent.mkdir(exist_ok=True)
                tmp = dest.with_suffix('.part')
                url = self.c['buildbotUrl'].rstrip('/') + '/api/v2/logs/' + str(step['log_id']) + '/raw'
                try:
                    with urlopen(url, timeout=60) as response, tmp.open('wb') as f:
                        while chunk := response.read(1024 * 1024):
                            f.write(chunk)
                        f.flush()
                        os.fsync(f.fileno())
                    if not tmp.stat().st_size:
                        raise ValueError('empty log: ' + url)
                    os.replace(tmp, dest)
                finally:
                    tmp.unlink(missing_ok=True)
        except Exception as e:
            logging.error('log download failed for %s: %s', bundle, e)
            return
        values = dict(repository=p['repository'], revision=p['revision'], parent_build_id=str(p['parent_build_id']),
                      bundle_path=str(bundle), failed_steps='\n'.join(
                          '- The entire flake failed to evaluate' if step['type'] == 'parent_evaluation'
                          else '- Attribute ' + step['attribute'] + ' failed to ' + (
                              'build' if step['type'] == 'build' else 'evaluate')
                          for step in p['failed_steps']))
        prompt = re.sub(r'\{\{([a-z_]+)\}\}', lambda m: values[m[1]], self.c['prompt'])
        branch = 'flake-update/fix-' + str(p['parent_build_id'])
        argv = [self.c['t3Executable'], 'thread', 'start', '--worktree', 'origin/flake-update',
                '--branch', branch, '--title', 'Fix flake update ' + str(p['parent_build_id']), '--json']
        if self.c.get('t3BaseDir'):
            argv += ['--base-dir', self.c['t3BaseDir']]
        argv += [self.c['repositories'][p['repository']], '-']
        try:
            result = subprocess.run(argv, input=prompt, text=True, capture_output=True, timeout=120, check=True)
            details = json.loads(result.stdout)
            logging.info('launched repair for %s: %s', bundle, details)
        except Exception as e:
            logging.exception('T3 launch failed for %s', bundle)


def serve(c):
    os.umask(0o077)
    receiver = Receiver(c)
    token = Path(c['secretFile'].replace('%d', os.environ.get('CREDENTIALS_DIRECTORY', ''))).read_text().strip() if c.get('secretFile') else None
    if token == '':
        raise ValueError('empty authentication secret')

    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            if self.path != '/buildbot-failure':
                self.send_error(404)
                return
            if token is not None and not hmac.compare_digest(self.headers.get('Authorization', ''), 'Bearer ' + token):
                self.send_error(401)
                return
            try:
                length = int(self.headers.get('Content-Length', '0'))
                if self.headers.get('Transfer-Encoding') or not 0 < length <= 262144:
                    raise ValueError('invalid body size')
                self.connection.settimeout(10)
                body = self.rfile.read(length)
                if len(body) != length:
                    raise ValueError('incomplete request')
                payload = validate(json.loads(body), c['repositories'])
            except (ValueError, OSError) as e:
                self.send_error(400, str(e))
                return
            self.send_response(202)
            self.send_header('Content-Length', '0')
            self.end_headers()
            self.wfile.flush()
            try:
                receiver.process(payload)
            except Exception:
                logging.exception('processing notification failed')

    host, separator, port = c['listenAddress'].rpartition(':')
    if not separator or not host or not port.isdecimal() or not 1 <= int(port) <= 65535:
        raise ValueError('listenAddress must be host:port with port between 1 and 65535')
    if host.startswith('[') and host.endswith(']'):
        host = host[1:-1]
    class Server(ThreadingHTTPServer):
        address_family = socket.AF_INET6 if ':' in host else socket.AF_INET

    server = Server((host, int(port)), Handler)
    server.serve_forever()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', required=True)
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO)
    serve(json.loads(Path(args.config).read_text()))
