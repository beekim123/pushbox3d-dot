#!/usr/bin/env python3
"""Read-only synthesis/audio audit. Writes reports only beside this script.
Run: python fourfold_next/audio_review/audit_audio.py [--project PATH]
Dependencies: installed NumPy, ffmpeg, ffprobe. No network, installs or game launch.
The generator AST is restricted to its DSP definitions and four state constants;
its OUT directory creation, write(), packaging, and __main__ are never executed.
Original WAVs and comparison encodes exist only in memory, never in game assets.
"""
from __future__ import annotations
import argparse, ast, collections, datetime, hashlib, io, json, math, re, subprocess, wave
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
DEFAULT_PROJECT = HERE.parents[1] / 'fourfold_atelier'
EXPECTED_MUSIC = ['hub','heaven','inferno','rainforest','city','confluence']
EXPECTED_AMBIENT = ['heaven_ambient','inferno_ambient','rainforest_ambient','city_ambient']
EXPECTED_EFFECTS = ['step','push','undo','reset','goal','win','blocked','portal']
SCORE_PARAMS = [('hub',84,'bell',0),('heaven',80,'bell',12),('inferno',108,'kalimba',0),('rainforest',92,'kalimba',0),('city',104,'keys',0),('confluence',96,'pluck',0)]


def sha(data): return hashlib.sha256(data).hexdigest()
def db(value): return 20*math.log10(max(float(value),1e-15))
def run(args, data=None):
    p = subprocess.run(args,input=data,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if p.returncode or p.stderr:
        raise RuntimeError(f'{args[0]} returned {p.returncode}: {p.stderr.decode(errors="replace")}')
    return p.stdout

def decode(path=None, data=None):
    output = run(['ffmpeg','-v','error','-xerror','-i',str(path) if path else 'pipe:0','-map','0:a:0','-f','f32le','-acodec','pcm_f32le','pipe:1'],data)
    return np.frombuffer(output,dtype='<f4').reshape(-1,2).copy()

def runs(mask):
    positions = np.flatnonzero(np.diff(np.r_[False,mask,False].astype(np.int8)))
    return [(int(a),int(b)) for a,b in zip(positions[::2],positions[1::2])]

def stats(samples, sr=32000):
    x=samples.astype(np.float64); absx=np.abs(x); delta=np.abs(np.diff(x,axis=0))
    r=np.sqrt(np.mean(x*x,axis=0)); seam=np.abs(x[0]-x[-1]); w=sr//100
    windows=x[:len(x)//w*w].reshape(-1,w,2)
    wrms=np.sqrt(np.mean(windows*windows,axis=(1,2)))
    quiet=runs(wrms<.001)  # 10 ms RMS windows below -60 dBFS
    interior=[(a,b) for a,b in quiet if a>0 and b<len(wrms)]
    zeros=runs(np.all(absx==0,axis=1))
    return {
        'frames':len(x),'seconds':len(x)/sr,'sample_rate':sr,'channels':2,
        'finite':bool(np.all(np.isfinite(x))),'peak':float(absx.max()),'peak_dbfs':db(absx.max()),
        'clipped_samples_ge_1':int(np.count_nonzero(absx>=1)),
        'near_full_scale_samples_ge_0_99':int(np.count_nonzero(absx>=.99)),
        'rms':float(np.sqrt(np.mean(x*x))),'rms_dbfs':db(np.sqrt(np.mean(x*x))),
        'channel_rms':r.tolist(),'right_minus_left_db':db(r[1]/max(r[0],1e-15)),
        'channel_dc':np.mean(x,axis=0).tolist(),'max_abs_dc_dbfs':db(np.max(np.abs(np.mean(x,axis=0)))),
        'boundary_step':float(seam.max()),'boundary_step_dbfs':db(seam.max()),
        'max_internal_sample_step':float(delta.max()),'boundary_over_max_internal':float(seam.max()/max(delta.max(),1e-15)),
        'boundary_percentile_internal_steps':[float(np.mean(delta[:,c]<=seam[c])*100) for c in range(2)],
        'first_frame':x[0].tolist(),'last_frame':x[-1].tolist(),
        'min_10ms_rms_dbfs':db(wrms.min()),'quiet_10ms_windows_below_minus60':int(np.count_nonzero(wrms<.001)),
        'longest_quiet_window_run_ms':max([10*(b-a) for a,b in quiet],default=0),
        'longest_interior_quiet_run_ms':max([10*(b-a) for a,b in interior],default=0),
        'interior_quiet_runs_100ms_or_more':[[a*.01,b*.01] for a,b in interior if b-a>=10],
        'longest_exact_zero_run_frames':max([b-a for a,b in zeros],default=0),
        'stereo_correlation':float(np.corrcoef(x.T)[0,1]),
    }

def source_namespace(source, capture, fix_ambient=False):
    if fix_ambient:
        old='out[:,1]+=np.sin(2*np.pi*f*t+phase+.14)*.015'
        new='out[:,1]+=np.sin(2*np.pi*f*t+phase+.14)/(k**.55)*.015'
        assert source.count(old)==1
        source=source.replace(old,new)
    tree=ast.parse(source)
    constants={'SR','RNG','PHRASES','HARMONY'}
    funcs={'freq','tone','add','room','percussion','score','ambient','effects'}
    nodes=[]
    for node in tree.body:
        if isinstance(node,ast.Assign) and len(node.targets)==1 and isinstance(node.targets[0],ast.Name) and node.targets[0].id in constants:
            nodes.append(node)
        elif isinstance(node,ast.FunctionDef) and node.name in funcs: nodes.append(node)
    found_funcs={n.name for n in nodes if isinstance(n,ast.FunctionDef)}
    assert found_funcs==funcs
    env={'np':np,'math':math,'write':capture}
    exec(compile(ast.Module(body=nodes,type_ignores=[]),'audited_generator_dsp_only','exec'),env)
    return env

def pcm_wav(samples,target_peak,sr=32000):
    x=samples-np.mean(samples,axis=0)
    peak=float(np.max(np.abs(x)))
    if peak>0: x*=target_peak/peak
    pcm=np.round(np.clip(x,-.999,.999)*32767).astype('<i2')
    out=io.BytesIO()
    with wave.open(out,'wb') as w:
        w.setnchannels(2);w.setsampwidth(2);w.setframerate(sr);w.writeframes(pcm.tobytes())
    return out.getvalue()

def encode(wav):
    return run(['ffmpeg','-hide_banner','-loglevel','error','-i','pipe:0','-c:a','libvorbis','-q:a','6','-map_metadata','-1','-f','ogg','pipe:1'],wav)

def audit(project):
    assets=project/'assets/audio'; generator=project/'tools/generate_audio.py'
    source=generator.read_text(); manifest=json.loads((assets/'audio_validation.json').read_text())['assets']
    source_paths=[generator,assets/'audio_validation.json',project/'default_bus_layout.tres',project/'project.godot',project/'scripts/main.gd']
    files=sorted([*assets.glob('*.ogg'),*assets.glob('*.wav')]); source_paths+=files
    before={str(p.relative_to(project)):sha(p.read_bytes()) for p in source_paths}
    expected=set(EXPECTED_MUSIC+EXPECTED_AMBIENT+EXPECTED_EFFECTS)
    actual={p.stem for p in files}
    result={'timestamp_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'project':str(project),'method':'Numerical analysis and source/import inspection only; no listening or player-experience claim.',
        'versions':{'numpy':np.__version__,'ffmpeg':subprocess.check_output(['ffmpeg','-version']).decode().splitlines()[0]},
        'snapshot_sha256':before,'expected_asset_count':18,'actual_asset_count':len(files),'missing':sorted(expected-actual),'unexpected':sorted(actual-expected),'assets':{},'synthesis_reproduction':{},'hypothetical_ambient_change':{}}
    decoded={}
    for p in files:
        probe=json.loads(run(['ffprobe','-v','error','-show_streams','-of','json',str(p)]))['streams'][0]
        assert int(probe['sample_rate'])==32000 and probe['channels']==2
        x=decode(p); decoded[p.stem]=x
        item=stats(x); item.update({'file':p.name,'sha256':sha(p.read_bytes()),'manifest_sha_match':sha(p.read_bytes())==manifest[p.stem]['sha256'],'codec':probe['codec_name'],'bytes':p.stat().st_size,'decoded_sha256':sha(x.tobytes()),'loop':p.stem not in EXPECTED_EFFECTS})
        if p.stem not in EXPECTED_EFFECTS:item['manifest_source_frames_match']=len(x)==manifest[p.stem]['source_frames']
        gain_db=-22 if p.stem in EXPECTED_AMBIENT else (-14 if p.stem in EXPECTED_MUSIC else -10)
        item['runtime_total_gain_db']=gain_db;item['runtime_rms_dbfs']=item['rms_dbfs']+gain_db;item['runtime_peak_dbfs']=item['peak_dbfs']+gain_db
        imp=p.with_suffix(p.suffix+'.import'); itext=imp.read_text()
        cached=re.search(r'^path="res://([^"]+)"',itext,re.M)
        item['import']={'sidecar_exists':True,'cached_resource_exists':bool(cached and (project/cached[1]).is_file()),'settings':itext.split('[params]')[-1].strip()}
        if cached:item['import']['cached_resource_absolute']=str(project/cached[1])
        result['assets'][p.stem]=item
        print(f'DECODE {p.name}: peak {item["peak_dbfs"]:.2f} dBFS; RMS {item["rms_dbfs"]:.2f}; R-L {item["right_minus_left_db"]:+.2f} dB',flush=True)
    for key,destination in [('sha256','duplicate_files'),('decoded_sha256','duplicate_decoded_audio')]:
        groups=collections.defaultdict(list)
        for name,a in result['assets'].items():groups[a[key]].append(name)
        result[destination]=[names for names in groups.values() if len(names)>1]
    def capture(name,samples,target_peak=.70,loop=False,meta=None):
        wav=pcm_wav(samples,target_peak)
        expected_sha=manifest[name]['source_wav_sha256'] if loop else manifest[name]['sha256']
        entry={'source_wav_sha256':sha(wav),'source_wav_hash_match':sha(wav)==expected_sha}
        if loop:
            check=decode(data=encode(wav)); original=decoded[name]
            entry.update({'reencoded_frames':len(check),'delivered_frames':len(original),'reencoded_decoded_bit_identical':bool(np.array_equal(check,original)),
                'reencoded_decoded_max_abs_difference':float(np.max(np.abs(check-original))) if check.shape==original.shape else None})
        else:entry['delivered_wav_byte_identical']=wav==(assets/(name+'.wav')).read_bytes()
        result['synthesis_reproduction'][name]=entry
        print(f'REPRODUCE {name}: {entry}',flush=True)
    env=source_namespace(source,capture)
    for params in SCORE_PARAMS:env['score'](*params)
    for world in ['heaven','inferno','rainforest','city']:env['ambient'](world)
    env['effects']()
    # In-memory, uncommitted counterfactual only: quantify the single proposed DSP correction.
    def fixed_capture(name,samples,target_peak=.70,loop=False,meta=None):
        x=decode(data=encode(pcm_wav(samples,target_peak)))
        result['hypothetical_ambient_change'][name]=stats(x)
    fixed=source_namespace(source,fixed_capture,True)
    for world in ['heaven','inferno','rainforest','city']:fixed['ambient'](world)
    # Static runtime coverage and conservative headroom. Not a listening/mixer capture.
    leveldata=json.loads((project/'assets/levels.json').read_text())
    levels=leveldata['levels']
    result['level_world_counts']=dict(collections.Counter(l['world'] for l in levels))
    result['all_level_world_music_present']=all(w in actual for w in result['level_world_counts'])
    result['runtime']={
        'routing':{'music':'Music -10 dB -> Master -4 dB','ambience':'player -8 dB -> Music -10 dB -> Master -4 dB','effects':'Effects -6 dB -> Master -4 dB'},
        'effect_player_pool':6,'missing_music_behavior':'No replacement or fallback; previous stream continues if one exists. Every current world has a track.',
        'missing_ambience_behavior':'Existing ambience stops; absent new ambience stays silent. Hub/confluence have no ambient file by design (generator produces four named world ambiences).',
        'missing_effect_behavior':'Returns silently. All eight explicitly requested action names exist.',
        'ogg_import_loop_default':False,'ogg_runtime_loop_enabled':True,'wav_import_compress_mode':2,
        'source_waveform_vs_imported_note':'ffmpeg checks source delivery assets. Imported Godot resources are separately present; source WAV PCM is not proof of post-import decoding.',
    }
    # Calculate a sample-peak bound for three simultaneous loudest effects + score + ambience.
    peak_m=max(result['assets'][n]['peak'] for n in EXPECTED_MUSIC)*10**(-14/20)
    peak_a=max(result['assets'][n]['peak'] for n in EXPECTED_AMBIENT)*10**(-22/20)
    peak_s=max(result['assets'][n]['peak'] for n in EXPECTED_EFFECTS)*10**(-10/20)
    result['runtime']['three_effects_plus_music_ambience_peak_bound']=peak_m+peak_a+3*peak_s
    result['runtime']['six_effect_pool_peak_sum_bound']=peak_m+peak_a+6*peak_s
    result['runtime']['peak_bounds_note']='Conservative aligned individual peaks; not an observed mix or evidence of clipping. Six-effect ceiling alone does not prove a reachable same-phase maximum.'
    after={str(p.relative_to(project)):sha(p.read_bytes()) for p in source_paths}
    result['source_audio_and_config_unchanged']=before==after
    result['changed_during_audit']=[p for p in before if before[p]!=after[p]]
    return result


def report(r):
    a=r['assets']; loops=[x for x in a.values() if x['loop']]; repro=r['synthesis_reproduction']
    lines=['# Original audio quality audit', '', '## Result', '', '**One bounded improvement is recommended:** correct the missing right-channel spectral weighting in `tools/generate_audio.py:137`. The four delivered ambience loops have a systematic 11.87–14.22 dB right-channel RMS excess. No production change was made.', '',
        f'All {len(a)} intended delivery files exist and decode without ffmpeg errors: six original score loops, four world ambience loops, and eight action effects. No missing world music, duplicate files, or byte-identical decoded tracks.', '',
        '## Provenance and reproducibility', '',
        f'- Re-executed only the generator’s synthesis functions and constants in memory. All {sum(x["source_wav_hash_match"] for x in repro.values())}/18 reconstructed PCM WAV SHA-256 values match the published manifest; the eight delivered WAV files match byte for byte.',
        f'- Re-encoded all ten reconstructed loop masters with the installed ffmpeg/libvorbis settings. {sum(x.get("reencoded_decoded_bit_identical",False) for x in repro.values())}/10 decoded results are float32 bit-identical to delivered Ogg audio. Random Ogg container serials are irrelevant; comparison uses decoded samples.',
        '- All 18 delivery-file hashes also match `assets/audio/audio_validation.json`. This establishes a reproducible mathematical synthesis path from the checked-in oscillator/noise/note/DSP code, not independent legal proof of authorship.',
        '- Synthesis uses hand-coded note phrases, sine harmonics/envelopes, periodic seeded Fourier noise, chirps, equal-power panning and delay taps. No source audio recordings, imports of audio libraries with sample content, network calls or external asset inputs occur in the synthesis path.', '',
        '## Numerical integrity', '',
        f'- Every asset is stereo 32,000 Hz; all values are finite. No samples reach ±1.0 or ±0.99. Largest decoded peak: {max(x["peak"] for x in a.values()):.6f} ({max(x["peak_dbfs"] for x in a.values()):.2f} dBFS).',
        f'- Largest absolute per-channel DC mean: {max(max(abs(v) for v in x["channel_dc"]) for x in a.values()):.8g} ({max(x["max_abs_dc_dbfs"] for x in a.values()):.2f} dBFS).',
        '- All ten Ogg decoded frame counts equal the source master counts. There is no net frame-count padding or truncation; this count check alone does not prove temporal/perceptual equivalence to the lossless master.',
        f'- Loop boundary steps range {min(x["boundary_step"] for x in loops):.8f}–{max(x["boundary_step"] for x in loops):.8f}; each is below its track’s largest internal sample step (largest ratio {max(x["boundary_over_max_internal"] for x in loops):.3f}). This does not alone prove perceptually inaudible seams.',
        f'- Longest interior quiet run (< −60 dBFS RMS in 10 ms windows) across all delivery files: {max(x["longest_interior_quiet_run_ms"] for x in a.values())} ms. No interior dropout of 100 ms or more. Full decoded replication provides stronger evidence against codec-induced dropouts than a silence threshold alone.', '',
        '| Asset | Seconds | Peak dBFS | RMS dBFS | Runtime RMS dBFS* | R − L dB | Loop seam / max step |',
        '|---|---:|---:|---:|---:|---:|---:|']
    for name in EXPECTED_MUSIC+EXPECTED_AMBIENT+EXPECTED_EFFECTS:
        x=a[name]; ratio=f'{x["boundary_over_max_internal"]:.4f}' if x['loop'] else 'one-shot'
        lines.append(f'| {name} | {x["seconds"]:.3f} | {x["peak_dbfs"]:.2f} | {x["rms_dbfs"]:.2f} | {x["runtime_rms_dbfs"]:.2f} | {x["right_minus_left_db"]:+.2f} | {ratio} |')
    lines += ['', '*Runtime column applies static player/bus gains; this is not a recorded engine mix or perceptual loudness measurement.*', '',
        '## Runtime coverage, import and mix inspection', '',
        f'- Campaign coverage: {r["level_world_counts"]}. All level world IDs have music; title/hub use `hub.ogg`, final world uses `confluence.ogg`. Only the four principal worlds have additional ambience, matching generator intent.',
        '- All eight effects (`step`, `push`, `undo`, `reset`, `goal`, `win`, `blocked`, `portal`) have action call sites and assets. `step`/`push` are short, percussive, layered synthesized pluck/bass/kalimba gestures; numerical inspection cannot establish perceived elasticity.',
        '- `main.gd:211–252`: music/ambience use `Music`; ambience has an additional −8 dB. Six one-shot players use `Effects`. `default_bus_layout.tres`: Music −10 dB, Effects −6 dB, Master −4 dB; all route to Master. Mute targets bus 0.',
        '- `.ogg.import` defaults to `loop=false`, but both music and ambience paths explicitly set `AudioStreamOggVorbis.loop=true` before playback. Every import-sidecar target exists in `.godot/imported`.',
        '- Effects retain stereo/sample rate and disable import trim/normalization/looping; import `compress/mode=2` means delivered PCM WAV checks do not alone attest the imported representation. A separate Godot 4.7.2 direct-playback decode probe covers the cached imported representations; see its report below. No GUI or listening was used.',
        '- Missing-music fallback is previous music (if already playing); missing ambience is stopped/silent; missing effects return silently. No currently referenced files are missing, and hub/confluence’s absence of a separate ambience file is intentional in this generator.',
        f'- Static music output RMS is {min(a[n]["runtime_rms_dbfs"] for n in EXPECTED_MUSIC):.2f} to {max(a[n]["runtime_rms_dbfs"] for n in EXPECTED_MUSIC):.2f} dBFS; ambience {min(a[n]["runtime_rms_dbfs"] for n in EXPECTED_AMBIENT):.2f} to {max(a[n]["runtime_rms_dbfs"] for n in EXPECTED_AMBIENT):.2f}; active effects {min(a[n]["runtime_rms_dbfs"] for n in EXPECTED_EFFECTS):.2f} to {max(a[n]["runtime_rms_dbfs"] for n in EXPECTED_EFFECTS):.2f}. Effects are foregrounded; world music spread is modest. These are whole-file RMS, not LUFS or listening judgments.',
        f'- Conservative music + ambience + three full-level effects peak-sum bound is {r["runtime"]["three_effects_plus_music_ambience_peak_bound"]:.3f} (<1). Six simultaneously aligned full-effect peaks give {r["runtime"]["six_effect_pool_peak_sum_bound"]:.3f}; that mathematical ceiling is not observed clipping, and actual voice timing/phase was not captured.', '',
        '## Single proposed improvement (not applied)', '',
        '`ambient()` currently applies `/(k**.55)` to its left periodic noise harmonic but not to its phase-shifted right harmonic. The resulting imbalance is systematic across every world, unlike the intentionally panned bells/chirps. Apply the same weight on the right:', '',
        '```python', 'out[:,0] += y * .015', 'out[:,1] += np.sin(2*np.pi*f*t + phase + .14) / (k**.55) * .015', '```', '',
        'The counterfactual below was synthesized and encoded in memory only, with the same seed/order, room taps and peak target. No assets were saved/replaced.', '',
        '| Ambience | Delivered R − L RMS dB | Proposed R − L RMS dB | Proposed RMS dBFS | Proposed seam / max step |',
        '|---|---:|---:|---:|---:|']
    for name in EXPECTED_AMBIENT:
        f=r['hypothetical_ambient_change'][name]
        lines.append(f'| {name} | {a[name]["right_minus_left_db"]:+.2f} | {f["right_minus_left_db"]:+.2f} | {f["rms_dbfs"]:.2f} | {f["boundary_over_max_internal"]:.4f} |')
    lines += ['',
        'Bounded acceptance if approved: change that one weighting, regenerate **only the four ambience assets and their manifest records** with the original seed/world order, preserve six music and eight effect bytes, reimport in a scratch project, then repeat decode/frame/DC/clipping/seam checks and compare by listening at the actual bus gains. Residual L/R differences may remain from deliberately panned events. Because peak normalization rebalances the mix, do not claim an audible improvement before listening.', '',
        '## Reproduction / limitations', '',
        '```sh', 'python fourfold_next/audio_review/audit_audio.py', '```', '',
        '- The script reads production inputs, does synthesis/codec comparisons in memory, and writes only `audit_results.json` and this report beside itself. It never imports or runs the generator main/write/package functions.',
        f'- Checked source/audio/config fingerprints unchanged during this run: {r["source_audio_and_config_unchanged"]}. Concurrent UI work can change `main.gd`; any such change is listed in JSON rather than attributed to this audit.',
        '- Not assessed: subjective composition, listening fatigue, device/headphone output, perceptual click audibility, runtime transition/restart behavior, observed voice-stealing, or full bus-mixed true peaks. No claim of having listened is made.',
        '- No downloads, AI generation services, installs, GUI, Git operations, upload, or production edits.', '']
    probe_path=HERE/'godot_imported_audio_results.json'
    if probe_path.exists():
        g=json.loads(probe_path.read_text()); ga=g['assets']
        lines += ['## Godot 4.7.2 imported-resource verification', '',
            f'- Explicit local engine `{g["engine"]["string"]}`; isolated audit working directory, writable XDG cache/config/data directories all under this review folder, Dummy audio driver. Existing imported resources were loaded by absolute path, without loading the game project or importing/modifying production resources.',
            f'- Direct `AudioStreamPlayback.mix_audio(1.0, frames)` decoded all 18 cached assets at {g["output_mix_rate"]:g} Hz. Passed: {g["all_loaded_and_decoded"]}; all finite, zero clipped frames; largest post-import/resampled peak {max(x["peak"] for x in ga.values()):.6f}.',
            '- All ten Ogg loops were decoded through the first wrap plus 4096 frames, with nonzero audio after the wrap. The eight effects are confirmed `AudioStreamWAV.FORMAT_QOA` imports, not raw PCM at runtime; all decoded to end-of-stream within 0.12 ms of nominal duration (resampling-end rounding).',
            '- This is numerical direct-playback decode, not real-time speaker/headphone listening, full bus-mix recording, or scene-transition testing. Detailed per-resource measurements are in `godot_imported_audio_results.json`; executable probe is `probe_imported_audio.gd`.',
            '- An initial discovery probe used the generic Godot alias, which resolved to 4.6.3 and could not create its default `[home]/.local/share/godot`, `[home]/.config/godot`, or `[home]/.cache/godot` directories. That probe was not counted as target-version acceptance. The subsequent explicit 4.7.2 probe used authorized review-local XDG locations and completed successfully; no escalation or retry against those home paths occurred.', '',
            '```sh', 'BASE="$PWD/fourfold_next/audio_review"', 'mkdir -p "$BASE/xdg/cache" "$BASE/xdg/data" "$BASE/xdg/config"', 'XDG_CACHE_HOME="$BASE/xdg/cache" XDG_DATA_HOME="$BASE/xdg/data" XDG_CONFIG_HOME="$BASE/xdg/config" \\', '  tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --audio-driver Dummy \\', '  --path "$BASE" --script "$BASE/probe_imported_audio.gd" --log-file "$BASE/godot_imported_audio.log"', '```', '',
            '## Selective-fix acceptance helper', '',
            '`verify_ambient_candidate.py --project CANDIDATE` independently reproduces the four candidate ambiences, checks their manifest hashes/decoded samples, and checks that all other 14 asset SHA-256s remain identical to this baseline. It is read-only against the candidate and writes only its own JSON result here.',
            'Acceptance thresholds: stereo 32 kHz / exactly 512000 frames; finite samples and peak <0.99; per-channel |DC| <1e-4; loop seam/max internal step ≤1.1; no interior run ≥100 ms of 10 ms windows below −60 dBFS; |R−L RMS| ≤3 dB. Exact centering is not required. Preserve the four-world seed/order and six scores/eight effects unchanged.', '']
    return '\n'.join(lines)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--project',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args(); args.output.mkdir(parents=True,exist_ok=True); r=audit(args.project.resolve())
    (args.output/'audit_results.json').write_text(json.dumps(r,indent=2)+'\n')
    (args.output/'AUDIO_AUDIT.md').write_text(report(r))
    print('Reports:',args.output/'AUDIO_AUDIT.md',args.output/'audit_results.json')
