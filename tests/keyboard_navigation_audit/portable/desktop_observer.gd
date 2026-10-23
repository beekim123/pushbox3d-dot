extends SceneTree

class Observer extends Node:
	var app
	var serial:=0
	var key_log: FileAccess
	func _ready():
		DirAccess.make_dir_recursive_absolute(OS.get_environment("KEYBOARD_AUDIT_OUT")+"/desktop")
		key_log=FileAccess.open(OS.get_environment("KEYBOARD_AUDIT_OUT")+"/desktop/events.jsonl",FileAccess.WRITE)
		capture.call_deferred("launch")
	func _input(event: InputEvent):
		if event is InputEventKey:
			key_log.store_line(JSON.stringify({"keycode":event.keycode,"physical_keycode":event.physical_keycode,"pressed":event.pressed,"echo":event.echo,"at_ms":Time.get_ticks_msec()}))
			key_log.flush()
			if event.pressed and not event.echo and event.keycode==KEY_F9:
				# Explicit QA setup only, not an ordinary gameplay interaction.
				app.initialize_resume("user://desktop_independent_"+str(Time.get_ticks_usec()))
				app.mark_resume_changed()
				app.resume_session.protect("desktop_independent_failure")
				app.request_exit()
				app.poll_resume_exit()
			if not event.pressed: capture.call_deferred(OS.get_keycode_string(event.keycode))
			if event.pressed and not event.echo and event.keycode==KEY_F8: app.finish_exit(0)
	func capture(label: String):
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if app.shutting_down: return
		serial+=1
		var stem:="%03d_%s"%[serial,label.replace("/","_")]
		var b:=get_viewport().gui_get_focus_owner()
		var info:={"label":label,"mode":app.mode,"world":app.active_world,"level":app.level.get("id",""),"moves":app.state.get("moves",0),"history_size":app.history.size(),"focus":str(b.get_meta("focus_action","")) if b!=null else "","modal":app.modal!=null,"exit_pending":app.exit_pending,"exit_waiting":app.exit_waiting,"display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name()}
		get_viewport().get_texture().get_image().save_png(OS.get_environment("KEYBOARD_AUDIT_OUT")+"/desktop/"+stem+".png")
		var f:=FileAccess.open(OS.get_environment("KEYBOARD_AUDIT_OUT")+"/desktop/"+stem+".json",FileAccess.WRITE)
		f.store_string(JSON.stringify(info,"  "))
		f.close()
		print("DESKTOP_OBSERVATION ",JSON.stringify(info))

func _initialize(): call_deferred("run")
func run():
	root.size=Vector2i(1440,900)
	var app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	var observer:=Observer.new()
	observer.app=app
	root.add_child(observer)
