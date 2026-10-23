#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export GODOT="${GODOT:-$(command -v godot || command -v godot4 || true)}"
if [[ -z "$GODOT" ]]; then echo 'Set GODOT=/path/to/Godot-4.7.2' >&2; exit 1; fi
OUT="${KEYBOARD_QA_OUTPUT:-$ROOT/tests/keyboard_navigation/regression_results}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
HOME_QA="$(mktemp -d "${TMPDIR:-/tmp}/fourfold-keyboard-regressions.XXXXXX")"
trap 'rm -rf "$HOME_QA"' EXIT
export XDG_CONFIG_HOME="$HOME_QA/config" XDG_DATA_HOME="$HOME_QA/data" XDG_CACHE_HOME="$HOME_QA/cache"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
VERSION="$("$GODOT" --version)"
if [[ "$VERSION" != 4.7.2.* ]]; then echo "Godot 4.7.2 required; got $VERSION" >&2; exit 1; fi
cd "$ROOT"
sha256sum scripts/main.gd > "$OUT/source_before.txt"
for name in completion_reconcile resume_integration save_migration_v2 font_coverage_v2; do
  "$GODOT" --headless --audio-driver Dummy --path . --script "res://tests/$name.gd" -- --qa > "$OUT/$name.log" 2>&1
  if grep -E 'SCRIPT ERROR:' "$OUT/$name.log"; then exit 1; fi
  if [[ "$name" == save_migration_v2 ]]; then
    # This fixture intentionally rejects one archive copy; no other ERROR is allowed.
    python3 - "$OUT/$name.log" <<'PY'
import json,pathlib,re,sys
errors=[line for line in pathlib.Path(sys.argv[1]).read_text().splitlines() if line.startswith('ERROR:')]
assert len(errors)==1 and re.fullmatch(r"ERROR: Failed to open '.*qa_progress_roundtrip_v1_archive\.json'\.",errors[0]),errors
assert json.load(open('tests/save_migration_v2.json'))['passed']
PY
  elif grep -E '^ERROR:' "$OUT/$name.log"; then exit 1; fi
  tail -n 1 "$OUT/$name.log"
done
bash tests/context_help_audit/run.sh > "$OUT/context_help_regression.log" 2>&1
bash tests/hint_ui_audit_run.sh > "$OUT/hint_ui_regression.log" 2>&1
AUDIT_OUTPUT_DIR="$OUT/resume_audit" python3 tests/resume_ui_audit/run.py > "$OUT/resume_audit.log" 2>&1
"$GODOT" --headless --audio-driver Dummy --path . -- --test-integration > "$OUT/full_handlers.log" 2>&1
if grep -E 'SCRIPT ERROR:|^ERROR:' "$OUT/full_handlers.log"; then exit 1; fi
tail -n 1 "$OUT/full_handlers.log"
python3 -m unittest discover -s tests -v > "$OUT/python_tests.log" 2>&1
tail -n 4 "$OUT/python_tests.log"
sha256sum --check "$OUT/source_before.txt"
