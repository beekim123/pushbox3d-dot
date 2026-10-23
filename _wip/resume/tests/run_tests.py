#!/usr/bin/env python3
"""Fresh author verification only; old lost results are never imported."""
import datetime as dt, hashlib, json, os, pathlib, re, subprocess, tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
GODOT=pathlib.Path(os.environ.get('GODOT','/workspace/scratch/e4cad742399c/tools/godot-4.7.2/godot'))
RESULTS=ROOT/'results'; RESULTS.mkdir(exist_ok=True)
userdata=pathlib.Path(tempfile.mkdtemp(prefix='fourfold-resume-rebuild-'))
env=dict(os.environ,XDG_DATA_HOME=str(userdata/'data'),XDG_CONFIG_HOME=str(userdata/'config'),XDG_CACHE_HOME=str(userdata/'cache'))
for key in ('XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME'): pathlib.Path(env[key]).mkdir(parents=True)
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def sources(): return {str(p.relative_to(ROOT)):sha(p) for pattern in ('*.gd','project.godot','tests/*.gd','tests/*.py','snapshot/*') for p in sorted(ROOT.glob(pattern)) if p.is_file()}
start=dt.datetime.now(dt.timezone.utc).isoformat(); before=sources()
version=subprocess.check_output([str(GODOT),'--version'],env=env,text=True).strip()
assert version.startswith('4.7.2.'), version
assert before['resume_codec.gd']=='5bbb79cbaffab0fd70ec310c9914b10bba9259ca58515ac65c0a83c97d102305'
assert before['resume_store.gd']=='c3840e3fabd873c6fc0dcfb494252bdb0f5fa6331951e9c0afed4f11e8828566'
runs=[]
for name,script,args in [('codec','test_codec.gd',[]),('store','test_store.gd',[]),('limits','test_limits.gd',[]),('relaunch_write','test_relaunch.gd',['--','write']),('relaunch_read','test_relaunch.gd',['--','read'])]:
    cmd=[str(GODOT),'--headless','--path',str(ROOT),'--script','tests/'+script,*args]
    stamp=dt.datetime.now(dt.timezone.utc).isoformat()
    result=subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=120)
    log=result.stdout+result.stderr;(RESULTS/(name+'.log')).write_text(log)
    parsed=json.loads((RESULTS/(name+'.json')).read_text()) if (RESULTS/(name+'.json')).exists() else {}
    passed=result.returncode==0 and not re.search(r'SCRIPT ERROR|(^|\s)ERROR:',log) and parsed.get('passed') is True
    runs.append(dict(name=name,command=cmd,started_utc=stamp,returncode=result.returncode,passed=passed,checks=parsed.get('checks',0)))
    print(name, 'PASS' if passed else 'FAIL',parsed.get('checks'),flush=True)
    if not passed: print(log,flush=True)
after=sources()
summary=dict(passed=all(r['passed'] for r in runs) and before==after,checks=sum(r['checks'] for r in runs),started_utc=start,completed_utc=dt.datetime.now(dt.timezone.utc).isoformat(),runs=runs,godot_version=version,godot_sha256=sha(GODOT),source_sha256=after,source_unchanged=before==after,userdata=str(userdata),note='Fresh post-recovery run. Source modules exactly match originals; tests and evidence rebuilt. No production UI claim.')
(RESULTS/'fresh_run_manifest.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:summary[k] for k in ('passed','checks','started_utc','completed_utc','source_unchanged')}))
raise SystemExit(0 if summary['passed'] else 1)
