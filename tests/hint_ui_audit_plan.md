# Independent production hint-UI audit plan

Status: original preparation checklist. See `hint_ui_audit_report.md` and `hint_ui_audit_summary.json` for the completed audit and exact evidence boundaries.

Only this audit's `tests/hint_ui_audit*` files may be changed by the auditor. Runtime owns `main.gd`, `world_view.gd`, and solver integration. Use actual Godot4.7.2 with isolated writable XDG directories and `--qa`; no primary save writes or Git writes.

## Required observed flows

1. Real hint button/key handler requests the current board, not the stored opening state. Final accepted design: first layer is a conservative generic rule/clue without search or a box highlight; second layer explicitly requests the next box/direction; third layer explicitly reveals only its approach route. No automatic player movement, crate movement, history/progress/counter changes during search or expansion.
2. Real close handler and Escape discard overlays and invalidate generations. Repeat requests while pending must not accumulate requests or return a stale first request. Moving animation/buffered-direction interruptions must not expose a hint for a board that is changing.
3. Actual legal move, undo, reset, undo-reset, win/undo-win, same-level restart, another level, world menu, hub, title, and help/modal handling are checked. Any prior highlight or route is gone after invalidation; old tokens are not current.
4. Force a genuine solver budget terminal path after the real UI handler starts a request, then observe the production process handler's text and controls. Never describe budget exhaustion as an established deadlock. Known legal unsolvable and completed fixtures are separate branches.
5. Enter a menu during a live search with allocated nodes; continue actual SceneTree frames with no active hint until `has_pending_cleanup` is false. A persistent solver instance must service cleanup across level/menu changes.
6. UI geometry checks for new controls plus actual capture review at supported 1440x900 layout. Review visual emphasis, board occlusion, route/arrow visibility and Chinese text fit. Headless functional checks alone do not validate pixels or rendered frame pacing.

## Evidence boundaries

- UI test uses production scene, original PuzzleRules, public handlers/buttons and actual process frames. Search-limit injection is used only to reliably exercise budget messages, not to expose a production UI override.
- Fixed legal midgame fixtures are copied from the independently checked prototype suite; they are not a replacement for real handler flows.
- Soft frame budgets remain soft. Prior large-cap cleanup spikes are retained in the solver audit. Production default cap must remain 8000, with no arbitrary higher UI budget input.
- Final report must include exact source hashes, assertion count, Godot version, logs, screenshot paths reviewed, and separate unverified coverage.
