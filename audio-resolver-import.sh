#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 2 ]] || { echo "Usage: audio-resolver-import.sh <source> <destination>" >&2; exit 2; }
[[ -d "$1" ]] || { echo "Source folder does not exist: $1" >&2; exit 1; }
mkdir -p "$2"
status=0
while IFS= read -r -d '' file; do
  "$HOME/.config/omarchy/plugins/quazix.audio-resolver/audio-resolver-convert.sh" "$file" "$2" || status=1
done < <(find "$1" -type f -print0)
exit "$status"
