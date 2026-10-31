"""Merge managed tracker settings into Deluge's two-JSON-document configs."""

import json
import os
from pathlib import Path
import sys
import tempfile


def update(path, change):
    header = {"file": 1, "format": 1}
    settings = {}
    if path.exists():
        decoder = json.JSONDecoder()
        text = path.read_text().strip()
        header, end = decoder.raw_decode(text)
        settings = json.loads(text[end:])
    change(settings)
    content = json.dumps(header, indent=4) + json.dumps(settings, indent=4) + "\n"
    if path.exists() and path.read_text() == content:
        return
    # Keep a copy of the previous settings and replace atomically. Config files
    # can contain credentials, so temporary files keep mkstemp's 0600 mode.
    if path.exists():
        backup = path.with_name(path.name + ".before-default-trackers")
        if not backup.exists():
            with open(backup, "x", opener=lambda p, flags: os.open(p, flags, 0o600)) as out:
                out.write(path.read_text())
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=path.name + ".")
    try:
        with os.fdopen(fd, "w") as out:
            out.write(content)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def enable(settings):
    plugins = settings.setdefault("enabled_plugins", [])
    if "DefaultTrackers" not in plugins:
        plugins.append("DefaultTrackers")


def trackers(settings):
    settings["dynamic_trackerlist_url"] = (
        "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt"
    )
    settings["dynamic_trackers_update_interval"] = 1
    settings.setdefault("last_dynamic_trackers_update", 0)
    settings.setdefault("trackers", [])


if __name__ == "__main__":
    directory = Path(sys.argv[1])
    directory.mkdir(parents=True, exist_ok=True)
    update(directory / "defaulttrackers.conf", trackers)
    update(directory / "core.conf", enable)
