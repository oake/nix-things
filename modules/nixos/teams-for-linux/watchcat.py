"""Mirror systemd-logind sleep blockers into the Teams for Linux state file."""

import argparse
import getpass
import logging
import os
from pathlib import Path

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib


def reconcile(state_file, enabled, forced_state):
    if not enabled:
        state_file.unlink(missing_ok=True)
        return

    contents = forced_state + "\n"
    try:
        if state_file.read_text() == contents:
            return
    except FileNotFoundError:
        pass

    state_file.parent.mkdir(parents=True, exist_ok=True)
    state_file.write_text(contents)


def has_sleep_blocker(inhibitors):
    return any(
        "sleep" in what.split(":") and mode in ("block", "block-weak")
        for what, _who, _why, mode, _uid, _pid in inhibitors
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-file", required=True)
    parser.add_argument("--forced-state", choices=("active", "inactive"), default="active")
    parser.add_argument("--interval", type=int, default=5)
    args = parser.parse_args()
    if args.interval < 1:
        parser.error("--interval must be positive")

    os.environ.setdefault("USER", getpass.getuser())
    state_file = Path(os.path.expandvars(os.path.expanduser(args.state_file)))
    if not state_file.is_absolute():
        parser.error("--state-file must expand to an absolute path")

    proxy = Gio.DBusProxy.new_for_bus_sync(
        Gio.BusType.SYSTEM,
        Gio.DBusProxyFlags.DO_NOT_AUTO_START,
        None,
        "org.freedesktop.login1",
        "/org/freedesktop/login1",
        "org.freedesktop.login1.Manager",
        None,
    )

    def is_inhibited():
        if proxy.get_name_owner() is None:
            return False
        inhibitors = proxy.call_sync(
            "ListInhibitors",
            None,
            Gio.DBusCallFlags.NONE,
            1000,
            None,
        ).unpack()[0]
        return has_sleep_blocker(inhibitors)

    def sync(*_args):
        enabled = False
        try:
            enabled = is_inhibited()
        except GLib.Error:
            logging.exception("Cannot query logind inhibitors; releasing override")
        try:
            reconcile(state_file, enabled, args.forced_state)
        except OSError:
            logging.exception("Cannot reconcile %s; will retry", state_file)
        return GLib.SOURCE_CONTINUE

    proxy.connect("g-properties-changed", sync)
    proxy.connect("notify::g-name-owner", sync)
    sync()
    GLib.timeout_add_seconds(args.interval, sync)
    GLib.MainLoop().run()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="watchcat: %(levelname)s: %(message)s")
    main()
