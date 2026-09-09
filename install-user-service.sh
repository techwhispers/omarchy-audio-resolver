#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="${PLUGIN_DIR:-$HOME/.config/omarchy/plugins/quazix.audio-resolver}"
SERVICE_SRC="$PLUGIN_DIR/audio-resolver.service"
SERVICE_DST="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/audio-resolver.service"

mkdir -p "$(dirname "$SERVICE_DST")"
install -m 0644 "$SERVICE_SRC" "$SERVICE_DST"

systemctl --user daemon-reload
systemctl --user enable --now audio-resolver.service
