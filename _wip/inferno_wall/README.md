# Inferno wall C0.80 — isolated WIP source preservation

Current frozen candidate: 2026-10-23 16:53 UTC. Root selected C0.80; final native rendering, camera/assets, semantic rebuild and independent review remain pending for this checkpoint. This is not a production/main promotion or user aesthetic acceptance.

The source and patch update the earlier syntax-only backup preserved at `b0db72f235b04f0be5a8e9f48de15523a6bc5dce`. The branch retains its production baseline `32b74c8ee98d91ec4fa815020bc5686596a1c3a7`. Only this isolated ignored directory changes; no runtime, gameplay, camera, lighting, terrain or production assets are changed in the branch.

Read `STATUS.md` for the selected cosmetic tradeoff: some ivory locator-tooth surfaces are newly obscured. Do not claim zero occlusion. The core ring/portal/legal-center result is sampled, finite and not area-weighted, with portals at initial pose; rejected B0.88 is not this candidate.

Author source SHA256: `d11994eaaf30cd29c2cc916e05dc8151137c788ca1c50af64811396e5f515021`.
Patch SHA256: `68a0e1caac46a3d8929fa197689df5e932cd6c56b2e8b7d07798a42a51b6b859`.
Author status SHA256: `f2141682c540674c4ecd8752a24c0021e2cc2f80a4f55bb76a8bc9eb49c43b87`.

Python syntax was checked again while freezing this backup, without executing Blender. This directory is not a self-contained build; no GLB, .blend, image, audio, cache or user data is uploaded. Existing binary-upload restrictions and the inherited incomplete checkout remain unchanged.
