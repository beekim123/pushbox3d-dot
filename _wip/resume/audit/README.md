# Rebuilt independent resume audit — recovery WIP

The previous execution workspace was lost. Historical results (46,619 isolated checks,
19,586 layout assertions, native Continue/Undo) are **not results for this reconstruction**.
No new pass is claimed until fresh logs, process outcomes, and source hashes exist.

All authored tests live here. The runner stages a PRIVATE copy of the recovered baseline
plus the author's resume overlays, then installs these tests into that copy. It does not
edit the production baseline or author-owned modules. XDG userdata is temporary and is
never put into the production source/package. Native desktop staging must use a shared
workspace path because the command executor and cloud desktop do not share /tmp.

Required retained regressions:
- Interrupted initial reader + exit timeout + Return must resume verification or visibly
  pause, not silently remain unwritable while promising automatic save.
- External token changes invalidate the old Continue candidate; reference text must not
  promise that an old checkpoint remains recoverable. External bytes remain untouched.
- Actual move/Reset/move + ordinary close during tween; fresh-process Continue; full Undo.
- Exit failure offers Return and Still exit; native GUI evidence remains PENDING.
- Full 8192 persisted history / refusal at 8193 without truncating in-session Undo.
- Foreign locks/pending, rename failure, corrupt/future originals, competing writer token.
- Footer geometry across all 204 levels and longest real status templates at 1440×900.
- Shared hints/resume scheduling is measured as a SOFT budget, not a frame deadline.

No Git operation is performed by this audit. WIP backup is delegated to the repository
sync agent. No session files are read.
