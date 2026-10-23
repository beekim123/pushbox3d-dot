extends SceneTree

var game
var checks := 0
var failures: Array = []
var observations: Array = []

func _initialize(): call_deferred("run")

func result_path(filename: String) -> String:
	var directory:=OS.get_environment("KEYBOARD_QA_OUTPUT")
	if directory.is_empty(): directory="res://tests/keyboard_navigation/results"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	return directory.path_join(filename)

func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures.append(label)
		print("KEYBOARD_FAIL ", label)

func event(code: Key, pressed: bool, shift: bool = false, echo: bool = false):
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	e.shift_pressed = shift
	e.echo = echo
	Input.parse_input_event(e)

func key(code: Key, shift: bool = false):
	event(code, true, shift)
	await process_frame
	event(code, false, shift)
	await process_frame
	await process_frame

func settle():
	await process_frame
	await process_frame
	await process_frame

func focus_id() -> String:
	var owner := root.gui_get_focus_owner()
	return str(owner.get_meta("focus_action", "")) if is_instance_valid(owner) else ""

func focus_to(action: String):
	for i in range(30):
		if focus_id() == action: return
		await key(KEY_TAB)
	check(false, "Tab can reach " + action + " (at " + focus_id() + ")")

func activate(action: String, code: Key = KEY_ENTER):
	await focus_to(action)
	if focus_id() == action: await key(code)

func snapshot() -> Dictionary:
	return {"state":game.state.duplicate(true), "history":game.history.duplicate(true), "progress":game.progress.duplicate(true)}

func ring(label: String):
	await settle()
	var scope: Control = game.modal if game.modal != null else game.ui
	var eligible: Array = scope.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree() and not b.disabled)
	check(eligible.all(func(button): return not str(button.get_meta("focus_action", "")).is_empty()), label + ": each eligible action has a semantic focus ID")
	var start := focus_id()
	var visited: Array = []
	var unique: Dictionary = {}
	for i in range(eligible.size()):
		visited.append(focus_id())
		unique[focus_id()] = true
		await key(KEY_TAB)
	check(focus_id() == start and visited.size() == eligible.size() and visited.size() == unique.size(), label + ": forward Tab visits each enabled action once and wraps")
	for i in range(eligible.size()): await key(KEY_TAB, true)
	check(focus_id() == start, label + ": reverse Tab wraps")
	check(game.ui.find_children("*", "Button", true, false).all(func(b): return b.focus_mode == Control.FOCUS_NONE if b not in eligible else b.focus_mode == Control.FOCUS_ALL), label + ": only visible enabled scope owns focus")

func flush_resume():
	var started := Time.get_ticks_msec()
	while game.resume_session.dirty and Time.get_ticks_msec() - started < 5000:
		game.resume_session.tick(game.level, game.state, game.history, 8.0, true)
		await process_frame
	check(not game.resume_session.dirty, "isolated resume checkpoint verified")

func run():
	root.size = Vector2i(1440,900)
	Input.use_accumulated_input = false
	Engine.max_fps = 240
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	check(focus_id() == "hub", "fresh title focuses Enter Hub")
	await ring("title")
	await key(KEY_ENTER)
	check(game.mode == "hub" and focus_id() == "world:heaven", "native Enter title to hub; Heaven initially selected")
	await ring("hub locked finale")
	for w in ["heaven", "inferno", "rainforest", "city"]:
		await activate("world:" + w, KEY_SPACE)
		check(game.mode == "world" and focus_id() == "level:" + w + "_01", w + ": native Space hub to first level focus")
		await ring(w + " first chapter")
		await key(KEY_ENTER)
		check(game.mode == "level" and game.level.id == w + "_01" and root.gui_get_focus_owner() == null, w + ": native Enter enters puzzle with unfocused HUD")
		await key(KEY_ESCAPE)
		check(focus_id() == "level:" + w + "_01", w + ": return restores selected level")
		for page in range(1,10):
			await activate("chapter:next", KEY_SPACE if page % 2 else KEY_ENTER)
			check(game.mode == "world" and int(game.chapter_pages[w]) == page, w + ": keyboard preview chapter " + str(page+1))
			check(focus_id() == ("chapter:previous" if page == 9 else "chapter:next"), w + ": paging focus retained or valid edge fallback")
			await ring(w + " chapter " + str(page+1))
		for page in range(8,-1,-1):
			await activate("chapter:previous")
			check(int(game.chapter_pages[w]) == page, w + ": keyboard previous chapter " + str(page+1))
		await key(KEY_ESCAPE)
		check(game.mode == "hub" and focus_id() == "world:" + w, w + ": return restores selected hub world")
	# Native spatial arrows, not gameplay input, operate in menu scopes.
	var original := focus_id()
	await key(KEY_DOWN)
	await key(KEY_LEFT)
	check(game.mode == "hub" and focus_id() != original, "native spatial arrows navigate hub without entering gameplay")
	await activate("help")
	check(focus_id() == "help:close", "menu help focuses acknowledgment")
	await ring("menu help")
	await key(KEY_SPACE)
	check(game.modal == null and focus_id() == "help", "native Space closes help and restores invoker")
	for i in range(4):
		await key(KEY_F1)
		await key(KEY_F1)
		await key(KEY_ESCAPE)
	check(game.modal == null and focus_id() == "help", "repeated F1 rebuilds and Esc preserve menu return focus")
	# Generation race: the last screen wins, and later valid mouse/native focus wins.
	game.show_title()
	game.show_hub()
	game.show_world_menu("city", 0)
	game.show_help()
	await settle()
	check(focus_id() == "help:close", "stale deferred jobs cannot focus rebuilt/obscured screens")
	await key(KEY_ESCAPE)
	check(focus_id().begins_with("level:"), "modal opened before deferred initial focus returns to valid world action")
	# Enabled/hidden transitions must repair focus and preserve a valid current owner.
	var selected: Button = root.gui_get_focus_owner()
	selected.disabled = true
	await settle()
	check(root.gui_get_focus_owner() != selected and focus_id() != "", "focused control disabling gets a valid fallback")
	selected.disabled = false
	var retained := focus_id()
	await settle()
	check(focus_id() == retained, "enabling another control does not steal focus")
	selected = root.gui_get_focus_owner()
	selected.hide()
	await settle()
	check(root.gui_get_focus_owner() != selected and focus_id() != "", "hidden focused control gets valid fallback")
	selected.show()
	await settle()
	await ring("dynamic hidden/disabled repaired")
	# Held acceptance: no echo/down may auto-advance a newly built screen.
	for code in [KEY_ENTER,KEY_SPACE,KEY_KP_ENTER]:
		game.show_title()
		await settle()
		event(code, true)
		await settle()
		for i in range(4):
			event(code, true, false, true)
			event(code, true)
			await settle()
		event(code, false)
		await settle()
		check(game.mode == "hub", "held activation reaches only one screen: " + str(code))
		event(code, true)
		event(code, false)
		await settle()
		check(game.mode == "world", "same-frame activation release/repress works: " + str(code))
	# Actual one-push completion and existing undo/reset/help semantics.
	game.start_level(game.levels_by_world.heaven[0])
	await key(KEY_RIGHT)
	await create_timer(.35).timeout
	check(game.modal != null and focus_id() == "completion:next", "real winning key focuses completion Next")
	await ring("completion")
	var before := snapshot()
	await key(KEY_F1)
	await ring("completion help")
	await key(KEY_SPACE)
	check(game.modal != null and focus_id() == "completion:next" and snapshot() == before, "help acknowledgment restores completion without gameplay mutation")
	await key(KEY_R)
	await key(KEY_Z)
	check(snapshot() == before and focus_id() == "completion:next", "R/Z restores winning state, full history, result focus")
	await key(KEY_Z)
	check(game.modal == null and root.gui_get_focus_owner() == null and not game.RULES.won(game.level, game.state), "Z completion returns to unfocused playable board")
	await key(KEY_RIGHT)
	await create_timer(.35).timeout
	await key(KEY_SPACE)
	check(game.level.id == "heaven_02" and game.modal == null and root.gui_get_focus_owner() == null, "native completion Space enters Next without HUD focus")
	# Unlocked finale and ending are reachable without making locked buttons focusable.
	game.progress.solved = game.levels.filter(func(entry): return entry.world != "confluence").map(func(entry): return entry.id)
	game.show_hub()
	await settle()
	await ring("hub unlocked finale")
	await activate("world:confluence")
	check(game.mode == "world" and game.active_world == "confluence", "unlocked finale reachable by native keyboard")
	await ring("finale chapter")
	game.show_hub()
	game.show_ending()
	await settle()
	await ring("ending")
	await key(KEY_SPACE)
	check(game.modal == null and game.mode == "hub" and focus_id() != "", "ending native return restores menu scope")
	# Real saved title Continue, including an undoable reset.
	var saved_directory := "user://keyboard_qa_" + str(Time.get_ticks_usec())
	game.initialize_resume(saved_directory)
	game.resume_session.debounce_ms = 0
	game.resume_session.interval_ms = 0
	game.start_level(game.levels_by_world.heaven[2])
	await key(KEY_LEFT)
	game.cancel_motion()
	await key(KEY_R)
	await flush_resume()
	before = snapshot()
	game.show_title()
	await settle()
	check(focus_id() == "continue", "verified Continue is title initial focus")
	await ring("verified Continue")
	await key(KEY_ENTER)
	check(game.mode == "level" and snapshot() == before and root.gui_get_focus_owner() == null, "native Continue preserves exact checkpoint/history/reset")
	game.resume_session.debounce_ms = 60000
	await key(KEY_Z)
	check(game.state.moves == 1, "native restored reset remains undoable")
	game.resume_session.protect("keyboard_qa_injected_failure")
	game.request_exit()
	check(game.exit_pending and not game.exit_waiting and game.focus_scope == null, "pending save has no action focus")
	await key(KEY_ESCAPE)
	# The next process frame reaches failure; Escape only cancels once waiting.
	if not game.exit_pending: game.request_exit()
	game.poll_resume_exit()
	await settle()
	check(game.exit_waiting and focus_id() == "exit:return", "failed-save exit selects safe Return")
	await ring("failed-save exit")
	before = snapshot()
	await key(KEY_ENTER)
	check(not game.exit_pending and game.modal == null and snapshot() == before, "native Enter safely cancels failed exit")
	game.request_exit()
	game.poll_resume_exit()
	await settle()
	await key(KEY_ESCAPE)
	check(not game.exit_pending and game.modal == null and snapshot() == before, "Escape safely cancels failed exit, never destructive")
	# Availability update is real controller verification, not direct button toggling.
	game.initialize_resume("user://keyboard_empty_" + str(Time.get_ticks_usec()))
	game.show_title()
	await settle()
	check(focus_id() == "hub" and game.resume_button.disabled, "empty Continue stays out of scope")
	game.initialize_resume(saved_directory)
	game.show_title()
	await settle()
	var started := Time.get_ticks_msec()
	while game.resume_session.reading and Time.get_ticks_msec() - started < 5000: await process_frame
	await settle()
	check(not game.resume_button.disabled and focus_id() == "hub", "asynchronous real Continue verification adds action without stealing current focus")
	await activate("continue",KEY_SPACE)
	check(game.mode == "level", "asynchronously enabled Continue is reachable by native Space")
	var report := {"engine":Engine.get_version_info().string, "checks":checks, "failures":failures, "scope":"Real Input.parse_input_event key down/up/echo in isolated QA XDG; direct setup explicitly used for locked/unlocked and exceptional state fixtures. Native GUI inspection not included."}
	var file := FileAccess.open(result_path("keyboard_navigation_results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("KEYBOARD_NAVIGATION ", JSON.stringify(report))
	await game.finish_exit(0 if failures.is_empty() else 1)
