#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT:-[workspace]/tools/godot-4.7.2/godot}"
export XDG_CONFIG_HOME="$ROOT/xdg/config"
export XDG_DATA_HOME="$ROOT/xdg/data"
export XDG_CACHE_HOME="$ROOT/xdg/cache"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
"$GODOT" --version | grep -q '^4\.7\.2\.'
"$GODOT" --headless --audio-driver Dummy --path "$ROOT/fixture" --script independent_keyboard.gd -- --qa > "$ROOT/run.log" 2>&1
if grep -E 'SCRIPT ERROR:|^ERROR:|INDEPENDENT_FAIL' "$ROOT/run.log"; then exit 1; fi
tail -n 1 "$ROOT/run.log"
