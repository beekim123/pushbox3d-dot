# Cloud interruption and recovery record

## Completion-state repair source checkpoint — 2026-10-23 15:55 UTC

This main checkpoint now repairs completion presentation after winning Reset/Undo,
help dismissal, resume and exit-return transitions. Registration and presentation
are separate; repeated feedback/score registration is avoided, and ordinary
movement respects an Esc-dismissed panel. Only runtime main.gd changed from the
F1 checkpoint `ccaac85ccd811297176b52c69dca127963835732`. Its final SHA-256 is
`b529ffb595d043cf74216a3f603efe20bc0ba69572b8d70d432bbdfe6a9a586e`.

Fresh evidence: 3,187 independent assertions (298 completion + 193 help behavior +
2,696 help layout), with 920 engine key events and 12 mouse events counted separately;
four final native 1440×900 images were viewed locally. The corrected audit runner
was fully rerun. The new original-handler regression completed all 204 levels with
8,056 checks, zero failures, exit 0; author focused checks passed 14. These are scoped
new results, not previous stage totals relabeled. Full source/test locks and limits
are under `tests/completion_reconcile_audit/`.

WIP history is preserved through `a2063ffd584acdff1cfac6932f94f3a95383e1bd`. Neither
WIP nor the separate orchard prototype is merged into this production tree. The
14:57 resume archives listed below remain useful recovery fallbacks but do not
contain F1 or this completion repair. No new complete archive is claimed here.

Remote binary migration remains 47/62 GLB, 0/18 audio, 0/6 Blender sources; these
new screenshots also remain unuploaded. The unresolved binary confirmation was not
retried or bypassed. This is not a complete runnable remote release or user art
approval. Repository-only documentation additions after author freeze are recorded
in `COMPLETION_SOURCE_CHECKPOINT.json`; all previous incident history is retained.

---

## Latest source checkpoint and newer recovery archives — 2026-10-23 15:32 UTC

The F1 contextual-help integration is now in this main source checkpoint: chapter
practice wording plus help-close key-release protection. Final sources are locked
in `tests/context_help_audit/FROZEN_TEXT_MANIFEST.json`; focused review passed 2,889
assertions plus 352 separately counted parsed key events. Six final X11 captures
were independently inspected locally. A native WASD A hold of 1,273 ms passed;
physical-arrow-key and OS autorepeat limits remain explicit in the report. A new
204-level original-handler run also completed: 7,852 checks, zero failures, exit 0,
with unchanged input hashes. This does not reuse the earlier interrupted run.

The newer complete resume-stage archives are a recovery fallback for main `77e1d7b`,
including daylight and resume, **before this F1 change**:

| File | Bytes | SHA256 |
| --- | ---: | --- |
| Loom_Resume_Full_4.7.2.zip | 38149510 | 2d1d3a908ac921f7397d5a9fa582b88062fab15724e2a1dd8460f655dff9184b |
| Loom_Resume_Project_4.7.2.zip | 17015505 | d35c4e7f27e741323c71618d9461f21a93346756f412c4fa6b48a8fac5b46a1b |

The full archive was durably saved. Native delivery of the Project archive was
accepted at 2026-10-23 14:57 UTC; this is not proof of user download or art acceptance.
Both contain the complete local binary assets. Earlier 12:42 hints archives remain
historical, not the newest recovery baseline. No private storage identifiers are
published. The archives are separate from the still incomplete GitHub asset migration.

GitHub still has 47/62 GLB, 0/18 audio, and 0/6 Blender sources. Context-help PNGs
were not uploaded. New binary uploads remain paused under the unresolved confirmation.
The WIP history remains on `work/context-help` through `156d9f2`; this main tree does
not include `_wip` or private userdata. Repository-only documentation changes after
author freeze are recorded in `CONTEXT_HELP_SOURCE_CHECKPOINT.json`.

---

## Recovered and revalidated — 2026-10-23 14:39 UTC

The complete delivered project backup has been restored in the recovered cloud workspace.
The four interrupted resume source modules were reconstructed and matched against their
original SHA-256 records before testing. The production store has only the recorded
preload-path adaptation (`a90ec821...`); the isolated original store remains preserved on
`work/resume-rebuild`. WIP source/evidence history is retained through `e327ae2b12d3432c5a4b0f6ce2fd1b74e185b08e`.

This main checkpoint now includes the recovered production Continue/save integration,
not the isolated WIP project. Fresh post-recovery evidence: 13,164 independent assertions
(13,114 headless + 50 native, 12 processes); the portable headless repeat passed 13,114
again and is not added to that headline. Original gameplay with audio was rerun across
204 levels: 7,852 checks, zero failures, exit 0. All runtime source locks match. See
`tests/resume_ui_audit/REPORT.md` and `tests/results/resume_recovered_handlers.json`.

The following 13:25 note is retained as dated history. Its statements that resume was
not in the checkout apply to `f421db6716fbac6ae1de326b02758e9376ac48a4` and earlier, not
this recovered source checkpoint. The 13:12 interrupted regression remains uncompleted
historical evidence and is never counted as a pass. Earlier delivered V2+hints archives
still do not include the later resume feature.

Remote assets remain incomplete: 47/62 GLBs, 0/18 audio, 0/6 Blender sources; six native
resume screenshots and other PNG evidence are not uploaded. New binary uploads remain
paused under the unresolved confirmation. These local tests do not make this remote
checkout a complete runnable distribution, prove macOS support, or establish user art
acceptance. No blocked content was sent through a substitute route.

Repository-only documentation banners/this dated note were added after the author's
final document snapshot. Original `evidence/final_hashes.json` is retained unchanged;
`RESUME_SOURCE_CHECKPOINT.json` records source-to-repository document transformations.

---

## Historical interruption note (2026-10-23 13:25 UTC)

Updated: 2026-10-23 13:25 UTC. This is a recovery note, not a release or test-pass declaration.

## Verified remote checkpoint

- Last implementation commit before this note: `9a8ffccc89e8cfc24bce2726fc6eb735631a6590` (restrained daylight lighting).
- Prior complete source milestones: `6c9aaed7e27b9b6e288f32d1d9cbc63ce8a79286` (progressive hints), `7ce361e4a54a6b06864d74468391d96347d60c7e` (teaching-text corrections).
- The remote checkout is still incomplete: 47 of 62 GLBs, zero of 18 audio files, and zero of six Blender source files were linked to the branch. Fifteen GLBs, all audio, all Blender sources and screenshot evidence remain to be migrated. See REPOSITORY_STATUS.md.
- New binary blob uploads remain paused pending an unresolved upload confirmation. Do not treat a blob uploaded without a branch reference as a backed-up project. Do not work around the pending confirmation by changing the binary-upload route.

## Complete project already delivered separately

Two native attachments were sent to the owner on 2026-10-23 at 12:42 UTC:

| File | Bytes | SHA256 |
| --- | ---: | --- |
| Loom_V2_Hints_Project.zip | 16902340 | ceddccc91bf13ca9ed59f0ab662a8b391f37960e2a11468aa27024174e0bfacf |
| Loom_V2_Hints_Screenshots.zip | 17708438 | db2b4b0abd8bf089c8bfe9726da34b786538f2a3cbbc7ed9950e292c0791ebc8 |

The Project archive contains the runnable Godot project, all 62 GLBs, 18 original audio resources, six .blend sources, and generation scripts. The screenshot archive is not needed to play. These are the V2 + hints stage, before the later daylight lighting change and before in-progress resume integration. Delivery acceptance is not evidence that the owner downloaded or approved the art.

The combined 34.6 MB archive exceeded the chat attachment limit, so the two files above are the actual delivered artifacts.

## Environment failure

At approximately 13:15 UTC the cloud execution environment became unavailable. Process creation failed with `exec-server transport disconnected`; the graphical automation connection was also removed. Subsequent recovery probing did not restore the environment. No replacement cloud coding environment was listed at that time. Work was not moved to the owner's computer.

The interrupted workspace may still contain uncommitted files; inability to access it does not prove deletion. Conversely, those files must not be claimed to be remotely backed up.

## Resume feature: work in progress, NOT in this checkout

Before the disconnection:

- An isolated resume codec/store prototype passed 7,368 author assertions and 46,619 independent checks, including actual subprocess restarts, competing writers and process termination around rename boundaries.
- The design uses a separate sidecar and preserves permanent progress V2. It reconstructs the complete surviving Undo history including Reset. The 8,192-action persistent-history cap does not truncate in-session Undo.
- The prototype is not hard real time. Large-history destruction/validation and synchronous file operations can exceed the requested soft slice budget.
- Production integration was written in the unavailable workspace: optional Continue, debounced saves, revision checks, bounded exit attempt, failure confirmation and protected old files.
- Independent integration tests found and prompted fixes for cancelled initial validation silently disabling saving, and for an externally invalidated candidate still being presented as recoverable. The final aggregate after these fixes was not completed.
- Actual native Continue + three Undo actions + window close was observed, and footer projection checks covered 204 levels × six text states. These partial results do not certify the unfinished integration.

The production resume source and its final reports have NOT been committed here or included in the delivered archives. Do not advertise Continue as available in the current repository or delivered V2 + hints build.

A new full 204-level handler regression was started at 13:12 UTC and interrupted by the environment failure. Its completion/exit code was not observed. The previous 7,852-check pass applies to the earlier hints checkpoint, not automatically to the interrupted resume integration.

## Recovery procedure

1. Restore access to a usable cloud execution workspace. Preserve any recovered working tree before changing it.
2. Read the actual current Git branch head; never force-push over concurrent changes.
3. Recover full runtime assets and Blender sources from the delivered Project archive, checking its SHA256. Avoid replacing newer validated assets with an older partial remote asset snapshot.
4. Keep the verified V2 + hints build as a fallback. Apply the reviewed daylight change separately if reconstructing from that archive.
5. If the interrupted resume files can be recovered, preserve them on a clearly marked WIP branch before further edits. Verify actual contents rather than reconstructing a supposedly identical file from memory.
6. Rerun imports, original gameplay regression, resume failure/exit/restart tests, final source-hash locking, font coverage and actual screenshots on the final recovered version.
7. Only after observing completion should TEST_REPORT.md and a release artifact state that the recovered version passed. Resolve the outstanding binary-upload confirmation before resuming those uploads.

No macOS, Retina, hardware-GPU performance, physical power-loss durability or final art acceptance is asserted by this note.
