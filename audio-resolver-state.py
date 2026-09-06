#!/usr/bin/env python3
import json
import os
import sys
import tempfile


STATE_PATH = os.path.expanduser(
    os.environ.get("XDG_STATE_HOME", "~/.local/state")
    + "/audio-resolver/imports.json"
)


def load() -> dict:
    try:
        with open(STATE_PATH) as state:
            value = json.load(state)
            return value if isinstance(value, dict) else {}
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save(state: dict) -> None:
    directory = os.path.dirname(STATE_PATH)
    os.makedirs(directory, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=directory, prefix=".imports.", text=True)
    with os.fdopen(fd, "w") as output:
        json.dump(state, output, indent=2, sort_keys=True)
        output.write("\n")
    # Replace the manifest only after the complete JSON document is on disk.
    os.replace(temporary, STATE_PATH)


def source_key(path: str) -> str:
    return os.path.realpath(path)


def main() -> int:
    if len(sys.argv) < 3 or sys.argv[1] not in {"check", "record"}:
        print("Usage: audio-resolver-state.py check|record <source> [output]", file=sys.stderr)
        return 2
    command, source = sys.argv[1:3]
    try:
        stat = os.stat(source)
    except FileNotFoundError:
        return 1
    state = load()
    key = source_key(source)
    entry = state.get(key)
    current = (
        isinstance(entry, dict)
        and entry.get("size") == stat.st_size
        and entry.get("mtime_ns") == stat.st_mtime_ns
    )
    if command == "check":
        return 0 if current else 1
    state[key] = {
        "size": stat.st_size,
        "mtime_ns": stat.st_mtime_ns,
        "output": os.path.realpath(sys.argv[3]) if len(sys.argv) > 3 else "",
    }
    save(state)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
