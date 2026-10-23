# Independent resume audit (Linux, Godot 4.7.2)

From any working directory:

```sh
GODOT=/absolute/path/to/godot-4.7.2 python3 /path/to/project/tests/resume_ui_audit/run.py
```

Default engine: sibling `tools/godot-4.7.2/godot`, then PATH `godot`. The manifest
records the actual binary SHA and version; published results used exact official
4.7.2, not another version. `AUDIT_OUTPUT_DIR=/outside/project/results` optionally
chooses report storage. Default staging, reports, XDG and fixtures are temporary
directories, never game source resources. Python subprocess timeouts bound runs.

`--only storage,lifecycle` runs a subset; `--native` launches three real processes
(two GUI). Run native mode from an actual Linux graphical terminal, not an executor
without DISPLAY. Read the on-screen states and perform: Continue, Z three times,
normal OS close; next window Up, OS close, Return, second OS close, Still exit.
The script checks actual process exits and verifies external bytes after closure.
This is manual/native input, not simulated proof from a function invocation.

Nine headless processes cover full Undo-Reset resume, two historical regressions,
permanent-progress protection, malformed inputs, token races, rename refusal,
live 8193/8192 cap, throttle, held-key Return, hints concurrency, and 204-level
footer geometry. See REPORT.md for exact coverage and unverified limits.

The .gdignore excludes audit fixtures from normal Godot import; the runner copies
only scripts into a private game's audit_tests directory. Do not copy temporary
userdata, .godot caches, transaction leftovers or private snapshots into a release.
