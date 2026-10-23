#!/usr/bin/env bash
# Launch from the native desktop Terminal. No production file modifications.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(realpath "${1:?project directory required}")"
OUTPUT="$(realpath -m "${2:?output directory required}")"
GODOT="${GODOT:-$(command -v godot || true)}"
[[ -x "$GODOT" ]] || { echo 'Set GODOT to Godot 4.7.2 executable' >&2; exit 1; }
[[ "$("$GODOT" --version)" == 4.7.2.* ]] || { echo 'Godot 4.7.2 required' >&2; exit 1; }
mkdir -p "$OUTPUT/.qa_env/data" "$OUTPUT/.qa_env/cache" "$OUTPUT/.qa_env/config"
export XDG_DATA_HOME="$OUTPUT/.qa_env/data" XDG_CACHE_HOME="$OUTPUT/.qa_env/cache" XDG_CONFIG_HOME="$OUTPUT/.qa_env/config"
EXTRA=(); [[ $# -lt 3 ]] || EXTRA+=("--baseline=$(realpath "$3")")
"$GODOT" --path "$PROJECT" --audio-driver Dummy --resolution 1440x900 --script "${CAPTURE_SCRIPT:-$HERE/native_capture.gd}" -- --qa --quality=high --qualities="${QUALITIES:-high,low}" --output="$OUTPUT" "${EXTRA[@]}" > "$OUTPUT/capture.log" 2>&1
