#!/usr/bin/env python3
"""Private recovery audit. Never writes production or reuses old evidence."""
import argparse,datetime,hashlib,json,os,pathlib,shutil,subprocess,tempfile,time
HERE=pathlib.Path(__file__).resolve().parent
GAME=HERE.parents[1]
ROOT=GAME.parent
DEFAULT_ENGINE=ROOT/'tools/godot-4.7.2/godot'
ENGINE=pathlib.Path(os.environ.get('GODOT',str(DEFAULT_ENGINE) if DEFAULT_ENGINE.exists() else (shutil.which('godot') or 'godot')))
OUTPUT_ROOT=pathlib.Path(os.environ.get('AUDIT_OUTPUT_DIR',tempfile.mkdtemp(prefix='fourfold-audit-results-')))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def sources():
    files=[GAME/'project.godot',GAME/'default_bus_layout.tres']
    for name in ['scripts','assets','scenes']:
        files += [p for p in (GAME/name).rglob('*') if p.is_file() and p.suffix not in ['.uid','.import']]
    files += [p for p in (HERE/'tests').glob('*.gd')]
    files += [HERE/'run.py',HERE/'README.md']
    return {str(p.relative_to(ROOT)):sha(p) for p in sorted(files)}
def prepare():
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    run=OUTPUT_ROOT/stamp;run.mkdir(parents=True)
    # Private local staging; never write fixtures/caches into the supplied project.
    stage=pathlib.Path(tempfile.mkdtemp(prefix='fourfold-audit-stage-'))/'project'
    shutil.copytree(GAME,stage,ignore=shutil.ignore_patterns('.git','.godot','screenshots','blender','docs','tests','*.log'))
    shutil.copytree(HERE/'tests',stage/'audit_tests')
    (stage/'.gdignore').unlink(missing_ok=True)
    manifest={'recovery_run':True,'started_utc':stamp,'engine':str(ENGINE),'engine_sha256':sha(ENGINE),'engine_version':subprocess.check_output([str(ENGINE),'--headless','--version'],env=env_for(pathlib.Path(tempfile.mkdtemp(prefix='fourfold-version-')),run),text=True).strip(),'sources_before':sources(),'stage':str(stage),'results':str(run),'runs':[],'passed':False}
    manifest['stage_matches_sources']=all(sha(stage/pathlib.Path(name).relative_to(GAME.name))==digest for name,digest in manifest['sources_before'].items() if name.startswith(GAME.name+'/') and not name.startswith(GAME.name+'/tests/'))
    (run/'manifest.json').write_text(json.dumps(manifest,indent=2))
    (OUTPUT_ROOT/'latest.json').write_text(json.dumps({'run':str(run),'stage':str(stage)},indent=2))
    return run,stage,manifest
def env_for(home,run):
    env=os.environ.copy();env.update({k:str(home/v) for k,v in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache'),('TMPDIR','tmp')]});env['RESUME_AUDIT_RESULTS']=str(run);env['GODOT_SILENCE_ROOT_WARNING']='1'
    for k in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','TMPDIR']:pathlib.Path(env[k]).mkdir(parents=True,exist_ok=True)
    return env
def invoke(name,script,report,stage,run,home,mode=None,qa=True,timeout=90,native=False):
    cmd=[str(ENGINE),'--headless','--audio-driver','Dummy','--path',str(stage),'--script','res://audit_tests/'+script,'--']
    if native:cmd.remove('--headless')
    if qa:cmd.append('--qa')
    if mode:cmd.append('--audit-mode='+mode)
    began=time.monotonic();info={'name':name,'command':cmd,'userdata_root':str(home)}
    try:
        proc=subprocess.run(cmd,env=env_for(home,run),capture_output=True,text=True,timeout=timeout)
        out=proc.stdout+proc.stderr;(run/(name+'.log')).write_text(out)
        info.update(returncode=proc.returncode,seconds=time.monotonic()-began)
        path=run/report
        data=json.loads(path.read_text()) if path.exists() else {}
        info.update(report=report,checks=data.get('checks',0),passed=proc.returncode==0 and data.get('passed',False) and 'SCRIPT ERROR:' not in out and 'Parse Error:' not in out)
        if name in ['exit_failure','native_failure']:
            user=pathlib.Path(data['userdata']);checks={'original_bytes_preserved':(user/'audit_original.bin').read_bytes()==(user/'fourfold_resume/resume.json').read_bytes(),'foreign_lock_preserved':native or (user/'fourfold_resume/resume.lock').is_dir(),'normal_process_exit':proc.returncode==0}
            info['postprocess']=checks;info['passed'] &= all(checks.values())
    except subprocess.TimeoutExpired as e:
        out=(e.stdout or b'')+(e.stderr or b'');(run/(name+'.log')).write_bytes(out if isinstance(out,bytes) else out.encode());info.update(passed=False,timeout=True,seconds=time.monotonic()-began)
    except Exception as e: info.update(passed=False,error=repr(e))
    print(json.dumps(info),flush=True);return info
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--prepare-only',action='store_true');parser.add_argument('--only',default='');parser.add_argument('--reuse',action='store_true');parser.add_argument('--native',action='store_true');args=parser.parse_args()
    if args.reuse:
        latest=json.loads((OUTPUT_ROOT/'latest.json').read_text());run=pathlib.Path(latest['run']);stage=pathlib.Path(latest['stage']);manifest=json.loads((run/'manifest.json').read_text());shutil.copytree(HERE/'tests',stage/'audit_tests',dirs_exist_ok=True)
    else:run,stage,manifest=prepare()
    scratch=pathlib.Path(tempfile.mkdtemp(prefix='fourfold-recovery-audit-'))
    command=[str(ENGINE),'--headless','--audio-driver','Dummy','--path',str(stage),'--editor','--import','--quit']
    proc=subprocess.run(command,env=env_for(scratch/'import',run),capture_output=True,text=True,timeout=90)
    (run/'import.log').write_text(proc.stdout+proc.stderr)
    print('STAGE',stage,'RESULTS',run,flush=True)
    if args.prepare_only:raise SystemExit(proc.returncode)
    entries=[('cap','cap.gd','cap.json','cap',None,True,90),('storage','storage.gd','storage.json','storage',None,True,90),('lifecycle','lifecycle.gd','lifecycle.json','lifecycle',None,True,90),('restart_writer','restart.gd','restart_writer.json','restart','writer',True,45),('restart_reader','restart.gd','restart_reader.json','restart','reader',True,45),('future_progress','restart.gd','future_progress.json','future','future_progress',False,45),('exit_failure','restart.gd','exit_failure_dispatch.json','exit','exit_failure',True,45),('schedule','schedule.gd','schedule.json','schedule',None,True,90),('layout','layout.gd','layout.json','layout',None,True,120)]
    if args.native:
        entries=[('restart_writer','restart.gd','restart_writer.json','restart','writer',True,45),('native_restart','restart.gd','restart_native.json','restart','native_restart',True,650),('native_failure','restart.gd','exit_failure_native.json','native_failure','native_failure',True,650)]
        print('NATIVE: Continue click -> Z three times -> OS close; next window: Up -> OS close -> Return -> OS close -> Still exit. Linux desktop required.',flush=True)
    chosen=set(args.only.split(',')) if args.only else set()
    for name,script,report,slot,mode,qa,timeout in entries:
        if chosen and name not in chosen:continue
        manifest['runs'].append(invoke(name,script,report,stage,run,scratch/slot,mode,qa,timeout,name.startswith('native_')));(run/'manifest.json').write_text(json.dumps(manifest,indent=2))
    manifest.update(finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),sources_after=sources(),tests_updated_since_snapshot=manifest['sources_before']!=sources())
    manifest['sources_stable']=manifest['sources_before']==manifest['sources_after'];manifest['passed']=manifest.get('stage_matches_sources',False) and manifest['sources_stable'] and all(x['passed'] for x in manifest['runs']);manifest['checks']=sum(x.get('checks',0) for x in manifest['runs'])
    (run/'manifest.json').write_text(json.dumps(manifest,indent=2));print('FINAL',manifest['passed'],manifest['checks'],run,flush=True)
    raise SystemExit(0 if manifest['passed'] else 1)
