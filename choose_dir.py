#!/usr/bin/env python3
import os
import re
import select
import subprocess
import sys
import urllib.parse


def pick_folder(initial_dir: str = "") -> str | None:
    initial_dir = initial_dir or os.path.expanduser("~")
    monitor = subprocess.Popen(
        ["gdbus", "monitor", "--session", "--dest", "org.freedesktop.portal.Desktop"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    options = "{'directory': <true>, 'multiple': <false>}"
    if os.path.isdir(initial_dir):
        uri = "file://" + urllib.parse.quote(os.path.abspath(initial_dir))
        options = (
            "{'directory': <true>, 'multiple': <false>, 'current_folder': <["
            + ", ".join(f"byte {value}" for value in uri.encode())
            + "]>}"
        )
    try:
        result = subprocess.run(
            [
                "gdbus", "call", "--session", "--dest",
                "org.freedesktop.portal.Desktop",
                "--object-path", "/org/freedesktop/portal/desktop",
                "--method", "org.freedesktop.portal.FileChooser.OpenFile",
                "", "Select folder", options,
            ],
            capture_output=True,
            text=True,
            check=True,
        )
        request = re.search(r"objectpath '([^']+)'", result.stdout)
        if not request or monitor.stdout is None:
            return None
        lines = []
        while True:
            ready, _, _ = select.select([monitor.stdout], [], [], 300)
            if not ready:
                return None
            line = monitor.stdout.readline()
            if not line:
                return None
            lines.append(line)
            if request.group(1) in line and "Response" in line:
                break
        match = re.search(r"'uris':\s*<\[\s*'([^']+)'", "".join(lines))
        if not match:
            return None
        path = urllib.parse.unquote(urllib.parse.urlparse(match.group(1)).path)
        return path if os.path.isdir(path) else None
    except (OSError, subprocess.CalledProcessError):
        return None
    finally:
        monitor.terminate()
        try:
            monitor.wait(timeout=2)
        except subprocess.TimeoutExpired:
            monitor.kill()
            monitor.wait()


if __name__ == "__main__":
    selected = pick_folder(sys.argv[1] if len(sys.argv) > 1 else "")
    if selected:
        print(selected)
        raise SystemExit(0)
    raise SystemExit(1)
