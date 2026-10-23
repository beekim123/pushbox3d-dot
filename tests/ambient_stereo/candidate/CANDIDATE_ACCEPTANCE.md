# Independent selective ambience correction acceptance

**PASS for the exact six-file allowlist below.** Do not merge this candidate as a whole project. Production audio/generator remained unchanged throughout this review.

## Verified scope and provenance

- Source diff is precisely the right-channel missing `/(k**.55)` denominator at generator line 137; no other generator changes.
- All 14 music/SFX delivery files and their complete manifest records are unchanged from the audited original. Manifest top-level metadata/key set is unchanged; only four ambience records differ.
- All ten retained PCM WAV master hashes match their respective source hashes in the merged manifest. Independently reconstructed corrected ambience WAV hashes match the four supplied masters/manifest records; re-encoding produces decoded float32 audio exactly equal to the four delivered candidate Ogg files.
- No external recordings/assets are introduced: original synthesis functions, seed and four-world order reproduce the corrected outputs.
- Candidate audio directory differs only in four Ogg files plus its validation manifest. Allowlist before/after hashes independently match production/candidate; all six candidate hashes still match after import/decode review.

## Four corrected ambience results

| Asset | Old R−L dB | Candidate R−L dB | Peak | Max absolute DC | Seam / max internal step |
|---|---:|---:|---:|---:|---:|
| heaven_ambient | +13.4621 | +2.5101 | 0.15039711 | 2.5554151e-06 | 0.002917 |
| inferno_ambient | +12.8510 | -0.0167 | 0.15032947 | 8.1968761e-05 | 0.285459 |
| rainforest_ambient | +14.2236 | +1.6657 | 0.14948447 | 2.566152e-06 | 0.005369 |
| city_ambient | +11.8739 | -0.3483 | 0.15088362 | 2.5723724e-06 | 0.048611 |

- Each is stereo 32,000 Hz / exactly 512,000 frames (16 seconds), finite, with no samples ≥0.99 absolute, no clipped samples and no interior ≥100 ms run of 10 ms windows below −60 dBFS RMS.
- Every per-channel DC mean is <1e−4; every seam/max-step ratio is ≤1.1; every |R−L RMS| is ≤3 dB. Residual stereo offset from intentionally panned events is retained; exact centering was not required.

## Fresh Godot 4.7.2 import and decode

- Copied all 18 candidate audio sources plus their import settings into `fourfold_next/audio_review/candidate_import`; no game runtime/models or production cache was used for import. Explicit `tools/godot-4.7.2/godot`, headless import, writable XDG locations wholly under the review folder. Import exit 0; no ERROR/WARNING lines.
- Fresh imported resources: **18/18 successfully loaded and decoded** by direct `AudioStreamPlayback.mix_audio` at 44100 Hz; finite samples, zero clipped frames. Ten loop resources continue with nonzero audio beyond the first wrap; eight QOA effects decode to EOS within 0.12 ms of nominal duration.
- Direct decode used the Dummy driver; no listening or subjective audible-improvement claim. This checks audio asset import/decoding, not full game transitions, speaker/headphone output, or bus-mixed true peaks.

## Integration allowlist and SHA-256

```text
d8ddfdf231b17c8064872448a6ab97a56bece3808760fd6d4949afa80e972c62  tools/generate_audio.py
4df7491349148c130da74a00944f6993f2a719a48222507be55021cab906e4f2  assets/audio/audio_validation.json
23b5925401015b30564bd35b032bcb036e5db27b60e6654d150d6ef6c0fe789a  assets/audio/heaven_ambient.ogg
c48d0258ee9f579096245b64a0d4db34407afaaec8cf95bb67df5fe3039ef8e8  assets/audio/inferno_ambient.ogg
9d1a6b7ca33a98e50bdebb076aba61d90a0c662528336ab38365670c7b975a7d  assets/audio/rainforest_ambient.ogg
76d9896cdde347876e897e4e710628cd7cb8baf933f568a238ebf078e8ebf106  assets/audio/city_ambient.ogg
```

## Evidence / reproduction

- `candidate_verification.json`: independent source reconstruction, codec equality, frame/DC/clipping/seam/stereo checks, 14 preserved delivery hashes.
- `candidate_scope_verification.json`: exact one-line diff, 14 manifest-record equality checks, ten master hashes, allowlist and audio-directory diff.
- `candidate_godot_decode.json`: fresh imported-resource decode metrics; import/decode console logs retained.
- `candidate_acceptance.json`: integration attestation; `candidate_allowlist_sha256.txt` is directly usable with `sha256sum -c` from the candidate directory.
- `verify_ambient_candidate.py --project fourfold_next/audio_fix` reruns read-only synthesis/numerical acceptance. `prepare_candidate_import.py`, `probe_imported_audio.gd`, and `finalize_candidate_review.py` preserve the remaining review steps.
