#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/audio-resolver"
LOG_FILE="$LOG_DIR/convert.log"
mkdir -p "$LOG_DIR"
VIDEO_EXTENSIONS="mp4 mov mkv avi mts m2ts 3gp flv wmv mxf"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/audio-resolver/config.env"
OUTPUT_LABEL=""
if [[ -f "$CONFIG" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG"
  OUTPUT_LABEL="${OUTPUT_LABEL:-${OUTPUT_SUFFIX:-}}"
fi
STATE_HELPER="$HOME/.config/omarchy/plugins/quazix.audio-resolver/audio-resolver-state.py"
PYTHON="${PYTHON:-python3}"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"; }
is_video() {
  local extension="${1##*.}"; extension="${extension,,}"
  for allowed in $VIDEO_EXTENSIONS; do [[ "$extension" == "$allowed" ]] && return 0; done
  return 1
}

convert_file() {
  local input="$1" destination="${2:-}"
  [[ -f "$input" ]] || return 0
  is_video "$input" || return 0
  local filename="${input##*/}"
  local stem="${filename%.*}"
  if "$PYTHON" "$STATE_HELPER" check "$input"; then
    log "SKIP: already imported: $filename"
    return 0
  fi
  local codec
  codec="$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$input" 2>/dev/null || true)"
  [[ "$codec" == "aac" ]] || { log "SKIP: $filename (audio codec: ${codec:-none})"; return 0; }
  [[ -n "$destination" ]] || destination="$(dirname "$input")"
  mkdir -p "$destination"
  local output="$destination/${stem}${OUTPUT_LABEL}.mov"
  [[ "$output" == "$input" ]] && { log "SKIP: output is the source file: $filename"; return 0; }
  if [[ -e "$output" ]]; then
    "$PYTHON" "$STATE_HELPER" record "$input" "$output"
    log "SKIP: output exists: ${output##*/}"
    return 0
  fi
  local temporary="${output}.part"
  log "CONVERTING: $filename -> ${output##*/}"
  if ffmpeg -hide_banner -loglevel error -i "$input" -map 0 -c:v copy -c:a pcm_s16le -c:s copy -f mov -y "$temporary" >>"$LOG_FILE" 2>&1; then
    mv -- "$temporary" "$output"
    "$PYTHON" "$STATE_HELPER" record "$input" "$output"
    log "SUCCESS: ${output##*/}"
    command -v notify-send >/dev/null && notify-send "Audio Resolver" "Converted ${filename}"
  else
    rm -f -- "$temporary"
    log "ERROR: conversion failed: $filename"
    return 1
  fi
}

if [[ $# -lt 1 ]]; then
  echo "Usage: audio-resolver-convert.sh <file> [destination]" >&2
  exit 2
fi
convert_file "$1" "${2:-}"
