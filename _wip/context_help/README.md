# F1 contextual help — first WIP source checkpoint

Frozen 2026-10-23 15:05 UTC, based on main `77e1d7bf08121559fdf386f29d3944e45fe38ee9`.
The feature author has begun the first implementation and testing. **No new test-pass,
independent acceptance, or playable-release claim is made by this source backup.**

Scope: chapter-practice wording for F1 plus a release-key guard after closing help.
H/J hint rules, saving, and level data are outside this intended change. Independent
review must confirm behavior and input safety before any main promotion.

The full main.gd and context_help.gd are preserved here without replacing production
paths in the branch. `.gdignore` keeps these incomplete snapshots out of Godot imports.
Preload paths are original production paths, not a connected WIP runnable project.
Do not overwrite the tested baseline automatically. Future fixes will be separate commits.

`work/resume-rebuild` remains intact. All binary uploads remain paused; inherited
remote assets are still incomplete (47/62 GLB, 0/18 audio, 0/6 Blender sources).

## Source hashes

- `scripts/main.gd`: `15a68661146db4cc1e47c11ea2a60ca2be0115099d529d0e54a1b46a11a6650e`
- `scripts/main.gd.uid`: `abcafb008acc0c644f562ce1f66548628dbfbcda3fd7e1d3b03bb2eb58f974ca`
- `scripts/context_help.gd`: `87cc343f9d568eb99b4dac3ec355366a56a9878f98d34ddd8262d9c8c354e220`
- `scripts/context_help.gd.uid`: `b42951d6ee7c0c4cb19947d766060e93b53f426b045422630927d425544b3fa5`

## Author evidence added — 2026-10-23 15:09 UTC

The author supplied the import/font/capture logs, capture script, font-coverage
source/result, and updated decisions/test report. Independent review remains pending.
These checks do not promote the feature to main or imply player acceptance. The four
PNG captures were not uploaded while binary confirmation is unresolved. Production
source hashes still match the first WIP snapshot.

## Metadata type guard — 2026-10-23 15:14 UTC

`context_help.gd` now requires both chapter/goal metadata fields to be Strings;
missing/null/numeric/array values are omitted rather than displayed. Author-reported
SHA-256: `0b43d5dedeffa7a305c87a897b103766097c72387ce601ba7a342488fbfd32f4`.
`main.gd` remains `15a68661146db4cc1e47c11ea2a60ca2be0115099d529d0e54a1b46a11a6650e`.
The independent final rerun is in progress. No main promotion is implied.

## Focused audit evidence — 2026-10-23 15:21 UTC

Final type-guard source passed 193 behavior + 2,696 layout assertions (2,889 total)
with 352 parsed physical-key events. Six real 1440×900 X11 captures were separately
viewed by the reviewer; `visual_review.json` records this later review, while the
original native capture manifest intentionally retains its earlier Pending wording.
PNG bytes remain excluded from GitHub. Source hashes are locked in FINAL_SUMMARY.json.

The parent has additionally requested a native CUA held-key probe. That new probe is
still pending at this checkpoint, so this backup is not a final main-promotion claim.
Author README is retained as AUTHOR_README.md without replacing this scope note.
Large layout.json is raw textual test evidence, not a screenshot or binary asset.

## Final native input evidence — 2026-10-23 15:28 UTC

The reviewer has frozen the final text manifest and added the requested real X11
held-key probe. Native WASD A was held for 1,273 ms; the help-close guard required
release/repress as intended. The native Left probe reported physical_keycode=0,
and no OS echo events were seen: this is NOT a claim that OS autorepeat was tested.
See native_input_review.json, REPORT.md, and FROZEN_TEXT_MANIFEST.json for boundaries.
All 12 production input hashes remain unchanged. This is a focused UI/lifecycle
audit, not a new complete gameplay regression. Main promotion still needs parent
authorization; no binary or screenshot upload was attempted.
