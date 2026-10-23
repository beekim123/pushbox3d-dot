extends "res://tests/hint_ui_audit.gd"
func walk_action() -> String:
	for action in ["U","D","L","R"]:
		var next:=Rules.step(game.level,game.state,action)
		if not next.is_empty() and not next.pushed: return action
	return ""
func live_request() -> int:
	press("toggle");press("advance")
	for i in 6: await process_frame
	check(game.hint_active and game.hints.get_result().allocated_nodes>0,"pending interruption starts from genuinely allocated work")
	return game.hint_request
func drain_cancelled() -> void:
	var count:=0
	while game.hints.has_pending_cleanup() and count<2000:
		await process_frame
		count+=1
	check(not game.hints.has_pending_cleanup(),"interrupted work is eventually reclaimed by production process")
func run() -> void:
	Engine.max_fps=240
	root.size=Vector2i(1440,900)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	solver_instance=game.hints.get_instance_id()
	for operation in ["close","toggle","escape","move","undo","reset","same_level","new_level","help"]:
		game.start_level(level_by_id("inferno_44"))
		if operation in ["undo","reset"]:
			var action:=walk_action()
			check(not action.is_empty(),"history setup has a non-pushing walk")
			game.request_direction(action)
			await wait_motion()
		var before:=snapshot()
		var old:=await live_request()
		match operation:
			"close": press("close")
			"toggle": key(KEY_H)
			"escape": key(KEY_ESCAPE)
			"move": game.request_direction(walk_action())
			"undo": key(KEY_Z)
			"reset": key(KEY_R)
			"same_level": game.start_level(game.level)
			"new_level": game.start_level(level_by_id("city_03"))
			"help": key(KEY_F1)
		no_hint("live request "+operation,old)
		if operation in ["close","toggle","escape","help"]:
			unchanged(before,"live cancellation itself does not alter game "+operation)
		await drain_cancelled()
		if game.moving: await wait_motion()
		no_hint("after old work drained "+operation,old)
		if operation=="escape": check(game.mode=="level","Escape cancels pending hint without leaving board")
	# New explicit request while the previous graph is still retired.
	game.start_level(level_by_id("inferno_44"))
	var old:=await live_request()
	press("close")
	check(game.hints.has_pending_cleanup(),"replacement begins before prior retirement drains")
	press("toggle");press("advance")
	var current: int=game.hint_request
	check(current!=old and game.hint_active,"new explicit request replaces old pending generation")
	var result_before: Dictionary=game.hints.get_result(current)
	check(game.hints.step_budget(2,old).status=="stale","late callback for old request is rejected")
	check(game.hints.get_result(current).compute_ms==result_before.compute_ms,"late old callback does not advance new request")
	await wait_hint()
	check(game.hint_status=="solved" and game.hints.is_current(current,game.state),"only latest replacement result becomes visible")
	check(game.hint_answer.request_id==current and game.hint_answer.request_id!=old,"visible answer has new generation")
	var report: Dictionary={"passed":failures.is_empty(),"assertions":checks,"failures":failures,"engine":Engine.get_version_info().string,"operations":["close","toggle","escape","move","undo","reset","same_level","new_level","help","immediate_replacement"],"scope":"All interruption cases begin while actual inferno44 search has allocated nodes and is still running; cleanup uses real production _process."}
	var file:=FileAccess.open("res://tests/hint_ui_audit_pending.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("HINT_UI_PENDING_AUDIT ",JSON.stringify(report))
	await game.finish_exit(0 if failures.is_empty() else 1)
