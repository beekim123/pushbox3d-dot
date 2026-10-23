extends "res://tests/keyboard_navigation.gd"

func run():
	Input.use_accumulated_input=false
	Engine.max_fps=240
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	var directory:="user://keyboard_exit_"+str(Time.get_ticks_usec())
	game.initialize_resume(directory)
	game.resume_session.debounce_ms=0
	game.resume_session.interval_ms=0
	game.start_level(game.levels_by_world.heaven[1])
	await flush_resume()
	var path: String=directory+"/resume.json"
	var saved:=FileAccess.get_file_as_bytes(path)
	game.resume_session.debounce_ms=60000
	await key(KEY_LEFT)
	game.cancel_motion()
	game.resume_session.protect("keyboard_explicit_exit_fixture")
	game.request_exit()
	# No frame/poll yet: Escape cannot cancel or bypass an active save attempt.
	event(KEY_ESCAPE,true)
	event(KEY_ESCAPE,false)
	check(game.exit_pending and not game.exit_waiting and not game.shutting_down,"Escape cannot bypass pending save")
	game.poll_resume_exit()
	await settle()
	check(focus_id()=="exit:return","safe Return remains the default before destructive choice")
	await key(KEY_TAB)
	check(focus_id()=="exit:unsaved","destructive choice requires explicit focus navigation")
	var code: Key=KEY_SPACE if "--keyboard-exit-key=space" in OS.get_cmdline_user_args() else KEY_ENTER
	await key(code)
	check(game.shutting_down and game.mode=="exiting","native chosen unsaved Exit invokes graceful termination")
	check(FileAccess.get_file_as_bytes(path)==saved,"chosen unsaved Exit preserves prior checkpoint bytes")
	var report:={"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"activation":str(code),"scope":"Separate terminating process; native focused unsaved Exit; process exit code verified by shell runner."}
	var name:="keyboard_exit_space" if code==KEY_SPACE else "keyboard_exit_enter"
	var file:=FileAccess.open(result_path(name+"_results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("KEYBOARD_EXIT_DISPATCH ",JSON.stringify(report))
	if not failures.is_empty(): quit(1)
	# Successful finish_exit should terminate the process before this watchdog.
	await create_timer(2.0).timeout
	print("KEYBOARD_FAIL chosen exit failed to terminate")
	quit(1)
