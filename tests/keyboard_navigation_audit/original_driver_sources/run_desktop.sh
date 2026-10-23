#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
export XDG_CONFIG_HOME="$ROOT/xdg/config"
export XDG_DATA_HOME="$ROOT/xdg/data"
export XDG_CACHE_HOME="$ROOT/xdg/cache"
[workspace]/tools/godot-4.7.2/godot --audio-driver Dummy --path "$ROOT/fixture" --script desktop_observer.gd -- --qa > "$ROOT/desktop.log" 2>&1
