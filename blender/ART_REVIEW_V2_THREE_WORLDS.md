# Three-world environment rebuild — V2 art and technical review

Date: 2026-10-23. Scope: inferno, rainforest, city only. Heaven/orchard, hub, runtime and levels are owned by the other work streams.

## Delivered originals

- `rebuild_worlds_v2.py` builds the inferno and rainforest geometry and owns asset export, simple creature/mechanism animation, material batching, full-scene composition and rendering.
- `city_meshes_v2.py` builds the original hillside-city modular kit.
- `inferno_v2.blend`, `rainforest_v2.blend`, `city_v2.blend` are compressed, fully editable source scenes. Modelling pieces, materials, curves, thick leaf surfaces and modifiers remain editable, not only the merged game meshes.
- 43 same-name and optional GLBs: 14 inferno, 14 rainforest, 15 city. Existing runtime names remain compatible; `landscape`, `landmark_b`, `decor_c`, `wall_b` add non-repetitive environment choices.
- No downloaded models, textures, photographs or AI images. Geometry and Principled materials were authored in Blender. GLBs have no images or external buffers.

## What changed in the art

### Inferno
- Separate radial voussoirs build actual thick round arches. Rounded piers carry their weight; they are not gold-outlined arch symbols.
- A curved copper boiler, dark recessed furnace mouth, physical ember/flame geometry, bent flanged copper pipes and a pressure gauge define the main landmark.
- A velvet-dark expressive coal stoker has curved horns, a cap, large cream eyes, ember cheeks and small feet.
- The ground is quiet uneven masonry on a continuous irregular rock mass. The fore-edge heat channel has a smooth centerline, changing width, inset rocks and a wider ember spring; it is not a gold-framed tile tray.
- Low stacked masonry remains distinct from the square push crate and clear circular goals.

### Rainforest
- Tapered branching trunks have seven solid plank-like buttress roots, bark seams and hanging lianas. Crown, secondary branches and low foliage provide several heights.
- The first draft was too sparse and grey. It was revised to larger overlapping thick curved leaf groups, additional rear canopy tiers, moss-green clearing surfaces and warm exposed soil, with only small worn stones within the grass.
- Walls are now broken stumps with spreading roots and fallen logs with readable pale cuts/growth rings, rather than rocks with a horizontal decorative bar.
- The creek centerline is smoothly interpolated; the bank has varied boulders, low grasses, broad understory and restrained coral flower cascades. The creek stays outside the playable grid.

### City
- Unequal terrace elevations carry several distinct houses, hipped clay roofs, rooftop utility rooms, projecting balconies, shop awnings and garden troughs.
- A raised street, real stair flights, balcony supports, bridge piers, curved viaducts and trams create vertical traffic layers. A broad low river and small ferries connect the scene to its embankments.
- The main quarter grows outward from its inner-corner anchor; it is not a repeated row of narrow tower tokens.
- The first full preview exposed coplanar tile surfaces. The substrate top was moved to -0.06m and the paver top to +0.005m. A separate actual Cycles tile render confirmed that the black faces disappeared. Final pavement is a warmer darker grey, separate from light step edges.

## Composition and readability

- Nominal landscape is a 7×7 board / 14×14m central clearing. Runtime may scale X/Z by board dimensions; Y is not scaled.
- Playable scenery is kept low; none of the three landscapes has a vertex above 0.15m within the audited center X/Z ±6.98m.
- Main landmark roots are **inner-corner anchors**, not symmetric model centers: inferno/rainforest construction is shifted Blender X=-1.3,Y=+0.8; city is shifted X=-2.2,Y=+0.6. This keeps large crowns/facades out of legal cells. Secondary landmarks retain central anchors and should sit farther outside the board.
- Gold decoration is no longer the structural language for terrain or walls. Crates, ring goals and direction/mechanism marks preserve rule readability.
- Preview camera framing was expanded after enlarged rainforest crowns and the city skyline exceeded the initial draft framing. Final Blender previews are 1500×1150 Cycles renders, 64 samples, without AI denoising.

## Technical evidence

`audit_worlds_v2.py` independently reads final GLB binary data; output is `worlds_v2_geometry_audit.json`.

| Final static asset | Material batches | Triangles |
|---|---:|---:|
| inferno landmark | 7 | 19,228 |
| inferno landscape | 6 | 29,084 |
| rainforest landmark | 11 | 46,426 |
| rainforest landscape | 14 | 126,332 |
| city landmark | 18 | 48,020 |
| city landscape | 20 | 71,460 |

- All 43 files: valid self-contained GLB, zero embedded image textures, zero external buffers.
- All three landscape clearance checks pass. Wall geometry remains below 1m.
- Creature and portal clips retain `idle`; the city gate retains `open` and `close`.
- Static construction is evaluated and merged per material only for game export. Source editing is not sacrificed.
- Tiny window/rail bevels and curve rings were reduced rather than removing architecture: city landmark dropped from 151,356 to 48,020 triangles; city landscape from 182,292 to 71,460.
- ZIP-deflate estimates for each final GLB kit: inferno 1.10MB, rainforest 3.00MB, city 1.71MB. The three compressed source scenes together are under 2MiB.

## Final rendered review

All three final PNGs were opened and visually inspected after the iterations. The enlarged rainforest canopy and city skyline are now completely inside the frame; the city pavement black faces are absent. Stumps/deadfall, masonry barriers, transport crates, clear target rings and mechanic markers are visually distinct. The sparse central clearing is intentional for puzzle readability; dense canopy and architecture remain around the perimeter. The final images are `screenshots/blender_inferno_v2.png`, `blender_rainforest_v2.png`, and `blender_city_v2.png`.

## Explicit limits

- Blender visual checks are not a substitute for Godot game-camera verification. Runtime import, framing, occlusion, draw calls and full-level tests are handled by the runtime/root work stream.
- No claim of user visual approval or real-GPU performance is made. The available execution environment uses software rendering.
- The puzzle remains a single playable plane; the city's layered transport is scenic, not a claim of multilevel pathfinding.
- Old `*_kit.blend` files and generated backup `.blend1` files were moved to the external `fourfold_versions/v1/blender_archived_during_v2/` archive, not deleted.


## Post-freeze path readability correction

After inspecting `screenshots/v2/godot_rainforest_9.png`, the legal path was found too similar to outer moss soil. Only `rainforest_tile.glb` was re-exported: the path is warmer/lighter, the worn stone inserts are pale ochre, and a 4% inset exposes a thin dark earth seam. Grass accents, tile footprint/height, all mechanics and every other GLB are unchanged. `rebuild_worlds_v2.py` and the editable `rainforest_v2.blend` source were synchronized. The original frozen V2 snapshot is retained by the delivery work stream.

Actual Cycles close-up `screenshots/v2/blender_rainforest_path_readability.png` was opened and inspected: the path reads clearly against the green perimeter without gold or metal framing. `rainforest_path_readability_audit.json` records that only one GLB changed and the other 61 hashes remained identical. The full three-world binary audit still passes. The earlier full-scene PNG depicts the frozen stage; this close-up is the evidence for the incremental path change. Runtime reimport and the same-level game-camera check were requested separately.

The updated `godot_rainforest_9.png` was subsequently opened and inspected. The same-level game view now clearly separates the warm legal path cells from surrounding green moss, with visible fine dark joints; boxes, arrow, courier and goals remain distinguishable. Godot imported-cache source MD5 matches the new tile GLB exactly.
