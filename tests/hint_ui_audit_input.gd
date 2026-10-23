extends "res://tests/hint_ui_audit.gd"
func real_click(button: Button) -> void:
	var center:=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new()
	motion.position=center
	motion.global_position=center
	Input.parse_input_event(motion)
	var down:=InputEventMouseButton.new()
	down.button_index=MOUSE_BUTTON_LEFT
	down.position=center
	down.global_position=center
	down.pressed=true
	Input.parse_input_event(down)
	await process_frame
	var up:=InputEventMouseButton.new()
	up.button_index=MOUSE_BUTTON_LEFT
	up.position=center
	up.global_position=center
	up.pressed=false
	Input.parse_input_event(up)
	await process_frame
	await process_frame
func click_hint(action: String) -> void:
	var buttons:=hint_buttons(action)
	check(buttons.size()==1,"one actual pointer target "+action)
	if buttons.size()!=1: return
	check(buttons[0].focus_mode==Control.FOCUS_NONE,"pointer target cannot steal movement key focus")
	await real_click(buttons[0])
func real_key(code: Key) -> void:
	var down:=InputEventKey.new()
	down.keycode=code
	down.physical_keycode=code
	down.pressed=true
	Input.parse_input_event(down)
	await process_frame
	var up:=InputEventKey.new()
	up.keycode=code
	up.physical_keycode=code
	up.pressed=false
	Input.parse_input_event(up)
	await process_frame
func run() -> void:
	Engine.max_fps=240
	Input.use_accumulated_input=false
	root.size=Vector2i(1440,900)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	solver_instance=game.hints.get_instance_id()
	for scheme in ["arrow","wasd"]:
		game.start_level(level_by_id("heaven_03"))
		await process_frame
		await process_frame
		var before:=snapshot()
		await click_hint("toggle")
		check(game.hint_tier==1 and is_instance_valid(game.hint_panel),"real pointer click opens hint "+scheme)
		await click_hint("advance")
		await wait_hint()
		check(game.hint_status=="solved" and game.hint_tier==2,"real pointer click starts solver "+scheme)
		await click_hint("advance")
		check(game.hint_tier==3,"real pointer click reveals optional route "+scheme)
		unchanged(before,"three real pointer clicks do not autoplay "+scheme)
		check(root.gui_get_focus_owner()==null,"hint click leaves no focused UI control "+scheme)
		var action:=legal_nonwinning_action()
		var expected:=Rules.step(game.level,game.state,action)
		var code: Key={"U":KEY_UP,"D":KEY_DOWN,"L":KEY_LEFT,"R":KEY_RIGHT}[action] if scheme=="arrow" else {"U":KEY_W,"D":KEY_S,"L":KEY_A,"R":KEY_D}[action]
		var old: int=game.hint_request
		await real_key(code)
		await wait_motion()
		check(game.state.player==expected.player and game.state.crates==expected.crates and game.state.moves==expected.moves,"physical "+scheme+" key dispatch performs exactly expected move after pointer focus")
		no_hint("physical "+scheme+" movement cancels",old)
		var after:=snapshot()
		await create_timer(.28).timeout
		unchanged(after,"released physical "+scheme+" key does not leave stuck movement")
	# Escape and close through the actual GUI event pipeline, not direct methods.
	game.start_level(level_by_id("heaven_03"))
	await process_frame
	await real_key(KEY_H)
	check(game.hint_tier==1,"real H opens clue")
	await real_key(KEY_J)
	await wait_hint()
	check(game.hint_status=="solved","real J initiates next-push search")
	var old: int=game.hint_request
	await real_key(KEY_ESCAPE)
	no_hint("real Escape closes hint",old)
	check(game.mode=="level","real Escape closes panel before navigating")
	await click_hint("toggle")
	await click_hint("close")
	no_hint("real pointer close")
	var report: Dictionary={"passed":failures.is_empty(),"assertions":checks,"failures":failures,"engine":Engine.get_version_info().string,"scope":"Input.parse_input_event mouse motion/buttons and physical arrows/WASD/H/J/Escape through actual UI propagation, not direct handler calls."}
	var file:=FileAccess.open("res://tests/hint_ui_audit_input.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("HINT_UI_REAL_INPUT_AUDIT ",JSON.stringify(report))
	await game.finish_exit(0 if failures.is_empty() else 1)
