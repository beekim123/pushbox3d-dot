extends "res://tests/keyboard_navigation.gd"

const KEYS := [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_W,KEY_S,KEY_A,KEY_D]
const DIR := {KEY_UP:"U",KEY_DOWN:"D",KEY_LEFT:"L",KEY_RIGHT:"R",KEY_W:"U",KEY_S:"D",KEY_A:"L",KEY_D:"R"}
var saved_directory := ""

func assert_held_then_repress(code: Key, label: String, before: Dictionary):
	await create_timer(.30).timeout
	check(snapshot() == before and root.gui_get_focus_owner() == null, label + ": held direction causes no state/history/progress change or HUD focus")
	check(game.help_release_keys.has(code), label + ": release latch survives screen/modal transition")
	var expected: Dictionary = game.RULES.step(game.level,game.state,DIR[code])
	check(not expected.is_empty(), label + ": fixture has a legal ordinary direction")
	# Deliberately no rendered frame between release and repress.
	event(code,false)
	event(code,true)
	event(code,false)
	await settle()
	game.cancel_motion()
	check(game.state == expected and game.history.size() == before.history.size()+1, label + ": same-frame release/repress accepts exactly one action")

func win_first():
	game.start_level(game.levels_by_world.heaven[0])
	await settle()
	await key(KEY_RIGHT)
	await create_timer(.30).timeout
	check(game.modal != null and game.RULES.won(game.level,game.state), "real first-level win creates transition fixture")

func run():
	root.size = Vector2i(1440,900)
	Input.use_accumulated_input = false
	Engine.max_fps = 240
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.progress.solved = ["heaven_01"]
	saved_directory = "user://keyboard_guards_" + str(Time.get_ticks_usec())
	game.initialize_resume(saved_directory)
	game.resume_session.debounce_ms=0
	game.resume_session.interval_ms=0
	game.start_level(game.levels_by_world.heaven[1])
	await flush_resume()
	# Keep transition fixtures from modifying the verified initial-level checkpoint.
	game.resume_session.debounce_ms=60000
	for code in KEYS:
		game.show_world_menu("heaven",0)
		await settle()
		event(code,true)
		await activate("level:heaven_02")
		check(game.level.id=="heaven_02" and game.mode=="level","held-key native level entry " + str(code))
		await assert_held_then_repress(code,"level entry " + str(code),snapshot())
	for code in KEYS:
		game.start_level(game.levels_by_world.heaven[1])
		await key(KEY_F1)
		event(code,true)
		await key(KEY_SPACE)
		await assert_held_then_repress(code,"help acknowledgment " + str(code),snapshot())
	for code in KEYS:
		await win_first()
		event(code,true)
		await key(KEY_ESCAPE)
		await assert_held_then_repress(code,"completion dismissal " + str(code),snapshot())
	for code in KEYS:
		await win_first()
		event(code,true)
		await activate("completion:next",KEY_SPACE)
		check(game.level.id=="heaven_02", "held-key native Next " + str(code))
		await assert_held_then_repress(code,"Next " + str(code),snapshot())
	for code in KEYS:
		game.initialize_resume(saved_directory)
		game.resume_session.debounce_ms=60000
		game.show_title()
		while game.resume_session.reading: await process_frame
		await settle()
		event(code,true)
		await activate("continue")
		check(game.level.id=="heaven_02" and game.mode=="level", "held-key native Continue " + str(code))
		await assert_held_then_repress(code,"Continue " + str(code),snapshot())
	for code in KEYS:
		game.start_level(game.levels_by_world.heaven[1])
		game.resume_session.protect("keyboard_guards_injected_failure")
		game.request_exit()
		game.poll_resume_exit()
		await settle()
		event(code,true)
		await activate("exit:return",KEY_SPACE)
		check(not game.exit_pending,"native failed-exit cancellation " + str(code))
		await assert_held_then_repress(code,"failed-exit Return " + str(code),snapshot())
	# Won-board exit cancellation reconciles a fresh primary completion focus.
	await win_first()
	game.request_exit()
	game.poll_resume_exit()
	await settle()
	await key(KEY_ESCAPE)
	check(game.modal!=null and focus_id()=="completion:next", "failed-exit Escape on won board recreates completion scope")
	# Movement/HUD remains unaffected by Tab and optional hint rebuilds.
	game.start_level(game.levels_by_world.heaven[1])
	await settle()
	await key(KEY_TAB)
	check(root.gui_get_focus_owner()==null, "ordinary HUD is outside keyboard focus scope")
	var before:=snapshot()
	await key(KEY_H)
	await key(KEY_J)
	await create_timer(.15).timeout
	check(snapshot()==before and root.gui_get_focus_owner()==null,"hint rebuild cannot steal focus or mutate board/history/progress")
	await key(KEY_ESCAPE)
	var report:={"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"contexts":["level entry","Help acknowledgment","completion dismissal","Next","Continue","failed-exit Return"],"physical_keys":KEYS,"scope":"Real injected key-down/up/echo; each arrow and WASD held across each listed transition; same-frame release/repress requires exactly one legal action. QA-isolated real checkpoint."}
	var file:=FileAccess.open(result_path("keyboard_transition_guards_results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("KEYBOARD_GUARDS ",JSON.stringify(report))
	await game.finish_exit(0 if failures.is_empty() else 1)
