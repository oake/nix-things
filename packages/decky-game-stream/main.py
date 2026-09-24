import os
import pwd
import subprocess

import decky

SYSTEMCTL = "@systemctl@"
TARGET = "game-stream.target"
CAPTURE = "game-stream-capture.service"

RESOLUTIONS = ["3840x2160", "2560x1440", "1920x1080"]
FRAMERATES = [30, 60, 120]
DEFAULTS = {"resolution": "3840x2160", "fps": 60}

# read by game-stream-capture.service as an EnvironmentFile
ENV_FILE = os.path.join(pwd.getpwuid(os.getuid()).pw_dir, ".config", "game-stream.env")


def systemctl(*args):
    uid = os.getuid()
    env = {
        **os.environ,
        "LD_LIBRARY_PATH": "",
        "XDG_RUNTIME_DIR": f"/run/user/{uid}",
        "DBUS_SESSION_BUS_ADDRESS": f"unix:path=/run/user/{uid}/bus",
    }
    result = subprocess.run(
        [SYSTEMCTL, "--user", *args], env=env, capture_output=True, text=True
    )
    if result.returncode != 0 and result.stderr:
        decky.logger.error(result.stderr)
    return result


def load_settings():
    settings = dict(DEFAULTS)
    try:
        with open(ENV_FILE) as f:
            env = dict(line.strip().split("=", 1) for line in f if "=" in line)
        resolution = f"{env['WIDTH']}x{env['HEIGHT']}"
        fps = int(env["FPS"])
        if resolution in RESOLUTIONS and fps in FRAMERATES:
            settings = {"resolution": resolution, "fps": fps}
    except (OSError, KeyError, ValueError):
        pass
    return settings


def save_settings(resolution, fps):
    width, height = resolution.split("x")
    os.makedirs(os.path.dirname(ENV_FILE), exist_ok=True)
    with open(ENV_FILE, "w") as f:
        f.write(f"WIDTH={width}\nHEIGHT={height}\nFPS={fps}\n")


class Plugin:
    async def get_state(self) -> dict:
        streaming = systemctl("is-active", "--quiet", TARGET).returncode == 0
        return {"streaming": streaming, **load_settings()}

    async def set_streaming(self, enabled: bool) -> dict:
        systemctl("start" if enabled else "stop", TARGET)
        return await self.get_state()

    async def set_settings(self, resolution: str, fps: int) -> dict:
        if resolution in RESOLUTIONS and fps in FRAMERATES:
            save_settings(resolution, fps)
            # picks up the new settings if live, no-op otherwise
            systemctl("try-restart", CAPTURE)
        return await self.get_state()
