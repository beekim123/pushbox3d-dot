extends "./independent_keyboard.gd"

func audit():
	root.size=Vector2i(1440,900)
	Input.use_accumulated_input=false
	Engine.max_fps=240
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	var directory:="user://independent_changed_token_"+str(Time.get_ticks_usec())
	app.initialize_resume(directory)
	app.resume_session.debounce_ms=0
	app.resume_session.interval_ms=0
	app.start_level(app.levels_by_world.heaven[1])
	await press(KEY_LEFT)
	await press(KEY_R)
	await flush_save()
	app.show_title()
	await settle()
	require(selected()=="continue" and not app.resume_button.disabled,"verified Continue initially owns title focus")
	var before:=capture_state()
	# Only this freshly generated QA sidecar is changed, not any user record.
	var path:=directory+"/resume.json"
	var changed_bytes:=FileAccess.get_file_as_string(path)+"\n"
	var f:=FileAccess.open(path,FileAccess.WRITE)
	f.store_string(changed_bytes)
	f.close()
	await press(KEY_ENTER)
	require(app.mode=="title" and app.resume_button.disabled and selected()=="hub","real token mismatch disables focused Continue and safely falls back")
	require(app.resume_session.paused and app.resume_session.candidate.is_empty(),"changed-token Continue preserves read-only protection")
	require(capture_state()==before and FileAccess.get_file_as_string(path)==changed_bytes,"failed Continue changes neither game history nor changed disk bytes")
	await inspect_ring("invalidated Continue")
	# Loss of Control focus without rebuilding keeps the remembered valid action.
	await tab_to("help")
	owner().release_focus()
	await settle()
	require(selected()=="help","loss of Control focus restores remembered valid action")
	# Suppress only main's key-release callback while the engine receives key-up.
	# This simulates stale latches after missed delivery, not physical hardware.
	for k in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_W,KEY_A,KEY_S,KEY_D]:
		app.start_level(app.levels_by_world.heaven[1])
		await press(KEY_F1)
		inject(k,true)
		await press(KEY_ESCAPE)
		before=capture_state()
		require(app.help_release_keys.has(k),"precondition held-key latch "+str(k))
		app.set_process_input(false)
		inject(k,false)
		app.set_process_input(true)
		await settle()
		require(app.help_release_keys.is_empty() and capture_state()==before,"physical-state clear repairs missing-keyup latch without movement "+str(k))
		var dir: String={KEY_UP:"U",KEY_DOWN:"D",KEY_LEFT:"L",KEY_RIGHT:"R",KEY_W:"U",KEY_A:"L",KEY_S:"D",KEY_D:"R"}[k]
		var expected: Dictionary=app.RULES.step(app.level,app.state,dir)
		inject(k,true)
		inject(k,false)
		await settle()
		app.cancel_motion()
		require(app.state==expected,"fresh direction accepted after missing-keyup recovery "+str(k))
	for k in [KEY_ENTER,KEY_SPACE,KEY_KP_ENTER]:
		app.show_title()
		await settle()
		inject(k,true)
		await settle()
		app.set_process_input(false)
		inject(k,false)
		app.set_process_input(true)
		await settle()
		require(app.activation_down.is_empty() and app.activation_release_keys.is_empty(),"activation physical-state-clear fallback "+str(k))
		await press(k)
		require(app.mode=="world","activation works after missing-keyup recovery "+str(k))
	var report:={"main_sha256":FileAccess.get_file_as_string("res://scripts/main.gd").sha256_text(),"checks":checks,"failures":failures,"scope":"Independent real QA sidecar token invalidation, focused control fallback, and missed-keyup recovery. For the latter main._input is temporarily disabled only while key-up reaches the engine, then reenabled before process fallback. This is an engine simulation, not a hardware focus-loss claim."}
	f=FileAccess.open(OS.get_environment("KEYBOARD_AUDIT_OUT")+"/fallback_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"  "))
	f.close()
	print("INDEPENDENT_FALLBACK ",JSON.stringify(report))
	await app.finish_exit(0 if failures.is_empty() else 1)
