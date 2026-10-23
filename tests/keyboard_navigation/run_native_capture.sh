#!/usr/bin/env bash
# Launch from the connected desktop Terminal, not an exec display override.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$(command -v godot || command -v godot4 || true)}"
if [[ -z "$GODOT" ]]; then echo 'Set GODOT=/path/to/Godot-4.7.2' >&2; exit 1; fi
HOME_QA="$(mktemp -d "${TMPDIR:-/tmp}/fourfold-keyboard-native.XXXXXX")"
trap 'rm -rf "$HOME_QA"' EXIT
export XDG_CONFIG_HOME="$HOME_QA/config" XDG_DATA_HOME="$HOME_QA/data" XDG_CACHE_HOME="$HOME_QA/cache"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
VERSION="$("$GODOT" --version)"
if [[ "$VERSION" != 4.7.2.* ]]; then echo "Godot 4.7.2 required; got $VERSION" >&2; exit 1; fi
OUT="${KEYBOARD_NATIVE_OUTPUT:-$ROOT/tests/keyboard_navigation/native_results}"
mkdir -p "$OUT"
export KEYBOARD_NATIVE_OUTPUT="$(cd "$OUT" && pwd)"
OUT="$KEYBOARD_NATIVE_OUTPUT"
sha256sum "$ROOT/scripts/main.gd" > "$OUT/source_before.txt"
"$GODOT" --audio-driver Dummy --path "$ROOT" --script res://tests/keyboard_focus_capture.gd -- --qa --quality=high > "$OUT/capture.log" 2>&1
sha256sum --check "$OUT/source_before.txt"
if grep -E 'SCRIPT ERROR:|^ERROR:|KEYBOARD_FAIL' "$OUT/capture.log"; then exit 1; fi
tail -n 1 "$OUT/capture.log"
