# Inferno obstacle walls — frozen C0.80 milestone

## Selected result and scope

Six uneven rounded ashlar stones replace the old parallel lavender ribs. Two staggered courses, dark plum side faces and restrained warm crowns make blocked cells read as masonry rather than raised paving. All geometry/materials are original Blender work; no downloaded assets or generated images were used.

The original/A top was0.63m. Root explicitly relaxed that **self-imposed design gate**, not a user requirement, and selected C0.80: only the lower course gains0.17m; X/Z plan, materials, copper pipe, runtime transforms, boundary scale, camera, lighting, shadows, terrain and gameplay are unchanged. The taller B0.88 was rejected for newly obscuring core gold goal rings. C0.78 did not eliminate cosmetic tooth clipping and offered less obstacle mass.

**C0.80 is not a zero-occlusion result.** Root accepts small ivory locator-tooth clipping as a cosmetic tradeoff. Core gold rings, portal spirals and legal-cell centers remain readable in the checked views and clear in the sampled geometry tests. No goal position or camera change was used to hide a failure.

## Geometry and performance

| Asset | Original triangles | C0.80 triangles | Material batches |
|---|---:|---:|---:|
| inferno_wall |940|552|2 →2|
| inferno_wall_b |3,884|3,496|4 →4|

- Original horizontal envelopes are exact (Godot X/Z); bottom remains0.01 and top deliberately becomes0.80.
- Projected X/Z triangle plans and full material data match frozen A, independently of export ordering.
- Only these two GLBs changed. All60 other GLBs—including current orchard assets—and all runtime/scenes/levels/project settings match the original production snapshot.
- Native draw calls are unchanged in each matched pair:234 at level10,244 at45,234 at23.
- 204-level camera/HUD fit:0 clips.62-asset dependency audit passes; no image textures/external buffers.

## Actual visual evidence

`evidence/native_before/` and `evidence/native_after/` contain six unchanged PNGs each: levels10,23,45 in high and low quality,1440×900. Native Godot4.7.2/X11/llvmpipe/GL Compatibility; camera transforms, lighting, goal/crate markers, MSAA and render scale match pairwise. Animations were frozen at the initial pose. No camera override was applied. Combined metadata retains its two original source manifests in `reports/`.

`evidence/blender/` contains matched original/final full scenes1050×805 and wall lineups1200×720, rendered in Blender4.3.2 Cycles. They are actual renders, not concept images.

## Visibility tests and honest limits

The exact imported-mesh audit covers51 inferno-skinned levels:1,070 legal-cell centers (908 adjacent to walls),86,580 goal-ring surface samples and910,350 portal surface samples. All have0 wall hits. It tests camera-facing triangle vertices, edge midpoints and centroids, and excludes candidate points hidden by the glyph's own mesh using exact self-rays.

Decorative ivory tooth hits are711 in original,414 in A,4,119 in C0.80. Hit sets were compared by level/type/world point, not just totals. C0.80 adds3,408 versus original:95 tooth-top,1,991 upper-bevel,1,322 side/lower points using tolerance-aware Y thresholds. These are **finite, non-area-normalized sample counts—not pixels or occluded area**. The all-surface test correctly remains failed; the selected acceptance gate distinguishes core symbols from cosmetic locator teeth.

Exact portal-surface sampling is at the initial pose. A separate conservative full-rotation/lowest-height disk, measured from imported glow vertices, samples73,440 points over51 levels with0 hits. This supplements rather than pretends to be pixel-complete animation testing.

Native llvmpipe prints the existing unsupported VSync-change warning; imports, captures and tests completed normally.

## Rebuild and verify

The exact photographed source/GLB/.blend bytes are pinned in `reports/frozen_core_hashes.json` and the separate `FINAL_C80_INTEGRATION_MANIFEST.json`. A clean rebuild has equivalent oriented triangles/normals/materials. Blender GLB object/index ordering is not guaranteed, so preserve the reviewed exports instead of substituting probe files.

From a project root, to rebuild only the two exported wall GLBs while retaining the complete editable source/preview scene:

```sh
FOURFOLD_EXPORT_ONLY=inferno_wall,inferno_wall_b FOURFOLD_RES=70 FOURFOLD_SAMPLES=32 \
  blender --background -t 4 --python blender/rebuild_worlds_v2.py -- inferno
```

Unset `FOURFOLD_EXPORT_ONLY` retains the normal full rebuild. A separate no-filter inferno smoke build exported all14 assets; no-filter behavior was not replaced by a wall-only default.

Portable read-only frozen-build verification (Python3+Pillow):

```sh
python3 qa/audit_final_c80.py --project /absolute/project \
  --allow-cosmetic-tooth-occlusion
```

Native recapture, launched from a real desktop Terminal with isolated QA save directories:

```sh
GODOT=/path/to/godot-4.7.2 qa/run_native_capture.sh /absolute/project /absolute/output
CAPTURE_SCRIPT="$PWD/qa/native_capture_23.gd" GODOT=/path/to/godot-4.7.2 \
  qa/run_native_capture.sh /absolute/project /absolute/output23
```

Pass a matching original capture manifest as the optional third argument to assert unchanged camera. `qa/wall_occlusion_surfaces.gd` and `qa/wall_portal_sweep.gd` run with `--headless --path PROJECT --script ABSOLUTE_SCRIPT -- --qa --output=ABSOLUTE_JSON`.

## Integration boundary

Production was not modified by this task. Root alone may copy the manifest's four core files, plus the separately recommended stats JSON, after final review. This QA bundle contains no baseline project, rebuild probe, `.godot`, `.qa_env`, user save, or `.blend1` backup. No GLB/.blend/PNG binary was sent to Git. Source-only WIP was preserved on `work/inferno-wall`; binary publication remains separately constrained.
