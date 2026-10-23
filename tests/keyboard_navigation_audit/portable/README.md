# Portable adaptation of independent keyboard audit

Only the helper `extends` path and evidence output paths differ from the original four audit drivers; see `adaptation.diff`. The runner accepts any explicit project path and uses a temporary XDG home, removed on exit. It never clones assets or runtime scripts.

```sh
GODOT=/path/to/godot-4.7.2 bash run_portable.sh /path/to/project /path/to/new-evidence
```

The evidence directory must be writable and should be a **new destination**, never the frozen original report. The runner checks Godot 4.7.2, runs core + three terminating-exit variants + fallback, validates all 293 assertions, and compares pinned production runtime/model/content hashes before/after. `ADAPTED_SMOKE_SUMMARY.json` identifies this as a fresh adaptation run, not the original independent293 evidence.

`desktop_observer.gd` is supplied with equivalent portable output paths but is not part of the headless runner. Set `KEYBOARD_AUDIT_OUT` and isolate XDG when using it in a coordinated GUI slot. Its F9 deliberately sets up failed-save confirmation; F8 exits the test process. Headless smoke does not claim to re-execute the original desktop UI sequence.
