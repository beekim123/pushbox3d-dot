# Independent keyboard implementation audit

## Result

**Pass for the bounded keyboard-navigation scope: 293/293 independent assertions, no runtime defect found.**

Final candidate `scripts/main.gd` SHA-256:
`50ff777465b3b9320ca8fde967c264e6b2f733bbda3447bce80aed79b07bb4b8`.

Production remains `b529ffb595d043cf74216a3f603efe20bc0ba69572b8d70d432bbdfe6a9a586e`; this audit changed no production files and performed no Git write/upload. The baseline 45-check gap report remains intact one directory above. Author full-campaign/aggregate regression is a **separate acceptance gate**, not included in this count.

| Independent suite | Checks | Evidence |
| --- | ---: | --- |
| Engine event / Button-dispatch audit | 237 | `results.json`, `run.log` |
| Explicit unsaved exit in three separate processes | 12 | `exit_enter/space/keypad.json` and logs; each process actually exited with status 0 |
| Continue invalidation and missed-keyup/focus fallback | 44 | `fallback_results.json`, `fallback.log` |

Reproduce headless tests with `bash fourfold_next/keyboard_navigation_review/implementation_audit/run_all.sh`. Tests instantiate byte-matching copied runtime scripts and use QA-isolated XDG/user-save directories. No author test assertions are counted as independent checks.

## What was verified

- An initial keyboard-only **engine-event** journey from title through hub into all four worlds and their first puzzle; native Godot Button dispatch receives `Input.parse_input_event`, not direct screen-handler calls. Later special fixtures explicitly use direct setup.
- Initial and return focus; full forward/reverse Tab cycles; locked finale/levels/Continue excluded; chapter paging and edge fallbacks; modal-only containment; puzzle HUD remains unfocused.
- Dynamic enable/hide/disable/removal; asynchronous real Continue verification does not steal focus. A real isolated checkpoint changed on disk while Continue was focused is rejected, preserved read-only, and safely falls back to Hub without changing game state/history.
- Enter/Space/keypad Enter, echo and repeated-down suppression, same-frame fresh activation, rapid screen/modal replacement, stale deferred jobs, repeated F1, and focus repair after loss of the owning Control.
- All eight directions held through Help dismissal remain blocked until release; subsequent press accepts exactly one normal action. Completion dismissal, help-after-completion, reset/undo reconciliation, optional hints, exact resume history, safe failed-exit Return/Escape, and all three deliberate unsaved-exit activations.
- Missing-keyup fallback is independently simulated by temporarily disabling **only main's `_input` callback during engine key-up**, then reenabling before `_process`. This proves stale movement/activation latches clear without ghost input; it is not a physical-keyboard focus-loss test.

## Rendered desktop / visual evidence

The auditor separately used **CUA/Sky-generated X11 key input** on the actual rendered Linux game, not `Input.parse_input_event` or pointer activation. This is native desktop interaction but **not a human physical-keyboard test**.

Final `50ff777` evidence is in `desktop/`, `desktop/events.jsonl`, and `desktop.log`:

1. New title hint renders completely: “菜单：Tab / 方向键选择 · Enter / Space 确认 · Esc 返回”; primary focus ring is visible and unclipped at 1440×900.
2. Desktop Enter → hub, Space → Heaven menu, Enter → first puzzle; F1 → focused Help, Esc → unfocused unchanged board.
3. Observer F9 deliberately creates a protected-save failure fixture; the actual failed-exit dialog selects safe Return. Desktop Enter closes it, preserving level, move count, history count, and unfocused HUD.
4. The observer is test-only: it records key metadata/state and actual viewport PNGs; F9 is explicitly setup and F8 performs orderly cleanup. It never injects navigation keys or modifies candidate runtime scripts.

Earlier `5a9a4e` evidence is preserved, not relabeled, under `snapshot_5a9a4e/`. That desktop run additionally verified Right/Tab/Space hub navigation, Help Tab/Shift-Tab containment, a winning Right move → completion → Space Next, selected-level return, and **observed actual Alt-Tab away to Terminal and back** retaining selection. CUA's arrow events carried `physical_keycode=0`; therefore desktop arrow taps do not replace injected-physical-key held/release coverage. The recorded Enter/Space events had usable physical keycodes.

The author’s 16 rendered focus captures were independently inspected as a contact sheet, with full-resolution title/help/failed-exit/city-chapter checks. Accent rings are distinct from unfocused borders, do not clip labels, and mark the safe failed-exit action. They span all four world themes, completion, Continue, finale, and ending. This is limited visual inspection, not broad accessibility certification.

## Source and evidence boundaries

- `source_final.json` proves all copied runtime scripts match the final candidate and records unchanged production main hash.
- `title_copy_delta.diff` proves final `50ff777` differs from audited `5a9a4e` only in the title footer string; final 293 checks and final desktop title/path were rerun against `50ff777` rather than silently inheriting the old hash.
- `SUMMARY.json` is the concise machine-readable result. `snapshot_5a9a4e/` preserves the earlier 249-check run and its desktop evidence separately.
- The supplemental harness initially referenced an unbound Godot Input method and failed to parse. This **test-harness error**, preserved in `fallback_harness_parse_attempt.log`, was corrected to the explicit missed-delivery simulation described above; the final harness runs cleanly.
- Rendered environment: Godot 4.7.2, X11, llvmpipe software rendering, auto low-quality mode. Only the known unsupported VSync-change warning appeared in desktop logs. No physical hardware keyboard, hardware GPU, macOS/Windows, gamepad, or broad accessibility claims.
- GUI cleanup verified: no Godot window remained; only the preexisting Terminal was left open. No desktop process is awaiting a decision.
