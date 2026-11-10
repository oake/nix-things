#!/usr/bin/env python3
"""Install BreezeX v2.0.1 SVGs as the GNOME cursor theme BreezeX-Black.

Fills are #00FF00 and outlines are #0000FF. Black is #000000 with a #FFFFFF
outline. Hotspots, frame delay, and aliases are in configs/x.build.toml.
nominal_size is the SVG width, so cursor size 24 renders at 24px.
"""

import json
import sys
import tomllib
from pathlib import Path


def frames(svg_root, name):
    one = svg_root / f"{name}.svg"
    if one.is_file():
        return [one]
    found = sorted((svg_root / name).glob(f"{name}-*.svg"))
    if not found:
        raise SystemExit(f"breezex-cursor: no svg for {name}")
    return found


def canvas_width(text, path):
    token = 'width="'
    start = text.find(token)
    if start < 0:
        raise SystemExit(f"breezex-cursor: {path} has no width")
    start += len(token)
    return int(text[start : text.find('"', start)])


def main():
    source = Path(sys.argv[1])
    dest = Path(sys.argv[2])
    svg_root = source / "svg"
    with (source / "configs" / "x.build.toml").open("rb") as handle:
        cursors = tomllib.load(handle)["cursors"]
    fallback = cursors["fallback_settings"]
    delay = int(fallback["x11_delay"])
    fallback_hot = (int(fallback["x_hotspot"]), int(fallback["y_hotspot"]))

    scalable = dest / "cursors_scalable"
    scalable.mkdir(parents=True)

    for name, spec in cursors.items():
        if name == "fallback_settings":
            continue
        hotspot = (
            int(spec.get("x_hotspot", fallback_hot[0])),
            int(spec.get("y_hotspot", fallback_hot[1])),
        )
        paths = frames(svg_root, name)
        cursor_dir = scalable / name
        cursor_dir.mkdir()
        metadata = []
        for path in paths:
            text = path.read_text().replace("#00FF00", "#000000").replace("#0000FF", "#FFFFFF")
            width = canvas_width(text, path)
            (cursor_dir / path.name).write_text(text)
            entry = {
                "filename": path.name,
                "hotspot_x": hotspot[0],
                "hotspot_y": hotspot[1],
                "nominal_size": width,
            }
            if len(paths) > 1:
                entry["delay"] = delay
            metadata.append(entry)
        (cursor_dir / "metadata.json").write_text(json.dumps(metadata, indent=4) + "\n")
        for alias in spec.get("x11_symlinks", []):
            (scalable / alias).symlink_to(name)

    (dest / "index.theme").write_text(
        "[Icon Theme]\nName=BreezeX-Black\nComment=Extended KDE Black\n"
    )


if __name__ == "__main__":
    main()
