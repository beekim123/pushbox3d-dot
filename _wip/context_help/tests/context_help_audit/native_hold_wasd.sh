#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-$(command -v godot || command -v godot4 || true)}"
HOME_AUDIT="$(mktemp -d "${TMPDIR:-/tmp}/fourfold-context-hold.XXXXXX")"
trap 'rm -rf "$HOME_AUDIT"' EXIT
export XDG_DATA_HOME="$HOME_AUDIT/data" XDG_CACHE_HOME="$HOME_AUDIT/cache" XDG_CONFIG_HOME="$HOME_AUDIT/config"
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
"$GODOT" --path . --audio-driver Dummy --script res://tests/context_help_audit/native_hold_wasd.gd -- --qa --quality=low > tests/context_help_audit/native_hold_wasd.log 2>&1
