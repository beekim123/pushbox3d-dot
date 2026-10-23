extends SceneTree
var app
var failures: Array=[]
var checks:=0
var variant:="enter"
func _initialize(): call_deferred("audit")
func check(ok: bool,label: String):
	checks+=1
	if not ok: failures.append(label); print("INDEPENDENT_EXIT_FAIL ",label)
func event(k: Key,pressed: bool):
	var e:=InputEventKey.new()
	e.keycode=k;e.physical_keycode=k;e.pressed=pressed
	Input.parse_input_event(e)
func key(k: Key):
	event(k,true)
	await process_frame
	event(k,false)
	await process_frame
	await process_frame
func selected() -> String:
	var b:=root.gui_get_focus_owner()
	return str(b.get_meta("focus_action","")) if b!=null else ""
func audit():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--activation="): variant=arg.trim_prefix("--activation=")
	Input.use_accumulated_input=false
	Engine.max_fps=240
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.initialize_resume("user://independent_unsaved_"+variant+"_"+str(Time.get_ticks_usec()))
	app.start_level(app.levels_by_world.heaven[1])
	app.resume_session.protect("independent_unsaved_exit_failure")
	app.request_exit()
	app.poll_resume_exit()
	await process_frame
	await process_frame
	check(app.exit_pending and app.exit_waiting and selected()=="exit:return","failed exit starts at safe Return")
	var before: Dictionary={"state":app.state.duplicate(true),"history":app.history.duplicate(true)}
	await key(KEY_TAB)
	check(selected()=="exit:unsaved","explicit Tab is required to select unsaved Exit")
	await key({"enter":KEY_ENTER,"space":KEY_SPACE,"keypad":KEY_KP_ENTER}[variant])
	check(app.shutting_down and app.mode=="exiting","chosen activation starts real orderly exit")
	check(app.state==before.state and app.history==before.history,"exit activation does not add a game action")
	var f:=FileAccess.open(OS.get_environment("KEYBOARD_AUDIT_OUT")+"/exit_"+variant+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"main_sha256":FileAccess.get_file_as_string("res://scripts/main.gd").sha256_text(),"checks":checks,"failures":failures,"activation":variant,"actual_finish_exit_started":app.shutting_down,"scope":"Independent explicit unsaved-exit selection in a separate QA-isolated process; launcher also checks real process exit code."},"  "))
	f.close()
	print("INDEPENDENT_EXIT ",variant," ",JSON.stringify({"checks":checks,"failures":failures}))
	# Do not quit here: the actual chosen button's finish_exit must terminate us.
	await create_timer(2.0).timeout
	push_error("Chosen exit did not terminate the process")
	quit(3)
