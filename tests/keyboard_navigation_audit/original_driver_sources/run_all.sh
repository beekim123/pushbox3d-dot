#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT:-[workspace]/tools/godot-4.7.2/godot}"
export XDG_CONFIG_HOME="$ROOT/xdg/config"
export XDG_DATA_HOME="$ROOT/xdg/data"
export XDG_CACHE_HOME="$ROOT/xdg/cache"
bash "$ROOT/run_independent.sh"
for variant in enter space keypad; do
 "$GODOT" --headless --audio-driver Dummy --path "$ROOT/fixture" --script independent_unsaved_exit.gd -- --qa --activation="$variant" > "$ROOT/exit_$variant.log" 2>&1
done
"$GODOT" --headless --audio-driver Dummy --path "$ROOT/fixture" --script independent_fallback.gd -- --qa > "$ROOT/fallback.log" 2>&1
if grep -E 'SCRIPT ERROR:|^ERROR:|INDEPENDENT.*FAIL' "$ROOT/run.log" "$ROOT/fallback.log" "$ROOT"/exit_*.log; then exit 1; fi
tail -n 1 "$ROOT/fallback.log"
