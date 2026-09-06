#!/usr/bin/env bash
set -euo pipefail
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/audio-resolver/config.env"
[[ -f "$CONFIG" ]] || { echo "Audio Resolver is not configured: $CONFIG" >&2; exit 1; }
# shellcheck source=/dev/null
source "$CONFIG"
[[ -d "$SOURCE_DIR" ]] || { echo "Source folder does not exist: $SOURCE_DIR" >&2; exit 1; }
LOG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/audio-resolver"
mkdir -p "$LOG_DIR" "$DESTINATION_DIR"
printf '[%s] Watching %s -> %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$SOURCE_DIR" "$DESTINATION_DIR" >>"$LOG_DIR/convert.log"

# Process files that arrived while the watcher was stopped before waiting for
# new filesystem events.
while IFS= read -r -d '' file; do
  "$HOME/.config/omarchy/plugins/quazix.audio-resolver/audio-resolver-convert.sh" "$file" "$DESTINATION_DIR" || true
done < <(find "$SOURCE_DIR" -type f -print0)

inotifywait -m -r -e close_write -e moved_to --format '%w%f' "$SOURCE_DIR" 2>>"$LOG_DIR/convert.log" |
while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  sleep 2
  "$HOME/.config/omarchy/plugins/quazix.audio-resolver/audio-resolver-convert.sh" "$file" "$DESTINATION_DIR" || true
done
