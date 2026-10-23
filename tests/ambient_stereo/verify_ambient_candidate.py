#!/usr/bin/env python3
"""Read-only acceptance of the selective ambience correction against saved baseline.
Run: python fourfold_next/audio_review/verify_ambient_candidate.py --project CANDIDATE
No project files are changed; --output is required. Baseline is historical/audit_results.json.
"""
import argparse, json, math
from pathlib import Path
import audit_audio as audit

parser=audit.argparse.ArgumentParser()
parser.add_argument('--project',required=True,type=Path)
parser.add_argument('--output',required=True,type=Path)
args=parser.parse_args();project=args.project.resolve()
baseline=json.loads((audit.HERE/'historical/audit_results.json').read_text())
manifest=json.loads((project/'assets/audio/audio_validation.json').read_text())['assets']
source=(project/'tools/generate_audio.py').read_text()
old='out[:,1]+=np.sin(2*np.pi*f*t+phase+.14)*.015'
corrected='out[:,1]+=np.sin(2*np.pi*f*t+phase+.14)/(k**.55)*.015'
result={'project':str(project),'scope':'Read-only selective ambience regression; no subjective listening claim',
        'corrected_formula_present':corrected in source and old not in source,'unchanged_other_assets':{},'ambiences':{}}
for name in audit.EXPECTED_MUSIC+audit.EXPECTED_EFFECTS:
    result['unchanged_other_assets'][name]=audit.sha((project/'assets/audio'/baseline['assets'][name]['file']).read_bytes())==baseline['assets'][name]['sha256']
def capture(name,samples,target_peak=.70,loop=False,meta=None):
    wav=audit.pcm_wav(samples,target_peak)
    encoded=audit.encode(wav); expected=audit.decode(data=encoded)
    path=project/'assets/audio'/(name+'.ogg');x=audit.decode(path);s=audit.stats(x)
    probe=json.loads(audit.run(['ffprobe','-v','error','-show_streams','-of','json',str(path)]))['streams'][0]
    s['codec_metadata']={'codec':probe['codec_name'],'sample_rate':int(probe['sample_rate']),'channels':probe['channels']}
    s['delivery_sha_matches_manifest']=audit.sha(path.read_bytes())==manifest[name]['sha256']
    s['source_wav_sha_matches_manifest']=audit.sha(wav)==manifest[name]['source_wav_sha256']
    s['decoded_equals_corrected_synthesis']=bool(audit.np.array_equal(x,expected))
    s['same_frames_as_baseline']=s['frames']==baseline['assets'][name]['frames']==512000
    s['checks']={
        'duration_16s_stereo_32k':s['same_frames_as_baseline'] and s['codec_metadata']=={'codec':'vorbis','sample_rate':32000,'channels':2},
        'finite_and_peak_below_point99':s['finite'] and s['peak']<.99,
        'dc_below_1e_minus4':max(abs(v) for v in s['channel_dc'])<1e-4,
        'seam_ratio_below_1point1':s['boundary_over_max_internal']<=1.1,
        'no_100ms_interior_silence':not s['interior_quiet_runs_100ms_or_more'],
        'stereo_rms_imbalance_within_3db':abs(s['right_minus_left_db'])<=3,
        'manifest_and_reproduction':s['delivery_sha_matches_manifest'] and s['source_wav_sha_matches_manifest'] and s['decoded_equals_corrected_synthesis'],
    }
    result['ambiences'][name]=s
    print(name, 'R-L dB',s['right_minus_left_db'],'all checks',all(s['checks'].values()))
env=audit.source_namespace(source,capture)
for world in ['heaven','inferno','rainforest','city']:env['ambient'](world)
result['passed']=result['corrected_formula_present'] and all(result['unchanged_other_assets'].values()) and all(all(x['checks'].values()) for x in result['ambiences'].values())
args.output.write_text(json.dumps(result,indent=2)+'\n')
print('PASS' if result['passed'] else 'FAIL',args.output)
raise SystemExit(0 if result['passed'] else 1)
