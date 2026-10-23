#!/usr/bin/env bash
# Adapted audit harness. Its results are NEW evidence, not the frozen original293.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "${1:?Usage: bash run_portable.sh PROJECT [OUTPUT]}" && pwd)"
OUT="${2:-$(mktemp -d "${TMPDIR:-/tmp}/keyboard-portable-evidence.XXXXXX")}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
GODOT="${GODOT:-godot}"
command -v "$GODOT" >/dev/null
test -f "$PROJECT/project.godot"
test -f "$PROJECT/scripts/main.gd"
QA_HOME="$(mktemp -d "${TMPDIR:-/tmp}/keyboard-portable-xdg.XXXXXX")"
trap 'rm -rf "$QA_HOME"' EXIT
export XDG_CONFIG_HOME="$QA_HOME/config" XDG_DATA_HOME="$QA_HOME/data" XDG_CACHE_HOME="$QA_HOME/cache"
export KEYBOARD_AUDIT_OUT="$OUT"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
"$GODOT" --version | grep -q '^4\.7\.2\.'
python3 - "$PROJECT" "$OUT" <<'PY'
from pathlib import Path
import hashlib,json,sys
p,o=map(Path,sys.argv[1:]); paths=list((p/'scripts').rglob('*.gd'))+list((p/'assets/models').glob('*.glb'))+[p/'assets/levels.json',p/'project.godot',p/'scenes/main.tscn']
d={str(f.relative_to(p)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(paths)}
(o/'source_before.json').write_text(json.dumps(d,indent=2)+'\n')
PY
"$GODOT" --headless --audio-driver Dummy --path "$PROJECT" --script "$HERE/independent_keyboard.gd" -- --qa > "$OUT/run.log" 2>&1
for variant in enter space keypad; do
 "$GODOT" --headless --audio-driver Dummy --path "$PROJECT" --script "$HERE/independent_unsaved_exit.gd" -- --qa --activation="$variant" > "$OUT/exit_$variant.log" 2>&1
done
"$GODOT" --headless --audio-driver Dummy --path "$PROJECT" --script "$HERE/independent_fallback.gd" -- --qa > "$OUT/fallback.log" 2>&1
if grep -E 'SCRIPT ERROR:|^ERROR:|INDEPENDENT.*FAIL' "$OUT/run.log" "$OUT/fallback.log" "$OUT"/exit_*.log; then exit 1; fi
python3 - "$PROJECT" "$OUT" <<'PY'
from pathlib import Path
import datetime,hashlib,json,sys
p,o=map(Path,sys.argv[1:]); before=json.loads((o/'source_before.json').read_text())
changed=[rel for rel,h in before.items() if not (p/rel).exists() or hashlib.sha256((p/rel).read_bytes()).hexdigest()!=h]
sha=hashlib.sha256((p/'scripts/main.gd').read_bytes()).hexdigest()
core=json.loads((o/'results.json').read_text()); fallback=json.loads((o/'fallback_results.json').read_text()); exits=[json.loads((o/f'exit_{v}.json').read_text()) for v in ['enter','space','keypad']]
reports=[core,fallback]+exits
assert not changed,changed
assert all(not d['failures'] and d['main_sha256']==sha for d in reports)
count=core['independent_checks']+fallback['checks']+sum(d['checks'] for d in exits)
assert count==293,count
d={'passed':True,'checks':count,'failures':[],'process_exit_code':0,'project':str(p),'runtime_main_sha256':sha,'protected_files':len(before),'source_changes':changed,'completed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'Fresh portable-adaptation smoke against specified production project; only extends/output/runner paths adapted. Separate new293 evidence, NOT a relabeling of frozen original independent293. Headless injected-engine events; temporary XDG removed after run.'}
(o/'ADAPTED_SMOKE_SUMMARY.json').write_text(json.dumps(d,indent=2)+'\n');print(json.dumps(d))
PY
