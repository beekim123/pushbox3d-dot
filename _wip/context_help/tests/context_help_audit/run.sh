#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-/workspace/scratch/e4cad742399c/tools/godot-4.7.2/godot}"
export GODOT
HOME_AUDIT="$(mktemp -d /tmp/fourfold-context-audit.XXXXXX)"
export XDG_DATA_HOME="$HOME_AUDIT/data" XDG_CACHE_HOME="$HOME_AUDIT/cache" XDG_CONFIG_HOME="$HOME_AUDIT/config"
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
"$GODOT" --version | grep -q '^4\.7\.2\.'
python3 - <<'PY'
import hashlib,json,pathlib
files=['scripts/main.gd','scripts/context_help.gd','scripts/ui_kit.gd','scripts/puzzle_rules.gd','scripts/hint_solver.gd','scripts/hint_overlay.gd','scripts/world_view.gd','scripts/resume_controller.gd','scripts/resume/resume_codec.gd','scripts/resume/resume_store.gd','assets/levels.json','project.godot']
p=pathlib.Path('tests/context_help_audit/source_before.json');p.write_text(json.dumps({f:hashlib.sha256(pathlib.Path(f).read_bytes()).hexdigest() for f in files},indent=2)+'\n')
PY
for name in behavior layout; do
 timeout 180 "$GODOT" --headless --path . --script "res://tests/context_help_audit/$name.gd" -- --qa > "tests/context_help_audit/$name.log" 2>&1
 if grep -E 'SCRIPT ERROR:|^ERROR:|CONTEXT_AUDIT_FAIL' "tests/context_help_audit/$name.log"; then exit 1; fi
 tail -n 1 "tests/context_help_audit/$name.log"
done
python3 - <<'PY'
import hashlib,json,pathlib
root=pathlib.Path('tests/context_help_audit');before=json.loads((root/'source_before.json').read_text());after={f:hashlib.sha256(pathlib.Path(f).read_bytes()).hexdigest() for f in before};assert before==after,'Runtime changed during audit; rerun against final hash.'
reports={n:json.loads((root/f'{n}.json').read_text()) for n in ['behavior','layout']};assert all(r['passed'] and not r['failures'] for r in reports.values())
summary={'passed':True,'runtime_unchanged':True,'source_sha256':after,'behavior_assertions':reports['behavior']['assertions'],'physical_key_events':reports['behavior']['physical_key_events'],'layout_assertions':reports['layout']['assertions'],'layout_rows':len(reports['layout']['rows']),'headless_only':True,'visual_qa':'separate native capture required'};(root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print('CONTEXT_HELP_AUDIT_PASS',json.dumps(summary))
PY
