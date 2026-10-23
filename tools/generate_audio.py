#!/usr/bin/env python3
"""Original deterministic Fourfold Atelier score and foley. No source recordings.
Requires Python 3 + NumPy + ffmpeg to regenerate; delivered audio has no runtime dependency.
All notes, voicings, instrumentation and DSP in this file were authored for this game.
"""
from pathlib import Path
import json, math, wave, hashlib, subprocess, shutil, argparse
import numpy as np

SR = 32000
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'audio'
OUT.mkdir(parents=True, exist_ok=True)
RNG = np.random.default_rng(48017)
STATS = {}

def freq(midi): return 440.0 * 2 ** ((midi - 69) / 12)

def tone(midi, seconds, kind='pluck', velocity=1):
    n = max(8, int(seconds * SR)); t = np.arange(n) / SR; f = freq(midi)
    attack = 1 - np.exp(-t / .008)
    if kind in ('pluck', 'kalimba'):
        y = sum((1 / h**1.65) * np.sin(2*np.pi*f*h*t) * np.exp(-t*(2.1+h*.48)) for h in range(1, 7))
        if kind == 'kalimba': y += .10*np.sin(2*np.pi*f*3.96*t)*np.exp(-t*15)
        y *= attack
    elif kind == 'bell':
        y = (np.sin(2*np.pi*f*t)*np.exp(-t*1.7) + .24*np.sin(2*np.pi*f*2.01*t)*np.exp(-t*2.9) + .07*np.sin(2*np.pi*f*4.02*t)*np.exp(-t*5.0)) * attack
    elif kind == 'keys':
        mod = .9*np.sin(2*np.pi*f*2*t)*np.exp(-t*5)
        y = (np.sin(2*np.pi*f*t+mod) + .12*np.sin(2*np.pi*f*3*t)) * np.exp(-t*2.0)*attack
    elif kind == 'flute':
        env = np.minimum(t/.10, 1)*np.minimum((seconds-t)/.20, 1)
        vib = .002*np.sin(2*np.pi*4.8*t)
        y = (np.sin(2*np.pi*f*t + vib) + .10*np.sin(2*np.pi*f*2*t)) * env * .7
    elif kind == 'pad':
        env = np.minimum(t/.35, 1)*np.minimum((seconds-t)/.55, 1)
        y = (np.sin(2*np.pi*f*t) + .22*np.sin(2*np.pi*f*2*t) + .09*np.sin(2*np.pi*f*3*t)) * env *.65
    elif kind == 'bass':
        y = (np.sin(2*np.pi*f*t) + .22*np.sin(2*np.pi*f*2*t)) * np.exp(-t*3.5)*attack
    else: raise ValueError(kind)
    # A short tail window removes arbitrary oscillator cut-offs.
    end = min(int(.04*SR), n//3); y[-end:] *= np.linspace(1,0,end)**2
    return y * velocity

def add(buf, mono, when, gain=.1, pan=0, circular=True):
    # Equal-power stereo, circular tail placement allows genuine seamless loops.
    i = int(round(when*SR)); p = np.clip(pan,-1,1)
    l,r = math.cos((p+1)*math.pi/4), math.sin((p+1)*math.pi/4)
    if circular:
        idx=(i+np.arange(len(mono)))%len(buf)
        np.add.at(buf[:,0],idx,mono*gain*l); np.add.at(buf[:,1],idx,mono*gain*r)
    else:
        end=min(i+len(mono),len(buf)); count=max(0,end-i)
        if count: buf[i:end] += mono[:count,None]*np.array([l,r])*gain

def room(buf, loop=True):
    original=buf.copy()
    for delay,gain in [(.113,.14),(.227,.105),(.337,.065),(.479,.04)]:
        shift=int(delay*SR)
        if loop: buf += np.roll(original[:,::-1],shift,axis=0)*gain
        else: buf[shift:] += original[:-shift,::-1]*gain
    return buf

def write(name, samples, target_peak=.70, loop=False, meta=None):
    samples=samples-np.mean(samples,axis=0)
    peak=float(np.max(np.abs(samples)))
    if peak>0: samples *= target_peak/peak
    data=np.round(np.clip(samples,-.999,.999)*32767).astype('<i2')
    with wave.open(str(OUT/(name+'.wav')),'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())
    # Boundary step must be comparable with normal sample-to-sample steps,
    # rather than a whole-track fade being mistaken for a seamless loop.
    differences=np.abs(np.diff(samples,axis=0))
    seam=float(np.max(np.abs(samples[0]-samples[-1])))
    STATS[name]={'seconds':round(len(data)/SR,5),'sample_rate':SR,'channels':2,
        'peak':round(float(np.max(np.abs(samples))),5),'rms':round(float(np.sqrt(np.mean(samples*samples))),5),
        'clipped_samples':int(np.sum(np.abs(data)>=32766)), 'loop':loop,
        'boundary_step':round(seam,7), 'max_internal_sample_step':round(float(differences.max()),7),
        'loop_boundary_ratio':round(seam/max(float(differences.max()),1e-9),4), **(meta or {})}
    print(name, STATS[name])

# A composed five-note theme: D E F# A B. Four statements are transformed,
# answered and given breathing space; these are not random note selections.
PHRASES = [
 [(0,0,.65),(1,2,.65),(2,4,.85),(3,7,.65)],
 [(0,9,1.25),(2,7,.7),(3,4,.65)],
 [(0,2,.7),(1.5,4,.7),(2.5,0,1.2)],
 [(0,7,1.1),(2,2,1.5)],
 [(0,4,.8),(1,7,.8),(2,9,1.5)],
 [(0,7,.7),(1,4,.7),(2.5,2,1.0)],
 [(0,0,1.5),(2,4,.8),(3,2,.7)],
 [(0,0,2.6)],
]
HARMONY=[(50,[0,4,7,14]),(47,[0,3,7,10]),(43,[0,4,7,14]),(45,[0,5,7,14])]

def percussion(seconds, kind):
    t=np.arange(int(seconds*SR))/SR
    if kind=='rim': return np.sin(2*np.pi*730*t)*np.exp(-t*70)+.25*np.sin(2*np.pi*1461*t)*np.exp(-t*100)
    if kind=='kick': return np.sin(2*np.pi*(55*t+3*(1-np.exp(-t*35))))*np.exp(-t*20)
    return (np.sin(2*np.pi*2400*t)+.3*np.sin(2*np.pi*3490*t))*np.exp(-t*110)

def score(name, bpm, instrument, octave=0):
    beat=60/bpm; duration=64*beat; out=np.zeros((round(duration*SR),2),dtype=np.float64)
    for bar in range(16):
        base=bar*4*beat; root,chord=HARMONY[bar%4]
        for j,interval in enumerate(chord):
            add(out,tone(root+12+interval,beat*4.4,'pad'),base,gain=.035,pan=(-.65+j*.4))
        for b in (0,2): add(out,tone(root,beat*1.5,'bass'),base+b*beat,gain=.105 if name=='inferno' else .075,pan=0)
        for j,b in enumerate([.5,1.5,2.5,3.5]):
            key=root+12+chord[j%4]
            add(out,tone(key,beat*1.7,'keys' if name=='city' else 'pluck'),base+b*beat,gain=.055,pan=(-.4 if j%2==0 else .4))
        phrase=PHRASES[bar%8]
        for idx,(b,degree,length) in enumerate(phrase):
            # Softer first statement; second phrase grows but does not become louder by much.
            pitch=62+degree+octave
            if name=='city' and b==1: b=1.25
            add(out,tone(pitch,max(.5,length*beat+.5),instrument,1),base+b*beat,.18 if bar<8 else .195,pan=.12)
            if name=='confluence' and bar>=8:
                add(out,tone(pitch+12,1.5,'bell'),base+b*beat,.035,pan=-.35)
        if name in ('inferno','city','confluence'):
            for b in (0,2): add(out,percussion(.22,'kick'),base+b*beat,.065)
            for b in (1,3): add(out,percussion(.12,'rim'),base+b*beat,.045,pan=-.35)
            if name=='city':
                for b in (.5,1.5,2.5,3.5): add(out,percussion(.08,'tick'),base+b*beat,.014,pan=.45)
        if name=='rainforest' and bar%2==1:
            add(out,tone(81,beat*1.5,'flute'),base+2.5*beat,.05,pan=-.55)
    room(out)
    write(name,out,.62,True,{'bpm':bpm,'bars':16,'instrument':instrument,'composition':'Original five-note D E F# A B theme; 16-bar arrangement'})


def ambient(name):
    duration=16; n=int(duration*SR); t=np.arange(n)/SR; out=np.zeros((n,2))
    # Periodic sparse Fourier noise is exactly periodic at the loop interval.
    for k in range(640,6400,97):
        phase=RNG.uniform(0,2*np.pi); f=k/duration
        y=np.sin(2*np.pi*f*t+phase)/(k**.55)
        out[:,0]+=y*.015; out[:,1]+=np.sin(2*np.pi*f*t+phase+.14)*.015
    if name=='heaven':
        for sec,midi in [(2,86),(7.5,81),(11,88)]: add(out,tone(midi,3,'bell'),sec,.08,pan=math.sin(sec))
    elif name=='inferno':
        for sec in np.arange(.7,16,1.73):
            add(out,percussion(.18,'rim'),float(sec),.018,pan=math.sin(sec*2))
        for k in (640,960,1280):
            out += np.sin(2*np.pi*k/duration*t)[:,None]*.008
    elif name=='rainforest':
        for sec,start in [(1,1700),(4.1,1400),(9,1900),(13,1500)]:
            tt=np.arange(int(.38*SR))/SR
            chirp=np.sin(2*np.pi*(start*tt+420*tt*tt))*np.sin(np.pi*tt/.38)**2
            add(out,chirp,sec,.035,pan=math.sin(sec))
        # Tiny rain-droplet resonances, not sampled field recordings.
        for sec in np.arange(.4,16,.93): add(out,tone(87+(int(sec)%5),.16,'pluck'),float(sec),.013,pan=math.cos(sec))
    elif name=='city':
        for k in (960,1440,1920): out += np.sin(2*np.pi*k/duration*t)[:,None]*.012
        for sec in (3,11): add(out,tone(74,1.2,'bell'),sec,.04,pan=-.4)
    room(out)
    write(name+'_ambient',out,.15,True,{'source':'Entirely synthesized ambience; no field recordings'})


def effects():
    definitions={
        'step':(.18,[(0,62,.11,'pluck',.5),(0,43,.10,'bass',.35)]),
        'push':(.34,[(0,43,.28,'bass',.65),(.025,62,.22,'kalimba',.5)]),
        'undo':(.45,[(0,76,.20,'keys',.5),(.08,69,.25,'keys',.4)]),
        'reset':(.75,[(0,74,.30,'bell',.4),(.12,69,.3,'bell',.4),(.24,62,.35,'bell',.5)]),
        'goal':(1.1,[(0,74,.8,'bell',.5),(.08,78,.8,'bell',.35),(.16,81,.8,'bell',.4)]),
        'win':(2.6,[(0,74,1.3,'bell',.5),(.18,76,1.3,'bell',.45),(.36,78,1.3,'bell',.5),(.54,81,1.3,'bell',.5),(.8,86,1.7,'bell',.6),(1,62,1.3,'pad',.3)]),
        'blocked':(.22,[(0,50,.16,'keys',.5)]),
        'portal':(.8,[(0,69,.6,'keys',.45),(.09,76,.6,'bell',.4),(.18,81,.5,'bell',.3)]),
    }
    for name,(seconds,notes) in definitions.items():
        out=np.zeros((int(seconds*SR),2))
        for start,midi,length,kind,vel in notes: add(out,tone(midi,length,kind),start,vel,0,False)
        room(out,False)
        # Effect tail truly fades to silence, unlike the circular music tracks.
        tail=min(int(.06*SR),len(out)); out[-tail:] *= np.linspace(1,0,tail)[:,None]**2
        write(name,out,.45 if name in ('step','blocked') else .65,False)

def package_audio(master_dir):
    """Encode our own loop masters, retaining the lossless sources outside the game."""
    master_dir.mkdir(parents=True, exist_ok=True)
    for name, values in STATS.items():
        wav = OUT / (name + '.wav')
        if not values['loop']:
            values['delivery_file'] = name + '.wav'
            values['delivery_format'] = 'PCM16 WAV'
            continue
        source = wav if wav.exists() else master_dir / wav.name
        dest = OUT / (name + '.ogg')
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(source),
            '-c:a', 'libvorbis', '-q:a', '6', '-map_metadata', '-1', str(dest)], check=True)
        decoded = subprocess.check_output(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-i',
            str(dest), '-f', 'f32le', '-acodec', 'pcm_f32le', '-'])
        samples = np.frombuffer(decoded, dtype='<f4').reshape(-1, 2)
        with wave.open(str(source)) as w:
            expected_frames = w.getnframes()
            rate = w.getframerate()
        seam = float(np.max(np.abs(samples[0] - samples[-1])))
        maximum_step = float(np.max(np.abs(np.diff(samples, axis=0))))
        peak = float(np.max(np.abs(samples)))
        assert len(samples) == expected_frames, f'Codec sample-length mismatch: {name}'
        assert peak < .99, f'Codec clipping: {name}'
        values['source_wav_sha256'] = hashlib.sha256(source.read_bytes()).hexdigest()
        values['sha256'] = hashlib.sha256(dest.read_bytes()).hexdigest()
        values['delivery_file'] = dest.name
        values['delivery_format'] = 'Ogg Vorbis quality 6 (lossy encoding of original synthesis)'
        values['delivery_bytes'] = dest.stat().st_size
        values['decoded_frames'] = len(samples)
        values['source_frames'] = expected_frames
        values['exact_duration_preserved'] = True
        values['decoded_seconds'] = len(samples) / rate
        values['decoded_peak'] = peak
        values['decoded_clipped_samples'] = int(np.count_nonzero(np.abs(samples) >= 1))
        values['decoded_boundary_step'] = seam
        values['decoded_max_internal_step'] = maximum_step
        values['decoded_boundary_ratio'] = seam / max(maximum_step, 1e-9)
        print('PACKAGED', name, dest.stat().st_size, 'bytes; exact frames', len(samples), 'peak', peak)
        if wav.exists(): shutil.move(str(wav), str(master_dir / wav.name))
        sidecar = OUT / (name + '.wav.import')
        if sidecar.exists(): shutil.move(str(sidecar), str(master_dir / sidecar.name))
    (OUT/'audio_validation.json').write_text(json.dumps({'generated_by':'tools/generate_audio.py',
        'seed':48017, 'codec_note':'Lossy Vorbis; all decoded durations checked against original WAV sample count. No inserted/truncated samples. Numerical checks do not replace subjective listening.',
        'assets':STATS}, ensure_ascii=False, indent=2)+'\n')
    (OUT/'README.txt').write_text('Original synthesized score and foley for Loom of Four Horizons.\n'
        'All waveforms, melodies and sound design are generated by tools/generate_audio.py.\n'
        'No sampled instruments, downloaded music, sound effects, recordings, or AI audio assets.\n'
        'Delivery: six music + four ambient loops as stereo 32000 Hz Ogg Vorbis quality 6; eight one-shot effects as PCM16 WAV.\n'
        'Music tracks are 16 bars, circularly rendered including reverb tails. Godot AudioStreamOggVorbis.loop=true.\n'
        'Vorbis is lossy. Decode validation preserves exact source frame counts; no added silence or clipped samples. Boundary statistics are numerical, not a claim of listening approval.\n'
        'Regenerate: python tools/generate_audio.py (requires NumPy and ffmpeg). Lossless loop masters are retained outside the game in ../fourfold_qa/audio_masters by default.\n'
        'Use --master-dir PATH for another archive location, or --package-only to encode existing masters without recomposing.\n')

if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--package-only', action='store_true')
    parser.add_argument('--master-dir', type=Path, default=ROOT.parent/'fourfold_qa'/'audio_masters')
    args = parser.parse_args()
    if args.package_only:
        STATS.update(json.loads((OUT/'audio_validation.json').read_text())['assets'])
    else:
        for params in [('hub',84,'bell',0),('heaven',80,'bell',12),('inferno',108,'kalimba',0),('rainforest',92,'kalimba',0),('city',104,'keys',0),('confluence',96,'pluck',0)]: score(*params)
        for world in ['heaven','inferno','rainforest','city']: ambient(world)
        effects()
        for name, values in STATS.items():
            assert values['clipped_samples'] == 0 and values['rms'] > .005
            if values['loop']: assert values['loop_boundary_ratio'] <= 1.1, f'Loop discontinuity: {name}'
            values['sha256'] = hashlib.sha256((OUT/(name+'.wav')).read_bytes()).hexdigest()
    assert len(STATS) == 18
    package_audio(args.master_dir)
