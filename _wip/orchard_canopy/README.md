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
