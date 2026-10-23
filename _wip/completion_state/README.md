# Completion-state repair — first WIP source checkpoint

Frozen 2026-10-23 15:40 UTC, based on tested main
`ccaac85ccd811297176b52c69dca127963835732`.

The first bounded repair separates win registration from completion presentation,
reconciles a winning board after Undo, restores completion after help dismissal, and
avoids repeated feedback during resume/exit restoration. The integration harness
no longer manually repairs the completion UI after winning Reset/Undo.

Only this first authored main.gd is preserved. Independent behavior/native review
has not completed for this snapshot; do not interpret source backup as a tested fix
or production promotion. Follow-up corrections will be separate commits.

The copy is isolated under `.gdignore` and retains original production preload
paths. It is not a standalone runnable WIP project. No production paths in this
branch were replaced, and the parallel orchard prototype is not included.
All binary-upload restrictions remain in effect; no binaries or private userdata
are backed up by this checkpoint.

Source SHA-256: `9e42102d54ba591985c1d0b728ebc3f503aeaf5095779adb306ea07d3a911874`.

## Dismiss-aware correction — 2026-10-23 15:42 UTC

Review of the first draft found ordinary movement could reopen a completion panel
after Esc dismissed it. The next candidate preserves ordinary dismissal through a
tween and reopens only on explicit restore operations. Author reports 11 focused
assertions passing; final independent verification remains pending.

Current main.gd SHA-256: `b529ffb595d043cf74216a3f603efe20bc0ba69572b8d70d432bbdfe6a9a586e`.
The initial 9e42102d draft remains historical and is not the current candidate.

## Author/root regression evidence — 2026-10-23 15:47 UTC

The candidate source still has SHA b529ffb5…. The author supplied 14 passing focused
reconciliation checks, and the parent observed a fresh 204-level original-handler
run completing 8,056 checks, zero failures, exit 0. Its source map/log hash were
checked when frozen; evidence is retained under tests/results/.

Independent review is still running. Author documentation is not frozen yet and is
intentionally omitted from this increment. No final acceptance/main promotion is
implied; these are new scoped results, not reused context-help counts.

## Final independent evidence frozen — 2026-10-23 15:53 UTC

The final corrected runner was completely rerun, exit 0. Frozen independent results:
3,187 assertions = 298 completion-focused + 193 help behavior + 2,696 help layout;
920 engine key events are counted separately. Four final native 1440×900 images
were viewed by the reviewer, recorded in visual_review.json; PNG bytes remain local.
The original native capture manifest retains its capture-time Pending wording,
closed by the later visual review rather than silently rewritten.

FROZEN_TEXT_MANIFEST.json locks the 24 result/source text files and all 12 runtime
inputs. Its own SHA-256 is 3de2f62bec53c1004fa30cbc0404fb3e2348cef3ad63659699ab6d1acc90768c.
The previously captured run.sh had an aggregation-index typo; this checkpoint
replaces it with the corrected, rerun version. Main promotion still requires the
parent's final authorization. No old result or screenshot upload is implied.
