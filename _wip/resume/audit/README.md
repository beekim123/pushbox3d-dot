# Rebuilt independent resume audit — recovered workspace

The previous execution workspace was lost. Historical results (46,619 isolated checks,
19,586 layout assertions, native Continue/Undo) are **not results for this reconstruction**.
Fresh recovery runs now exist under results/. The final report separates these from
historical counts; no old result is reused as a new pass.

All authored tests live here. The runner stages a PRIVATE copy of the recovered baseline
including its frozen resume integration, then installs these tests into that copy. It does not
edit the production baseline or author-owned modules. XDG userdata is temporary and is
never put into the production source/package. Native desktop staging must use a shared
workspace path because the command executor and cloud desktop do not share /tmp.

Required retained regressions:
- Interrupted initial reader + exit timeout + Return must resume verification or visibly
  pause, not silently remain unwritable while promising automatic save.
- External token changes invalidate the old Continue candidate; reference text must not
  promise that an old checkpoint remains recoverable. External bytes remain untouched.
- Actual move/Reset/move + ordinary close during tween; fresh-process Continue; full Undo.
- Exit failure offers Return and Still exit; native GUI failure/Return/StillExit has fresh evidence.
- Full 8192 persisted history / refusal at 8193 without truncating in-session Undo.
- Foreign locks/pending, rename failure, corrupt/future originals, competing writer token.
- Footer geometry across all 204 levels and longest real status templates at 1440×900.
- Shared hints/resume scheduling is measured as a SOFT budget, not a frame deadline.

No Git operation is performed by this audit. WIP backup is delegated to the repository
sync agent. No session files are read.

## Reproduce

From the workspace root: `python3 fourfold_next/resume_audit_rebuild/run.py`.
The exact Godot 4.7.2 binary path is pinned in the runner. Each run creates a private
`_runtime/` snapshot plus unique `results/` directory and temporary XDG directories.
Nine headless processes cover storage, lifecycle, live cap, two-process restart,
protected permanent progress, exit refusal, concurrent hints, and 204-level layout.

For native checks, first prepare with `run.py --prepare-only`, then launch
`bash .../resume_audit_rebuild/native_run.sh` from the real cloud desktop Terminal.
The log prompts a native Continue click, three Z presses, OS close; then an Up press,
OS close, Return click, second OS close, StillExit click. This separate Python runner
verifies process exit and external-file preservation after the GUI closes.
Do not run executor DISPLAY hacks; the desktop and executor /tmp directories differ.

`_runtime/` and `latest.json` are disposable staging, not release resources.
Do not package XDG test data, caches, or transaction fixtures.
