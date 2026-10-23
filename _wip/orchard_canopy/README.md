# Orchard canopy source prototype — WIP

Frozen 2026-10-23 15:39 UTC from the author's isolated `fourfold_next/orchard_canopy`
prototype, based on main `ccaac85ccd811297176b52c69dca127963835732`.
This preserves the generator, its exact baseline and a portable source diff. Python
syntax was parsed and the patch dry-run against the retained baseline succeeded.
These checks are not Blender export, visual approval, Godot integration or release QA.
The first visual iteration is still being evaluated; production assets are not changed.

`.gdignore` keeps this backup out of project imports. Source retains original relative
project paths; do not execute it in place expecting a connected release toolchain.
Only plain text is backed up. The three prototype GLBs, .blend and PNGs remain local.
All existing binary-upload restrictions remain in effect; no alternate upload path
is used. The inherited remote game still has incomplete runtime media.

## Frozen source hashes

- `blender/generate_orchard.py`: `fb97d93a4080d513a243e830bab4ac3ecbc8f3eaf5039a124d3436ce82f361be`
- `canopy_review/orchard_canopy_source.patch`: `a38f1d2cea58c9d8c565d08381da37feefe9f2a11a7117820d43de69cbab0259`
- `canopy_review/generate_orchard.baseline.py`: `92a8cac84bd6aa8d58f1bb0ce252a9c5e8f6f4b6b2d28e7e5f4e532a2fdec747`

## Solid-fan candidate source — 2026-10-23 15:59 UTC

Current generator is copied from the author's explicit final frozen source, SHA-256
`9a76c92be8caa087569d0f9e4b3ae37b8713649a91b7f694121add4b36d631ad`.
The new final patch (SHA `f3f8db3a266e0a86d98fcf9593b8f70024777b377999c3a52493c0cb5614f328`)
applies against the retained baseline; Python syntax and patch dry-run were checked.
The earlier v1 source and patch remain in Git history.

Author reports all three AABBs within baseline, with 30,824 / 41,204 / 15,412 triangles
and 12 batches each. Those figures are author-reported at this source checkpoint,
not a new independent art acceptance. Same-camera native high/low review is still
in progress. GLBs, .blend and images stay local; production is unchanged.

## Shadow-fixed reviewed source — 2026-10-23 16:17 UTC

The current generator comes from the explicitly frozen reviewed source, SHA-256
`4077183a1854e81c594557adc6938baecb97c97de1fc9d523ef458a6a0dc9c11`.
The exporter-sort experiment was reverted; the new accepted patch is retained
separately from earlier iterations. Syntax and baseline patch dry-run passed here.

The author reports internal independent visual review, eight native capture cases,
204 camera checks without clipping, and a 62-asset audit. This is not user art
acceptance or a claim that this Git branch has the reviewed binary assets. The
five-file local integration allowlist and exact source/asset hashes are preserved
in canopy_review/integration_manifest.json; only its textual record is uploaded.

Byte-for-byte exporter reproducibility is explicitly unsupported: GLB exporter
ordering varies. The recorded delivery hashes identify exact reviewed assets;
semantic geometry checks are a different claim. GLBs, .blend and images remain
local under the unresolved binary upload restriction. No production Git paths
are changed by this isolated WIP checkpoint.
