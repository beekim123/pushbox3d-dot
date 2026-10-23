# Independent interrupted-puzzle resume audit — recovered workspace

**Result: 13,164 fresh checks passed, zero failures, across 12 actual Godot processes.**
This is Linux testing of the restored production integration, not a macOS release claim.
No pre-outage result is counted. The old 46,619 / 19,586 / interrupted 65-check runs are
historical only. Reconstructed tests were rerun against the recovered files.

## Frozen input and evidence

- Official Godot **4.7.2.stable.official.ed1daf0bf**, executable SHA256
  `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`.
- Final headless run: **2026-10-23 14:27:52–14:28:47 UTC**, 9 processes, **13,114 checks**.
  `evidence/headless/manifest.json` records commands, separate exits, input hashes,
  and before/after equality. The private staged source matched production input bytes.
- Native run: **2026-10-23 14:22:53–14:25:46 UTC**, 3 processes, **50 checks**;
  `evidence/native/manifest.json`. Writer PID 43 (headless), reader PID 57 (X11),
  external-change failure PID 136 (X11), all exited 0. A real cloud desktop supplied
  pointer/key/window-manager input; this was not the user's Mac.
- Every process used isolated temporary XDG userdata. The audit did not modify runtime
  source, author tests, real progress or real player saves. Approved export adds only
  this dedicated test subtree and `screenshots/resume/`.

| Runtime input | SHA256 |
|---|---|
| `scripts/main.gd` | `f4768bae8bedcae981afa1c25051acd23b16d31c7af741b1a7ff15415372c93f` |
| `scripts/resume_controller.gd` | `fecc26a2c27bbe3bdf569efb4e22b4084b167dfa08b8effe93b7ec07a9bda862` |
| `scripts/resume/resume_codec.gd` | `5bbb79cbaffab0fd70ec310c9914b10bba9259ca58515ac65c0a83c97d102305` |
| `scripts/resume/resume_store.gd` | `a90ec821acca7ca32e28e9700a63cdf023d94bc9b9d0b18c6352f2fdca2430b3` |
| `scripts/puzzle_rules.gd` | `260130edbe5978fc610a5e8fcc2f84ff19e8fc8beb16d3a2971790f1cc68df64` |
| `scripts/world_view.gd` | `b73a8cad67115445cf9c9bdb0c6312dd5280a0fe43c1c2ddc0ec11b021893a6d` |
| `assets/levels.json` | `3658774f0015b859ff27e13b0ef48c6e5071df921d0d155be797565de302fcda` |

The integrated store differs from the isolated author's `c3840e3...` only in its preload
path. The full input list, including assets and test scripts, is in the manifest.
Documentation hashes are recorded separately after the author's authorized report update;
document/report export is not treated as a runtime-source change.

## Fresh coverage

| Suite | Checks | What was actually exercised |
|---|---:|---|
| Storage/codec | 138 | Exact current state and all surviving Undo including Reset; hostile/oversized/deep/invalid-UTF8 bytes; unsupported versions/rules/fields; re-signed impossible history; changed level geometry; terminal replay; stale revisions and disk tokens; actual file commits, foreign pending/lock preservation, injected rename failure; read-only future originals. |
| Lifecycle | 57 | Actual scene and dispatched input, explicit Continue, two Undo operations, 1-second debounce / 5-second cadence, held direction through Return, release/repress, the two historical regressions below, exact original bytes retained. |
| Live persistence cap | 9 | Valid 8,193-Reset snapshot fixture rejected without shortening the live Undo stack; explicit 8,192 warning; actual Undo to 8,192 allows a complete new checkpoint. |
| Restart writer / reader | 7 + 12 | Actual two processes; move/Reset/move, close while real tween and opposite buffered direction exist, saved logical endpoint only; fresh-process explicit Continue, all three Undo operations exact. |
| Permanent progress | 12 | Non-QA startup with future-format progress sentinel and completed checkpoint; completion reconciled in memory, terminal state undoable, permanent progress bytes unchanged. |
| Failed-exit dispatch | 15 | Actual foreign lock, refusal, Return, second refusal, StillExit; post-process byte and lock checks, actual exit 0. |
| Shared hints / save | 10 | Actual `_process` scheduler, active hint solver plus 512 valid Reset snapshots; Undo invalidates writer, only newest 511 snapshots commit, no autoplay or history/progress mutation. |
| Footer layout | 12,854 | All **204 levels × 7 real status strings = 1,428 layouts**, **30,184 legal-floor projections**, zero footer intersections. Actual 1440×900 camera/control geometry; all footer labels/buttons enclosed. Status fixtures are layout tests, not fabricated save successes. |
| Native writer / reader / failure | 7 + 20 + 23 | Actual X11 Continue, three Z presses including Undo Reset, ordinary Alt+F4; real external-file replacement invalidates candidate, native Up/Alt+F4, Return, another Alt+F4 and StillExit. Parent process then confirms the external replacement bytes survived exactly. |

The three extra post-process assertions for the dispatched exit and the native preservation
check are required pass conditions, not added to the 13,164 GDScript assertion count.

## Historical bugs rechecked

1. **Interrupted initial verification silently disabled saving:** a valid 8,192-action file
   remains under validation, a fresh level starts, 1 ms exit deadline expires, Return is
   selected twice. The recovered implementation now reports explicit `paused` state and
   `initial_verification_cancelled` protection. Old bytes and the full current Undo survive;
   it no longer claims autosave is active while permanently unwritable.
2. **Stale candidate and false disk-recovery promise:** after a verified checkpoint, the
   test replaces the actual sidecar with external future-format bytes. The next save
   detects the token change, clears the old candidate, disables Continue, and retains
   only a clearly marked reference summary. The exit warning does **not** promise that
   the old record remains recoverable; external bytes are not overwritten.

No additional implementation defect was found by these recovered runs. Conservative
read-only fallback is intentional; returning to play does not silently steal a lock or
retry over unverified external data.

## Native visual review

The auditor directly viewed the native title, restored board, Undo-Reset result, paused
footer, latest failed-exit dialog, and returned unsaved game. The exported 1440×900 PNGs
were also opened, including the full warning with both buttons. The warning explicitly
says the summary is reference only, recovery is not guaranteed, and unsaved changes will
be lost on exit. No text/button clipping was observed in these captures.

Files under project `screenshots/resume/`: `native_title.png`,
`native_restored.png`, `native_undo_reset.png`, `native_paused_footer.png`,
`native_exit_failure.png`, `native_return_unsaved.png`.
Rendering used Linux X11 llvmpipe, production low-quality fallback. The cloud desktop is
1364 pixels wide and can clip the window's right edge; the saved application viewport is
1440×900. Full viewport geometry was independently checked for all levels above.

## Limits — not claims of unlimited persistence or hard realtime

- **Persisted history is capped at 8,192 actions / 64 KiB.** Refusal preserves in-session
  Undo; this is not unlimited saved history. The large-history fixtures are valid Reset
  snapshots, not thousands of human/native keystrokes.
- The **2 ms budget is soft**. Final shared scheduler maximum was **9.616 ms**; the live
  8,192-history tick maximum was **3.072 ms**. Earlier fresh recovery repetitions reached
  12.740 ms and 5.635 ms respectively. Allocation, destruction, full-file operations and
  cancellation are not hard time-bounded; ordinary-exit wall-clock checks cannot interrupt
  a single blocking operation. No hitch-free guarantee is made.
- A checksum detects accidental corruption, **not hostile tampering/authentication**.
  The suite intentionally accepts a changed but valid, correctly re-signed replay.
- Atomic same-directory replacement and cooperative lock/token checks do not imply
  protection against arbitrary hostile filesystem manipulation or hardware power loss.
  This recovery round injects rename failure and preserves unknown pending/lock files;
  the old SIGKILL-before/after-rename evidence was **not rerun or reused**.
- RULESET is a semantic version, not a hash of rule source. Geometry fingerprint changes
  are detected; rules behavior changes still require an intentional RULESET update.
- No macOS/Windows export, touch/gamepad, other resolution, network filesystem, arbitrary
  noncooperative multi-writer, or physical power-loss testing is claimed. All-level footer
  projection is not a fresh independent all-level gameplay-solution proof.

See README.md for the portable Python runner, `GODOT` override, temporary outputs,
subprocess timeouts, and explicit native-input sequence. Raw original evidence remains
under `fourfold_next/resume_audit_rebuild/results/`; release evidence includes only selected
final JSON/small logs and screenshots, never userdata or corrupt checkpoint fixtures.

## Portable export verification

The release runner was actually executed with an explicit `GODOT` override and an
external report directory on 2026-10-23 after export. All nine headless processes
passed again (13,114 checks); `evidence/portable_runner_manifest.json` contains
this separate reproducibility run. It is not added again to the 13,164 headline.
The export initially exposed a harness-only stage-hash path bug; this was corrected
before the complete portable rerun. No game source was changed. The native proof
above comes from the original real-desktop launcher, not from a second native run
of the portable wrapper.
