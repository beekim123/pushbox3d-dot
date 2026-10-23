#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="$(python3 - <<'PY'
import os,re,shutil,subprocess,sys
explicit=os.environ.get('GODOT')
candidates=[explicit] if explicit else [shutil.which('godot'),shutil.which('godot4')]
errors=[]
for candidate in filter(None,candidates):
    try:
        result=subprocess.run([candidate,'--version'],capture_output=True,text=True,timeout=15,check=True)
        version=result.stdout.strip()
        if re.match(r'^4\.7\.2\.',version):
            print(candidate)
            break
        errors.append(f'{candidate}: {version!r}')
    except (OSError,subprocess.SubprocessError) as exc:
        errors.append(f'{candidate}: {exc}')
else:
    print('ERROR: Godot 4.7.2 is required. Put godot/godot4 on PATH, or set GODOT=/path/to/godot. '+('; '.join(errors) or 'No candidate executable found.'),file=sys.stderr)
    sys.exit(1)
PY
)"
export GODOT
AUDIT_TMP="$(mktemp -d "${TMPDIR:-/tmp}/fourfold-hint-ui-audit.XXXXXX")"
trap 'rm -rf "$AUDIT_TMP"' EXIT
export XDG_CONFIG_HOME="$AUDIT_TMP/config"
export XDG_DATA_HOME="$AUDIT_TMP/data"
export XDG_CACHE_HOME="$AUDIT_TMP/cache"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
python3 - <<'PY'
import pathlib,hashlib,json
files=['scripts/main.gd','scripts/hint_solver.gd','scripts/hint_overlay.gd','scripts/puzzle_rules.gd','scripts/world_view.gd','scripts/ui_kit.gd','assets/levels.json','project.godot']
source={name:hashlib.sha256(pathlib.Path(name).read_bytes()).hexdigest() for name in files}
assert source['scripts/hint_solver.gd']=='f266da3bb93226cbb68c3077d8481d637411ea0da81d508016ec431c443ddbe9',source
assert source['scripts/puzzle_rules.gd']=='260130edbe5978fc610a5e8fcc2f84ff19e8fc8beb16d3a2971790f1cc68df64',source
pathlib.Path('tests/hint_ui_audit_source_before.json').write_text(json.dumps(source,indent=2)+'\n')
PY
for script in hint_ui_audit hint_ui_audit_input hint_ui_audit_pending hint_ui_audit_layout; do
  python3 - "$script" <<'PY'
import os,pathlib,subprocess,sys
name=sys.argv[1]
log=pathlib.Path(f'tests/{name}.log')
with log.open('w') as output:
    try:
        result=subprocess.run([os.environ['GODOT'],'--headless','--path','.','--script',f'tests/{name}.gd','--','--qa'],stdout=output,stderr=subprocess.STDOUT,timeout=180)
    except subprocess.TimeoutExpired:
        print(f'ERROR: {name} exceeded 180 seconds; see {log}.',file=sys.stderr)
        sys.exit(1)
if result.returncode:
    print(f'ERROR: {name} exited {result.returncode}; see {log}.',file=sys.stderr)
    sys.exit(1)
PY
  if grep -E 'SCRIPT ERROR:|^ERROR:' "tests/${script}.log"; then exit 1; fi
  tail -1 "tests/${script}.log"
done
python3 - <<'PY'
import json,pathlib,hashlib
root=pathlib.Path('.')
before=json.loads((root/'tests/hint_ui_audit_source_before.json').read_text())
after={name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in before}
assert before==after,'Source changed during audit; rerun frozen code instead of attesting a later hash.'
reports={name:json.loads((root/f'tests/{name}.json').read_text()) for name in ['hint_ui_audit','hint_ui_audit_input','hint_ui_audit_pending','hint_ui_audit_layout']}
assert all(r['passed'] and not r['failures'] for r in reports.values()),reports
assert reports['hint_ui_audit']['assertions']>=700,reports
assert reports['hint_ui_audit_input']['assertions']>=50,reports
assert reports['hint_ui_audit_pending']['assertions']>=150,reports
assert reports['hint_ui_audit_layout']['templates']==1632 and not reports['hint_ui_audit_layout']['overlaps'],reports
summary={'passed':True,'source_unchanged_during_audit':True,'source_sha256':after,'assertions':sum(r['assertions'] for r in reports.values()),'behavior_assertions':reports['hint_ui_audit']['assertions'],'real_input_assertions':reports['hint_ui_audit_input']['assertions'],'pending_interruption_assertions':reports['hint_ui_audit_pending']['assertions'],'layout_assertions':reports['hint_ui_audit_layout']['assertions'],'layout_templates':1632,'layout_projected_legal_cells':reports['hint_ui_audit_layout']['projected_legal_cells'],'layout_potential_box_stand_samples':reports['hint_ui_audit_layout']['potential_box_stand_samples'],'layout_overlaps':0,'engine':reports['hint_ui_audit']['engine']}
(root/'tests/hint_ui_audit_summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
print('HINT_UI_AUDIT_SUITE_PASS',json.dumps(summary,ensure_ascii=False))
PY
