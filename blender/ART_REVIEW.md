# V2 revision: orchard and landscape, following user rejection of V1

The user rejected the first model presentation. V1 technical completeness is not visual acceptance. Current heaven art is entirely replaced by a Pantao peach orchard, not palace architecture.

## Orchard review iterations

1. Replaced roofs, columns and metallic tray with visible branching peach trees, twig-borne five-petal blossoms, pointed leaves, split peaches, wood baskets, flower sockets, old stone paving and a continuous moss garden.
2. Root's actual Godot screenshot review rejected soft potato-like stone walls, thin flower bands and a narrow pond. Replaced walls with directional cut planes, warm/cool strata grooves and moss caps; increased unequal flower bands while reducing petal tessellation; broadened water into a crescent and grouped large lotus leaves.
3. Blender composition initially clipped the large tree. Raised/widened the camera. Garden rocks initially resembled smooth rings; changed them to asymmetric cut cavities. Broadened the crescent's usable water surface again and added layered rock edges.

Final Blender view: `screenshots/blender_heaven_v2.png`. This is a modelling review composition, not proof of solved gameplay. Actual Godot camera/UI/readability remain separately tested by the runtime task.

## Shared hub revision

Replaced the metallic tiled hub with a four-lobed moss-and-stone garden, quiet thin limestone paving, a carved wooden central bobbin/loom with four colored cords, small garden posts, stones and lantern. Original courier remains the connective character. New source: `hub_garden_v2.blend`.

## Performance and provenance

Original editable curves and petals are retained in `heaven_orchard.blend`; static export meshes are merged by material. Large trees have 12 mesh groups, not one draw call per petal. A geometry audit caught an initial 159,580-triangle tree; replacing sphere petals with cached shallow five-petal cups and lowering twig subdivision reduced it to 39,100 triangles without removing branches or flower groups. Double-tree module is 62,664 triangles, landscape 32,340 and wall 2,244. `orchard_hub_audit.json` records mesh/triangle counts and absence of image textures. No external source images enter the game.

## Remaining subjective limits

The visual result is a compact stylized garden diorama, not photorealism. The playable center remains flat by design for legible Sokoban rules. The final choice of camera framing and exposure materially affects whether the orchard appears rich or sparse; Blender previews alone cannot establish user acceptance.

---

# Historical V1 self-review (superseded, not accepted)

# Blender art self-review

## Shared language

All four worlds use the same 2-unit square ceramic tray, thick dark edge, inset brass pins, rounded cabinet-like obstacles and brass-bound reliquary crates. Forms have real bevels, weighted normals, smooth sculptural primitives and curved tubes rather than flat low-poly proxies. A single original bobbin courier links the worlds. Readable game geometry deliberately has lower height than peripheral landmarks.

## World checks and iterations

- **Heaven:** jade curved glazed roof planes with raised eave corners, vermilion columns, brass eave lines, tiered pavilion and hanging bells. An original bell-crane and porcelain cloud motifs distinguish the world without importing a pagoda model. First preview was grainy; sampling increased from 32 to 160 and the studio ground brightened.
- **Inferno:** plum enamel rounded arches, squat horned furnace, brass bowls of warm coals and a smiling coal creature. The playfield remains light enough to read rather than becoming a dark cave. Rounded arch weight and localized warm details contrast with Heaven's thin lifted eaves. The compact kit is intentionally playful, not horror imagery.
- **Rainforest:** buttress-root trees, layered broad leaves, coral wax flowers and turquoise glazed basin. Self-review rejected the first faceted paper-like leaf planes. The source was revised to curved, thick, smoothly shaded wax leaves; basin water was raised to be visibly above the bowl interior.
- **City:** elevated staggered warm towers with windows, balconies and railings, two different base heights, outside stairways, stilt supports and sloping viaduct. This is a mountain-city structural interpretation, not a copy of a real building. Self-review rejected a tube-like viaduct: it is now a deck with twin rails and sleepers. The camera was widened/raised to prevent the upper roof from cropping.

## Animation provenance

Courier idle, walk, push and celebrate are authored as six-bone Blender actions and exported as named glTF animation clips. Main limbs articulate independently. Four creatures have authored idle clips. Inferno's portal has an idle clip; the city's gate has open/close clips that move only the bar assembly while supports stay fixed.

## Limits

These are polished compact diorama kits, not a vast free-roaming world. The Blender overview composition demonstrates asset language; it is not evidence of a playable Godot puzzle. The final game camera, animation playback, UI layering and performance need separate Godot verification. Residual fine Cycles sampling noise may be visible at full image size because the installed Blender build cannot denoise. This is reported rather than smoothed with an external image filter.
