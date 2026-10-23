# Original audio quality audit

## Result

**One bounded improvement is recommended:** correct the missing right-channel spectral weighting in `tools/generate_audio.py:137`. The four delivered ambience loops have a systematic 11.87–14.22 dB right-channel RMS excess. No production change was made.

All 18 intended delivery files exist and decode without ffmpeg errors: six original score loops, four world ambience loops, and eight action effects. No missing world music, duplicate files, or byte-identical decoded tracks.

## Provenance and reproducibility

- Re-executed only the generator’s synthesis functions and constants in memory. All 18/18 reconstructed PCM WAV SHA-256 values match the published manifest; the eight delivered WAV files match byte for byte.
- Re-encoded all ten reconstructed loop masters with the installed ffmpeg/libvorbis settings. 10/10 decoded results are float32 bit-identical to delivered Ogg audio. Random Ogg container serials are irrelevant; comparison uses decoded samples.
- All 18 delivery-file hashes also match `assets/audio/audio_validation.json`. This establishes a reproducible mathematical synthesis path from the checked-in oscillator/noise/note/DSP code, not independent legal proof of authorship.
- Synthesis uses hand-coded note phrases, sine harmonics/envelopes, periodic seeded Fourier noise, chirps, equal-power panning and delay taps. No source audio recordings, imports of audio libraries with sample content, network calls or external asset inputs occur in the synthesis path.

## Numerical integrity

- Every asset is stereo 32,000 Hz; all values are finite. No samples reach ±1.0 or ±0.99. Largest decoded peak: 0.649994 (-3.74 dBFS).
- Largest absolute per-channel DC mean: 3.5272561e-05 (-89.05 dBFS).
- All ten Ogg decoded frame counts equal the source master counts. There is no net frame-count padding or truncation; this count check alone does not prove temporal/perceptual equivalence to the lossless master.
- Loop boundary steps range 0.00015228–0.01179727; each is below its track’s largest internal sample step (largest ratio 0.680). This does not alone prove perceptually inaudible seams.
- Longest interior quiet run (< −60 dBFS RMS in 10 ms windows) across all delivery files: 0 ms. No interior dropout of 100 ms or more. Full decoded replication provides stronger evidence against codec-induced dropouts than a silence threshold alone.

| Asset | Seconds | Peak dBFS | RMS dBFS | Runtime RMS dBFS* | R − L dB | Loop seam / max step |
|---|---:|---:|---:|---:|---:|---:|
| hub | 45.714 | -4.02 | -17.00 | -31.00 | +0.85 | 0.0300 |
| heaven | 48.000 | -4.07 | -18.39 | -32.39 | +1.18 | 0.0357 |
| inferno | 35.556 | -4.08 | -17.49 | -31.49 | +0.84 | 0.0214 |
| rainforest | 41.739 | -4.11 | -17.04 | -31.04 | +0.80 | 0.0906 |
| city | 36.923 | -4.13 | -17.38 | -31.38 | +0.94 | 0.0960 |
| confluence | 40.000 | -4.17 | -18.00 | -32.00 | +0.66 | 0.0153 |
| heaven_ambient | 16.000 | -16.53 | -32.09 | -54.09 | +13.46 | 0.0098 |
| inferno_ambient | 16.000 | -16.25 | -29.24 | -51.24 | +12.85 | 0.6800 |
| rainforest_ambient | 16.000 | -16.41 | -29.76 | -51.76 | +14.22 | 0.1019 |
| city_ambient | 16.000 | -16.45 | -30.83 | -52.83 | +11.87 | 0.0420 |
| step | 0.180 | -6.94 | -15.42 | -25.42 | +0.00 | one-shot |
| push | 0.340 | -3.74 | -13.21 | -23.21 | +0.00 | one-shot |
| undo | 0.450 | -3.74 | -12.93 | -22.93 | +0.00 | one-shot |
| reset | 0.750 | -3.74 | -14.85 | -24.85 | +0.00 | one-shot |
| goal | 1.100 | -3.74 | -16.79 | -26.79 | +0.00 | one-shot |
| win | 2.600 | -3.74 | -17.27 | -27.27 | +0.00 | one-shot |
| blocked | 0.220 | -6.94 | -12.03 | -22.03 | +0.00 | one-shot |
| portal | 0.800 | -3.74 | -14.05 | -24.05 | +0.00 | one-shot |

*Runtime column applies static player/bus gains; this is not a recorded engine mix or perceptual loudness measurement.*

## Runtime coverage, import and mix inspection

- Campaign coverage: {'heaven': 50, 'inferno': 50, 'rainforest': 50, 'city': 50, 'confluence': 4}. All level world IDs have music; title/hub use `hub.ogg`, final world uses `confluence.ogg`. Only the four principal worlds have additional ambience, matching generator intent.
- All eight effects (`step`, `push`, `undo`, `reset`, `goal`, `win`, `blocked`, `portal`) have action call sites and assets. `step`/`push` are short, percussive, layered synthesized pluck/bass/kalimba gestures; numerical inspection cannot establish perceived elasticity.
- `main.gd:211–252`: music/ambience use `Music`; ambience has an additional −8 dB. Six one-shot players use `Effects`. `default_bus_layout.tres`: Music −10 dB, Effects −6 dB, Master −4 dB; all route to Master. Mute targets bus 0.
- `.ogg.import` defaults to `loop=false`, but both music and ambience paths explicitly set `AudioStreamOggVorbis.loop=true` before playback. Every import-sidecar target exists in `.godot/imported`.
- Effects retain stereo/sample rate and disable import trim/normalization/looping; import `compress/mode=2` means delivered PCM WAV checks do not alone attest the imported representation. A separate Godot 4.7.2 direct-playback decode probe covers the cached imported representations; see its report below. No GUI or listening was used.
- Missing-music fallback is previous music (if already playing); missing ambience is stopped/silent; missing effects return silently. No currently referenced files are missing, and hub/confluence’s absence of a separate ambience file is intentional in this generator.
- Static music output RMS is -32.39 to -31.00 dBFS; ambience -54.09 to -51.24; active effects -27.27 to -22.03. Effects are foregrounded; world music spread is modest. These are whole-file RMS, not LUFS or listening judgments.
- Conservative music + ambience + three full-level effects peak-sum bound is 0.754 (<1). Six simultaneously aligned full-effect peaks give 1.371; that mathematical ceiling is not observed clipping, and actual voice timing/phase was not captured.

## Single proposed improvement (not applied)

`ambient()` currently applies `/(k**.55)` to its left periodic noise harmonic but not to its phase-shifted right harmonic. The resulting imbalance is systematic across every world, unlike the intentionally panned bells/chirps. Apply the same weight on the right:

```python
out[:,0] += y * .015
out[:,1] += np.sin(2*np.pi*f*t + phase + .14) / (k**.55) * .015
```

The counterfactual below was synthesized and encoded in memory only, with the same seed/order, room taps and peak target. No assets were saved/replaced.

| Ambience | Delivered R − L RMS dB | Proposed R − L RMS dB | Proposed RMS dBFS | Proposed seam / max step |
|---|---:|---:|---:|---:|
| heaven_ambient | +13.46 | +2.51 | -36.41 | 0.0029 |
| inferno_ambient | +12.85 | -0.02 | -27.49 | 0.2855 |
| rainforest_ambient | +14.22 | +1.67 | -36.13 | 0.0054 |
| city_ambient | +11.87 | -0.35 | -30.30 | 0.0486 |

Bounded acceptance if approved: change that one weighting, regenerate **only the four ambience assets and their manifest records** with the original seed/world order, preserve six music and eight effect bytes, reimport in a scratch project, then repeat decode/frame/DC/clipping/seam checks and compare by listening at the actual bus gains. Residual L/R differences may remain from deliberately panned events. Because peak normalization rebalances the mix, do not claim an audible improvement before listening.

## Reproduction / limitations

```sh
python fourfold_next/audio_review/audit_audio.py
```

- The script reads production inputs, does synthesis/codec comparisons in memory, and writes only `audit_results.json` and this report beside itself. It never imports or runs the generator main/write/package functions.
- Checked source/audio/config fingerprints unchanged during this run: True. Concurrent UI work can change `main.gd`; any such change is listed in JSON rather than attributed to this audit.
- Not assessed: subjective composition, listening fatigue, device/headphone output, perceptual click audibility, runtime transition/restart behavior, observed voice-stealing, or full bus-mixed true peaks. No claim of having listened is made.
- No downloads, AI generation services, installs, GUI, Git operations, upload, or production edits.

## Godot 4.7.2 imported-resource verification

- Explicit local engine `4.7.2-stable (official)`; isolated audit working directory, writable XDG cache/config/data directories all under this review folder, Dummy audio driver. Existing imported resources were loaded by absolute path, without loading the game project or importing/modifying production resources.
- Direct `AudioStreamPlayback.mix_audio(1.0, frames)` decoded all 18 cached assets at 44100 Hz. Passed: True; all finite, zero clipped frames; largest post-import/resampled peak 0.651825.
- All ten Ogg loops were decoded through the first wrap plus 4096 frames, with nonzero audio after the wrap. The eight effects are confirmed `AudioStreamWAV.FORMAT_QOA` imports, not raw PCM at runtime; all decoded to end-of-stream within 0.12 ms of nominal duration (resampling-end rounding).
- This is numerical direct-playback decode, not real-time speaker/headphone listening, full bus-mix recording, or scene-transition testing. Detailed per-resource measurements are in `godot_imported_audio_results.json`; executable probe is `probe_imported_audio.gd`.
- An initial discovery probe used the generic Godot alias, which resolved to 4.6.3 and could not create its default `[home]/.local/share/godot`, `[home]/.config/godot`, or `[home]/.cache/godot` directories. That probe was not counted as target-version acceptance. The subsequent explicit 4.7.2 probe used authorized review-local XDG locations and completed successfully; no escalation or retry against those home paths occurred.

```sh
BASE="$PWD/fourfold_next/audio_review"
mkdir -p "$BASE/xdg/cache" "$BASE/xdg/data" "$BASE/xdg/config"
XDG_CACHE_HOME="$BASE/xdg/cache" XDG_DATA_HOME="$BASE/xdg/data" XDG_CONFIG_HOME="$BASE/xdg/config" \
  tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --audio-driver Dummy \
  --path "$BASE" --script "$BASE/probe_imported_audio.gd" --log-file "$BASE/godot_imported_audio.log"
```

## Selective-fix acceptance helper

`verify_ambient_candidate.py --project CANDIDATE` independently reproduces the four candidate ambiences, checks their manifest hashes/decoded samples, and checks that all other 14 asset SHA-256s remain identical to this baseline. It is read-only against the candidate and writes only its own JSON result here.
Acceptance thresholds: stereo 32 kHz / exactly 512000 frames; finite samples and peak <0.99; per-channel |DC| <1e-4; loop seam/max internal step ≤1.1; no interior run ≥100 ms of 10 ms windows below −60 dBFS; |R−L RMS| ≤3 dB. Exact centering is not required. Preserve the four-world seed/order and six scores/eight effects unchanged.
