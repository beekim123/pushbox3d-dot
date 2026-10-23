# Production integration addendum — 2026-10-23 17:45 UTC

**The integrated production keyboard UI passes this additional visual/evidence review.** This is a new addendum; the original independent 293-check report remains frozen with its original audit-time statement that production was still `b529ffb`.

## Source binding

Current `fourfold_atelier/scripts/main.gd` independently rehashed as:
`50ff777465b3b9320ca8fde967c264e6b2f733bbda3447bce80aed79b07bb4b8`.

It matches the final isolated candidate tested by the 293 independent assertions. Root reports integration changed only `main.gd` among 95 protected preexisting files, and production import plus 30-frame boot exited 0 without errors. Those integration/boot checks were root-run, not additional independent assertions.

## Production render review

The auditor inspected all three actual production PNGs plus `results.json`, `capture.gd`, `run.sh`, `source_before.txt`, and `run.log` at:
`fourfold_next/keyboard_navigation/qa/production_native/`.

| Actual production image | Independent visual finding |
| --- | --- |
| `title.png` | Final menu-key hint is complete and readable; gold initial Hub-action focus ring is visible and unclipped. No overlap with the progress count. |
| `help.png` | Generic title Help content and gold acknowledgment ring fit completely; obscured title actions are not highlighted. |
| `failed_exit.png` | Safe Return has the pink focus ring; destructive unsaved Exit remains visibly separate and unfocused. Text and both borders fit. |

The production capture script's post-Enter check verifies **exit_pending=false, modal=null, unchanged logical state, and no GUI focus**. `results.json` has no failures. It records production project path, final source hash, X11/llvmpipe, 1440×900 captures, and expected focus IDs (`hub`, `help:close`, `exit:return`). The log has the known software-driver VSync warning, no script/resource errors.

These production screenshots are **high-quality rendered output with injected Godot engine key events and explicit failed-save setup**. They are not a CUA-generated desktop-keyboard replay and not a physical-keyboard test.

## Meaningful comparison, not pixel identity

- Compare the title with the **final 50ff** independent `implementation_audit/desktop/001_launch.png`: identical intended menu-key copy, initial action, and focus treatment. The production run forces high quality while that independent desktop run used auto low quality; scene pixels are not expected to match.
- The final independent Help screenshot is contextual puzzle Help, whereas production captures generic title Help. Compare containment, acknowledgment focus, and clipping—not identical text, height, or image bytes.
- Production failed-exit setup is Heaven 02; final independent CUA setup is Heaven 01. Both choose safe Return, preserve the game on activation, and release GUI focus. Different backdrop/level text is expected.
- Pre-footer `5a9a4e` screenshots remain explicitly historical under `implementation_audit/snapshot_5a9a4e/`. They must not be relabeled as final 50ff evidence or used to claim title pixel identity.

## Packaging and remaining gate

`export_manifest.json` is a SHA-256-bound file allowlist with suggested repository destinations. It separates final CUA images, historical 5a9a4e images, original frozen audit text/drivers, and actual production captures. It excludes fixture runtime/assets, `.godot`, XDG directories, and user-save records. The auditor has not copied files into production.

Portable driver changes are a **new adapted harness**: fix the helper `extends` path, preserve production-root scene loads, redirect evidence outputs away from frozen records, and retain save isolation. Record adaptation smoke tests separately; do not present them as the original 293 assertions.

The completed adaptation is supplied under `portable/` with its exact path-only `adaptation.diff`. Its fresh run against actual production passed **293/293, exit 0**, with 75 pinned runtime/model/content files unchanged; see `portable_smoke_results_final/ADAPTED_SMOKE_SUMMARY.json` (2026-10-23 17:49:43 UTC). Temporary XDG saves were removed. This is new portable-smoke evidence, not a rewrite of the original 293 audit. The portable desktop observer is supplied but was not rerun graphically; the prior CUA/render evidence retains its original provenance.

**Final gate now closed:** root's fresh production full-204 handler run completed **8,056 checks / 204 levels / 0 failures / exit 0**, with all 74 pinned runtime/model hashes unchanged. The build worker's separate production author suite also passed **637 checks / exit 0**. The auditor read and bound both terminal reports in `final_regression_status_2026-10-23T1747Z.json`; these are attributed to their actual runners, not counted as extra independent assertions. The earlier pending value in `review_manifest.json` records the state at the first visual review and is superseded by this dated final status.

No runtime edits, Git writes, binary uploads, or external publication were performed by this review. The original 93-file allowlist and original 293-check report remain frozen; additional portable-driver/smoke evidence is exported separately.
