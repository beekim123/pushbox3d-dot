# Repository backup scope — 2026-10-23 14:33 UTC

This isolated WIP backup preserves the newly reconstructed independent audit sources
and fresh result text. It does not merge the feature into main or complete remote assets.

- Headless run `20261023T142752.177145Z`: 13,114 checks, nine processes, all exit 0.
  Manifest reports passed, stable sources, and staging matches source. The audit files
  in this checkpoint were matched against that manifest's exact SHA-256 locks.
- Native run `native_20261023T142253Z`: 50 checks across three processes, all exit 0;
  includes real desktop Continue/Undo-Reset, failure Return and StillExit.
  Six PNG screenshots exist locally but are NOT included in GitHub; binary upload
  approval remains unresolved. JSON/log text records the run but is not a substitute
  for viewing the omitted screenshots.
- `../results/layout_replay_6accd40a.json` is a separate 7,368-check module-only replay
  of the exact committed WIP directory layout, not production UI validation.

The retained audit runners use the original workspace layout (`fourfold_atelier`,
`fourfold_next/resume_audit_rebuild`, and tools/godot-4.7.2/godot). This directory is a
source/evidence backup, not yet a portable reproduction bundle. A separate portable
production audit export is being prepared by the audit author. Do not execute the
workspace runner directly here expecting it to find a complete game.

`_runtime`, temporary pointers, user data, transaction fixtures, caches, and PNGs
are excluded. Historical pre-crash counts are not treated as new results. The main
branch is unchanged; remote media remains 47/62 GLB, 0/18 audio, and 0/6 Blender sources.
