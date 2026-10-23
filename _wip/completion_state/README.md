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
