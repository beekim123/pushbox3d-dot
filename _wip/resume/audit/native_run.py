#!/usr/bin/env python3
"""Launch through cloud desktop Terminal, not executor DISPLAY/socket."""
import datetime,hashlib,json,os,pathlib,subprocess,tempfile
HERE=pathlib.Path(__file__).resolve().parent
ROOT=HERE.parents[1]
latest=json.loads((HERE/'latest.json').read_text());stage=pathlib.Path(latest['stage']);run=HERE/'results'/('native_'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ'));run.mkdir(parents=True)
for p in (HERE/'tests').glob('*.gd'):(stage/'audit_tests'/p.name).write_bytes(p.read_bytes())
engine=ROOT/'tools/godot-4.7.2/godot'
result={'recovery_run':True,'native_cloud_desktop':True,'results':str(run),'stage':str(stage),'runs':[],'hashes':{str(p.relative_to(stage)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (stage/'scripts').rglob('*.gd')}}
(HERE/'native_latest.json').write_text(json.dumps({'run':str(run)},indent=2))
def execute(mode,home,headless=False):
 env=os.environ.copy();env.update(RESUME_AUDIT_RESULTS=str(run),GODOT_SILENCE_ROOT_WARNING='1')
 for k,sub in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache'),('TMPDIR','tmp')]:
  path=home/sub;path.mkdir(parents=True,exist_ok=True);env[k]=str(path)
 cmd=[str(engine),'--audio-driver','Dummy','--path',str(stage),'--script','res://audit_tests/restart.gd']
 if headless:cmd.append('--headless')
 cmd+=['--','--qa','--audit-mode='+mode]
 with (run/(mode+'.log')).open('w') as log:
  proc=subprocess.Popen(cmd,env=env,stdout=log,stderr=subprocess.STDOUT)
  print('NATIVE AUDIT',mode,'PID',proc.pid,'RESULTS',run,flush=True)
  try:code=proc.wait(timeout=650)
  except subprocess.TimeoutExpired:proc.terminate();code=proc.wait(timeout=20)
 item={'mode':mode,'pid':proc.pid,'returncode':code,'command':cmd}
 report=run/({'writer':'restart_writer.json','native_restart':'restart_native.json','native_failure':'exit_failure_native.json'}[mode])
 data=json.loads(report.read_text()) if report.exists() else {};item['report']=str(report);item['passed']=code==0 and data.get('passed',False)
 if mode=='native_failure' and data:
  user=pathlib.Path(data['userdata']);item['external_bytes_preserved']=(user/'audit_original.bin').read_bytes()==(user/'fourfold_resume/resume.json').read_bytes();item['passed'] &= item['external_bytes_preserved']
 result['runs'].append(item);(run/'manifest.json').write_text(json.dumps(result,indent=2));print('FINISHED',json.dumps(item),flush=True)
 return item['passed']
restart=pathlib.Path(tempfile.mkdtemp(prefix='fourfold-native-restart-'))
if execute('writer',restart,True):execute('native_restart',restart)
execute('native_failure',pathlib.Path(tempfile.mkdtemp(prefix='fourfold-native-failure-')))
result['passed']=all(x['passed'] for x in result['runs']) and len(result['runs'])==3
result['finished_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();(run/'manifest.json').write_text(json.dumps(result,indent=2));print('NATIVE AUDIT DONE',result['passed'],run)
