extends SceneTree
const Rules=preload("res://scripts/puzzle_rules.gd")
var game: Node
var failures: Array[String]=[]
var checks:=0
var observations: Array=[]
var pump_frames:=0
var solver_instance:=0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		print("HINT_UI_AUDIT_FAIL ",label)
func level_by_id(id: String) -> Dictionary:
	for entry in game.levels:
		if entry.id==id: return entry
	return {}
func snapshot() -> Dictionary:
	return {"state":game.state.duplicate(true),"history":game.history.duplicate(true),"progress":game.progress.duplicate(true)}
func unchanged(before: Dictionary,label: String) -> void:
	check(game.state==before.state and game.history==before.history and game.progress==before.progress,label)
func hint_buttons(action: String) -> Array:
	return game.ui.find_children("","Button",true,false).filter(func(button): return button.get_meta("hint_action","")==action)
func press(action: String) -> void:
	var buttons:=hint_buttons(action)
	check(buttons.size()==1,"exactly one actual hint button "+action)
	if buttons.size()==1:
		check(not buttons[0].disabled,"hint button enabled "+action)
		buttons[0].pressed.emit()
func press_text(text: String) -> void:
	var buttons: Array=game.ui.find_children("","Button",true,false).filter(func(button): return button.text==text)
	check(buttons.size()==1,"actual button found "+text)
	if buttons.size()==1: buttons[0].pressed.emit()
func key(code: Key,echo: bool=false) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.pressed=true
	event.echo=echo
	game._unhandled_key_input(event)
func message_text() -> String:
	var labels: Array=game.ui.find_children("","Label",true,false).filter(func(label): return bool(label.get_meta("hint_message",false)))
	return labels[0].text if labels.size()==1 else ""
func wait_hint() -> void:
	var began:=Time.get_ticks_usec()
	var frames:=0
	while game.hint_active and frames<4000 and Time.get_ticks_usec()-began<60000000:
		await process_frame
		frames+=1
	pump_frames+=frames
	check(not game.hint_active,"active hint finishes within test observation window")
func wait_motion() -> void:
	var frames:=0
	while game.moving and frames<1000:
		await process_frame
		frames+=1
	check(not game.moving,"real movement tween finishes")
func no_hint(label: String,old: int=-1) -> void:
	check(not is_instance_valid(game.hint_panel) and not is_instance_valid(game.hint_overlay),label+" removes panel/overlay immediately")
	check(not game.hint_active and game.hint_answer.is_empty() and game.hint_tier==0,label+" clears active answer")
	if old>=0: check(game.hints.get_result(old).status=="stale",label+" invalidates old request")
	check(game.hints.get_instance_id()==solver_instance,label+" keeps persistent solver instance")
func check_geometry() -> void:
	await process_frame
	await process_frame
	var viewport:=Rect2(Vector2.ZERO,Vector2(root.size))
	if is_instance_valid(game.hint_panel):
		check(viewport.encloses(game.hint_panel.get_global_rect()),"hint panel remains in viewport")
	for button in game.ui.find_children("","Button",true,false):
		if button.has_meta("hint_action"):
			check(viewport.encloses(button.get_global_rect()),"hint button remains in viewport "+str(button.get_meta("hint_action")))
	if is_instance_valid(game.hint_overlay):
		check(game.hint_overlay.mouse_filter==Control.MOUSE_FILTER_IGNORE,"overlay cannot intercept input")
		var center: Vector2=game.hint_overlay.point(game.hint_answer.box,0.75)
		check(viewport.has_point(center),"hinted box projects inside viewport")
		check(not game.hint_panel.get_global_rect().has_point(center),"hint panel does not cover hinted box center")
func solved_hint() -> int:
	if is_instance_valid(game.hint_panel): game.invalidate_hint()
	var before:=snapshot()
	var generation: int=game.hints.get_result().request_id
	press("toggle")
	check(game.hint_tier==1 and game.hint_status=="clue" and not game.hint_active,"first layer is a spoiler-light rule clue without search")
	check(game.hints.get_result().request_id==generation,"opening clue does not begin search")
	unchanged(before,"tier1 does not autoplay or change progress")
	press("advance")
	var request: int=game.hint_request
	check(game.hint_active and request>=0,"actual advance starts current-state search")
	game.advance_hint()
	key(KEY_J)
	check(game.hint_request==request,"repeated advance while running does not create new request")
	await wait_hint()
	check(game.hint_status=="solved" and game.hint_tier==2,"search reveals next push only after explicit advance")
	if game.hint_status!="solved": return request
	check(game.hints.is_current(request,game.state),"displayed result matches current source")
	check(is_instance_valid(game.hint_overlay) and game.hint_overlay.tier==2,"next-push overlay is attached at tier2")
	check(not game.hint_answer.has("solution_actions"),"UI never requests full answer string")
	check(game.hint_answer.limits.max_frontier==8000,"UI uses production 8000-node cap")
	unchanged(before,"search and tier2 do not autoplay or change progress")
	var witness: Dictionary=game.state.duplicate(true)
	for action in game.hint_answer.walk_actions:
		var next:=Rules.step(game.level,witness,action)
		check(not next.is_empty() and not next.pushed,"displayed approach is legal and non-pushing")
		if next.is_empty(): break
		witness=next
	var push:=Rules.step(game.level,witness,game.hint_answer.direction)
	check(not push.is_empty() and push.pushed,"displayed next push is legal under original rules")
	await check_geometry()
	press("advance")
	check(game.hint_tier==3 and game.hint_overlay.tier==3 and game.hint_request==request,"route requires another explicit click without a new search")
	unchanged(before,"tier3 route never moves entities or writes progress")
	await check_geometry()
	return request
func legal_nonwinning_action() -> String:
	for action in ["U","D","L","R"]:
		var next:=Rules.step(game.level,game.state,action)
		if not next.is_empty() and not Rules.won(game.level,next): return action
	return ""
func run() -> void:
	Engine.max_fps=240
	root.size=Vector2i(1440,900)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	solver_instance=game.hints.get_instance_id()
	check(game.qa_mode,"QA flag prevents primary save load/write")
	check(not FileAccess.file_exists("user://fourfold_progress.json"),"isolated QA has no primary save")
	for id in ["heaven_03","inferno_03","rainforest_03","city_03","confluence_01"]:
		game.start_level(level_by_id(id))
		var request:=await solved_hint()
		observations.append({"level":id,"status":game.hint_status,"tier":game.hint_tier,"walk_length":game.hint_answer.get("walk_actions","").length()})
		press("close")
		no_hint("actual close "+id,request)
	# Real movement, current-state hint, undo and undo-reset.
	game.start_level(level_by_id("heaven_03"))
	var initial:=snapshot()
	var request:=await solved_hint()
	var action:=legal_nonwinning_action()
	check(not action.is_empty(),"movement fixture has a legal nonwinning action")
	game.request_direction(action)
	no_hint("legal move",request)
	var moving_snapshot:=snapshot()
	key(KEY_H)
	key(KEY_J)
	no_hint("hint keys while moving")
	unchanged(moving_snapshot,"hint keys during movement add no extra action")
	await wait_motion()
	var moved:=snapshot()
	request=await solved_hint()
	check(game.hint_answer.source_key!=game.hints._key(game.hints._normalize(initial.state).p,game.hints._normalize(initial.state).boxes),"midgame hint signature is not the opening state")
	key(KEY_Z)
	no_hint("undo",request)
	unchanged(initial,"undo after hint restores exact original state/history/progress")
	game.request_direction(action)
	await wait_motion()
	moved=snapshot()
	request=await solved_hint()
	key(KEY_R)
	no_hint("reset",request)
	check(game.state==Rules.initial(game.level),"reset still restores initial puzzle")
	request=await solved_hint()
	key(KEY_Z)
	no_hint("undo reset",request)
	unchanged(moved,"undo-reset retains original game's history semantics")
	# Keyboard close priority and modal interruption.
	request=await solved_hint()
	key(KEY_ESCAPE)
	no_hint("Escape closes hint first",request)
	check(game.mode=="level","first Escape does not unexpectedly leave level")
	key(KEY_H,true)
	no_hint("echo H ignored")
	key(KEY_H)
	check(game.hint_tier==1,"H opens clue")
	key(KEY_H)
	no_hint("H toggles closed")
	key(KEY_J)
	no_hint("J while closed does not reveal anything")
	request=await solved_hint()
	key(KEY_F1)
	no_hint("help interruption",request)
	check(is_instance_valid(game.modal),"help modal is open")
	key(KEY_H);key(KEY_J)
	no_hint("hint keys behind modal ignored")
	key(KEY_ESCAPE)
	check(not is_instance_valid(game.modal) and game.mode=="level","Escape closes help without opening old hints")
	# Menu/same-level/new-level invalidation and persistent identity.
	for destination in ["same_level","new_level","world","hub","title"]:
		game.start_level(level_by_id("heaven_03"))
		request=await solved_hint()
		match destination:
			"same_level": game.start_level(game.level)
			"new_level": game.start_level(level_by_id("city_03"))
			"world": press_text("选关")
			"hub": press_text("织机中庭")
			"title":
				press_text("织机中庭")
				key(KEY_ESCAPE)
		no_hint("navigation "+destination,request)
	# Genuine budget terminal produced by the solver after the REAL handler starts.
	game.start_level(level_by_id("heaven_03"))
	press("toggle");press("advance")
	request=game.hint_request
	game.hints.set("_max_frontier",0) # test-only branch forcing; no UI option exists.
	await wait_hint()
	check(game.hint_status=="budget_exhausted","budget path reaches actual UI terminal status")
	check("达到上限" in message_text() and "不代表无解" in message_text() and "已确认" not in message_text(),"budget text never mislabels exhaustion as proven deadlock")
	check(not is_instance_valid(game.hint_overlay) and game.hint_answer.is_empty(),"budget message has no partial/stale arrows")
	# Known legal dead and solved states; distinct statuses, no automatic mutation.
	var cases: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/hint_ui_audit_cases.json"))
	for item in cases:
		game.start_level(level_by_id(item.level_id))
		game.state={"player":Rules.cell(item.state.player),"crates":Rules.cells(item.state.crates),"moves":7,"pushes":3}
		game.world.sync_state(game.state)
		var before:=snapshot()
		press("toggle")
		if item.expected_status!="already_solved":
			press("advance")
			await wait_hint()
		check(game.hint_status==item.expected_status,"separate real UI status "+item.case_id)
		check(not is_instance_valid(game.hint_overlay),"non-solved status never draws answer "+item.case_id)
		unchanged(before,"non-solved status never mutates puzzle "+item.case_id)
	# Menu cleanup with actual allocated search work, not a forged node graph.
	game.start_level(level_by_id("inferno_44"))
	press("toggle");press("advance")
	for i in 6: await process_frame
	check(game.hint_active and game.hints.get_result().allocated_nodes>0,"heavy request is live before interruption")
	request=game.hint_request
	press_text("选关")
	no_hint("menu cancels pending search",request)
	check(game.hints.has_pending_cleanup(),"menu retains pending cleanup for incremental release")
	var cleanup_frames:=0
	while game.hints.has_pending_cleanup() and cleanup_frames<4000:
		await process_frame
		cleanup_frames+=1
	check(not game.hints.has_pending_cleanup() and cleanup_frames>0,"menu's real _process drains cleanup without active hint")
	check(game.mode=="world" and not game.hint_active,"background cleanup neither navigates nor restarts hint")
	observations.append({"menu_cleanup_frames":cleanup_frames})
	# Defensive state signature: bypassing a handler must still reject old result.
	game.start_level(level_by_id("heaven_03"))
	press("toggle");press("advance")
	request=game.hint_request
	action=legal_nonwinning_action()
	game.state=Rules.step(game.level,game.state,action)
	game.world.sync_state(game.state)
	await wait_hint()
	no_hint("late result with changed state rejected",request)
	# Real winning move must clear the hint; undo-win must not resurrect it.
	game.start_level(level_by_id("heaven_01"))
	request=await solved_hint()
	var winning: String=game.hint_answer.direction
	game.request_direction(winning)
	no_hint("winning move",request)
	await wait_motion()
	check(game.win_shown and is_instance_valid(game.modal),"real win UI still works with hints installed")
	key(KEY_Z)
	no_hint("undo win")
	check(not game.win_shown and not is_instance_valid(game.modal),"undo-win closes completion without stale hints")
	check(not FileAccess.file_exists("user://fourfold_progress.json"),"entire QA wrote no primary save")
	var report: Dictionary={"passed":failures.is_empty(),"assertions":checks,"failures":failures,"observations":observations,"search_frames":pump_frames,"engine":Engine.get_version_info().string,"scope":"Production scene, real hint button signals/key handlers/process frames and original rules; budget cap overwritten only in the test to exercise its real UI branch."}
	var file:=FileAccess.open("res://tests/hint_ui_audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("HINT_UI_AUDIT ",JSON.stringify(report))
	await game.finish_exit(0 if failures.is_empty() else 1)
