#!/usr/bin/env bash
set -euo pipefail
OUT="$(cd "$(dirname "$0")" && pwd)"
PROJECT=[workspace]/fourfold_atelier
GODOT=[workspace]/tools/godot-4.7.2/godot
HOME_QA="$(mktemp -d /tmp/fourfold-production-keyboard-native.XXXXXX)"
trap 'rm -rf "$HOME_QA"' EXIT
export XDG_CONFIG_HOME="$HOME_QA/config" XDG_DATA_HOME="$HOME_QA/data" XDG_CACHE_HOME="$HOME_QA/cache"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
sha256sum "$PROJECT/scripts/main.gd" > "$OUT/source_before.txt"
"$GODOT" --audio-driver Dummy --path "$PROJECT" --script "$OUT/capture.gd" -- --qa --quality=high > "$OUT/run.log" 2>&1
sha256sum --check "$OUT/source_before.txt"
if grep -E 'SCRIPT ERROR:|^ERROR:' "$OUT/run.log"; then exit 1; fi
tail -n1 "$OUT/run.log"
