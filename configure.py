#!/usr/bin/env python3
import os
import shlex
import sys
import tempfile


def main() -> int:
    if len(sys.argv) not in (3, 4):
        print("Usage: configure.py <source> <destination> [suffix]", file=sys.stderr)
        return 2
    config_dir = os.path.expanduser("~/.config/audio-resolver")
    os.makedirs(config_dir, exist_ok=True)
    config_path = os.path.join(config_dir, "config.env")
    current = {}
    if os.path.isfile(config_path):
        with open(config_path) as existing:
            for line in existing:
                key, separator, value = line.rstrip().partition("=")
                if separator:
                    try:
                        current[key] = shlex.split(value)[0]
                    except ValueError:
                        current[key] = value
    source_arg, destination_arg = sys.argv[1:3]
    label_arg = sys.argv[3] if len(sys.argv) == 4 else current.get(
        "OUTPUT_LABEL", current.get("OUTPUT_SUFFIX", "")
    )
    source = os.path.abspath(source_arg) if source_arg else current.get("SOURCE_DIR", "")
    destination = os.path.abspath(destination_arg) if destination_arg else current.get("DESTINATION_DIR", "")
    if source and not os.path.isdir(source):
        print(f"Source folder does not exist: {source}", file=sys.stderr)
        return 1
    if destination:
        os.makedirs(destination, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=config_dir, prefix=".config.", text=True)
    with os.fdopen(fd, "w") as config:
        config.write(f"SOURCE_DIR={shlex.quote(source)}\n" if source else "")
        config.write(f"DESTINATION_DIR={shlex.quote(destination)}\n" if destination else "")
        config.write(f"OUTPUT_LABEL={shlex.quote(label_arg)}\n")
    os.replace(temporary, config_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
