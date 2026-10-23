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
