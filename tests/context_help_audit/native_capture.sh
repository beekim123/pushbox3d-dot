#!/usr/bin/env bash
# Launch from the connected desktop Terminal; exec's display socket is separate.
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-$(command -v godot || command -v godot4 || true)}"
if [ -z "$GODOT" ]; then echo 'Set GODOT=/path/to/Godot-4.7.2' >&2; exit 1; fi
HOME_AUDIT="$(mktemp -d "${TMPDIR:-/tmp}/fourfold-context-native.XXXXXX")"
trap 'rm -rf "$HOME_AUDIT"' EXIT
export XDG_DATA_HOME="$HOME_AUDIT/data" XDG_CACHE_HOME="$HOME_AUDIT/cache" XDG_CONFIG_HOME="$HOME_AUDIT/config"
mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" screenshots/context_help_audit
VERSION="$("$GODOT" --version)"
if [[ "$VERSION" != 4.7.2.* ]]; then echo "Godot 4.7.2 required; got $VERSION" >&2; exit 1; fi
python3 - <<'PY'
import hashlib,json,pathlib
files=['scripts/main.gd','scripts/context_help.gd','scripts/ui_kit.gd','scripts/world_view.gd','assets/levels.json','tests/context_help_audit/capture.gd']
pathlib.Path('tests/context_help_audit/native_source_before.json').write_text(json.dumps({f:hashlib.sha256(pathlib.Path(f).read_bytes()).hexdigest() for f in files},indent=2)+'\n')
PY
"$GODOT" --path . --audio-driver Dummy --script res://tests/context_help_audit/capture.gd -- --qa --quality=high > tests/context_help_audit/capture.log 2>&1
python3 - <<'PY'
import hashlib,json,pathlib
root=pathlib.Path('tests/context_help_audit');before=json.loads((root/'native_source_before.json').read_text());assert all(hashlib.sha256(pathlib.Path(f).read_bytes()).hexdigest()==h for f,h in before.items()),'Sources changed during native capture'
r=json.loads((root/'capture.json').read_text());assert r['passed'] and not r['headless'] and len(r['rows'])==6,r
images={x['path'].removeprefix('res://'):hashlib.sha256(pathlib.Path(x['path'].removeprefix('res://')).read_bytes()).hexdigest() for x in r['rows']}
(root/'native_manifest.json').write_text(json.dumps({'passed':True,'runtime_unchanged':True,'source_sha256':before,'image_sha256':images,'visual_review':'Pending independent pixel inspection; native capture is not itself visual approval'},indent=2)+'\n');print('CONTEXT_NATIVE_CAPTURE_PASS',json.dumps({'images':len(images),'adapter':r['adapter'],'display_server':r['display_server']}))
PY
