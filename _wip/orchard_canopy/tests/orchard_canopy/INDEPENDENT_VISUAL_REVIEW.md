# Independent peach-orchard canopy review

Reviewer: `review_orchard_visual_polish`  
Date: 2026-10-23 UTC  
Scope: read-only source/art review and actual rendered-pixel inspection; this report and its independent hash manifest are the only reviewer-authored project artifacts.

## Status

**PASS — final-byte visual acceptance, 2026-10-23 16:16 UTC.** The frozen rebuilt assets listed below passed independent semantic verification and renewed actual-pixel inspection of all eight `native_final/` frames plus both final Blender previews. This report does not authorize publishing binary assets or override the outstanding upload restriction. No further art edits are requested for this milestone.

## Visual findings and iteration

- Original trees were recognizable as a peach orchard, but their crowns read as flat, uniformly speckled flower shelves. The repeated small tree reused the hero skeleton.
- V1/V2 improved branch connectivity and tree identities but became too sparse: narrow tip bouquets on long bare branches. Those versions were not accepted.
- Shallow, asymmetric blossom fans restored coherent pink groups while preserving open branch gaps. Large Blender previews still show some pale cushion-like edges; at game scale this is a minor stylization issue rather than a blocking regression.
- The first native candidate exposed a large dark gray/brown overlapping underside on the right-facing hero tree in levels 10 and 45. That was a blocking visual regression, despite successful geometry metrics.
- The shadow fix thinned/lowered fan volumes, removed backing from the overlapping front spray, and warmed existing underside material. Source inspection found no global lighting or shadow-toggle change.
- In the accepted shadow-fixed native frames, the slab-like dark patch is gone; coherent blossom masses, exposed wood, fruit accents and a distinct sapling remain. Goals, crates, wind lanes and HUD are unobscured.

## Actual images inspected

Paths below are relative to the project root unless stated otherwise.

### Original evidence

- `screenshots/blender_heaven_v2.png`
- `screenshots/v2/godot_heaven_9.png`
- `screenshots/v2/godot_heaven_44.png`
- `screenshots/resume/restored_high_quality.png`

### Iteration evidence in `canopy_review/`

- `lineup_before.png`
- `lineup_after_v1.png`, `lineup_after_v2.png`, `lineup_after_v4.png`, `lineup_after_v5.png`
- `garden_before.png`, `garden_after.png`
- All eight matched frames in both `native_before/` and superseded `native_after/`: `heaven_03_high.png`, `heaven_03_low.png`, `heaven_10_high.png`, `heaven_10_low.png`, `heaven_45_high.png`, `heaven_45_low.png`, `hub_high.png`, `hub_low.png`.
- All eight corresponding frames in **`native_after_shadow_fix/`**.
- Untouched automatic-framing frames in `native_after_shadow_fix/`: `native_heaven_03_high.png`, `native_heaven_10_high.png`, `native_heaven_45_low.png`.
- **Final frozen-byte evidence:** all eight corresponding matched frames in `native_final/`, plus `garden_after_accepted.png` and `lineup_after_accepted.png`. Every final frame was opened and inspected again, not assumed to match an earlier iteration.

These were opened with `view_image`; this review is not inferred from filenames, triangle counts or author claims.

## Preservation checks independently read/compared

- Shadow-fixed and final capture manifests report Godot 4.7.2, X11, compatibility renderer, llvmpipe, 1440 × 900, and no capture failures/missing assets.
- All eight matched pairs have equal camera position/rotation/size, crate/goal markers, lighting fields and draw-call counts.
- Draw calls: level 3 = 280; level 10 = 296; level 45 = 312; hub = 531, unchanged in both quality modes.
- Recorded shadow-fixed geometry: hero 30,184 triangles; leaning pair 41,204; sapling 15,412. Each has 12 material meshes and lies inside the original asset AABB.
- Only the three tree GLBs are listed as changed. Shared gameplay blossoms remain isolated from the tree-specific flower helper.
- Production and candidate `scripts/world_view.gd` hashes match at review time. `main.gd` differs because production has newer unrelated work; integration must be asset/source scoped and must not overwrite that runtime work.
- The author-run camera audit log reports 204 levels checked, zero HUD clips. This is a geometry audit, not visual inspection of all 204 levels.

## Export determinism and final identity

The first two object-sorted rebuilds had different SHA-256 hashes for all three GLBs. Therefore **byte-reproducible export is not established**. The ineffective sort/comment-only change was reverted; the final source is exactly the visually accepted source below. Hashes identify this frozen build, not a promise that future Blender exports will be byte-identical.

The author retained the second post-sort output and compared it to the final accepted-source rebuild using canonical orientation-preserving triangle positions/normals rounded to 1e-6 plus material properties (`semantic_geometry_report.json`). All three semantic hashes match. The reviewer read that comparator and independently checked scene roots, named node transforms, child hierarchy, mesh bindings, attribute sets and primitive modes: all match. The meshes contain only POSITION/NORMAL attributes and triangle mode 4. The initially viewed pre-sort GLB bytes were not retained, so they cannot be compared directly; restored source identity plus the semantic checks and fresh final-byte native renders close that evidence gap.

### Frozen file identities (SHA-256)

| File | SHA-256 |
| --- | --- |
| `blender/generate_orchard.py` | `4077183a1854e81c594557adc6938baecb97c97de1fc9d523ef458a6a0dc9c11` |
| `blender/heaven_orchard.blend` | `4083136429ce77c57bd75ad4c92ce820362cad995e51f3f2e3add9e594c2b021` |
| `assets/models/heaven_landmark.glb` | `ac00b6c3c5ab947afa91d4b2652f278cde6c3b552640aa2dffd5751d30ba6ac4` |
| `assets/models/heaven_landmark_b.glb` | `e578928aa5288d0d393d0538c186279deab410c21fc9edfe55a4e658a814c5a7` |
| `assets/models/heaven_decor_a.glb` | `1f1eca183a35e1840c1d4809b4d356cabb94c5fe2f36602cf7cefa23a2b0dfa3` |

The reviewer independently computed these hashes from disk. `INDEPENDENT_REVIEW_MANIFEST.json` binds them to the exact final image and evidence files reviewed.

## Production-integration addendum — PASS, 2026-10-23 16:26 UTC

The reviewer independently rehashed all five files in production `fourfold_atelier/`: each matches the frozen identity above. Production `main.gd` remains `b529ffb595d043cf74216a3f603efe20bc0ba69572b8d70d432bbdfe6a9a586e`; the accepted art was integrated without overwriting that newer runtime work.

The reviewer independently compared `canopy_review/production_native/` with `canopy_review/native_final/`: all four high-quality capture-manifest rows (Heaven 3, 10, 45 and hub) are exactly equal, and all eight PNGs (matched camera plus untouched auto-fit) are byte-identical. The production file hashes also match `production_verification.json`. This transfers the already inspected candidate image result to these exact production views; it does not claim a fresh production low-quality capture or a full gameplay run.

Root-run production logs in `/workspace/scratch/e4cad742399c/recovery/orchard_canopy/` were read: import completed; boot reached high-quality initialization; the camera audit reports 204 levels / zero HUD clips; the asset audit passes 62 models and 6 sources with no errors. These checks were executed by root, not rerun by this reviewer. Package construction and ZIP verification remain a separate step. Binary-upload restrictions and the byte-reproducibility limitation remain unchanged.

## Limits

- This is independent visual acceptance of a bounded canopy improvement, not user aesthetic approval, a full gameplay regression pass, or publication approval.
- No hardware performance conclusion follows from llvmpipe captures. Equal draw calls and reduced primitives only establish that those measured rendering costs did not increase.
- Only the listed native views were inspected; other level layouts rely on the separate 204-level camera-bound audit.
- Production integration has the scoped final-byte verification above; any delivery ZIP still requires its own verification. Binary upload restrictions remain in effect.

## One next-priority finding — research only

Actual `screenshots/v2/godot_inferno_9.png` and `godot_inferno_44.png` show repeated lavender wall ribs resembling raised paving rather than substantial masonry obstacles. `godot_rainforest_9.png`, `godot_rainforest_44.png`, `godot_city_9.png`, and `godot_city_44.png` were also inspected; their obstacle material separation is clearer.

A bounded later candidate is the Inferno wall kit: reshape existing low stone courses into uneven rounded masonry with readable side faces, staggered joints, and restrained warm top planes. Keep the current footprint and maximum height; preserve portal/goal visibility, collision semantics and batching. Candidate code is the wall branches of `inferno_build()` in `blender/rebuild_worlds_v2.py`, producing `inferno_wall.glb`, `inferno_wall_b.glb` and editable `.blend` source. Compare levels 10/45 in matched high/light captures. No building expansion, downloaded assets, gameplay changes or implementation were started by this review.
