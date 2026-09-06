#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 1 ]] || { echo "Usage: select-folder.sh <source|destination>" >&2; exit 2; }
case "$1" in
  source) title="Select Audio Resolver source folder" ;;
  destination) title="Select Audio Resolver destination folder" ;;
  *) echo "Unknown folder type: $1" >&2; exit 2 ;;
esac

config="${XDG_CONFIG_HOME:-$HOME/.config}/audio-resolver/config.env"
source_dir=""
destination_dir=""
if [[ -f "$config" ]]; then
  # shellcheck source=/dev/null
  source "$config"
fi

selected="$(omarchy file select --directory --title "$title")"
[[ -n "$selected" ]] || exit 1

if [[ "$1" == "source" ]]; then
  source_dir="$selected"
else
  destination_dir="$selected"
fi

python3 "$HOME/.config/omarchy/plugins/quazix.audio-resolver/configure.py" \
  "$source_dir" "$destination_dir"
printf '%s\n' "$selected"
