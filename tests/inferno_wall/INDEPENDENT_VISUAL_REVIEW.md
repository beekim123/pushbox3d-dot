# Independent visual review — inferno wall C0.80

## Decision and scope

**PASS for the frozen C0.80 candidate within the revised core-symbol readability gate.** This is not a zero-occlusion certification. Parent/root explicitly accepted partial clipping of decorative ivory goal-locator teeth after comparison with the original baseline. B0.88 remains rejected because its extra height encroached on the core gold goal ring. C0.78 was an audit comparison, not the selected final candidate.

Reviewer: `independent-reviewer`, 2026-10-23. No production/source/model edits or GUI actions were performed by this reviewer. Acceptance is local art/QA evidence, not permission to upload binaries or evidence of production integration.

The change replaces the repeated lavender paving-rib obstacle appearance with six staggered, rounded ashlar stones and darker side faces. C0.80 raises only lower-course thickness versus frozen A0.63, lifting the unchanged crown plan by 0.17. Horizontal footprint, copper pipe, gameplay, level data, terrain, lighting and camera code remain unchanged. No added architecture, downloaded assets or AI bitmap assets are part of this change.

## Actual image inspection

Opened the original and final native **inferno levels 10, 23 and 45 in both high and low quality** at their supplied 1440×900 size, not only filenames or geometry metrics. Exact pairs are in the accompanying manifest. High uses render scale 1.0 / MSAA 2; low uses render scale ~0.6 / MSAA 0. Capture manifests report Godot 4.7.2, X11, GL compatibility/llvmpipe, no failures or missing assets.

Also opened matched Blender original/final lineups (1200×720) and full scenes (1050×805). Earlier A, B and C diagnostic frames were reviewed during iteration; only `native_final/`, `native_final_23/`, `blender_final_lineup.png`, and `blender_final_scene.png` bind this final visual decision.

- The staggered crowns and thicker soot-plum side bodies read as compact wall obstacles, unlike the original parallel ribs that resembled raised paving. Broad faces and rounded chamfers retain the toy-like style without adding noisy geometry.
- Walkable floor remains the lighter, flatter grid; walls retain a separate dark side silhouette. Crate silhouettes and the courier remain distinct.
- In all six final native frames the **core gold goal circles remain recognizable and continuous**, and portal spirals stay distinguishable from goals. Adjacent playable tile centers remain visible. Low quality is intentionally pixelated but does not erase these distinctions.
- Level 23 is the key close-clearance comparison: front walls partially shorten ivory locator teeth. This cosmetic clipping is accepted as a documented tradeoff for stronger wall mass; the circular goal core is not confused with an obstacle or portal.
- No further art adjustment is recommended in this bounded milestone.

Independent JSON comparison confirms identical camera, marker positions, lighting, quality and draw-call fields for every original/final native pair. Draw calls are 234 (10), 234 (23), and 244 (45), unchanged in both quality modes. Camera equality includes automatic framing; no comparison-only camera override is needed.

## Geometry, scope and source checks

Independently hashed every GLB: only `inferno_wall.glb` and `inferno_wall_b.glb` differ from the original baseline; the other 60 are byte-identical. All files in `scripts/`, `project.godot`, and `assets/levels.json` are byte-identical to the baseline clone. This review does not overwrite newer production code.

| Model | Original triangles | Final triangles | Original/final material batches |
|---|---:|---:|---:|
| inferno_wall | 940 | 552 | 2 / 2 |
| inferno_wall_b | 3,884 | 3,496 | 4 / 4 |

Parsed final GLB accessors independently: model height is ~0.800000012 (original ~0.63); X/Z extrema are unchanged. Base bottom differs only by ~5.6e-9 export precision. Wall body footprint is X ±0.86, Z ±0.76; the unchanged wall_b pipe extends Z to ~0.84499794. All exported wall nodes have identity transforms.

Read final C80 QA logs: camera fit `checked=204 HUD_clips=0`; asset audit `passed=true, models=62, sources=6, errors=[]`; GLB audit reports no image textures or external buffers. These were author-run checks, independently read here, not new reviewer execution. HUD fit does not prove symbol visibility. Final semantic comparison reports agree on oriented triangle POSITION/NORMAL values rounded 1e-6 and named material properties after a clean filtered rebuild. They exclude hierarchy/transforms; final wall nodes were separately checked as identity. **Byte-reproducible Blender export is not claimed**; use the exact frozen hashes below.

## Occlusion audit interpretation and limitations

Independently read `wall_occlusion_refined.gd` and `wall_occlusion_surfaces.gd`, checked actual goal/portal GLB geometry and runtime placement, and compared hit sets (level + kind + world point rounded 1e-5).

- Camera rays from point + camera basis Z toward the point are correct for this orthographic camera. Wall triangles and bounds use actual imported global transforms.
- Correct goal ring equator world Y=.085 includes the .02 runtime offset; actual tooth top is Y=.12. The earlier analytic tooth corners were conservative unbeveled empty-space samples, so those totals cannot certify rendered-symbol occlusion. Analytic .535-radius ring samples also do not exactly follow every faceted torus edge.
- The final surface audit samples actual imported camera-facing triangle vertices, edge midpoints and centroids, and excludes hits already hidden by the same glyph's triangles. It includes the runtime placement offsets, avoiding the analytic-coordinate issue. The shading-normal facing filter and finite samples are not a raster/full-pixel proof.
- Portal surface sampling is its initial pose only. Portal idle animation rotates and bobs; all animation times are **not** proven. The obsolete analytic portal Y=.16 was tube-bottom height, not centerline .195.

Final C80 audit covers 51 inferno/inferno-skinned confluence initial layouts: 1,070 legal-cell-center samples (908 wall-adjacent), 86,580 goal-ring surface samples, 143,676 ivory-tooth samples, and 910,350 portal-spiral samples. **No wall intersections were reported for sampled legal centers, gold core rings or portal spirals.** This is limited finite initial-pose evidence, paired with the six native image checks.

| Variant | Ivory-tooth surface hits | New vs original | Core ring / portal / center hits |
|---|---:|---:|---:|
| Original | 711 | — | 0 / 0 / 0 |
| A0.63 | 414 | 0 (removes 297) | 0 / 0 / 0 |
| C0.80 selected | 4,119 | 3,408 | 0 / 0 / 0 |
| C0.78 audit alternative | 3,721 | 3,010 | 0 / 0 / 0 |

C0.80 newly hides 95 sampled tooth-top points, 1,991 upper-bevel points, and 1,322 side/lower-boundary points versus original. Regions use a 1e-5 height tolerance (top Y>=.11999; upper bevel Y>.10001), avoiding float-noise misclassification at Y=.10. These are finite, tessellation-dependent sample counts, **not clipped pixel counts or area percentages**. The whole-symbol audit therefore has `passed=false`, intentionally retained; root relaxed only the decorative-tooth criterion after actual image comparison. Do not relabel it as a blanket no-occlusion pass.

No claim is made about every game state, display size, GPU, animation pose, or all-world visual inspection. Source/asset preservation and the 204-layout camera check have broader scope than the six native image inspections.

## Exact frozen candidate hashes

Canonical candidate directory: `wall_review/height_variant_c80/` relative to the isolated inferno-wall project. Root-level old A validation/delivery artifacts are not the selected final C80 evidence.

- `blender/rebuild_worlds_v2.py`
  `d11994eaaf30cd29c2cc916e05dc8151137c788ca1c50af64811396e5f515021`
- `blender/inferno_v2.blend`
  `9f69bed78bfc0d069ff5d2a34665da3709bfd7acaf956ccbb5cf21e3ef44641d`
- `blender/v2_inferno_stats.json`
  `f2ad48875a81f1bff075bc39df2913482287d1f22cdad3733d02febaa65e12a8`
- `assets/models/inferno_wall.glb`
  `9c5d82799ec4fd831e6a6317b8a8d0216e055098dcea8c0541acb197d231265e`
- `assets/models/inferno_wall_b.glb`
  `bff53007b2e01e76caeeb4030d7069b5e82a4f13213a9d28589297266f6afba7`

`INDEPENDENT_REVIEW_MANIFEST.json` records exact evidence hashes and inspected pairs. Rebuilding can change GLB bytes; a replacement build requires binding the changed bytes to equivalent geometry and visual evidence. Production integration, if later performed, requires a separate verification addendum.

## Frozen integration-manifest binding

Independently verified `FINAL_C80_INTEGRATION_MANIFEST.json` SHA-256
`fc31becb014cccdfcc3bcd9aa7e58102a4ff36735e0bfe8c7f2f91a548832cd9`:
all four core inputs plus recommended stats match the exact candidate hashes above;
the author's before/after capture-build pins are equal; all 54 files in the clean
`final_delivery/` bundle match its recorded hashes. Final native PNGs and Blender
previews in that bundle match the inspected evidence. The manifest is the selected
C0.80 handoff, not the obsolete A `delivery_manifest.json`.

Supplementary portal audit source and report were read independently. It derives a
radius ~0.54627758 and minimum world Y~0.16 from actual imported glow vertices,
then tests the lowest full-rotation disk at 144 angles and five radii for each portal.
Its 73,440 portal samples across 51 layouts report no wall hits. This supplements
the initial-pose surface check; finite disk samples still are **not pixel-complete
animation rendering or proof for all game states**. It does not change the accepted
ivory-tooth tradeoff or convert the whole-symbol audit into a zero-occlusion pass.

This binding approves the reviewed candidate for the parent's scoped integration
process. Production execution/integration was not checked by this reviewer at this
point; no production result or upload permission is implied.
