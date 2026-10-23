# Cloud interruption and recovery record

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
