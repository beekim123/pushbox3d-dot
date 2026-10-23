#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-$(command -v godot || command -v godot4 || true)}"
if [[ -z "$GODOT" ]]; then echo 'Set GODOT=/path/to/Godot-4.7.2' >&2; exit 1; fi
HOME_QA="$(mktemp -d "${TMPDIR:-/tmp}/fourfold-keyboard-events.XXXXXX")"
trap 'rm -rf "$HOME_QA"' EXIT
export XDG_CONFIG_HOME="$HOME_QA/config" XDG_DATA_HOME="$HOME_QA/data" XDG_CACHE_HOME="$HOME_QA/cache"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
"$GODOT" --version | grep -q '^4\.7\.2\.'
OUT="${KEYBOARD_QA_OUTPUT:-$ROOT/tests/keyboard_navigation/results}"
mkdir -p "$OUT"
export KEYBOARD_QA_OUTPUT="$(cd "$OUT" && pwd)"
OUT="$KEYBOARD_QA_OUTPUT"
sha256sum "$ROOT/scripts/main.gd" > "$OUT/keyboard_source_before.txt"
"$GODOT" --headless --editor --import --path "$ROOT" --quit > "$OUT/keyboard_import.log" 2>&1
if grep -E 'SCRIPT ERROR:|^ERROR:' "$OUT/keyboard_import.log"; then exit 1; fi
for script in keyboard_navigation keyboard_transition_guards keyboard_mouse_races; do
  "$GODOT" --headless --audio-driver Dummy --path "$ROOT" --script "res://tests/$script.gd" -- --qa > "$OUT/$script.log" 2>&1
  if grep -E 'SCRIPT ERROR:|^ERROR:|KEYBOARD_FAIL' "$OUT/$script.log"; then exit 1; fi
  tail -n 1 "$OUT/$script.log"
done
for key in enter space; do
  "$GODOT" --headless --audio-driver Dummy --path "$ROOT" --script res://tests/keyboard_exit_process.gd -- --qa "--keyboard-exit-key=$key" > "$OUT/keyboard_exit_$key.log" 2>&1
  if grep -E 'SCRIPT ERROR:|^ERROR:|KEYBOARD_FAIL' "$OUT/keyboard_exit_$key.log"; then exit 1; fi
  tail -n 1 "$OUT/keyboard_exit_$key.log"
done
sha256sum --check "$OUT/keyboard_source_before.txt"
